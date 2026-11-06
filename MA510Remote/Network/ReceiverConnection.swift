import Foundation
import Network

/// A persistent TCP session with the receiver.
///
/// - Sends the 0x50 initialization query on connect and waits for the model reply.
/// - Streams every response (solicited or not) to `onEvent`, so knob turns and
///   IR-remote changes on the receiver show up live in the app.
/// - Keeps the link alive with a 0x50 query every 15 s (unlike 0x51, this does
///   not reset the receiver's auto-standby timer) and drops the link if the
///   receiver goes quiet.
///
/// All mutable state is confined to `queue`.
final class ReceiverConnection: @unchecked Sendable {
    enum Event: Sendable {
        case ready(modelCode: UInt8)
        case response(MAResponse)
        case closed(reason: String?)
    }

    let host: String
    let port: UInt16

    private let queue = DispatchQueue(label: "MA510Remote.receiver")
    private let onEvent: @Sendable (Event) -> Void
    private var connection: NWConnection?
    private var parser = MAResponseParser()
    private var initialized = false
    private var finished = false
    private var lastHeard = Date()
    private var handshakeTimer: DispatchSourceTimer?
    private var keepaliveTimer: DispatchSourceTimer?

    init(host: String, port: UInt16 = MA.port, onEvent: @escaping @Sendable (Event) -> Void) {
        self.host = host
        self.port = port
        self.onEvent = onEvent
    }

    func start() {
        queue.async { self.open() }
    }

    /// Close without emitting a `.closed` event (user-initiated).
    func cancel() {
        queue.async {
            guard !self.finished else { return }
            self.finished = true
            self.teardown()
        }
    }

    func send(_ frame: Data) {
        queue.async {
            guard self.initialized, !self.finished, let connection = self.connection else { return }
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                guard let self, let error else { return }
                self.queue.async { self.finish("Send failed: \(error.localizedDescription)") }
            })
        }
    }

    func send(_ frames: [Data]) {
        for frame in frames { send(frame) }
    }

    // MARK: - Private (queue-confined)

    private func open() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return finish("Invalid port \(port).") }

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.prohibitedInterfaceTypes = [.cellular]   // the receiver lives on your home LAN

        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.handle(state)
        }
        handshakeTimer = makeTimer(after: 6) { [weak self] in
            self?.finish("No answer from \(self?.host ?? "the receiver"). Check the IP address and that the receiver is on (not in Green standby).")
        }
        connection.start(queue: queue)
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            lastHeard = Date()
            receive()
            connection?.send(content: MAFrame.query(.initialize), completion: .contentProcessed { _ in })
        case .waiting(let error):
            finish("Can't reach \(host): \(Self.describe(error))")
        case .failed(let error):
            finish("Connection failed: \(Self.describe(error))")
        case .cancelled:
            finish(nil)
        default:
            break
        }
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self, !self.finished else { return }
            if let data, !data.isEmpty {
                self.lastHeard = Date()
                for response in self.parser.feed(data) { self.process(response) }
            }
            if let error { return self.finish("Connection lost: \(Self.describe(error))") }
            if isComplete { return self.finish("The receiver closed the connection.") }
            self.receive()
        }
    }

    private func process(_ response: MAResponse) {
        if !initialized {
            guard response.commandID == MA.Command.initialize.rawValue else { return }
            guard response.isOK, let model = response.data.first else {
                return finish("The device at \(host) refused initialization (\(response.errorMessage)).")
            }
            initialized = true
            handshakeTimer?.cancel(); handshakeTimer = nil
            startKeepalive()
            onEvent(.ready(modelCode: model))
            return
        }
        // Keepalive acknowledgements are internal.
        if response.commandID == MA.Command.initialize.rawValue && response.isOK { return }
        onEvent(.response(response))
    }

    private func startKeepalive() {
        keepaliveTimer = makeTimer(after: 15, repeating: 15) { [weak self] in
            guard let self, let connection = self.connection else { return }
            if Date().timeIntervalSince(self.lastHeard) > 40 {
                return self.finish("The receiver stopped responding.")
            }
            connection.send(content: MAFrame.query(.initialize), completion: .contentProcessed { _ in })
        }
    }

    private func finish(_ reason: String?) {
        guard !finished else { return }
        finished = true
        teardown()
        onEvent(.closed(reason: reason))
    }

    private func teardown() {
        handshakeTimer?.cancel(); handshakeTimer = nil
        keepaliveTimer?.cancel(); keepaliveTimer = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        initialized = false
    }

    private func makeTimer(after delay: TimeInterval, repeating interval: TimeInterval? = nil, _ handler: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        if let interval {
            timer.schedule(deadline: .now() + delay, repeating: interval)
        } else {
            timer.schedule(deadline: .now() + delay)
        }
        timer.setEventHandler(handler: handler)
        timer.resume()
        return timer
    }

    static func describe(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED: return "connection refused (is IP control available? Green standby disables it)"
            case .EHOSTUNREACH, .EHOSTDOWN: return "host unreachable"
            case .ENETUNREACH, .ENETDOWN: return "network unavailable — is your iPhone on Wi-Fi?"
            case .ETIMEDOUT: return "timed out"
            default: return error.localizedDescription
            }
        default:
            return error.localizedDescription
        }
    }
}

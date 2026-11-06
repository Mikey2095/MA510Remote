import Foundation
import Network
import Darwin

struct DiscoveredReceiver: Identifiable, Hashable {
    let host: String
    let modelCode: UInt8
    var id: String { host }
    var modelName: String { MA.modelName(modelCode) }
}

enum LocalNetwork {
    /// Accepts private-LAN IPv4 addresses only (10/8, 172.16/12, 192.168/16, 169.254/16).
    static func validatedIPv4(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [Int] = []
        for part in parts {
            guard (1...3).contains(part.count), part.allSatisfy(\.isNumber), let value = Int(part), value <= 255 else { return nil }
            octets.append(value)
        }
        let isPrivate = octets[0] == 10
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 169 && octets[1] == 254)
        return isPrivate ? octets.map(String.init).joined(separator: ".") : nil
    }

    /// The iPhone's own Wi-Fi IPv4 address and netmask, as host-order integers.
    static func wifiInterface() -> (address: UInt32, mask: UInt32)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var fallback: (UInt32, UInt32)?
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let flags = Int32(bitPattern: entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  let netmask = entry.ifa_netmask else { continue }
            let name = String(cString: entry.ifa_name)
            let ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            if name == "en0" { return (ip, mask) }
            if name.hasPrefix("en") { fallback = (ip, mask) }
        }
        return fallback
    }

    static func format(_ ip: UInt32) -> String {
        "\(ip >> 24 & 0xFF).\(ip >> 16 & 0xFF).\(ip >> 8 & 0xFF).\(ip & 0xFF)"
    }

    /// Hosts on the phone's subnet, limited to its /24 so a scan stays quick.
    static func candidateHosts() -> [String] {
        guard let interface = wifiInterface() else { return [] }
        let ip = interface.address
        let mask = max(interface.mask, 0xFFFF_FF00)
        let network = ip & mask
        let broadcast = network | ~mask
        guard broadcast > network + 1 else { return [] }
        return ((network + 1)..<broadcast).filter { $0 != ip }.map(format)
    }
}

enum NetworkScanner {
    /// Probes every host on the local /24 for an MA-series receiver on port 50000.
    static func scan(progress: @escaping @Sendable (Double) -> Void) async -> [DiscoveredReceiver] {
        let hosts = LocalNetwork.candidateHosts()
        guard !hosts.isEmpty else { return [] }

        var found: [DiscoveredReceiver] = []
        await withTaskGroup(of: DiscoveredReceiver?.self) { group in
            let width = 48
            var next = 0
            while next < min(width, hosts.count) {
                let host = hosts[next]
                group.addTask { await probe(host) }
                next += 1
            }
            var completed = 0
            while let result = await group.next() {
                completed += 1
                progress(Double(completed) / Double(hosts.count))
                if let result { found.append(result) }
                if next < hosts.count {
                    let host = hosts[next]
                    group.addTask { await probe(host) }
                    next += 1
                }
            }
        }
        return found.sorted { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
    }

    /// Connects, sends the 0x50 init query, and returns the receiver if it answers.
    static func probe(_ host: String, timeout: TimeInterval = 1.6) async -> DiscoveredReceiver? {
        await withCheckedContinuation { continuation in
            Probe(host: host, timeout: timeout) { model in
                continuation.resume(returning: model.map { DiscoveredReceiver(host: host, modelCode: $0) })
            }.start()
        }
    }
}

/// One short-lived probe. Keeps itself alive through its connection handlers until done.
private final class Probe: @unchecked Sendable {
    private let host: String
    private let timeout: TimeInterval
    private let completion: (UInt8?) -> Void
    private let queue = DispatchQueue(label: "MA510Remote.probe")
    private var connection: NWConnection?
    private var parser = MAResponseParser()
    private var done = false

    init(host: String, timeout: TimeInterval, completion: @escaping (UInt8?) -> Void) {
        self.host = host
        self.timeout = timeout
        self.completion = completion
    }

    func start() {
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 2
        tcp.noDelay = true
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: MA.port)!, using: NWParameters(tls: nil, tcp: tcp))
        self.connection = connection
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: MAFrame.query(.initialize), completion: .contentProcessed { _ in })
                self.receive()
            case .failed, .waiting:
                self.finish(nil)
            default:
                break
            }
        }
        queue.asyncAfter(deadline: .now() + timeout) { self.finish(nil) }
        connection.start(queue: queue)
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, isComplete, error in
            if let data {
                let reply = self.parser.feed(data).first { $0.commandID == MA.Command.initialize.rawValue && $0.isOK }
                if let model = reply?.data.first { return self.finish(model) }
            }
            if error != nil || isComplete { return self.finish(nil) }
            self.receive()
        }
    }

    private func finish(_ model: UInt8?) {
        guard !done else { return }
        done = true
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        completion(model)
    }
}

import Foundation
import Observation

enum ControlMode: String {
    case demo, live
}

enum LinkState: Equatable {
    case offline
    case connecting
    case connected(model: String)
    case reconnecting
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct Favorite: Codable, Equatable {
    var sourceRaw: UInt8
    var modeRaw: UInt8
    var volume: Int

    var source: InputSource { InputSource(rawValue: sourceRaw) ?? .bluetooth }
    var mode: SurroundMode { SurroundMode(rawValue: modeRaw) ?? .allStereo }

    static let standard = Favorite(sourceRaw: InputSource.bluetooth.rawValue, modeRaw: SurroundMode.allStereo.rawValue, volume: 32)
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
}

/// App state + every receiver action. In demo mode actions only change local state;
/// in live mode they are sent to the receiver, and the receiver's replies (and any
/// changes made with the knob or original remote) flow back into this state.
@MainActor
@Observable
final class RemoteStore {

    // MARK: Settings (persisted)

    var controlMode: ControlMode { didSet { defaults.set(controlMode.rawValue, forKey: Keys.mode) } }
    var host: String { didSet { defaults.set(host, forKey: Keys.host) } }
    var volumeCap: Int { didSet { defaults.set(volumeCap, forKey: Keys.cap); if volume > volumeCap, !link.isConnected { volume = volumeCap } } }
    var roomName: String { didSet { defaults.set(roomName, forKey: Keys.room) } }
    var favorite: Favorite { didSet { if let data = try? JSONEncoder().encode(favorite) { defaults.set(data, forKey: Keys.favorite) } } }

    // MARK: Link

    var link: LinkState = .offline
    var isScanning = false
    var scanProgress = 0.0
    var discovered: [DiscoveredReceiver] = []

    // MARK: Receiver state

    var power = true
    var volume = 32
    var muted = false
    var source: InputSource = .bluetooth
    var surround: SurroundMode = .allStereo
    var unsupportedSurroundCode: UInt8?
    var bass = 0
    var treble = 0
    var displayDim = 0
    var dialogEnhancement = false
    var roomEQ = false
    var streaming: StreamingStatus?
    var demoPlaying = true

    // MARK: UI feedback

    var lastAction = "Remote loaded · demo mode"
    var toast: Toast?
    var hapticTick = 0
    var isAdjustingVolume = false

    var isLive: Bool { controlMode == .live }
    var canControl: Bool { controlMode == .demo || link.isConnected }
    var isPlaying: Bool { isLive ? (streaming?.isPlaying ?? false) : demoPlaying }

    // MARK: Private

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var connection: ReceiverConnection?
    @ObservationIgnored private var connectionToken = UUID()
    @ObservationIgnored private var wantsConnection = false
    @ObservationIgnored private var hasConnectedOnce = false
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryDelay: Double = 1
    @ObservationIgnored private var volumeTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var resyncTask: Task<Void, Never>?

    private enum Keys {
        static let mode = "controlMode", host = "receiverHost", cap = "volumeCap"
        static let room = "roomName", favorite = "favorite"
    }

    init() {
        let d = UserDefaults.standard
        controlMode = ControlMode(rawValue: d.string(forKey: Keys.mode) ?? "") ?? .demo
        host = d.string(forKey: Keys.host) ?? ""
        let savedCap = d.integer(forKey: Keys.cap)
        volumeCap = savedCap == 0 ? 65 : max(10, min(99, savedCap))
        roomName = d.string(forKey: Keys.room) ?? "Living room"
        if let data = d.data(forKey: Keys.favorite), let fav = try? JSONDecoder().decode(Favorite.self, from: data) {
            favorite = fav
        } else {
            favorite = .standard
        }
    }

    // MARK: - Connection lifecycle

    /// Called on launch and whenever the app returns to the foreground.
    func resume() {
        guard controlMode == .live, LocalNetwork.validatedIPv4(host) != nil else { return }
        wantsConnection = true
        if connection == nil { open() }
    }

    /// Called when the app goes to the background — iOS would suspend the socket anyway.
    func suspend() {
        retryTask?.cancel()
        connection?.cancel()
        connection = nil
        if controlMode == .live { link = .offline }
    }

    func connect() {
        guard let ip = LocalNetwork.validatedIPv4(host) else {
            link = .failed("Enter the receiver's local IP address, like 192.168.1.80.")
            return
        }
        host = ip
        controlMode = .live
        wantsConnection = true
        hasConnectedOnce = false
        retryDelay = 1
        open()
    }

    func useDemo() {
        wantsConnection = false
        retryTask?.cancel()
        connection?.cancel()
        connection = nil
        link = .offline
        controlMode = .demo
        streaming = nil
        log("Demo mode activated")
    }

    func disconnect() {
        useDemo()
    }

    private func open() {
        retryTask?.cancel()
        connection?.cancel()
        let token = UUID()
        connectionToken = token
        if link != .reconnecting { link = .connecting }
        let connection = ReceiverConnection(host: host) { [weak self] event in
            Task { @MainActor [weak self] in self?.handle(event, token: token) }
        }
        self.connection = connection
        connection.start()
    }

    private func handle(_ event: ReceiverConnection.Event, token: UUID) {
        guard token == connectionToken else { return }   // stale connection
        switch event {
        case .ready(let code):
            link = .connected(model: MA.modelName(code))
            hasConnectedOnce = true
            retryDelay = 1
            if code != 0x01 { show("Connected to \(MA.modelName(code)) — this app is tuned for the MA510") }
            log("LIVE · Connected to \(MA.modelName(code)) at \(host)")
            syncAll()
        case .response(let response):
            apply(response)
        case .closed(let reason):
            connection = nil
            guard wantsConnection, controlMode == .live else { link = .offline; return }
            if hasConnectedOnce {
                link = .reconnecting
                log("Link dropped · reconnecting")
                scheduleRetry()
            } else {
                wantsConnection = false
                link = .failed(Self.hint(for: reason))
            }
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 15)
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.wantsConnection, self.connection == nil else { return }
            self.open()
        }
    }

    private static func hint(for reason: String?) -> String {
        let base = reason ?? "Couldn't connect."
        return base + "\nIf iOS asked about Local Network access, allow it in Settings › MA510 Remote and try again."
    }

    // MARK: - Discovery

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        discovered = []
        Task { [weak self] in
            let results = await NetworkScanner.scan { [weak self] value in
                Task { @MainActor [weak self] in self?.scanProgress = value }
            }
            guard let self else { return }
            self.isScanning = false
            self.discovered = results
            if results.isEmpty {
                self.show("No receiver answered on port 50000. Is it awake and on this Wi-Fi?")
            } else if results.count == 1 {
                self.host = results[0].host
            }
        }
    }

    // MARK: - State sync

    func syncAll() {
        guard isLive, let connection, link.isConnected else { return }
        let queries: [MA.Command] = [.power, .volume, .mute, .source, .surround, .bass, .treble,
                                     .displayDim, .dialogEnhancement, .roomEQ, .streamingState]
        connection.send(queries.map(MAFrame.query))
        log("LIVE · Synced receiver state")
    }

    private func resyncSoon(after seconds: Double = 4) {
        resyncTask?.cancel()
        resyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.syncAll()
        }
    }

    private func apply(_ response: MAResponse) {
        guard let command = response.command else { return }
        guard response.isOK else {
            let notNow = response.code == MA.ResponseCode.invalidNow.rawValue
            if command == .roomEQ && notNow {
                roomEQ = false
                show("Room EQ needs an EZ Set EQ calibration on the receiver first")
            } else if !(command == .streamingState && notNow) {
                show("\(command.label): \(response.errorMessage)\(power ? "" : " — receiver is in standby")")
            }
            // Re-read the real value so the UI never lies after a rejection.
            if command != .simulatedIR, let connection { connection.send(MAFrame.query(command)) }
            return
        }
        guard let value = response.data.first else { return }
        switch command {
        case .power:
            let wasOn = power
            power = value == 0x01
            if power && !wasOn { resyncSoon() }
        case .volume:
            if !isAdjustingVolume { volume = Int(value) }
        case .mute:
            muted = value == 0x01
        case .source:
            if let s = InputSource(rawValue: value) { source = s }
            connection?.send(MAFrame.query(.streamingState))
        case .surround:
            if let mode = SurroundMode(rawValue: value) { surround = mode; unsupportedSurroundCode = nil }
            else { unsupportedSurroundCode = value }
        case .bass: bass = MA.decodeTone(value)
        case .treble: treble = MA.decodeTone(value)
        case .displayDim: displayDim = Int(min(value, 3))
        case .dialogEnhancement: dialogEnhancement = value == 0x01
        case .roomEQ: roomEQ = value != 0x00
        case .streamingState:
            if response.data.count >= 2 { streaming = StreamingStatus(server: value, state: response.data[1]) }
        default:
            break
        }
    }

    // MARK: - Actions

    private func perform(_ description: String, _ frame: Data?, change: () -> Void) {
        guard canControl else {
            show(link == .reconnecting ? "Reconnecting to the receiver…" : "Not connected — tap the status chip to connect")
            return
        }
        change()
        hapticTick += 1
        log((isLive ? "LIVE · " : "DEMO · ") + description)
        if isLive, let frame { connection?.send(frame) }
    }

    func togglePower() {
        let on = !power
        perform(on ? "POWER ON" : "STANDBY", MAFrame.encode(.power, [on ? 0x01 : 0x00])) { power = on }
        if on && isLive { resyncSoon() }
    }

    func toggleMute() {
        let on = !muted
        perform(on ? "MUTE" : "UNMUTE", MAFrame.encode(.mute, [on ? 0x01 : 0x00])) { muted = on }
    }

    func nudgeVolume(_ delta: Int) {
        if delta > 0 && volume >= volumeCap {
            show("Safety limit is \(volumeCap) — change it in Connection settings")
            return
        }
        setVolume(volume + delta)
    }

    /// Updates the UI immediately; the network write is coalesced so a slider drag
    /// doesn't flood the receiver.
    func setVolume(_ target: Int) {
        let value = max(0, min(volumeCap, target))
        guard canControl else { return perform("", nil) {} }
        volume = value
        hapticTick += 1
        volumeTask?.cancel()
        volumeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled, let self else { return }
            self.log((self.isLive ? "LIVE · " : "DEMO · ") + "VOLUME \(value)")
            if self.isLive { self.connection?.send(MAFrame.encode(.volume, [UInt8(value)])) }
        }
    }

    func setSource(_ newSource: InputSource) {
        perform("INPUT \(newSource.name)", MAFrame.encode(.source, [newSource.rawValue])) { source = newSource }
    }

    func stepSource(_ direction: Int) {
        let all = InputSource.allCases
        let index = all.firstIndex(of: source) ?? 0
        setSource(all[(index + direction + all.count) % all.count])
    }

    func setSurround(_ mode: SurroundMode) {
        perform("MODE \(mode.name)", MAFrame.encode(.surround, [mode.rawValue])) {
            surround = mode
            unsupportedSurroundCode = nil
        }
    }

    func cycleSurround() {
        let order: [SurroundMode] = [.allStereo, .native, .stereo20, .proLogic2, .stereo21]
        let index = order.firstIndex(of: surround) ?? -1
        setSurround(order[(index + 1) % order.count])
    }

    func press(_ key: RemoteKey) {
        perform("KEY \(key.label)", MAFrame.encode(.simulatedIR, key.irData)) {}
        show("\(key.label) sent" + (isLive ? " to receiver" : " (demo)"))
    }

    func setBass(_ db: Int) {
        let v = max(-12, min(12, db))
        perform("BASS \(v) dB", MAFrame.encode(.bass, [MA.encodeTone(v)])) { bass = v }
    }

    func setTreble(_ db: Int) {
        let v = max(-12, min(12, db))
        perform("TREBLE \(v) dB", MAFrame.encode(.treble, [MA.encodeTone(v)])) { treble = v }
    }

    func setDisplayDim(_ level: Int) {
        let v = max(0, min(3, level))
        perform("DISPLAY \(["FULL", "50%", "25%", "OFF"][v])", MAFrame.encode(.displayDim, [UInt8(v)])) { displayDim = v }
    }

    func cycleDisplayDim() { setDisplayDim((displayDim + 1) % 4) }

    func toggleDialogEnhancement() {
        let on = !dialogEnhancement
        perform("DIALOG \(on ? "ON" : "OFF")", MAFrame.encode(.dialogEnhancement, [on ? 1 : 0])) { dialogEnhancement = on }
    }

    func toggleRoomEQ() {
        let on = !roomEQ
        perform("ROOM EQ \(on ? "EZ SET EQ" : "OFF")", MAFrame.encode(.roomEQ, [on ? 1 : 0])) { roomEQ = on }
    }

    /// Play/pause. Live mode uses the 0x11 streaming-state command for the
    /// current network stream (Spotify, AirPlay, etc.).
    func togglePlayback() {
        if !isLive {
            demoPlaying.toggle()
            log("DEMO · " + (demoPlaying ? "Play" : "Pause") + " (no audio is generated)")
            hapticTick += 1
            return
        }
        guard let stream = streaming, stream.hasServer else {
            show("Nothing streaming — use your music app or the receiver's Network input")
            return
        }
        let next: UInt8 = stream.isPlaying ? 0x02 : 0x01
        perform(next == 0x01 ? "PLAY" : "PAUSE", MAFrame.encode(.streamingState, [stream.server, next])) {
            streaming = StreamingStatus(server: stream.server, state: next)
        }
    }

    func skipTrack(_ direction: Int) {
        if isLive {
            show("The MA510's IP protocol has no next/previous track — use your music app")
        } else {
            log("DEMO · " + (direction > 0 ? "Next" : "Previous") + " preview track")
            hapticTick += 1
        }
    }

    func recallFavorite() {
        guard canControl else { return perform("", nil) {} }
        setSource(favorite.source)
        setSurround(favorite.mode)
        setVolume(min(favorite.volume, volumeCap))
        log((isLive ? "LIVE · " : "DEMO · ") + "FAVORITE \(favorite.source.name) · \(favorite.mode.name) · \(min(favorite.volume, volumeCap))")
        show("Favorite recalled")
    }

    func saveFavorite() {
        favorite = Favorite(sourceRaw: source.rawValue, modeRaw: surround.rawValue, volume: volume)
        hapticTick += 1
        show("Saved \(source.name) · \(surround.name) · \(volume) as favorite")
    }

    var isFavoriteActive: Bool {
        source == favorite.source && surround == favorite.mode
    }

    // MARK: - Feedback

    func show(_ message: String) {
        toast = Toast(message: message)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func log(_ message: String) {
        lastAction = message
    }
}

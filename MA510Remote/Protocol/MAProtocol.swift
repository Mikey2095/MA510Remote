import Foundation

/// JBL MA-Series IP Control protocol (v1.7, 2024-11-20).
///
/// Controller → receiver:  0x23  CmdID  DataLen  Data…  0x0D
/// Receiver → controller:  0x02 0x23  CmdID  RspCode  DataLen  Data…  0x0D
///
/// TCP port 50000. After connecting, send the 0x50 initialization query once;
/// the receiver answers with its model code and then accepts commands.
/// Sending 0xF0 as Data1 for any settable command queries its current value.
/// The receiver also pushes unsolicited status messages when something changes
/// from the front panel or the original IR remote.
enum MA {
    static let port: UInt16 = 50000
    static let query: UInt8 = 0xF0

    enum Command: UInt8, CaseIterable {
        case power = 0x00
        case displayDim = 0x01
        case softwareVersion = 0x02
        case simulatedIR = 0x04
        case source = 0x05
        case volume = 0x06
        case mute = 0x07
        case surround = 0x08
        case treble = 0x0B
        case bass = 0x0C
        case roomEQ = 0x0D
        case dialogEnhancement = 0x0E
        case dolbyMode = 0x0F
        case streamingState = 0x11
        case initialize = 0x50
        case heartbeat = 0x51

        var label: String {
            switch self {
            case .power: return "Power"
            case .displayDim: return "Display dim"
            case .softwareVersion: return "Software version"
            case .simulatedIR: return "Remote key"
            case .source: return "Input"
            case .volume: return "Volume"
            case .mute: return "Mute"
            case .surround: return "Surround mode"
            case .treble: return "Treble"
            case .bass: return "Bass"
            case .roomEQ: return "Room EQ"
            case .dialogEnhancement: return "Dialog enhancement"
            case .dolbyMode: return "Dolby mode"
            case .streamingState: return "Playback"
            case .initialize: return "Initialization"
            case .heartbeat: return "Heartbeat"
            }
        }
    }

    enum ResponseCode: UInt8 {
        case ok = 0x00
        case unknownCommand = 0xC1
        case unknownParameter = 0xC2
        case invalidNow = 0xC3
        case invalidLength = 0xC4

        var message: String {
            switch self {
            case .ok: return "OK"
            case .unknownCommand: return "command not recognized"
            case .unknownParameter: return "value not recognized"
            case .invalidNow: return "not available right now"
            case .invalidLength: return "invalid data length"
            }
        }
    }

    /// Model codes returned by the 0x50 initialization query.
    static func modelName(_ code: UInt8) -> String {
        switch code {
        case 0x01: return "MA510"
        case 0x02: return "MA710"
        case 0x03: return "MA7100HP"
        case 0x04: return "MA9100HP"
        default: return "Unknown model (0x\(String(code, radix: 16)))"
        }
    }

    /// Treble/bass: 0x00…0x0C = 0…+12 dB, 0xFF…0xF4 = −1…−12 dB (two's complement).
    static func encodeTone(_ db: Int) -> UInt8 {
        UInt8(bitPattern: Int8(max(-12, min(12, db))))
    }

    static func decodeTone(_ byte: UInt8) -> Int {
        max(-12, min(12, Int(Int8(bitPattern: byte))))
    }
}

// MARK: - Framing

enum MAFrame {
    static func encode(_ command: MA.Command, _ data: [UInt8] = []) -> Data {
        encode(id: command.rawValue, data)
    }

    static func encode(id: UInt8, _ data: [UInt8] = []) -> Data {
        precondition(data.count <= 255, "MA frames carry at most 255 data bytes")
        var bytes: [UInt8] = [0x23, id, UInt8(data.count)]
        bytes.append(contentsOf: data)
        bytes.append(0x0D)
        return Data(bytes)
    }

    static func query(_ command: MA.Command) -> Data {
        encode(command, [MA.query])
    }
}

struct MAResponse: Equatable {
    let commandID: UInt8
    let code: UInt8
    let data: [UInt8]

    var command: MA.Command? { MA.Command(rawValue: commandID) }
    var isOK: Bool { code == MA.ResponseCode.ok.rawValue }
    var errorMessage: String {
        MA.ResponseCode(rawValue: code)?.message ?? "error 0x\(String(code, radix: 16))"
    }
}

/// Incremental parser: TCP can split or merge frames, so bytes are buffered
/// until a complete, well-formed frame is available.
struct MAResponseParser {
    private(set) var buffer: [UInt8] = []

    mutating func feed<S: Sequence>(_ bytes: S) -> [MAResponse] where S.Element == UInt8 {
        buffer.append(contentsOf: bytes)
        var responses: [MAResponse] = []
        var i = 0
        while buffer.count - i >= 6 {
            guard buffer[i] == 0x02, buffer[i + 1] == 0x23 else { i += 1; continue }
            let length = Int(buffer[i + 4])
            let total = 6 + length
            if buffer.count - i < total { break }           // wait for the rest
            if buffer[i + total - 1] == 0x0D {
                let data = Array(buffer[(i + 5)..<(i + 5 + length)])
                responses.append(MAResponse(commandID: buffer[i + 2], code: buffer[i + 3], data: data))
                i += total
            } else {
                i += 1                                       // not a real frame start; resync
            }
        }
        buffer.removeFirst(i)
        if buffer.count > 8192 { buffer.removeAll() }       // never grow without bound
        return responses
    }
}

// MARK: - MA510 vocabularies

enum InputSource: UInt8, CaseIterable, Identifiable {
    case tv = 0x01, hdmi1 = 0x02, hdmi2 = 0x03, hdmi3 = 0x04, hdmi4 = 0x05
    case coax = 0x08, optical = 0x09, analog1 = 0x0A, analog2 = 0x0B
    case bluetooth = 0x0D, network = 0x0E

    var id: UInt8 { rawValue }

    var name: String {
        switch self {
        case .tv: return "TV (ARC)"
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .hdmi3: return "HDMI 3"
        case .hdmi4: return "HDMI 4"
        case .coax: return "Coax"
        case .optical: return "Optical"
        case .analog1: return "Analog 1"
        case .analog2: return "Analog 2"
        case .bluetooth: return "Bluetooth"
        case .network: return "Network"
        }
    }

    var short: String {
        switch self {
        case .tv: return "TV"
        case .hdmi1, .hdmi2, .hdmi3, .hdmi4: return "HDMI"
        case .coax: return "COAX"
        case .optical: return "OPT"
        case .analog1, .analog2: return "AUX"
        case .bluetooth: return "BT"
        case .network: return "NET"
        }
    }

    var symbol: String {
        switch self {
        case .tv: return "tv"
        case .hdmi1, .hdmi2, .hdmi3, .hdmi4: return "rectangle.connected.to.line.below"
        case .coax: return "circle.circle"
        case .optical: return "sun.min"
        case .analog1, .analog2: return "waveform"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .network: return "network"
        }
    }
}

/// Surround modes the MA510 accepts (Dolby Surround / DTS Neural:X are MA710+ only).
enum SurroundMode: UInt8, CaseIterable, Identifiable {
    case allStereo = 0x05, native = 0x06, stereo20 = 0x03, proLogic2 = 0x07, stereo21 = 0x04

    var id: UInt8 { rawValue }

    var name: String {
        switch self {
        case .stereo20: return "Stereo 2.0"
        case .stereo21: return "Stereo 2.1"
        case .allStereo: return "All Stereo"
        case .native: return "Native"
        case .proLogic2: return "ProLogic II"
        }
    }

    var caption: String {
        switch self {
        case .stereo20: return "Front L + R"
        case .stereo21: return "Front L + R + sub"
        case .allStereo: return "All 5 speakers"
        case .native: return "Film audio"
        case .proLogic2: return "Surround mix"
        }
    }

    var glyph: String {
        switch self {
        case .allStereo: return "◉"
        case .native: return "◈"
        case .stereo20: return "◐"
        case .stereo21: return "◑"
        case .proLogic2: return "✦"
        }
    }

    /// Speakers expected to carry sound (illustrative, not telemetry).
    var activeSpeakers: Set<Speaker> {
        switch self {
        case .stereo20, .stereo21: return [.frontLeft, .frontRight]
        default: return Set(Speaker.allCases)
        }
    }
}

enum Speaker: String, CaseIterable {
    case frontLeft = "FRONT L", center = "CENTER", frontRight = "FRONT R"
    case surroundLeft = "SURROUND L", surroundRight = "SURROUND R"
}

/// Simulated IR keys (0x04). Data = 0x01 0x0E <code>.
enum RemoteKey: UInt8, CaseIterable {
    case up = 0x99, down = 0x59, left = 0x83, right = 0x43, ok = 0x21
    case menu = 0xCA, back = 0xA1

    var irData: [UInt8] { [0x01, 0x0E, rawValue] }
    var label: String {
        switch self {
        case .up: return "UP"
        case .down: return "DOWN"
        case .left: return "LEFT"
        case .right: return "RIGHT"
        case .ok: return "OK"
        case .menu: return "MENU"
        case .back: return "BACK"
        }
    }
}

/// 0x11 streaming state: Data1 = server, Data2 = 0 stopped / 1 playing / 2 paused.
struct StreamingStatus: Equatable {
    let server: UInt8
    let state: UInt8

    var isPlaying: Bool { state == 0x01 }
    var hasServer: Bool { server != 0 }

    var serverName: String {
        switch server {
        case 0: return "No stream"
        case 1: return "Airable"
        case 4: return "USB"
        case 6: return "vTuner"
        case 9: return "TuneIn"
        case 10: return "UPnP"
        case 11: return "QPlay"
        case 12: return "Bluetooth"
        case 13: return "AirPlay"
        case 15: return "Spotify"
        case 16: return "Google Cast"
        case 17: return "Airable Radio"
        case 18: return "Podcasts"
        case 19: return "Napster"
        case 20: return "Qobuz"
        case 21: return "Deezer"
        case 22: return "Tidal"
        case 23: return "Roon"
        case 26: return "Amazon Music"
        case 33: return "Pandora"
        default: return "Stream \(server)"
        }
    }

    var stateName: String {
        switch state {
        case 0x01: return "Playing"
        case 0x02: return "Paused"
        default: return "Stopped"
        }
    }
}

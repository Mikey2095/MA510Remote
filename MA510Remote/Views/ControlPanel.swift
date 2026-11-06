import SwiftUI

/// "Your home system" column: sound field, quick modes, level, tuning, log.
struct ControlPanel: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            header.padding(.bottom, 8)
            SoundFieldCard()
            QuickModesCard()
            MasterLevelCard()
            SoundTuningCard()
            ControlLogCard()
            disclaimer
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0x9F9892))
                .lineSpacing(5)
                .padding(.horizontal, 2)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("YOUR HOME SYSTEM").overline(10, color: Palette.bronzeSoft, tracking: 2.1)
                (Text(store.roomName) + Text(".").foregroundColor(Color(hex: 0xB99770)))
                    .font(.system(size: 38, weight: .medium))
                    .tracking(-2.2)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 9).padding(.bottom, 6)
                Text("Five built-in ceiling speakers connected to your JBL MA510.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x82807C))
                    .lineSpacing(4)
            }
            Spacer(minLength: 12)
            Text("◈").font(.system(size: 39)).foregroundStyle(Color(hex: 0xC5B5A2, opacity: 0.8))
        }
    }

    private var disclaimer: Text {
        Text("Personal remote · Not affiliated with JBL. ").fontWeight(.semibold).foregroundColor(Color(hex: 0x6C6864))
        + Text("Live mode talks to the MA510 directly over your home Wi-Fi using JBL's published IP control protocol (TCP port 50000). The speaker map shows expected routing, not a speaker test. Play/pause applies to network streams on the receiver; track skipping isn't part of the protocol.")
    }
}

// MARK: - Sound field

struct SoundFieldCard: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("YOUR SOUND FIELD").overline(10, color: Palette.inkSoft, tracking: 1.3)
                Spacer()
                Text("5.0 SYSTEM").overline(8, color: Color(hex: 0x8B8580), tracking: 0.8)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0xD7D0C6), lineWidth: 1))
            }
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                Text("TV WALL").overline(9, color: Color(hex: 0x9A9288), tracking: 2)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 180)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xD9D3CC)).frame(height: 2) }
                    .padding(.bottom, 20)
                HStack {
                    speaker(.frontLeft).frame(maxWidth: .infinity)
                    speaker(.center).frame(maxWidth: .infinity)
                    speaker(.frontRight).frame(maxWidth: .infinity)
                }
                VStack(spacing: 2) {
                    Image(systemName: "sofa.fill").font(.system(size: 24)).foregroundStyle(Color(hex: 0xACA7A0))
                    Text("COUCH").overline(8, color: Color(hex: 0xACA7A0), tracking: 1)
                }
                .padding(.vertical, 18)
                HStack {
                    speaker(.surroundLeft)
                    Spacer()
                    speaker(.surroundRight)
                }
                .padding(.horizontal, 12)
            }
            .padding(EdgeInsets(top: 15, leading: 18, bottom: 14, trailing: 18))
            .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(hex: 0xF8F5EE), Color(hex: 0xF4F0EA)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEEE6DB), lineWidth: 1))

            HStack(spacing: 8) {
                Circle().fill(Palette.live).frame(width: 7, height: 7)
                Text(message).font(.system(size: 11)).foregroundStyle(Color(hex: 0x7A8178))
            }
            .padding(.top, 13)
        }
        .panelCard()
    }

    private var message: String {
        if !store.power { return "Standby. Routing shown for illustration." }
        if store.muted { return "Muted. Speaker map shows expected routing." }
        if store.surround == .allStereo { return "All Stereo is configured to use all five channels." }
        return "Expected routing for \(store.surround.name) — not a speaker test."
    }

    private func speaker(_ speaker: Speaker) -> some View {
        let on = store.power && !store.muted && store.surround.activeSpeakers.contains(speaker)
        return VStack(spacing: 5) {
            ZStack {
                Circle().fill(on ? Palette.speakerOnFill : Color(hex: 0xF0ECE7))
                Circle().stroke(on ? Palette.speakerOnRing : Color(hex: 0xC7C2B9), lineWidth: 1)
                Circle().fill(on ? Palette.speakerOn : Color(hex: 0xC1BAB2)).frame(width: 14, height: 14)
                Circle().stroke(on ? Palette.speakerOn : Color(hex: 0xC1BAB2), lineWidth: 2).frame(width: 22, height: 22)
            }
            .frame(width: 34, height: 34)
            .overlay(Circle().stroke(Color(hex: 0xC8E5D6, opacity: on ? 0.6 : 0), lineWidth: 4).padding(-4))
            Text(speaker.rawValue).overline(8, color: on ? Color(hex: 0x4D8C70) : Color(hex: 0x9F9991), tracking: 0.2)
                .fixedSize()
        }
        .animation(.easeOut(duration: 0.2), value: on)
    }
}

// MARK: - Quick modes

struct QuickModesCard: View {
    @Environment(RemoteStore.self) private var store
    private let modes: [SurroundMode] = [.allStereo, .native, .stereo20, .proLogic2]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(title: "QUICK MODES", trailing: "DSP / DECODING")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                ForEach(modes) { mode in
                    let chosen = store.surround == mode && store.unsupportedSurroundCode == nil
                    Button { store.setSurround(mode) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.glyph).font(.system(size: 20)).foregroundStyle(Color(hex: 0xB69974)).padding(.bottom, 4)
                            Text(mode.name).font(.system(size: 12, weight: .bold))
                                .foregroundStyle(chosen ? .white : Palette.ink)
                            Text(mode.caption).font(.system(size: 10))
                                .foregroundStyle(chosen ? Color(hex: 0xC6BCAE) : Color(hex: 0xA09A92))
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(chosen ? Palette.charcoal : Palette.tile))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(chosen ? Color(hex: 0x262B2E) : Color(hex: 0xE5DFD8), lineWidth: 1))
                        .animation(.easeOut(duration: 0.18), value: chosen)
                    }
                    .buttonStyle(PressStyle(scale: 0.97))
                }
            }
            if store.surround == .stereo21 {
                Text("Stereo 2.1 active — tap MODE on the remote to cycle.")
                    .font(.system(size: 11)).foregroundStyle(Palette.faint).padding(.top, 10)
            }
        }
        .panelCard()
    }
}

// MARK: - Master level

struct MasterLevelCard: View {
    @Environment(RemoteStore.self) private var store
    @State private var dragValue: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(title: "MASTER LEVEL", trailing: "\(Int(dragValue ?? Double(store.volume))) / \(store.volumeCap)")
            Slider(
                value: Binding(
                    get: { dragValue ?? Double(min(store.volume, store.volumeCap)) },
                    set: { newValue in
                        dragValue = newValue
                        store.setVolume(Int(newValue.rounded()))
                    }),
                in: 0...Double(store.volumeCap),
                step: 1,
                onEditingChanged: { editing in
                    store.isAdjustingVolume = editing
                    if !editing { dragValue = nil }
                })
                .tint(Palette.sand)
            HStack {
                Text("0 / MIN")
                Spacer()
                Text("\(store.volumeCap) / SAFETY LIMIT")
            }
            .overline(9, color: Color(hex: 0x9B958C), weight: .medium, tracking: 0.5)
            .padding(.top, 8).padding(.bottom, 20)

            HStack(spacing: 7) {
                pill(store.muted ? "UNMUTE" : "MUTE", action: store.toggleMute)
                pill(store.power ? "POWER" : "POWER ON", action: store.togglePower)
                pill("SYNC STATE ↻", action: store.syncAll)
                    .disabled(!store.link.isConnected)
                    .opacity(store.link.isConnected ? 1 : 0.45)
            }
        }
        .panelCard()
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .overline(9, color: Color(hex: 0x615E58), tracking: 0.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0xF8F5EF)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: 0xDFD7CB), lineWidth: 1))
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}

// MARK: - Sound tuning (real MA510 commands beyond the mockup)

struct SoundTuningCard: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardTitle(title: "SOUND TUNING", trailing: "TONE / ENHANCE").padding(.bottom, -2)
            toneRow("BASS", value: store.bass, set: store.setBass)
            toneRow("TREBLE", value: store.treble, set: store.setTreble)
            HStack(spacing: 7) {
                toggle("DIALOG", on: store.dialogEnhancement, action: store.toggleDialogEnhancement)
                toggle("ROOM EQ", on: store.roomEQ, action: store.toggleRoomEQ)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("FRONT DISPLAY").overline(9, color: Palette.faint, tracking: 1)
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { level in
                        let chosen = store.displayDim == level
                        Button { store.setDisplayDim(level) } label: {
                            Text(["FULL", "50%", "25%", "OFF"][level])
                                .overline(9, color: chosen ? .white : Color(hex: 0x615E58), tracking: 0.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Color(hex: 0x2B2D2F) : .clear))
                        }
                        .buttonStyle(PressStyle(scale: 0.97))
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0xECE8E1)))
            }
        }
        .panelCard()
    }

    private func toneRow(_ title: String, value: Int, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title).overline(9, color: Palette.inkSoft, tracking: 1)
            Spacer()
            stepButton("minus") { set(value - 1) }.disabled(value <= -12)
            Text(value > 0 ? "+\(value) dB" : "\(value) dB")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(width: 62)
            stepButton("plus") { set(value + 1) }.disabled(value >= 12)
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { RoundKey(systemImage: symbol, size: 32, iconSize: 12) }
            .buttonStyle(PressStyle(scale: 0.9))
            .buttonRepeatBehavior(.enabled)
    }

    private func toggle(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(on ? Palette.live : Color(hex: 0xD6D0CA)).frame(width: 7, height: 7)
                Text(title + (on ? " ON" : " OFF")).overline(9, color: on ? Palette.ink : Color(hex: 0x615E58), tracking: 0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 9).fill(on ? Color(hex: 0xEEF5F0) : Color(hex: 0xF8F5EF)))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(on ? Color(hex: 0xBFDDCD) : Color(hex: 0xDFD7CB), lineWidth: 1))
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }
}

// MARK: - Log

struct ControlLogCard: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(title: "CONTROL LOG", trailing: "LATEST ACTION").padding(.bottom, -4)
            HStack(spacing: 10) {
                Circle().fill(Color(hex: 0xCAA77E)).frame(width: 6, height: 6)
                Text(store.lastAction).font(.system(size: 12)).foregroundStyle(Color(hex: 0x80766C))
                    .contentTransition(.opacity)
            }
        }
        .panelCard()
    }
}

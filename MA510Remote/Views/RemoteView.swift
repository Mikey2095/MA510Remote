import SwiftUI

/// The pearl-silver handset: glass display, nav pad and hardware keys.
struct RemoteView: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            topRow
            GlassDisplay()
            VStack(spacing: 0) {
                Text("NAVIGATION").overline(8, color: Color(hex: 0x898680))
                    .padding(.top, 15).padding(.bottom, 9)
                NavPad().padding(.bottom, 16)
                functionRow.padding(.bottom, 16)
                middleRow.padding(.bottom, 18)
                mediaRow.padding(.bottom, 22)
                footerRow
            }
            .padding(.horizontal, 9)
            wordmark.padding(.top, 17)
        }
        .padding(EdgeInsets(top: 13, leading: 15, bottom: 18, trailing: 15))
        .frame(maxWidth: 352)
        .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(Palette.metal))
        .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(Color(hex: 0xC8C5C0), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 39, style: .continuous).stroke(.white.opacity(0.73), lineWidth: 1).padding(5).allowsHitTesting(false))
        .shadow(color: Color(hex: 0x9B8E7E, opacity: 0.22), radius: 19, x: 12, y: 26)
        .shadow(color: Color(hex: 0xB3A99B, opacity: 0.2), radius: 4, x: 2, y: 6)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: store.hapticTick)
    }

    private var topRow: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("JBL").font(.system(size: 20, weight: .heavy)).tracking(-1).foregroundStyle(Color(hex: 0x2A2D2F))
                Text("MA510").font(.system(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(Color(hex: 0xA3988D))
            }
            Spacer()
            Button(action: store.togglePower) {
                Image(systemName: "power")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(store.power ? Color(hex: 0xF2D5B3) : Color(hex: 0x777777))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: 0x27292B)))
                    .overlay(Circle().stroke(Color(hex: 0x6C6965), lineWidth: 1))
                    .shadow(color: .white, radius: 0, y: 1)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(store.power ? "Put receiver in standby" : "Power on receiver")
        }
        .frame(height: 53)
        .padding(.horizontal, 16)
    }

    private var functionRow: some View {
        HStack {
            functionKey("arrow.uturn.backward", "BACK") { store.press(.back) }
            functionKey("line.3.horizontal", "MENU") { store.press(.menu) }
            functionKey("smallcircle.filled.circle", "MODE") { store.cycleSurround() }
            functionKey(store.isFavoriteActive ? "star.fill" : "star", "FAV") { store.recallFavorite() }
                .contextMenu {
                    Button("Save current as favorite", systemImage: "plus.circle") { store.saveFavorite() }
                    Button("Recall favorite", systemImage: "star") { store.recallFavorite() }
                }
        }
    }

    private func functionKey(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundKey(systemImage: symbol)
                Text(title).overline(8, color: Palette.keyCaption, tracking: 0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressStyle())
    }

    private var middleRow: some View {
        HStack {
            Rocker(label: "VOL", upSymbol: "plus", downSymbol: "minus",
                   up: { store.nudgeVolume(1) }, down: { store.nudgeVolume(-1) })
            Spacer()
            Button(action: store.toggleMute) {
                VStack(spacing: 3) {
                    Image(systemName: store.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 17))
                    Text(store.muted ? "UNMUTE" : "MUTE").font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(store.muted ? Palette.alert : Color(hex: 0x56514D))
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color(hex: 0xF7F5F0)))
                .overlay(Circle().stroke(Color(hex: 0xCBC5BF), lineWidth: 1))
                .overlay(Circle().stroke(Color(hex: 0xD88974, opacity: store.muted ? 0.32 : 0), lineWidth: 3).padding(-3))
                .shadow(color: Color(hex: 0xAAA3A0, opacity: 0.35), radius: 3, x: 1, y: 3)
            }
            .buttonStyle(PressStyle())
            Spacer()
            Rocker(label: "INPUT", upSymbol: "chevron.up", downSymbol: "chevron.down",
                   up: { store.stepSource(1) }, down: { store.stepSource(-1) }, repeats: false)
        }
        .padding(.horizontal, 6)
    }

    private var mediaRow: some View {
        HStack(spacing: 22) {
            mediaKey("backward.end.fill") { store.skipTrack(-1) }
                .opacity(store.isLive ? 0.45 : 1)
            mediaKey(store.isPlaying ? "pause.fill" : "play.fill") { store.togglePlayback() }
            mediaKey("forward.end.fill") { store.skipTrack(1) }
                .opacity(store.isLive ? 0.45 : 1)
        }
    }

    private func mediaKey(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundKey(systemImage: symbol, size: 43, iconSize: 14, tint: Color(hex: 0x54504B))
        }
        .buttonStyle(PressStyle())
    }

    private var footerRow: some View {
        HStack {
            footerKey(symbol: "antenna.radiowaves.left.and.right", title: "BT", tint: Color(hex: 0x8B9DC1)) { store.setSource(.bluetooth) }
            Spacer()
            footerKey(symbol: "square.grid.3x2", title: "ALL STEREO", tint: Color(hex: 0x595550)) { store.setSurround(.allStereo) }
            Spacer()
            footerKey(symbol: "sun.max", title: dimLabel, tint: Color(hex: 0x595550)) { store.cycleDisplayDim() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color(hex: 0xEFEDE8)))
        .overlay(Capsule().stroke(Color(hex: 0xCAC6C0), lineWidth: 1))
        .padding(.horizontal, 6)
    }

    private var dimLabel: String { ["DIM", "DIM 50", "DIM 25", "DISP OFF"][store.displayDim] }

    private func footerKey(symbol: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 13))
                Text(title).font(.system(size: 8, weight: .heavy)).tracking(0.6)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 4)
        }
        .buttonStyle(PressStyle())
    }

    private var wordmark: some View {
        HStack(spacing: 6) {
            (Text("MA").fontWeight(.heavy) + Text("510").fontWeight(.light))
            Text("•").font(.system(size: 13)).foregroundStyle(Color(hex: 0xB79A78))
            Text("DIGITAL EDITION").fontWeight(.heavy)
        }
        .font(.system(size: 9))
        .tracking(2)
        .foregroundStyle(Color(hex: 0x86817A))
    }
}

// MARK: - Glass display

struct GlassDisplay: View {
    @Environment(RemoteStore.self) private var store
    private let quickSources: [InputSource] = [.tv, .hdmi1, .bluetooth, .network]

    private var statusText: String {
        switch store.link {
        case .connected: return "LAN CONTROL"
        case .connecting: return "CONNECTING"
        case .reconnecting: return "RECONNECTING"
        case .failed: return "OFFLINE"
        case .offline: return store.isLive ? "OFFLINE" : "SIMULATED"
        }
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 15,
                                           bottomTrailingRadius: 15, topTrailingRadius: 26, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(store.power ? "ACTIVE SOURCE" : "RECEIVER POWER").overline(8, color: Color(hex: 0xAAA7A5))
                Spacer()
                HStack(spacing: 4) {
                    Text("◉").font(.system(size: 9)).foregroundStyle(store.link.isConnected ? Palette.live : Color(hex: 0xB7A082))
                    Text(statusText).overline(7, color: Color(hex: 0xAAA6A1), tracking: 0.5)
                }
            }

            Menu {
                ForEach(InputSource.allCases) { source in
                    Button {
                        store.setSource(source)
                    } label: {
                        if source == store.source { Label(source.name, systemImage: "checkmark") } else { Text(source.name) }
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.power ? store.source.name : "Standby")
                        .font(.system(size: 32, weight: .light))
                        .tracking(-1.2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: 0x6F6B66))
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 4)

            HStack(alignment: .firstTextBaseline) {
                Text(modeText).overline(9, color: Palette.champagne, weight: .bold, tracking: 1.1)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("VOL").overline(8, color: Color(hex: 0x98999A), tracking: 1)
                    Text("\(store.volume)").font(.system(size: 17, weight: .regular).monospacedDigit()).foregroundStyle(.white)
                }
            }

            if let stream = store.streaming, stream.hasServer, store.isLive, store.power {
                Text("\(stream.serverName.uppercased()) · \(stream.stateName.uppercased())")
                    .overline(7.5, color: Color(hex: 0x98999A), tracking: 1)
                    .padding(.top, 4)
            }

            Visualizer(active: store.power && !store.muted && store.isPlaying)
                .frame(height: 35)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)

            Rectangle().fill(.white.opacity(0.13)).frame(height: 1).padding(.bottom, 10)

            HStack(spacing: 6) {
                ForEach(quickSources) { source in
                    Button { store.setSource(source) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: source.symbol).font(.system(size: 15))
                            Text(source.short).font(.system(size: 9, weight: .medium)).tracking(0.5)
                        }
                        .foregroundStyle(store.source == source ? Color(hex: 0xF5D5AD) : Color(hex: 0xA9A6A1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(store.source == source ? 0.09 : 0)))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: 0xBA9D73, opacity: store.source == source ? 0.33 : 0), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 23, bottom: 13, trailing: 23))
        .frame(minHeight: 232)
        .background(shape.fill(Palette.glass))
        .overlay(alignment: .topLeading) {
            // Diagonal sheen across the glass.
            LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 300, height: 100)
                .rotationEffect(.degrees(-12))
                .offset(x: -70, y: -20)
                .allowsHitTesting(false)
        }
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: Color(hex: 0x5D5B58, opacity: 0.25), radius: 4, y: 4)
        .opacity(store.power ? 1 : 0.62)
        .animation(.easeOut(duration: 0.2), value: store.power)
    }

    private var modeText: String {
        guard store.power else { return "POWER OFF" }
        if let code = store.unsupportedSurroundCode { return "MODE 0x\(String(code, radix: 16).uppercased())" }
        return store.surround.name.uppercased()
    }
}

struct Visualizer: View {
    var active: Bool
    private let restHeights: [CGFloat] = [9, 9, 23, 14, 29, 23, 9, 14, 23, 29, 9, 23, 9, 14, 29]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 14, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<15, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.gold, Palette.goldPale], startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: active ? height(i, t) : 3)
                        .opacity(active ? 0.9 : 0.3)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: active)
        }
    }

    private func height(_ i: Int, _ t: Double) -> CGFloat {
        let wave = (sin(t * 3.1 + Double(i) * 0.9) + sin(t * 1.7 + Double(i) * 2.3)) / 4 + 0.5
        return max(4, restHeights[i] * (0.55 + wave * 0.6))
    }
}

// MARK: - Nav pad & rocker

struct NavPad: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFAF9F6), Color(hex: 0xE8E5DF), Color(hex: 0xC0BEB9)],
                                     center: .center, startRadius: 0, endRadius: 82))
                .overlay(Circle().stroke(Color(hex: 0xCFCCC5), lineWidth: 1))
                .shadow(color: .black.opacity(0.13), radius: 5, y: 3)

            arrow("chevron.up", .up).offset(y: -57)
            arrow("chevron.down", .down).offset(y: 57)
            arrow("chevron.left", .left).offset(x: -57)
            arrow("chevron.right", .right).offset(x: 57)

            Button { store.press(.ok) } label: {
                Text("OK")
                    .font(.system(size: 12, weight: .medium)).tracking(1.2)
                    .foregroundStyle(Color(hex: 0x847B71))
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(RadialGradient(colors: [Color(hex: 0xFFFEF9), Color(hex: 0xE8DFD3)], center: .center, startRadius: 0, endRadius: 40)))
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .shadow(color: Color(hex: 0xA9A096, opacity: 0.55), radius: 2, y: 1)
                    .shadow(color: Color(hex: 0xFFEED9), radius: 3)
            }
            .buttonStyle(PressStyle(scale: 0.93))
        }
        .frame(width: 160, height: 160)
    }

    private func arrow(_ symbol: String, _ key: RemoteKey) -> some View {
        Button { store.press(key) } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: 0x56504B))
                .frame(width: 44, height: 40)
        }
        .buttonStyle(PressStyle(scale: 0.85))
        .accessibilityLabel(key.label.capitalized)
    }
}

struct Rocker: View {
    var label: String
    var upSymbol: String
    var downSymbol: String
    var up: () -> Void
    var down: () -> Void
    var repeats = true

    var body: some View {
        VStack(spacing: 0) {
            key(upSymbol, up)
            Spacer()
            Text(label).overline(10, color: Color(hex: 0x86817A), tracking: 1)
            Spacer()
            key(downSymbol, down)
        }
        .padding(.vertical, 8)
        .frame(width: 66, height: 132)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.keyFace))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(hex: 0xC9C5BE), lineWidth: 1))
        .shadow(color: Color(hex: 0xAAA8A1, opacity: 0.39), radius: 2, x: 1, y: 3)
    }

    private func key(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Color(hex: 0x474747))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(PressStyle(scale: 0.88))
        .buttonRepeatBehavior(repeats ? .enabled : .disabled)
    }
}

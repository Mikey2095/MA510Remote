import SwiftUI

struct ContentView: View {
    @Environment(RemoteStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingConnection = false

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            ScrollView {
                VStack(spacing: 0) {
                    TopBar(showingConnection: $showingConnection)
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 50) {
                            remoteColumn.frame(maxWidth: 420)
                            ControlPanel().frame(maxWidth: 560).padding(.top, 18)
                        }
                        .padding(.top, 30)
                    } else {
                        VStack(spacing: 28) {
                            remoteColumn
                            ControlPanel()
                        }
                        .padding(.top, 17)
                    }
                }
                .frame(maxWidth: 1240)
                .padding(.horizontal, sizeClass == .regular ? 28 : 16)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
            .refreshable { store.syncAll() }

            if let toast = store.toast {
                Text(toast.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: 0x252B2B)))
                    .shadow(color: .black.opacity(0.2), radius: 11, y: 5)
                    .padding(.horizontal, 24).padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
        .sheet(isPresented: $showingConnection) {
            ConnectionSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(23)
        }
    }

    private var remoteColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("CONCEPT / 001")
                Rectangle().fill(Color(hex: 0xCAC3BC)).frame(height: 1)
                Text("DIGITAL REMOTE")
            }
            .overline(9, color: Color(hex: 0x827F7C), tracking: 1.7)
            .padding(.horizontal, 10)
            .padding(.bottom, 22)

            RemoteView()

            HStack(spacing: 7) {
                Text("PEARL SILVER")
                Text("•").foregroundStyle(Color(hex: 0xB09A83))
                Text("BRUSHED ALUMINUM")
                Text("•").foregroundStyle(Color(hex: 0xB09A83))
                Text("GLASS UI")
            }
            .overline(8, color: Color(hex: 0x9B948D), weight: .regular, tracking: 1.2)
            .padding(.top, 25)
        }
    }

    private var background: some View {
        ZStack {
            Palette.canvas
            RadialGradient(colors: [Palette.canvasGlow, Palette.canvas.opacity(0)],
                           center: UnitPoint(x: 0.25, y: 0.15), startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct TopBar: View {
    @Environment(RemoteStore.self) private var store
    @Binding var showingConnection: Bool

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Text("◈").font(.system(size: 30)).foregroundStyle(Palette.bronze)
                VStack(alignment: .leading, spacing: 3) {
                    (Text("REMOTE").fontWeight(.heavy) + Text(" STUDIO").fontWeight(.light))
                        .font(.system(size: 15)).tracking(0.6).foregroundStyle(Palette.ink)
                    Text("MA510 / \(store.roomName.uppercased())").overline(8, color: Palette.muted, tracking: 2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button { showingConnection = true } label: {
                HStack(spacing: 8) {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                    Text(label).overline(10, color: Color(hex: 0x444444), tracking: 0.8)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: 0xA7A09B))
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(Capsule().fill(Color(hex: 0xFDFAF6)))
                .overlay(Capsule().stroke(Color(hex: 0xD6D0CA), lineWidth: 1))
            }
            .buttonStyle(PressStyle(scale: 0.97))
            .accessibilityLabel("Receiver connection: \(label)")
        }
        .frame(height: 62)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    private var label: String {
        switch store.link {
        case .connected: return "LAN CONNECTED"
        case .connecting: return "CONNECTING"
        case .reconnecting: return "RECONNECTING"
        case .failed: return "OFFLINE"
        case .offline: return store.isLive ? "OFFLINE" : "DEMO MODE"
        }
    }

    private var dotColor: Color {
        switch store.link {
        case .connected: return Palette.live
        case .failed: return Palette.alert
        case .offline where store.isLive: return Palette.alert
        default: return Palette.amber
        }
    }
}

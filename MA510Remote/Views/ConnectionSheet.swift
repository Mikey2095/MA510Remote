import SwiftUI

struct ConnectionSheet: View {
    @Environment(RemoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choice: ControlMode = .demo
    @FocusState private var ipFocused: Bool

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("LOCAL NETWORK CONNECTION").overline(10, color: Palette.bronzeSoft, tracking: 2)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Color(hex: 0x7E7872))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Close")
                }
                Text("Connect your JBL.")
                    .font(.system(size: 28, weight: .semibold)).tracking(-1.1)
                    .foregroundStyle(Color(hex: 0x272727))
                    .padding(.top, 8)
                Text("Try every control in Demo mode, or connect straight to your MA510 over your home Wi-Fi — no bridge or computer needed.") //This is copy that can be edited once Demo is removed from the other files. Can be replaced with simple copy. Text("Connect straight to your MA510 over your home Wi-Fi — no bridge or computer needed.")"
                    .font(.system(size: 13)).foregroundStyle(Color(hex: 0x77736F)).lineSpacing(4)
                    .padding(.top, 8).padding(.bottom, 20)

                modeSwitch.padding(.bottom, 20)

                if choice == .live {
                    liveFields
                } else {
                    Button {
                        store.useDemo()
                        dismiss()
                    } label: { primaryLabel("USE DEMO MODE") }
                    .buttonStyle(PressStyle(scale: 0.98))
                } //You would also remove this entire block and leave only liveFields. Use as only IF statement.

                settings.padding(.top, 28)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(hex: 0xFCFAF6))
        .onAppear { choice = store.controlMode }
        .onChange(of: store.link) { _, link in
            if link.isConnected && choice == .live {
                store.show("Connected to JBL \(modelName)")
                dismiss()
            }
        }
    }

    private var modelName: String {
        if case .connected(let model) = store.link { return model }
        return "MA510"
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segment("DEMO", .demo)
            segment("LIVE", .live)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xECE8E1)))
    }

    private func segment(_ title: String, _ mode: ControlMode) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { choice = mode } } label: {
            Text(title)
                .overline(11, color: choice == mode ? .white : Palette.ink, tracking: 0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 9).fill(choice == mode ? Color(hex: 0x2B2D2F) : .clear))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var liveFields: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Receiver IP address").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: 0x6A625A))
                TextField("192.168.1.80", text: $store.host)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($ipFocused)
                    .font(.system(size: 16).monospacedDigit())
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xD7D0C8), lineWidth: 1))
            }

            Button { ipFocused = false; store.scan() } label: {
                HStack(spacing: 8) {
                    if store.isScanning {
                        ProgressView(value: store.scanProgress).frame(width: 60).tint(Palette.sand)
                        Text("SCANNING \(Int(store.scanProgress * 100))%")
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("FIND MY RECEIVER")
                    }
                }
                .overline(10, color: Color(hex: 0x615E58), tracking: 0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xF8F5EF)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xDFD7CB), lineWidth: 1))
            }
            .buttonStyle(PressStyle(scale: 0.98))
            .disabled(store.isScanning)

            if !store.discovered.isEmpty {
                VStack(spacing: 6) {
                    ForEach(store.discovered) { receiver in
                        Button { store.host = receiver.host } label: {
                            HStack {
                                Text("◈").foregroundStyle(Palette.bronze)
                                Text("JBL \(receiver.modelName)").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(receiver.host).font(.system(size: 13).monospacedDigit()).foregroundStyle(Palette.muted)
                                if store.host == receiver.host { Image(systemName: "checkmark").foregroundStyle(Palette.speakerOn) }
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xE3DED6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Your iPhone and the MA510 must be on the same Wi-Fi. Green standby turns network control off — wake the receiver with its power button first. The first time you connect, iOS asks to allow Local Network access; tap Allow.")
                .font(.system(size: 11)).foregroundStyle(Color(hex: 0x8A8177)).lineSpacing(3)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xEEEAE3)))

            if store.link.isConnected {
                Button { store.disconnect() } label: { primaryLabel("DISCONNECT · USE DEMO", dark: false) } //You would just remove the · USE DEMO
                    .buttonStyle(PressStyle(scale: 0.98))
            } else {
                Button { ipFocused = false; store.connect() } label: {
                    primaryLabel(store.link == .connecting ? "CONNECTING…" : "CONNECT TO RECEIVER")
                }
                .buttonStyle(PressStyle(scale: 0.98))
                .disabled(store.link == .connecting)
            }

            if case .failed(let message) = store.link {
                Text(message).font(.system(size: 11)).foregroundStyle(Color(hex: 0x9F6253)).lineSpacing(3)
            } else if store.link == .reconnecting {
                Text("Link dropped — reconnecting automatically…").font(.system(size: 11)).foregroundStyle(Color(hex: 0x9F6253))
            }
        }
    }

    private var settings: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 14) {
            Text("PREFERENCES").overline(10, color: Palette.bronzeSoft, tracking: 2)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Volume safety limit").font(.system(size: 13, weight: .semibold))
                    Text("The app never sends a level above this (receiver max is 99).")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Stepper("\(store.volumeCap)", value: $store.volumeCap, in: 20...99, step: 5)
                    .fixedSize()
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Room name").font(.system(size: 13, weight: .semibold))
                TextField("Living room", text: $store.roomName)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xD7D0C8), lineWidth: 1))
            }
            Text("Favorite: \(store.favorite.source.name) · \(store.favorite.mode.name) · vol \(store.favorite.volume). Long-press FAV on the remote to save the current setup.")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
        }
        .foregroundStyle(Palette.ink)
    }

    private func primaryLabel(_ title: String, dark: Bool = true) -> some View {
        Text(title)
            .overline(12, color: dark ? .white : Palette.ink, tracking: 1.1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 12).fill(dark ? Color(hex: 0x252B2B) : Color(hex: 0xECE8E1)))
    }
}

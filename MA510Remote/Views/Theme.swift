import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double(hex >> 16 & 0xFF) / 255,
                  green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Pearl silver · brushed aluminum · black glass.
enum Palette {
    static let canvas = Color(hex: 0xF4F0EB)
    static let canvasGlow = Color(hex: 0xFFFAF3)
    static let ink = Color(hex: 0x171919)
    static let inkSoft = Color(hex: 0x5E5954)
    static let muted = Color(hex: 0x94908C)
    static let faint = Color(hex: 0xA09A94)
    static let hairline = Color(hex: 0xDBD7D2)
    static let bronze = Color(hex: 0xA58662)
    static let bronzeSoft = Color(hex: 0xAC8C6F)
    static let gold = Color(hex: 0xD9AE74)
    static let goldPale = Color(hex: 0xDDC6A6)
    static let champagne = Color(hex: 0xC9B598)
    static let sand = Color(hex: 0xC7A17C)
    static let amber = Color(hex: 0xDBAD6F)
    static let live = Color(hex: 0x66BBA5)
    static let speakerOn = Color(hex: 0x4D9F77)
    static let speakerOnFill = Color(hex: 0xD9EBDF)
    static let speakerOnRing = Color(hex: 0x74BD98)
    static let alert = Color(hex: 0xB85848)
    static let charcoal = Color(hex: 0x242B2C)

    static let card = Color(hex: 0xFFFDF9, opacity: 0.66)
    static let cardBorder = Color(hex: 0xE3DED6)
    static let key = Color(hex: 0xF8F7F3)
    static let keyBorder = Color(hex: 0xCFCBC5)
    static let keyInk = Color(hex: 0x575450)
    static let keyCaption = Color(hex: 0x6A6764)
    static let tile = Color(hex: 0xFAF8F4)

    static let metal = LinearGradient(stops: [
        .init(color: Color(hex: 0xB8B5B2), location: 0),
        .init(color: Color(hex: 0xFBFAF6), location: 0.13),
        .init(color: Color(hex: 0xE4E1DC), location: 0.51),
        .init(color: Color(hex: 0xFEFDFA), location: 0.83),
        .init(color: Color(hex: 0xA9A6A3), location: 1),
    ], startPoint: UnitPoint(x: 0, y: 0.45), endPoint: UnitPoint(x: 1, y: 0.55))

    static let glass = LinearGradient(stops: [
        .init(color: Color(hex: 0x11161A), location: 0),
        .init(color: Color(hex: 0x22262B), location: 0.54),
        .init(color: Color(hex: 0x0B1014), location: 1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let keyFace = LinearGradient(colors: [Color(hex: 0xF9F8F3), Color(hex: 0xE4E0D9)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// Small, wide-tracked uppercase label used throughout the design.
    func overline(_ size: CGFloat = 9, color: Color = Palette.muted, weight: Font.Weight = .heavy, tracking: CGFloat? = nil) -> some View {
        self.font(.system(size: size, weight: weight))
            .tracking(tracking ?? size * 0.19)
            .foregroundStyle(color)
    }

    func panelCard() -> some View {
        self.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.cardBorder, lineWidth: 1))
            .shadow(color: Color(hex: 0xD5C8BB, opacity: 0.12), radius: 8, y: 4)
    }
}

/// Physical-feeling press: slight shrink.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Round porcelain key (BACK / MENU / MODE / FAV, media keys).
struct RoundKey: View {
    var systemImage: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 17
    var tint: Color = Palette.keyInk
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.key))
            .overlay(Circle().stroke(Palette.keyBorder, lineWidth: 1))
            .shadow(color: Color(hex: 0xAAA3A0, opacity: 0.27), radius: 1.5, x: 1, y: 2)
    }
}

struct CardTitle: View {
    var title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title).overline(10, color: Palette.inkSoft, tracking: 1.3)
            Spacer()
            if let trailing { Text(trailing).overline(9, color: Palette.faint, weight: .bold, tracking: 0.3) }
        }
        .padding(.bottom, 16)
    }
}

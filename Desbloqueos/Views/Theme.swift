import SwiftUI

extension Color {
    /// Color que se adapta solo a claro y oscuro.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> UIColor {
    UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

enum Palette {
    /// Violeta de la marca.
    static let accent = Color(light: rgb(99, 71, 235), dark: rgb(150, 126, 255))
    /// Verde de "vas bien, sigue así".
    static let calm = Color(light: rgb(22, 145, 92), dark: rgb(84, 214, 148))
    /// Ámbar de "muchos desbloqueos seguidos".
    static let alert = Color(light: rgb(184, 111, 10), dark: rgb(247, 181, 74))

    static let card = Color(light: .white, dark: rgb(26, 26, 36))
    static let cardBorder = Color(light: rgb(228, 226, 240), dark: rgb(48, 47, 64))

    static let canvasTop = Color(light: rgb(245, 243, 255), dark: rgb(16, 15, 26))
    static let canvasBottom = Color(light: rgb(255, 255, 255), dark: rgb(9, 9, 15))

    static let primaryText = Color(light: rgb(24, 22, 40), dark: rgb(245, 244, 255))
    static let secondaryText = Color(light: rgb(108, 104, 132), dark: rgb(158, 154, 180))

    /// Color con el que se pinta una pausa según lo larga que sea.
    static func tint(forGap seconds: TimeInterval?) -> Color {
        guard let seconds else { return secondaryText }
        switch seconds {
        case ..<(5 * 60): return alert
        case ..<(30 * 60): return accent
        default: return calm
        }
    }
}

/// Fondo degradado común a todas las pantallas.
struct CanvasBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Palette.canvasTop, Palette.canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Tarjeta redondeada con borde suave.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

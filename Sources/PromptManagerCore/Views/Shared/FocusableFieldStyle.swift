import SwiftUI

struct FocusableFieldStyle: ViewModifier {
    let radius: CGFloat
    let border: Color
    let background: Color
    let ringOpacity: Double
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.appAccentStyle) private var accent

    init(
        radius: CGFloat = DT.Radius.md,
        border: Color = DT.ColorToken.borderStrong,
        background: Color = DT.ColorToken.surfacePrimary,
        ringOpacity: Double = 0.14
    ) {
        self.radius = radius
        self.border = border
        self.background = background
        self.ringOpacity = ringOpacity
    }

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .background(enabled ? background : DT.ColorToken.disabledBackground, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(border, lineWidth: focused ? 1.2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius + 3)
                    .stroke(Color.clear, lineWidth: 3)
                    .padding(-3)
            )
    }
}

struct FieldChromeStyle: ViewModifier {
    let focused: Bool
    let radius: CGFloat
    let border: Color
    let background: Color
    let ringOpacity: Double
    @Environment(\.isEnabled) private var enabled
    @Environment(\.appAccentStyle) private var accent

    func body(content: Content) -> some View {
        content
            .background(enabled ? background : DT.ColorToken.disabledBackground, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(border, lineWidth: focused ? 1.2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius + 3)
                    .stroke(Color.clear, lineWidth: 3)
                    .padding(-3)
            )
    }
}

extension View {
    func fieldChrome(
        focused: Bool,
        radius: CGFloat = DT.Radius.md,
        border: Color = DT.ColorToken.borderStrong,
        background: Color = DT.ColorToken.surfacePrimary,
        ringOpacity: Double = 0.14
    ) -> some View {
        modifier(FieldChromeStyle(focused: focused, radius: radius, border: border, background: background, ringOpacity: ringOpacity))
    }

    func focusableFieldChrome(
        radius: CGFloat = DT.Radius.md,
        border: Color = DT.ColorToken.borderStrong,
        background: Color = DT.ColorToken.surfacePrimary
    ) -> some View {
        modifier(FocusableFieldStyle(radius: radius, border: border, background: background))
    }
}

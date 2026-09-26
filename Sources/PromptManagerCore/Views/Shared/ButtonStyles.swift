import SwiftUI

struct PrimaryToolbarButton: View {
    let title: String; let systemImage: String; let action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: systemImage).labelStyle(.titleAndIcon) }.buttonStyle(PrimaryButtonStyle()) }
}

struct SecondaryToolbarButton: View {
    let title: String; let systemImage: String; let action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: systemImage).labelStyle(.titleAndIcon) }.buttonStyle(SecondaryButtonStyle()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            role: .primary,
            destructive: false,
            horizontalPadding: horizontalPadding
        )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var destructive = false
    var horizontalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            role: .secondary,
            destructive: destructive,
            horizontalPadding: horizontalPadding
        )
    }
}

struct SecondaryMenuButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            role: .secondary,
            destructive: false,
            horizontalPadding: horizontalPadding
        )
    }
}

struct IconToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverIconButtonBody(configuration: configuration)
    }
}

private enum HoverButtonRole { case primary, secondary }

private struct HoverButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let role: HoverButtonRole
    let destructive: Bool
    let horizontalPadding: CGFloat
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.appAccentStyle) private var accent
    @Environment(\.appButtonVisualStyle) private var visualStyle
    @Environment(\.appButtonTextWeight) private var textWeight
    @Environment(\.appFontScale) private var scale
    @Environment(\.appButtonSize) private var buttonSize
    @Environment(\.appRuntimeSettings) private var runtime

    var body: some View {
        configuration.label
            .font(.system(size: buttonSize.fontSize * scale.scale, weight: textWeight.fontWeight))
            .foregroundStyle(enabled ? foreground : DT.ColorToken.textMuted)
            .padding(.horizontal, horizontalPadding)
            .frame(height: buttonSize.height + (runtime.largerTargets ? 8 : 0))
            .background(enabled ? currentBackground : DT.ColorToken.disabledBackground, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: DT.Radius.md).strokeBorder(border, lineWidth: 1)
                }
            }
            .onHover { hovering = $0 }
    }

    private var pressedOrHovered: Bool { configuration.isPressed || hovering }

    private var foreground: Color {
        guard role == .primary else { return destructive ? DT.ColorToken.dangerRed : DT.ColorToken.textPrimary }
        switch visualStyle {
        case .filled: return DT.ColorToken.textInverse
        case .soft, .outline, .minimal: return accent.color
        }
    }

    private var currentBackground: Color {
        guard role == .primary else { return pressedOrHovered ? DT.ColorToken.surfaceHover : DT.ColorToken.surfacePrimary }
        switch visualStyle {
        case .filled: return pressedOrHovered ? accent.hoverColor : accent.color
        case .soft: return pressedOrHovered ? accent.borderColor.opacity(0.48) : accent.softColor
        case .outline: return pressedOrHovered ? accent.softColor : DT.ColorToken.surfacePrimary
        case .minimal: return pressedOrHovered ? accent.softColor : Color.clear
        }
    }

    private var border: Color? {
        guard role == .primary else { return destructive ? DT.ColorToken.promptCardBorder : (runtime.increaseContrast ? DT.ColorToken.textTertiary : DT.ColorToken.borderStrong) }
        switch visualStyle {
        case .filled, .minimal: return nil
        case .soft, .outline: return accent.borderColor
        }
    }
}

private struct HoverIconButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.appRuntimeSettings) private var runtime
    @Environment(\.appButtonSize) private var buttonSize
    @Environment(\.appButtonTextWeight) private var textWeight
    @Environment(\.appFontScale) private var scale

    var body: some View {
        configuration.label
            .font(.system(size: (buttonSize.fontSize + 3) * scale.scale, weight: textWeight.fontWeight))
            .foregroundStyle(enabled ? DT.ColorToken.textSecondary : DT.ColorToken.textMuted)
            .frame(width: iconFrame, height: iconFrame)
            .background(enabled ? (configuration.isPressed || hovering ? DT.ColorToken.surfaceHover : DT.ColorToken.surfacePrimary) : DT.ColorToken.disabledBackground, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).strokeBorder(runtime.increaseContrast ? DT.ColorToken.textTertiary : DT.ColorToken.borderStrong, lineWidth: runtime.increaseContrast ? 1.5 : 1))
            .focusEffectDisabled()
            .onHover { hovering = $0 }
    }

    private var iconFrame: CGFloat {
        max(buttonSize.height, runtime.largerTargets ? 46 : buttonSize.height)
    }
}

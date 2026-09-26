import SwiftUI

public enum DesignTokens {
    public enum ColorToken {
        public static let appBackground = Color(light: "#F5F6F8", dark: "#101419")
        public static let surfacePrimary = Color(light: "#FFFFFF", dark: "#171C22")
        public static let surfaceSecondary = Color(light: "#F8F9FB", dark: "#131820")
        public static let surfaceTertiary = Color(light: "#F1F3F5", dark: "#1D242C")
        public static let surfaceHover = Color(light: "#F3F6FA", dark: "#202832")
        public static let surfaceSelected = Color(light: "#EAF3FF", dark: "#102B4F")
        public static let surfaceSelectedStrong = Color(light: "#DCEBFF", dark: "#123762")
        public static let borderDefault = Color(light: "#E5E7EB", dark: "#2A313A")
        public static let borderSubtle = Color(light: "#EEF0F3", dark: "#242C35")
        public static let borderStrong = Color(light: "#D6DAE0", dark: "#3A4450")
        public static let textPrimary = Color(light: "#111827", dark: "#F8FAFC")
        public static let textSecondary = Color(light: "#4B5563", dark: "#CBD5E1")
        public static let textTertiary = Color(light: "#6B7280", dark: "#94A3B8")
        public static let textMuted = Color(light: "#9CA3AF", dark: "#64748B")
        public static let textInverse = Color(hex: "#FFFFFF")
        public static let accentBlue = Color(hex: "#0A66E8")
        public static let accentBlueHover = Color(hex: "#075BD1")
        public static let accentBlueSoft = Color(light: "#EAF3FF", dark: "#0B2543")
        public static let accentBlueBorder = Color(light: "#BFD7FF", dark: "#1E4E86")
        public static let successGreen = Color(hex: "#16A34A")
        public static let successGreenSoft = Color(light: "#DCFCE7", dark: "#10331F")
        public static let warningYellow = Color(hex: "#F59E0B")
        public static let warningYellowSoft = Color(light: "#FEF3C7", dark: "#3B2A08")
        public static let dangerRed = Color(hex: "#EF4444")
        public static let dangerRedSoft = Color(light: "#FEE2E2", dark: "#401919")
        public static let purpleAccent = Color(hex: "#7C3AED")
        public static let purpleSoft = Color(light: "#EDE9FE", dark: "#2B174F")
        public static let orangeAccent = Color(hex: "#F97316")
        public static let orangeSoft = Color(light: "#FFEDD5", dark: "#3B220D")
        public static let proTipBorder = Color(light: "#D7E8FF", dark: "#1E4E86")
        public static let promptCardBorder = Color(light: "#F3C4C4", dark: "#633131")
        public static let disabledBackground = Color(light: "#F3F4F6", dark: "#202832")

        public static let darkAppBackground = Color(hex: "#101419")
        public static let darkSurfacePrimary = Color(hex: "#171C22")
        public static let darkSurfaceSecondary = Color(hex: "#131820")
        public static let darkBorder = Color(hex: "#2A313A")
        public static let darkTextPrimary = Color(hex: "#F8FAFC")
        public static let darkTextSecondary = Color(hex: "#CBD5E1")
    }

    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 12
        public static let window: CGFloat = 16
        public static let pill: CGFloat = 999
    }

    public enum Space {
        public static let s1: CGFloat = 4
        public static let s2: CGFloat = 8
        public static let s3: CGFloat = 12
        public static let s4: CGFloat = 16
        public static let s5: CGFloat = 20
        public static let s6: CGFloat = 24
        public static let s8: CGFloat = 32
    }

    public enum Size {
        public static let toolbarHeight: CGFloat = 64
        public static let compactToolbarHeight: CGFloat = 52
        public static let sidebarWidth: CGFloat = 240
        public static let promptListMinWidth: CGFloat = 260
        public static let promptListWidth: CGFloat = 320
        public static let promptListMaxWidth: CGFloat = 520
        public static let detailsWidth: CGFloat = 300
        public static let editorMinWidth: CGFloat = 480
        public static let variablePanelMinWidth: CGFloat = 180
        public static let variablePanelMaxWidth: CGFloat = 360
        public static let variableFieldDefaultHeight: CGFloat = 72
        public static let variableFieldMinHeight: CGFloat = 72
        public static let variableFieldMaxHeight: CGFloat = 220
        public static let minWindowWidth: CGFloat = 1200
        public static let minWindowHeight: CGFloat = 760
        public static let defaultWindowWidth: CGFloat = 1440
        public static let defaultWindowHeight: CGFloat = 1024
    }

    public enum FontToken {
        public static let titleWindow = Font.system(size: 14, weight: .semibold)
        public static let headingPrimary = Font.system(size: 24, weight: .bold)
        public static let headingSection = Font.system(size: 11, weight: .bold)
        public static let bodyDefault = Font.system(size: 14, weight: .regular)
        public static let bodyStrong = Font.system(size: 14, weight: .semibold)
        public static let bodySmall = Font.system(size: 13, weight: .regular)
        public static let bodySmallStrong = Font.system(size: 13, weight: .semibold)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let captionStrong = Font.system(size: 12, weight: .semibold)
    }
}

typealias DT = DesignTokens

import SwiftUI
#if os(macOS)
import AppKit
#endif

public extension Color {
    init(hex: String) {
        #if os(macOS)
        self.init(nsColor: NSColor(hex: hex))
        #else
        self.init(.sRGB, red: 0, green: 0, blue: 0)
        #endif
    }

    #if os(macOS)
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let mode = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: mode == .darkAqua ? dark : light)
        })
    }
    #endif
}

#if os(macOS)
extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red, green, blue, alpha: UInt64
        switch cleaned.count {
        case 3:
            (red, green, blue, alpha) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17, 255)
        case 6:
            (red, green, blue, alpha) = (value >> 16, value >> 8 & 0xFF, value & 0xFF, 255)
        case 8:
            (red, green, blue, alpha) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (red, green, blue, alpha) = (0, 0, 0, 255)
        }
        self.init(srgbRed: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: Double(alpha) / 255)
    }
}
#endif

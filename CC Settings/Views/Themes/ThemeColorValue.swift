import SwiftUI

/// Parses the colour strings a Claude Code theme accepts: `rgb(r,g,b)`, `#rgb`, `#rrggbb`,
/// `ansi256(n)` and `ansi:<name>`.
enum ThemeColorValue {
    static let ansiNames: [String: (Double, Double, Double)] = [
        "black": (0, 0, 0), "red": (205, 49, 49), "green": (13, 188, 121), "yellow": (229, 229, 16),
        "blue": (36, 114, 200), "magenta": (188, 63, 188), "cyan": (17, 168, 205), "white": (229, 229, 229),
        "blackBright": (102, 102, 102), "redBright": (241, 76, 76), "greenBright": (35, 209, 139),
        "yellowBright": (245, 245, 67), "blueBright": (59, 142, 234), "magentaBright": (214, 112, 214),
        "cyanBright": (41, 184, 219), "whiteBright": (255, 255, 255),
    ]

    /// RGB components (0...255) for a theme colour string, or nil when Claude Code would
    /// reject it.
    static func rgb(_ raw: String) -> (r: Int, g: Int, b: Int)? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("rgb(") && s.hasSuffix(")") {
            let parts = s.dropFirst(4).dropLast().split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 3, let r = parts[0], let g = parts[1], let b = parts[2],
                  [r, g, b].allSatisfy({ (0...255).contains($0) }) else { return nil }
            return (r, g, b)
        }
        if s.hasPrefix("#") {
            var hex = String(s.dropFirst())
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
            return (Int((v >> 16) & 0xFF), Int((v >> 8) & 0xFF), Int(v & 0xFF))
        }
        if s.hasPrefix("ansi:"), let c = ansiNames[String(s.dropFirst(5))] {
            return (Int(c.0), Int(c.1), Int(c.2))
        }
        if s.hasPrefix("ansi256("), s.hasSuffix(")"), let n = Int(s.dropFirst(8).dropLast()), (0...255).contains(n) {
            return ansi256(n)
        }
        return nil
    }

    static func isValid(_ raw: String) -> Bool { rgb(raw) != nil }

    static func color(_ raw: String?) -> Color? {
        guard let raw, let c = rgb(raw) else { return nil }
        return Color(.sRGB, red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, opacity: 1)
    }

    private static func ansi256(_ n: Int) -> (Int, Int, Int) {
        if n < 16 {
            let names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
                         "blackBright", "redBright", "greenBright", "yellowBright", "blueBright", "magentaBright", "cyanBright", "whiteBright"]
            let c = ansiNames[names[n]] ?? (0, 0, 0)
            return (Int(c.0), Int(c.1), Int(c.2))
        }
        if n >= 232 {
            let v = 8 + (n - 232) * 10
            return (v, v, v)
        }
        let i = n - 16
        let steps = [0, 95, 135, 175, 215, 255]
        return (steps[i / 36], steps[(i / 6) % 6], steps[i % 6])
    }
}

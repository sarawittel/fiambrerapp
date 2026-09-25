import CoreText
import SwiftUI

enum Theme {
    static let background = Color(hex: 0x14100d)
    static let outline = Color(hex: 0x0b0806)
    static let ink = Color(hex: 0xe8dcc0)
    static let muted = Color(hex: 0xa89878)
    static let wood = Color(hex: 0x3a2a1e)
    static let woodLight = Color(hex: 0x5a4230)
    static let woodDark = Color(hex: 0x241a12)
    static let woodDeep = Color(hex: 0x1a120c)
    static let parchment = Color(hex: 0xd9c8a0)
    static let parchmentLight = Color(hex: 0xeadcb8)
    static let parchmentDark = Color(hex: 0xb09a6c)
    static let parchmentInk = Color(hex: 0x2a1e14)
    static let parchmentMuted = Color(hex: 0x6a5234)
    static let candle = Color(hex: 0xe0a83a)
    static let candleDark = Color(hex: 0xa8742a)
    static let moss = Color(hex: 0x7a8f4a)
    static let blood = Color(hex: 0xa8322d)

    /// Tamaño de un "píxel" de los bordes, en puntos.
    static let px: CGFloat = 3
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }

    /// "#e0a83a" → Color
    init(hexString: String) {
        self.init(hex: UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xffffff)
    }
}

extension Font {
    /// Fuente de títulos (Press Start 2P). Es muy ancha: usa tamaños pequeños.
    static func pixelTitle(_ size: CGFloat = 12) -> Font {
        .custom("PressStart2P-Regular", size: size, relativeTo: .headline)
    }

    /// Fuente de texto (VT323).
    static func pixelBody(_ size: CGFloat = 22) -> Font {
        .custom("VT323-Regular", size: size, relativeTo: .body)
    }
}

enum FontLoader {
    /// Registra las TTF del bundle; así no hace falta declararlas en el Info.plist.
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

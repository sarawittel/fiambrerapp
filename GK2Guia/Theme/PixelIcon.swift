import GK2Core
import ImageIO
import SwiftUI

/// Imagen de la wiki si la hay; si no, el sprite de 8x8 de `Sprites`.
/// Usa tamaños múltiplos de 8 para que el sprite quede nítido.
struct PixelIcon: View {
    let name: String
    var image: String?
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let image, let cgImage = WikiImages.load(image) {
                // ampliada sin suavizado para que el pixel art no se emborrone
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .interpolation(CGFloat(cgImage.width) <= size ? .none : .medium)
                    .scaledToFit()
            } else {
                sprite
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var sprite: some View {
        Canvas { ctx, canvasSize in
            let cell = canvasSize.width / 8
            for (y, row) in Sprites.sprite(name).enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let hex = Sprites.palette[ch] else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    ctx.fill(Path(rect), with: .color(Color(hex: hex)), style: FillStyle(antialiased: false))
                }
            }
        }
    }
}

extension Text {
    /// El icono de un día dentro de un texto: en el juego los días no tienen nombre.
    @MainActor init(dayIcon day: Day, height: CGFloat = 18) {
        if let image = day.image, let cgImage = WikiImages.load(image) {
            let icon = Image(cgImage, scale: CGFloat(cgImage.height) / height, label: Text(day.name))
            self = Text(icon).baselineOffset(-height / 4)
        } else {
            self = Text(day.short)
        }
    }
}

/// Carga y guarda en memoria las imágenes de `GK2Core/Data/Images`.
@MainActor
enum WikiImages {
    private static var cache: [String: CGImage] = [:]

    static func load(_ name: String) -> CGImage? {
        if let hit = cache[name] { return hit }
        guard let url = GameData.imageURL(name),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[name] = image
        return image
    }
}

/// Icono dentro de un marco oscuro, para cabeceras y tarjetas.
struct IconFrame: View {
    let name: String
    var image: String?
    var size: CGFloat = 48

    var body: some View {
        PixelIcon(name: name, image: image, size: size)
            .padding(8 + Theme.px)
            .pixelBox(.woodDark)
    }
}

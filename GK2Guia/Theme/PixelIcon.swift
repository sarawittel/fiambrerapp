import GK2Core
import SwiftUI

/// Dibuja un sprite de 8x8 de `Sprites`. Usa tamaños múltiplos de 8 para que quede nítido.
struct PixelIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
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
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Icono dentro de un marco oscuro, para cabeceras y tarjetas.
struct IconFrame: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        PixelIcon(name: name, size: size)
            .padding(8 + Theme.px)
            .pixelBox(.woodDark)
    }
}

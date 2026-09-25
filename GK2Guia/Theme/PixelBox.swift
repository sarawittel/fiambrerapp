import SwiftUI

/// Rectángulo con las esquinas recortadas un píxel, como los marcos de un juego 16-bit.
struct NotchedRect: Shape {
    var notch: CGFloat = Theme.px

    func path(in r: CGRect) -> Path {
        let n = notch
        var p = Path()
        p.addLines([
            CGPoint(x: r.minX + n, y: r.minY), CGPoint(x: r.maxX - n, y: r.minY),
            CGPoint(x: r.maxX - n, y: r.minY + n), CGPoint(x: r.maxX, y: r.minY + n),
            CGPoint(x: r.maxX, y: r.maxY - n), CGPoint(x: r.maxX - n, y: r.maxY - n),
            CGPoint(x: r.maxX - n, y: r.maxY), CGPoint(x: r.minX + n, y: r.maxY),
            CGPoint(x: r.minX + n, y: r.maxY - n), CGPoint(x: r.minX, y: r.maxY - n),
            CGPoint(x: r.minX, y: r.minY + n), CGPoint(x: r.minX + n, y: r.minY + n),
        ])
        p.closeSubpath()
        return p
    }
}

/// Materiales de las cajas: relleno, luz arriba, sombra abajo y color de texto.
enum BoxStyle {
    case wood, woodDark, woodSelected, parchment, button, candle, blood, field

    var fill: Color {
        switch self {
        case .wood: Theme.wood
        case .woodDark: Theme.woodDark
        case .woodSelected: Theme.woodLight
        case .parchment: Theme.parchment
        case .button: Color(hex: 0x6a4a2a)
        case .candle: Theme.candle
        case .blood: Theme.blood
        case .field: Theme.parchmentLight
        }
    }

    var highlight: Color {
        switch self {
        case .wood: Theme.woodLight
        case .woodDark: Theme.wood
        case .woodSelected: Color(hex: 0x7a5a40)
        case .parchment: Theme.parchmentLight
        case .button: Color(hex: 0x8a6a44)
        case .candle: Color(hex: 0xf4cc6a)
        case .blood: Color(hex: 0xc8524a)
        case .field: Theme.parchmentDark
        }
    }

    var shadow: Color {
        switch self {
        case .wood: Theme.woodDark
        case .woodDark, .woodSelected: Theme.woodDeep
        case .parchment: Theme.parchmentDark
        case .button: Color(hex: 0x4a321c)
        case .candle: Theme.candleDark
        case .blood: Color(hex: 0x6a1c18)
        case .field: Theme.parchmentLight
        }
    }

    var text: Color {
        switch self {
        case .parchment, .candle, .field: Theme.parchmentInk
        default: Theme.ink
        }
    }
}

struct PixelBox: ViewModifier {
    var style: BoxStyle
    var edge: Color = Theme.outline
    var pressed = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(style.text)
            .background {
                ZStack {
                    NotchedRect().fill(edge)
                    VStack(spacing: 0) {
                        (pressed ? style.shadow : style.highlight).frame(height: Theme.px)
                        style.fill
                        (pressed ? style.highlight : style.shadow).frame(height: Theme.px)
                    }
                    .padding(Theme.px)
                }
            }
    }
}

extension View {
    func pixelBox(_ style: BoxStyle, edge: Color = Theme.outline, pressed: Bool = false) -> some View {
        modifier(PixelBox(style: style, edge: edge, pressed: pressed))
    }
}

struct PixelButtonStyle: ButtonStyle {
    var style: BoxStyle = .button
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixelBody(compact ? 20 : 22))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 8)
            .pixelBox(style, pressed: configuration.isPressed)
            .offset(y: configuration.isPressed ? 2 : 0)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static var pixel: PixelButtonStyle { PixelButtonStyle() }
    static func pixel(_ style: BoxStyle, compact: Bool = false) -> PixelButtonStyle {
        PixelButtonStyle(style: style, compact: compact)
    }
}

/// Suelo de tierra a cuadros con viñeta.
struct PixelBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 12
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x17120e)))
            for row in 0...Int(size.height / tile) {
                for col in 0...Int(size.width / tile) where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    ctx.fill(Path(rect), with: .color(Color(hex: 0x1a1410)))
                }
            }
        }
        .overlay(RadialGradient(colors: [.clear, .black.opacity(0.65)], center: .center, startRadius: 200, endRadius: 900))
        .drawingGroup()
    }
}

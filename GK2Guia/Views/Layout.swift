import SwiftUI

/// Sección con lista y detalle, con navegación apilada.
struct MasterDetail<Master: View, Detail: View>: View {
    let title: String
    @Binding var path: [String]
    @ViewBuilder let master: () -> Master
    @ViewBuilder let detail: (String) -> Detail

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView { master().padding(12) }
                .pixelScreen(title)
                .navigationDestination(for: String.self) { id in
                    ScrollView { detail(id).padding(12) }
                        .pixelScreen(title)
                }
        }
    }
}

/// Sección de una sola página.
struct SingleScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView { content().padding(12) }
                .pixelScreen(title)
        }
    }
}

extension View {
    /// Fondo, título y selector de juego para las pantallas dentro de un NavigationStack.
    func pixelScreen(_ title: String) -> some View {
        self
            .background(PixelBackground().ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { GameToolbarItem() }
    }
}

/// Selector de juego sin la cápsula de cristal que iOS 26 pone a los botones de la barra.
private struct GameToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) { GameSwitch() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { GameSwitch() }
        }
    }
}

/// Coloca las vistas en filas y salta de línea cuando no caben.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(maxWidth: bounds.width, subviews: subviews)
        for (subview, (point, width)) in zip(subviews, zip(result.points, result.clamped)) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                          proposal: width.map { ProposedViewSize(width: $0, height: nil) } ?? .unspecified)
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint], clamped: [CGFloat?]) {
        var points: [CGPoint] = [], clamped: [CGFloat?] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            // lo que no cabe ni solo en una fila se ajusta al ancho (su texto salta de línea)
            var size = subview.sizeThatFits(.unspecified)
            let tooWide = size.width > maxWidth
            if tooWide {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            clamped.append(tooWide ? maxWidth : nil)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (CGSize(width: width, height: y + rowHeight), points, clamped)
    }
}

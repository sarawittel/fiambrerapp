import SwiftUI

private struct WideLayoutKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// true en Mac y iPad; false en iPhone (tamaño compacto).
    var isWideLayout: Bool {
        get { self[WideLayoutKey.self] }
        set { self[WideLayoutKey.self] = newValue }
    }
}

/// Sección con lista y detalle: en columnas si hay sitio; si no, con navegación apilada.
struct MasterDetail<Master: View, Detail: View>: View {
    let title: String
    @Binding var path: [String]
    let selection: String?
    @ViewBuilder let master: () -> Master
    @ViewBuilder let detail: (String) -> Detail
    @Environment(\.isWideLayout) private var wide

    var body: some View {
        if wide {
            HStack(alignment: .top, spacing: 20) {
                ScrollView { master().padding(Theme.px) }
                    .frame(width: 340)
                ScrollView {
                    if let selection { detail(selection).padding(Theme.px) }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        } else {
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
}

/// Sección de una sola página.
struct SingleScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.isWideLayout) private var wide

    var body: some View {
        if wide {
            ScrollView { content().padding(20) }
        } else {
            NavigationStack {
                ScrollView { content().padding(12) }
                    .pixelScreen(title)
            }
        }
    }
}

/// Horizontal en pantallas anchas, vertical en iPhone.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder let content: () -> Content
    @Environment(\.isWideLayout) private var wide

    var body: some View {
        if wide {
            HStack(alignment: .top, spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing, content: content)
        }
    }
}

extension View {
    /// Fondo, título y botón de día para las pantallas dentro de un NavigationStack.
    func pixelScreen(_ title: String) -> some View {
        self
            .background(PixelBackground().ignoresSafeArea())
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { TodayBadge() }
            }
            #endif
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
        for (subview, point) in zip(subviews, result.points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
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
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}

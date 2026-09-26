import SwiftUI

struct ContentView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch router.tab {
                case .recipes: RecipesView()
                case .items: ItemsView()
                case .technologies: TechnologiesView()
                case .planner: PlannerView()
                case .characters: CharactersView()
                case .guide: GuideView()
                case .chests: ChestsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomTabs()
        }
        .font(.pixelBody())
        .foregroundStyle(Theme.ink)
        .background(PixelBackground().ignoresSafeArea())
    }
}

private struct BottomTabs: View {
    @Environment(Router.self) private var router
    @Environment(AppState.self) private var state
    @State private var showMore = false

    /// En el móvil solo caben cuatro pestañas holgadas; el resto va en «Más».
    private static let primary = Array(AppTab.allCases.prefix(4))
    private static let secondary = AppTab.allCases.filter { !primary.contains($0) }

    var body: some View {
        let moreTab = Self.secondary.contains(router.tab) ? router.tab : nil
        HStack(spacing: 0) {
            ForEach(Self.primary) { tab in
                Button { router.tab = tab } label: {
                    TabLabel(icon: tab.icon, title: tab.shortTitle, active: router.tab == tab,
                             badge: tab == .planner ? state.planSize : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
            Button { showMore = true } label: {
                TabLabel(icon: moreTab?.icon ?? "skull", title: moreTab?.shortTitle ?? "Más",
                         active: moreTab != nil)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(moreTab.map { "Más: \($0.title)" } ?? "Más")
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background(Theme.woodDark.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.outline.frame(height: Theme.px) }
        .sheet(isPresented: $showMore) {
            MoreTabsSheet(tabs: Self.secondary) { tab in
                router.tab = tab
                showMore = false
            }
            .presentationDetents([.height(CGFloat(Self.secondary.count) * 72 + 70)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.woodDark)
        }
    }
}

private struct TabLabel: View {
    let icon: String
    let title: String
    let active: Bool
    var badge = 0

    var body: some View {
        VStack(spacing: 4) {
            PixelIcon(name: icon, size: 26)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 { PlanCount(count: badge).offset(x: 14, y: -6) }
                }
            Text(title)
                .font(.pixelBody(20))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(active ? Theme.candle : Theme.muted)
        .background(active ? Theme.wood : .clear)
        .overlay(alignment: .top) {
            if active { Theme.candle.frame(height: Theme.px) }
        }
        .contentShape(Rectangle())
    }
}

/// Panel de «Más» con las pestañas que no caben en la barra inferior.
private struct MoreTabsSheet: View {
    @Environment(Router.self) private var router
    let tabs: [AppTab]
    let select: (AppTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Más")
                .font(.pixelTitle(12))
                .foregroundStyle(Theme.candle)
                .padding(.bottom, 2)
            ForEach(tabs) { tab in
                let active = router.tab == tab
                Button { select(tab) } label: {
                    HStack(spacing: 12) {
                        PixelIcon(name: tab.icon, size: 28)
                        Text(tab.title).font(.pixelTitle(11))
                        Spacer()
                        Text("→").font(.pixelBody(24))
                    }
                    .foregroundStyle(active ? Theme.parchmentInk : Theme.ink)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pixel(active ? .parchment : .wood))
            }
            Spacer(minLength: 0)
        }
        .font(.pixelBody())
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }
}

private struct PlanCount: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.pixelTitle(8))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Theme.blood)
            .overlay(Rectangle().strokeBorder(Theme.outline, lineWidth: 2))
    }
}

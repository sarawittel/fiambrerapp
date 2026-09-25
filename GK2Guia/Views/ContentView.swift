import SwiftUI

struct ContentView: View {
    @Environment(Router.self) private var router
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var wide: Bool { sizeClass == .regular }
    #else
    private let wide = true
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if wide {
                HeaderBar()
                TopTabs()
            }
            Group {
                switch router.tab {
                case .recipes: RecipesView()
                case .items: ItemsView()
                case .planner: PlannerView()
                case .calendar: CalendarView()
                case .characters: CharactersView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !wide { BottomTabs() }
        }
        .font(.pixelBody())
        .foregroundStyle(Theme.ink)
        .background(PixelBackground().ignoresSafeArea())
        .environment(\.isWideLayout, wide)
    }
}

private struct HeaderBar: View {
    var body: some View {
        HStack(spacing: 14) {
            PixelIcon(name: "skull", size: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text("Guía del Guardián")
                    .font(.pixelTitle(16))
                    .foregroundStyle(Theme.candle)
                    .shadow(color: Theme.outline, radius: 0, x: 3, y: 3)
                Text("GRAVEYARD KEEPER")
                    .font(.pixelBody(20))
                    .tracking(2)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            TodayBadge()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

private struct TopTabs: View {
    @Environment(Router.self) private var router
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                let active = router.tab == tab
                Button { router.tab = tab } label: {
                    HStack(spacing: 8) {
                        PixelIcon(name: tab.icon, size: 24)
                        Text(tab.title).font(.pixelTitle(10))
                        if tab == .planner, state.planSize > 0 {
                            PlanCount(count: state.planSize)
                        }
                    }
                    .foregroundStyle(active ? Theme.parchmentInk : Theme.muted)
                }
                .buttonStyle(.pixel(active ? .parchment : .woodDark))
                .offset(y: active ? -2 : 0)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }
}

private struct BottomTabs: View {
    @Environment(Router.self) private var router
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = router.tab == tab
                Button { router.tab = tab } label: {
                    VStack(spacing: 2) {
                        PixelIcon(name: tab.icon, size: 24)
                            .overlay(alignment: .topTrailing) {
                                if tab == .planner, state.planSize > 0 {
                                    PlanCount(count: state.planSize).offset(x: 14, y: -6)
                                }
                            }
                        Text(tab.shortTitle).font(.pixelBody(18))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(active ? Theme.candle : Theme.muted)
                    .background(active ? Theme.wood : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .background(Theme.woodDark.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.outline.frame(height: Theme.px) }
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

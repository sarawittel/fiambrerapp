import GK2Core
import SwiftUI

struct RecipesView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var wide
    @State private var query = ""
    @State private var station: String?

    var body: some View {
        @Bindable var router = router
        let results = state.data.searchRecipes(query, station: station)
        let selection = router.recipeId ?? results.first?.id

        MasterDetail(title: "Recetas", path: $router.recipePath, selection: selection) {
            VStack(alignment: .leading, spacing: 12) {
                Panel(title: "Recetario") {
                    PixelTextField(placeholder: "Buscar objeto o ingrediente…", text: $query)
                    stationMenu
                    LazyVStack(spacing: 4) {
                        ForEach(results) { recipe in
                            let item = state.data.item(recipe.output)
                            ListRow(
                                icon: item?.icon ?? "skull",
                                image: item?.image,
                                title: item?.name ?? recipe.output,
                                subtitle: recipe.station,
                                selected: wide && recipe.id == selection
                            ) { router.openRecipe(recipe.id) }
                        }
                    }
                    if results.isEmpty {
                        Text("Nada por aquí… solo polvo y huesos.").foregroundStyle(Theme.muted)
                    }
                }
                DataSourceNotice()
            }
        } detail: { id in
            if let recipe = state.data.recipe(id) {
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    private var stationMenu: some View {
        Menu {
            Button("Todas las estaciones") { station = nil }
            ForEach(state.data.stations, id: \.self) { s in
                Button(s) { station = s }
            }
        } label: {
            HStack {
                Text(station ?? "Todas las estaciones")
                Spacer()
                Text("▾")
            }
            .font(.pixelBody(22))
            .foregroundStyle(Theme.parchmentInk)
            .padding(.horizontal, 10 + Theme.px)
            .padding(.vertical, 6 + Theme.px)
            .pixelBox(.field)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let data = state.data
        let item = data.item(recipe.output)
        let usedIn = data.recipes(using: recipe.output)
        let inPlan = state.count(of: recipe.id)

        Panel(style: .parchment) {
            HStack(spacing: 16) {
                IconFrame(name: item?.icon ?? "skull", image: item?.image, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item?.name ?? recipe.output).font(.pixelTitle(16))
                    FlowLayout(spacing: 6) {
                        HStack(spacing: 4) {
                            if let image = data.stationImage(recipe.station) {
                                PixelIcon(name: "anvil", image: image, size: 24)
                            }
                            Tag(recipe.station)
                        }
                        Tag("Produce ×\(recipe.outputQty)")
                        if let time = recipe.time { Tag("Tiempo \(time)") }
                    }
                }
            }

            if let description = item?.description {
                Text("«\(description)»").foregroundStyle(Theme.parchmentMuted)
            }

            SectionTitle("Ingredientes")
            ForEach(recipe.ingredients, id: \.item) { ing in
                FlowLayout(spacing: 10) {
                    ItemChip(itemId: ing.item, qty: ing.qty)
                    Text(hint(for: ing.item))
                        .font(.pixelBody(19))
                        .foregroundStyle(Theme.parchmentMuted)
                }
            }

            if let notes = recipe.notes { NoteView(text: notes) }

            if !usedIn.isEmpty {
                SectionTitle("Se usa en")
                ChipFlow(itemIds: usedIn.map(\.output))
            }

            FlowLayout(spacing: 10) {
                Button(inPlan > 0 ? "+ Añadir al plan (\(inPlan))" : "+ Añadir al plan") {
                    state.addToPlan(recipe.id)
                }
                .buttonStyle(.pixel(.candle))
                Button("Qué necesito →") { router.tab = .planner }
                    .buttonStyle(.pixel)
            }
            .padding(.top, 10)
        }
    }

    private func hint(for itemId: String) -> String {
        let data = state.data
        if data.recipe(producing: itemId) != nil { return "Fabricable" }
        let sources = data.item(itemId)?.sources ?? []
        let sellers = data.sellers(of: itemId).map { "Lo vende: \($0.name)" }
        let all = sources + sellers
        return all.isEmpty ? "Origen desconocido" : all.joined(separator: " · ")
    }
}

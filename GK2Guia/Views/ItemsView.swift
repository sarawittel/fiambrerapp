import GK2Core
import SwiftUI

struct ItemsView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var wide
    @State private var query = ""
    @State private var category: ItemCategory?

    var body: some View {
        @Bindable var router = router
        let data = state.data
        let results = data.searchItems(query, category: category, craftable: false)
        let selection = router.itemId ?? results.first?.id

        MasterDetail(title: "Objetos", path: $router.itemPath, selection: selection) {
            VStack(alignment: .leading, spacing: 12) {
                Panel(title: "Objetos") {
                    Text("Lo que no se fabrica: se compra, se recoge o te lo dan. Lo fabricable está en Recetas.")
                        .font(.pixelBody(19))
                        .foregroundStyle(Theme.muted)
                    PixelTextField(placeholder: "Buscar objeto…", text: $query)
                    FlowLayout(spacing: 6) {
                        Button("Todos") { category = nil }
                            .buttonStyle(.pixel(category == nil ? .candle : .woodDark, compact: true))
                        ForEach(ItemCategory.allCases, id: \.self) { c in
                            Button(c.title) { category = c }
                                .buttonStyle(.pixel(category == c ? .candle : .woodDark, compact: true))
                        }
                    }
                    LazyVStack(spacing: 4) {
                        ForEach(results) { item in
                            ListRow(
                                icon: item.icon,
                                image: item.image,
                                title: item.name,
                                subtitle: item.category.title,
                                selected: wide && item.id == selection
                            ) { router.openItem(item.id) }
                        }
                    }
                    if results.isEmpty {
                        Text("Nada por aquí… solo polvo y huesos.").foregroundStyle(Theme.muted)
                    }
                }
                DataSourceNotice()
            }
        } detail: { id in
            if let item = data.item(id) {
                ItemDetailView(item: item)
            }
        }
    }
}

struct ItemDetailView: View {
    let item: Item
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let data = state.data
        let sources = item.sources ?? []
        let sellers = data.sellers(of: item.id)
        let buyers = data.buyers(of: item.id)
        let usedIn = data.recipes(using: item.id)
        let quests = data.quests(involving: item.id)

        Panel(style: .parchment) {
            HStack(spacing: 16) {
                IconFrame(name: item.icon, image: item.image, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name).font(.pixelTitle(16))
                    Tag(item.category.title)
                }
            }

            if let description = item.description {
                Text("«\(description)»").foregroundStyle(Theme.parchmentMuted)
            }

            if !sources.isEmpty {
                SectionTitle("Se obtiene")
                FlowLayout(spacing: 6) {
                    ForEach(sources, id: \.self) { Tag($0) }
                }
            }

            if !sellers.isEmpty {
                SectionTitle("Lo vende")
                CharacterChips(npcs: sellers)
            }

            if !buyers.isEmpty {
                SectionTitle("Lo compra")
                CharacterChips(npcs: buyers)
            }

            if !usedIn.isEmpty {
                SectionTitle("Se usa en")
                ChipFlow(itemIds: usedIn.map(\.output))
            }

            if !quests.isEmpty {
                SectionTitle("Encargos")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(quests, id: \.key) { entry in
                        let reward = entry.quest.rewards?.contains(item.id) == true
                        Button { router.openCharacter(entry.npc.id) } label: {
                            HStack(spacing: 6) {
                                PixelIcon(name: entry.npc.icon, image: entry.npc.image, size: 16)
                                Text("\(entry.npc.name) · \(entry.quest.name)")
                                if reward { Text("(recompensa)").opacity(0.7) }
                            }
                        }
                        .buttonStyle(.pixel(.button, compact: true))
                    }
                }
            }

            if sources.isEmpty, sellers.isEmpty, !quests.contains(where: { $0.quest.rewards?.contains(item.id) == true }) {
                Text("Origen desconocido").foregroundStyle(Theme.parchmentMuted)
            }
        }
    }
}

extension ItemCategory {
    var title: String {
        switch self {
        case .material: "Material"
        case .comida: "Comida"
        case .alquimia: "Alquimia"
        case .funerario: "Funerario"
        case .herramienta: "Herramienta"
        }
    }
}

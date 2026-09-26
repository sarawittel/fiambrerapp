import GK2Core
import SwiftUI

struct ChestsView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @State private var newName = ""
    @State private var query = ""

    var body: some View {
        @Bindable var router = router

        MasterDetail(title: "Baúles", path: $router.chestPath) {
            Panel(title: "Mis baúles") {
                Text("Apunta qué guardas en cada baúl: objetos y cosas fabricables, pero no estaciones ni construcciones.")
                    .font(.pixelBody(19))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    PixelTextField(placeholder: "Nombre del baúl…", text: $newName)
                        .onSubmit(create)
                    Button("+ Crear", action: create)
                        .buttonStyle(.pixel(.candle))
                }
                let results = state.searchChests(query)
                if !state.chests.isEmpty {
                    PixelTextField(placeholder: "Buscar baúl u objeto…", text: $query)
                }
                LazyVStack(spacing: 4) {
                    ForEach(results, id: \.chest.id) { chest, items in
                        ListRow(
                            icon: "chest",
                            title: chest.name.isEmpty ? "Sin nombre" : chest.name,
                            subtitle: items.isEmpty ? summary(chest) : found(items, in: chest)
                        ) { router.openChest(chest.id) }
                    }
                }
                if state.chests.isEmpty {
                    Text("Aún no tienes baúles. Ponle nombre a uno y créalo.").foregroundStyle(Theme.muted)
                } else if results.isEmpty {
                    Text("Ningún baúl guarda «\(query)».").foregroundStyle(Theme.muted)
                }
            }
        } detail: { id in
            if let chest = state.chest(id) {
                ChestDetailView(chest: chest)
            }
        }
    }

    private func create() {
        let chest = state.addChest(named: newName)
        newName = ""
        router.openChest(chest.id)
    }

    /// Los objetos buscados que guarda el baúl, p. ej. «Tronco ×3 · Tablón ×1».
    private func found(_ items: [String], in chest: Chest) -> String {
        items.map { "\(state.data.itemName($0)) ×\(chest.count(of: $0))" }.joined(separator: " · ")
    }

    private func summary(_ chest: Chest) -> String {
        switch chest.items.count {
        case 0: "Vacío"
        case 1: "1 objeto · \(chest.total) uds."
        default: "\(chest.items.count) objetos · \(chest.total) uds."
        }
    }
}

struct ChestDetailView: View {
    let chest: Chest
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var confirmDelete = false

    var body: some View {
        let data = state.data
        let rows = chest.items.sorted { data.itemName($0.key).localizedCompare(data.itemName($1.key)) == .orderedAscending }

        Panel(style: .parchment) {
            HStack(spacing: 16) {
                IconFrame(name: "chest", size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    PixelTextField(placeholder: "Nombre del baúl…", text: Binding(
                        get: { chest.name },
                        set: { state.renameChest(chest.id, to: $0) }
                    ))
                    Tag(chest.total == 1 ? "1 unidad" : "\(chest.total) unidades")
                }
            }

            SectionTitle("Contenido")
            if rows.isEmpty {
                Text("Está vacío. Busca abajo lo que quieras guardar.").foregroundStyle(Theme.parchmentMuted)
            }
            VStack(spacing: 0) {
                ForEach(rows, id: \.key) { itemId, count in
                    Rectangle().fill(.tertiary).frame(height: 2)
                    // todo en una línea: el nombre se ajusta y los controles quedan alineados a la derecha
                    HStack(spacing: 8) {
                        itemLink(itemId)
                        Spacer(minLength: 4)
                        controls(itemId: itemId, count: count).fixedSize()
                    }
                    .padding(.vertical, 6)
                }
            }

            SectionTitle("Añadir")
            PixelTextField(placeholder: "Buscar objeto…", text: $query)
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                let results = data.searchItems(query, storable: true)
                VStack(spacing: 4) {
                    ForEach(results.prefix(12)) { item in
                        Button { state.addToChest(item.id, chest: chest.id) } label: {
                            HStack(spacing: 10) {
                                PixelIcon(name: item.icon, image: item.image, size: 24)
                                Text(item.name)
                                Spacer(minLength: 4)
                                let count = chest.count(of: item.id)
                                if count > 0 { Text("×\(count)").foregroundStyle(Theme.parchmentMuted) }
                                Text("+").font(.pixelTitle(11))
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir \(item.name)")
                    }
                }
                if results.isEmpty {
                    Text("Nada por aquí… solo polvo y huesos.").foregroundStyle(Theme.parchmentMuted)
                } else if results.count > 12 {
                    Text("Y \(results.count - 12) más: afina la búsqueda.")
                        .font(.pixelBody(19))
                        .foregroundStyle(Theme.parchmentMuted)
                }
            }

            Button("× Borrar baúl") { confirmDelete = true }
                .buttonStyle(.pixel(.blood))
                .padding(.top, 10)
        }
        .confirmationDialog("¿Borrar «\(chest.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar baúl", role: .destructive) {
                router.chestPath.removeAll { $0 == chest.id }
                state.deleteChest(chest.id)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se perderá la lista de lo que guarda.")
        }
    }

    /// Icono y nombre; lleva a la receta si es fabricable o a la ficha del objeto.
    private func itemLink(_ itemId: String) -> some View {
        let item = state.data.item(itemId)
        return Button {
            if let recipe = state.data.recipe(producing: itemId) {
                router.openRecipe(recipe.id)
            } else {
                router.openItem(itemId)
            }
        } label: {
            HStack(spacing: 6) {
                PixelIcon(name: item?.icon ?? "skull", image: item?.image, size: 24)
                Text(item?.name ?? itemId)
                    .font(.pixelBody(21))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func controls(itemId: String, count: Int) -> some View {
        HStack(spacing: 8) {
            CountField(value: count) { state.setCount($0, of: itemId, inChest: chest.id) }
            Button("×") { state.setCount(0, of: itemId, inChest: chest.id) }
                .buttonStyle(.pixel(.blood, compact: true))
                .help("Sacar del baúl")
                .accessibilityLabel("Sacar \(state.data.itemName(itemId)) del baúl")
        }
    }
}

/// Botón para guardar un objeto en uno de los baúles, y en cuáles está ya.
/// No aparece con estaciones ni construcciones, que no caben en un baúl.
struct ChestSection: View {
    let itemId: String
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        if !state.data.isStation(itemId) {
            let stored = state.chests(containing: itemId)
            SectionTitle("En tus baúles")
            FlowLayout(spacing: 6) {
                ForEach(stored, id: \.chest.id) { entry in
                    Button { router.openChest(entry.chest.id) } label: {
                        HStack(spacing: 6) {
                            PixelIcon(name: "chest", size: 16)
                            Text("\(entry.chest.name) ×\(entry.count)")
                        }
                    }
                    .buttonStyle(.pixel(.button, compact: true))
                }
                if state.chests.isEmpty {
                    Button("+ Crear un baúl →") { router.tab = .chests }
                        .buttonStyle(.pixel(.button, compact: true))
                } else {
                    Menu {
                        ForEach(state.chests) { chest in
                            Button("\(chest.name) (\(chest.count(of: itemId)))") {
                                state.addToChest(itemId, chest: chest.id)
                            }
                        }
                    } label: {
                        Text("+ Guardar en baúl")
                            .font(.pixelBody(20))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .pixelBox(.button)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
    }
}

import GK2Core
import SwiftUI

struct TechnologiesView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var wide
    @State private var query = ""

    var body: some View {
        @Bindable var router = router
        let data = state.data
        let selection = router.techTreeId ?? data.technologies.first?.id
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let results = data.searchTechnologies(query)

        MasterDetail(title: "Tecnologías", path: $router.techTreePath, selection: selection) {
            VStack(alignment: .leading, spacing: 12) {
                Panel(title: "Tecnologías") {
                    Text("Se pagan con puntos de tres colores. Los consigues trabajando y estudiando objetos en la mesa de estudio.")
                        .font(.pixelBody(19))
                        .foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        PointLegend(color: "red", text: "Trabajo físico: talar, minar, forjar")
                        PointLegend(color: "green", text: "Naturaleza: cultivar, recoger, madera")
                        PointLegend(color: "blue", text: "Espíritu: morgue, cementerio, escritura, alquimia")
                    }
                    PixelTextField(placeholder: "Buscar tecnología u objeto…", text: $query)
                    if searching {
                        VStack(spacing: 4) {
                            ForEach(results.indices, id: \.self) { i in
                                let (tree, tech) = results[i]
                                ListRow(
                                    icon: "candle",
                                    image: tree.image,
                                    title: tech.name,
                                    subtitle: tree.name + (state.isResearched(tech, in: tree) ? " · investigada" : ""),
                                    selected: wide && tree.id == selection && router.techId == tech.id
                                ) { router.openTechTree(tree.id, tech: tech.id) }
                            }
                        }
                        if results.isEmpty {
                            Text("Ninguna tecnología coincide con «\(query)».").foregroundStyle(Theme.muted)
                        }
                    } else {
                        VStack(spacing: 4) {
                            ForEach(data.technologies) { tree in
                                let techs = tree.technologies
                                let done = techs.filter { state.isResearched($0, in: tree) }.count
                                ListRow(
                                    icon: "candle",
                                    image: tree.image,
                                    title: tree.name,
                                    subtitle: "\(done)/\(techs.count) investigadas" + (tree.dlc.map { " · DLC \($0)" } ?? ""),
                                    selected: wide && tree.id == selection
                                ) { router.openTechTree(tree.id) }
                            }
                        }
                    }
                }
                DataSourceNotice()
            }
        } detail: { id in
            if let tree = data.techTree(id) {
                TechTreeDetailView(tree: tree)
            }
        }
    }
}

private struct PointLegend: View {
    let color: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            PixelIcon(name: "candle", image: "techpoint_\(color)", size: 20)
            Text(text).font(.pixelBody(19))
        }
    }
}

struct TechTreeDetailView: View {
    let tree: TechTree
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let techs = tree.technologies
        let done = techs.filter { state.isResearched($0, in: tree) }.count

        ScrollViewReader { proxy in
            Panel(style: .parchment) {
                HStack(spacing: 16) {
                    IconFrame(name: "candle", image: tree.image, size: 64)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tree.name).font(.pixelTitle(16))
                        FlowLayout(spacing: 6) {
                            Tag("\(done)/\(techs.count) investigadas")
                            if let dlc = tree.dlc { Tag("DLC \(dlc)") }
                        }
                    }
                }
                ForEach(Array((tree.text ?? []).enumerated()), id: \.offset) { _, paragraph in
                    RichText(paragraph).foregroundStyle(Theme.parchmentMuted)
                }
                ForEach(Array(tree.branches.enumerated()), id: \.offset) { _, branch in
                    if let name = branch.name { SectionTitle(name) }
                    ForEach(Array((branch.text ?? []).enumerated()), id: \.offset) { _, paragraph in
                        RichText(paragraph).font(.pixelBody(20)).foregroundStyle(Theme.parchmentMuted)
                    }
                    VStack(spacing: 8) {
                        ForEach(branch.techs) { tech in
                            TechCard(tree: tree, tech: tech, highlighted: router.techId == tech.id)
                                .id(tech.id)
                        }
                    }
                }
            }
            .onAppear { scroll(proxy) }
            .onChange(of: router.techId) { scroll(proxy) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let id = router.techId, tree.technologies.contains(where: { $0.id == id }) else { return }
        withAnimation { proxy.scrollTo(id, anchor: .top) }
    }
}

/// Una tecnología: coste, requisitos y lo que desbloquea; se puede marcar como investigada.
struct TechCard: View {
    let tree: TechTree
    let tech: Technology
    var highlighted = false
    @Environment(AppState.self) private var state

    var body: some View {
        let done = state.isResearched(tech, in: tree)
        let names = Dictionary(tree.technologies.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle(isOn: Binding(get: { done }, set: { state.setResearched($0, tech, in: tree) })) { EmptyView() }
                    .toggleStyle(PixelCheckboxStyle())
                    .accessibilityLabel(done ? "Investigada" : "Pendiente")
                VStack(alignment: .leading, spacing: 4) {
                    Text(tech.name)
                        .font(.pixelBody(23))
                        .strikethrough(done)
                    FlowLayout(spacing: 6) {
                        ForEach(tech.cost?.points ?? [], id: \.color) { point in
                            HStack(spacing: 2) {
                                PixelIcon(name: "candle", image: "techpoint_\(point.color)", size: 20)
                                Text("\(point.value)").font(.pixelBody(21))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(point.value) \(point.color.pointTitle)")
                        }
                        if let dlc = tech.dlc { Tag("DLC \(dlc)") }
                    }
                }
            }

            if let requires = tech.requires, !requires.isEmpty {
                Text("Requiere: " + requires.map { names[$0] ?? $0 }.joined(separator: " + "))
                    .font(.pixelBody(19))
                    .foregroundStyle(Theme.parchmentMuted)
            }
            if let condition = tech.condition {
                RichText(condition).font(.pixelBody(20))
            }
            if let unlocks = tech.unlocks, !unlocks.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(unlocks, id: \.self) { UnlockChip(unlock: $0) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(highlighted ? Theme.candleDark : Theme.parchmentDark, lineWidth: 3))
        .opacity(done ? 0.6 : 1)
    }
}

/// Lo que desbloquea una tecnología: el objeto enlazado si existe; si no, su nombre.
private struct UnlockChip: View {
    let unlock: TechUnlock
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Text(unlock.kind.title)
                .font(.pixelBody(18))
                .foregroundStyle(Theme.parchmentMuted)
            if let item = unlock.item {
                ItemChip(itemId: item)
            } else {
                HStack(spacing: 4) {
                    if let image = state.data.stationImage(unlock.name) {
                        PixelIcon(name: "anvil", image: image, size: 24)
                    }
                    Tag(unlock.name)
                }
            }
        }
    }
}

/// Botones que llevan a cada tecnología, en su árbol.
struct TechChips: View {
    let entries: [(tree: TechTree, tech: Technology)]
    @Environment(Router.self) private var router

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(entries.indices, id: \.self) { i in
                let entry = entries[i]
                Button { router.openTechTree(entry.tree.id, tech: entry.tech.id) } label: {
                    HStack(spacing: 4) {
                        PixelIcon(name: "candle", image: entry.tree.image, size: 16)
                        Text("\(entry.tree.name) · \(entry.tech.name)")
                    }
                }
                .buttonStyle(.pixel(.button, compact: true))
            }
        }
    }
}

extension TechUnlock.Kind {
    var title: String {
        switch self {
        case .blueprint: "Plano"
        case .create: "Fabricar"
        case .extract: "Extraer"
        case .gathering: "Recolectar"
        case .perk: "Perk"
        case .recipe: "Receta"
        }
    }
}

extension String {
    /// nombre de un color de punto de tecnología ("red"…), para la accesibilidad
    var pointTitle: String {
        switch self {
        case "red": "puntos rojos"
        case "green": "puntos verdes"
        case "blue": "puntos azules"
        case "soul": "puntos de alma"
        default: "puntos violeta"
        }
    }
}

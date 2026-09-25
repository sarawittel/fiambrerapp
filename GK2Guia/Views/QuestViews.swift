import GK2Core
import SwiftUI

/// Markdown en línea de la wiki. Los enlaces `gk2://item/<id>` y `gk2://character/<id>`
/// llevan a la receta (o ficha) del objeto y a la ficha del personaje.
struct RichText: View {
    let markdown: String
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    init(_ markdown: String) { self.markdown = markdown }

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                open(url) ? .handled : .systemAction
            })
    }

    private func open(_ url: URL) -> Bool {
        guard url.scheme == "gk2", let id = url.pathComponents.last else { return false }
        switch url.host {
        case "item":
            if let recipe = state.data.recipe(producing: id) { router.openRecipe(recipe.id) } else { router.openItem(id) }
        case "character":
            router.openCharacter(id)
        default:
            return false
        }
        return true
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var text = try? AttributedString(markdown: markdown, options: options) else {
            return AttributedString(markdown)
        }
        for run in text.runs where run.link != nil {
            text[run.range].foregroundColor = Theme.blood
            text[run.range].underlineStyle = .single
        }
        return text
    }
}

/// Botones que llevan a la ficha de cada personaje.
struct CharacterChips: View {
    let npcs: [NPC]
    @Environment(Router.self) private var router

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(npcs) { npc in
                Button { router.openCharacter(npc.id) } label: {
                    HStack(spacing: 4) {
                        PixelIcon(name: npc.icon, image: npc.image, size: 16)
                        Text(npc.name)
                    }
                }
                .buttonStyle(.pixel(.button, compact: true))
            }
        }
    }
}

/// Un encargo: se despliega para ver los pasos y se puede marcar como hecho.
struct QuestCard: View {
    let npc: NPC
    let quest: Quest
    @Environment(AppState.self) private var state
    @State private var expanded = false

    var body: some View {
        let done = state.isDone(quest, of: npc)
        let data = state.data

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle(isOn: Binding(get: { done }, set: { state.setDone($0, quest, of: npc) })) { EmptyView() }
                    .toggleStyle(PixelCheckboxStyle())
                    .accessibilityLabel(done ? "Hecho" : "Pendiente")
                Button { expanded.toggle() } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.name)
                                .font(.pixelBody(23))
                                .strikethrough(done)
                            FlowLayout(spacing: 6) {
                                if let friendship = quest.friendship { Tag("+\(friendship) ♥", highlighted: true) }
                                if let dlc = quest.dlc { Tag("DLC \(dlc)") }
                            }
                        }
                        Spacer(minLength: 4)
                        Text(expanded ? "▾" : "▸").foregroundStyle(Theme.parchmentMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "Ocultar detalles" : "Ver detalles")
            }

            if let rewards = quest.rewards, !rewards.isEmpty {
                Text("Recompensa").font(.pixelBody(19)).foregroundStyle(Theme.parchmentMuted)
                ChipFlow(itemIds: rewards)
            }

            if expanded {
                ForEach(Array(quest.text.enumerated()), id: \.offset) { _, paragraph in
                    RichText(paragraph).font(.pixelBody(20))
                }
                if let items = quest.items, !items.isEmpty {
                    Text("Objetos que aparecen").font(.pixelBody(19)).foregroundStyle(Theme.parchmentMuted)
                    ChipFlow(itemIds: items)
                }
                let people = (quest.characters ?? []).compactMap(data.character)
                if !people.isEmpty {
                    Text("Personajes").font(.pixelBody(19)).foregroundStyle(Theme.parchmentMuted)
                    CharacterChips(npcs: people)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(Theme.parchmentDark, lineWidth: 3))
        .opacity(done ? 0.6 : 1)
    }
}

/// Qué se desbloquea en cada nivel de amistad.
struct FriendshipLadder: View {
    let milestones: [FriendshipMilestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                HStack(alignment: .top, spacing: 10) {
                    Tag("\(milestone.level) ♥", highlighted: true)
                    VStack(alignment: .leading, spacing: 6) {
                        RichText(milestone.text).font(.pixelBody(20))
                        if let items = milestone.items, !items.isEmpty {
                            ChipFlow(itemIds: items)
                        }
                    }
                }
            }
        }
    }
}

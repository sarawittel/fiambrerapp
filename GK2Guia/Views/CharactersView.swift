import GK2Core
import SwiftUI

struct CharactersView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var wide
    @State private var dayFilter: String?

    var body: some View {
        @Bindable var router = router
        let data = state.data
        let list = dayFilter.map { day in data.characters.filter { $0.isAvailable(on: day) } } ?? data.characters
        let selection = router.characterId ?? list.first?.id

        MasterDetail(title: "Personajes", path: $router.characterPath, selection: selection) {
            Panel(title: "Personajes") {
                FlowLayout(spacing: 6) {
                    Button("Todos") { dayFilter = nil }
                        .buttonStyle(.pixel(dayFilter == nil ? .candle : .woodDark, compact: true))
                    ForEach(data.days) { day in
                        Button { dayFilter = day.id } label: {
                            HStack(spacing: 4) {
                                PixelIcon(name: day.icon, image: day.image, size: 16)
                                Text(day.short)
                            }
                        }
                        .buttonStyle(.pixel(dayFilter == day.id ? .candle : .woodDark, compact: true))
                    }
                }
                VStack(spacing: 4) {
                    ForEach(list) { npc in
                        ListRow(
                            icon: npc.icon,
                            image: npc.image,
                            title: npc.name,
                            subtitle: "\(npc.title) · \(npc.location)",
                            badge: npc.isAvailable(on: state.today) ? "Hoy" : nil,
                            selected: wide && npc.id == selection
                        ) { router.openCharacter(npc.id) }
                    }
                }
                if list.isEmpty {
                    Text("Nadie aparece ese día.").foregroundStyle(Theme.muted)
                }
            }
        } detail: { id in
            if let npc = data.character(id) {
                CharacterDetailView(npc: npc)
            }
        }
    }
}

struct CharacterDetailView: View {
    let npc: NPC
    @Environment(AppState.self) private var state

    var body: some View {
        let quests = npc.quests ?? []
        let done = quests.filter { state.isDone($0, of: npc) }.count

        Panel(style: .parchment) {
            HStack(spacing: 16) {
                IconFrame(name: npc.icon, image: npc.image, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text(npc.name).font(.pixelTitle(16))
                    FlowLayout(spacing: 6) {
                        Tag(npc.title)
                        Tag(npc.location)
                    }
                }
            }
            SectionTitle("Días de visita")
            DayBadges(active: npc.days)
            if !quests.isEmpty {
                SectionTitle("Encargos · \(done)/\(quests.count)")
                VStack(spacing: 8) {
                    ForEach(quests) { QuestCard(npc: npc, quest: $0) }
                }
            }
            if let friendship = npc.friendship, !friendship.isEmpty {
                SectionTitle("Amistad")
                FriendshipLadder(milestones: friendship)
            }
            if let sells = npc.sells, !sells.isEmpty {
                SectionTitle("Vende")
                ChipFlow(itemIds: sells)
            }
            if let buys = npc.buys, !buys.isEmpty {
                SectionTitle("Compra")
                ChipFlow(itemIds: buys)
            }
            if let notes = npc.notes {
                NoteView(text: notes).padding(.top, 8)
            }
        }
    }
}

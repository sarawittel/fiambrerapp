import GK2Core
import SwiftUI

/// Guía de logros al 100 %, por apartados, con los logros que ya tienes marcados.
struct GuideView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        let data = state.data
        let all = data.guide.flatMap(\.achievements)
        let done = all.filter(state.isAchieved).count

        MasterDetail(title: "Guía", path: $router.guidePath) {
            VStack(alignment: .leading, spacing: 12) {
                GameProgressPanel()
                Panel(title: "Logros al 100 %") {
                    Text(all.isEmpty
                         ? "Todavía no hay logros de \(state.game.title) en la guía."
                         : "Cómo conseguir cada logro del juego, por apartados. Márcalos según los consigas.")
                        .font(.pixelBody(19))
                        .foregroundStyle(Theme.muted)
                    if !all.isEmpty {
                        FlowLayout(spacing: 6) {
                            Tag("\(done)/\(all.count) conseguidos", highlighted: done == all.count)
                        }
                    }
                    VStack(spacing: 4) {
                        ForEach(data.guide) { section in
                            let achievements = section.achievements
                            let got = achievements.filter(state.isAchieved).count
                            ListRow(
                                icon: "crown",
                                image: achievements.first?.image,
                                title: section.title,
                                subtitle: "\(got)/\(achievements.count) conseguidos" + (section.spoiler == true ? " · spoilers" : "")
                            ) { router.openGuideSection(section.id) }
                        }
                    }
                }
                DataSourceNotice()
            }
        } detail: { id in
            if let section = data.guideSection(id) {
                // `.id` para que los spoilers vuelvan a ocultarse al cambiar de apartado
                GuideSectionView(section: section).id(section.id)
            }
        }
    }
}

/// Juego completado y el progreso de misiones, tecnologías y logros.
private struct GameProgressPanel: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let percent = Int((state.completion * 100).rounded(.down))
        Panel(title: "Juego completado") {
            HStack(spacing: 12) {
                Text("\(percent)%")
                    .font(.pixelTitle(18))
                    .foregroundStyle(Theme.candle)
                ProgressBar(fraction: state.completion)
                    .frame(height: 12)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Juego completado: \(percent) por ciento")
            Text("Media de misiones, tecnologías y logros.")
                .font(.pixelBody(19))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                // un juego sin misiones o sin logros (GK2) no muestra ese contador
                if state.questProgress.total > 0 { stat("person", state.questProgress, label: "Misiones", tab: .characters) }
                if state.techProgress.total > 0 { stat("candle", state.techProgress, label: "Tecnologías", tab: .technologies) }
                if state.achievementProgress.total > 0 { stat("crown", state.achievementProgress, label: "Logros", tab: nil) }
            }
        }
    }

    /// `tab` nil = ya estamos en esa sección
    private func stat(_ icon: String, _ progress: AppState.Progress, label: String, tab: AppTab?) -> some View {
        Button { if let tab { router.tab = tab } } label: {
            VStack(spacing: 4) {
                PixelIcon(name: icon, size: 24)
                Text("\(progress.done)/\(progress.total)")
                    .font(.pixelBody(22))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(label)
                    .font(.pixelBody(18))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pixel(.woodDark, compact: true))
        .accessibilityLabel("\(label): \(progress.done) de \(progress.total)")
    }
}

struct GuideSectionView: View {
    let section: GuideSection
    @Environment(AppState.self) private var state
    @State private var showSpoilers = false

    var body: some View {
        let achievements = section.achievements
        let done = achievements.filter(state.isAchieved).count
        let hidden = section.spoiler == true && !showSpoilers

        Panel(style: .parchment) {
            HStack(spacing: 16) {
                IconFrame(name: "crown", image: achievements.first?.image, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title).font(.pixelTitle(16))
                    FlowLayout(spacing: 6) {
                        Tag("\(done)/\(achievements.count) conseguidos")
                        if section.spoiler == true { Tag("Spoilers") }
                    }
                }
            }

            if hidden {
                Text("Este apartado cuenta partes de la historia. Los nombres de los logros se ven; el cómo conseguirlos, no.")
                    .font(.pixelBody(20))
                    .foregroundStyle(Theme.parchmentMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Mostrar spoilers") { showSpoilers = true }
                    .buttonStyle(.pixel(.button, compact: true))
            }

            VStack(spacing: 8) {
                ForEach(achievements) { AchievementCard(achievement: $0, showsDetails: !hidden) }
            }
        }
    }
}

/// Un logro: imagen, cómo conseguirlo y si ya lo tienes.
struct AchievementCard: View {
    let achievement: Achievement
    var showsDetails = true
    @Environment(AppState.self) private var state
    @State private var expanded = false

    var body: some View {
        let done = state.isAchieved(achievement)
        let people = (achievement.characters ?? []).compactMap(state.data.character)
        let items = achievement.items ?? []

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Toggle(isOn: Binding(get: { done }, set: { state.setAchieved($0, achievement) })) { EmptyView() }
                    .toggleStyle(PixelCheckboxStyle())
                    .accessibilityLabel(done ? "Conseguido" : "Pendiente")
                PixelIcon(name: "crown", image: achievement.image, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.name)
                        .font(.pixelBody(23))
                        .strikethrough(done)
                    FlowLayout(spacing: 6) {
                        if achievement.missable == true { Tag("¡Se puede perder!", highlighted: true) }
                        if let dlc = achievement.dlc { Tag("DLC \(dlc)") }
                    }
                }
            }

            if showsDetails {
                ForEach(Array(achievement.text.enumerated()), id: \.offset) { _, paragraph in
                    RichText(paragraph).font(.pixelBody(20))
                }
                if !items.isEmpty || !people.isEmpty {
                    Button { expanded.toggle() } label: {
                        Text((expanded ? "▾ " : "▸ ") + "Objetos y personajes")
                            .font(.pixelBody(19))
                            .foregroundStyle(Theme.parchmentMuted)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if expanded {
                    if !items.isEmpty { ChipFlow(itemIds: items) }
                    if !people.isEmpty { CharacterChips(npcs: people) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(Theme.parchmentDark, lineWidth: 3))
        .opacity(done ? 0.6 : 1)
    }
}

extension GuideSection {
    /// nombre del apartado en español; el de la wiki si no se conoce
    var title: String {
        switch id {
        case "starting_out": "Primeros pasos"
        case "graveyard": "Cementerio"
        case "questlines": "Historias"
        case "crafting_cooking_farming": "Fabricar, cocinar y cultivar"
        case "fishing": "Pesca"
        case "points": "Puntos de tecnología"
        case "dungeon": "Mazmorra"
        case "miscellaneous": "Otros"
        default: name
        }
    }
}

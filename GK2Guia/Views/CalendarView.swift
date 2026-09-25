import GK2Core
import SwiftUI

struct CalendarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let data = state.data
        let present = data.characters.filter { $0.isAvailable(on: state.today) }
        let arriving = data.characters.filter { $0.isAvailable(on: state.tomorrow.id) && !$0.isAvailable(on: state.today) }

        SingleScreen(title: "Calendario") {
            VStack(spacing: 20) {
                Panel(title: "La semana") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 14) {
                        ForEach(data.days) { DayTile(day: $0) }
                    }
                    Button("Dormir hasta el día siguiente →") { state.sleep() }
                        .buttonStyle(.pixel(.candle))
                        .padding(.top, 6)
                }

                AdaptiveStack {
                    Panel(title: "Hoy · \(state.todayDay.name)", style: .parchment) {
                        NPCList(npcs: present, empty: "Nadie a la vista. Buen día para cavar.")
                    }
                    Panel(title: "Mañana llegan · \(state.tomorrow.short)", style: .parchment) {
                        NPCList(npcs: arriving, empty: "Nadie nuevo mañana.")
                    }
                }

                Panel(title: "Quién está cada día") {
                    WeekGrid()
                }
            }
        }
    }
}

private struct DayTile: View {
    let day: Day
    @Environment(AppState.self) private var state

    var body: some View {
        let active = day.id == state.today
        Button { state.today = day.id } label: {
            VStack(spacing: 8) {
                PixelIcon(name: day.icon, size: 40)
                Text(day.short)
            }
            .foregroundStyle(active ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .pixelBox(active ? .woodSelected : .woodDark, edge: active ? Color(hexString: day.color) : Theme.outline)
            .offset(y: active ? -3 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.name)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct NPCList: View {
    let npcs: [NPC]
    let empty: String
    @Environment(Router.self) private var router

    var body: some View {
        if npcs.isEmpty {
            Text(empty).foregroundStyle(Theme.parchmentMuted)
        } else {
            VStack(spacing: 4) {
                ForEach(npcs) { npc in
                    ListRow(icon: npc.icon, title: npc.name, subtitle: npc.location) {
                        router.openCharacter(npc.id)
                    }
                }
            }
        }
    }
}

private struct WeekGrid: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let data = state.data
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("PERSONAJE").font(.pixelTitle(8)).padding(.vertical, 8)
                ForEach(data.days) { day in
                    PixelIcon(name: day.icon, size: 16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(day.id == state.today ? Theme.candle.opacity(0.15) : .clear)
                        .help(day.name)
                }
            }
            Theme.ink.frame(height: Theme.px).gridCellUnsizedAxes(.horizontal)
            ForEach(data.characters) { npc in
                GridRow {
                    Button(npc.name) { router.openCharacter(npc.id) }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        .padding(.trailing, 10)
                    ForEach(data.days) { day in
                        Text(npc.isAvailable(on: day.id) ? "●" : " ")
                            .foregroundStyle(Theme.candle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(day.id == state.today ? Theme.candle.opacity(0.15) : .clear)
                    }
                }
                Rectangle().fill(.black.opacity(0.35)).frame(height: 2).gridCellUnsizedAxes(.horizontal)
            }
        }
    }
}

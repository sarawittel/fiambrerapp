import GK2Core
import SwiftUI

struct PlannerView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @Environment(\.isWideLayout) private var wide

    var body: some View {
        SingleScreen(title: "Qué necesito") {
            if state.plan.isEmpty {
                emptyState
            } else {
                AdaptiveStack {
                    planPanel.frame(width: wide ? 340 : nil)
                    MaterialsPanel()
                }
            }
        }
    }

    private var emptyState: some View {
        Panel(title: "Qué necesito") {
            VStack(spacing: 16) {
                PixelIcon(name: "sack", size: 64)
                Text("Tu saco está vacío. Añade recetas desde el recetario para calcular los materiales.")
                    .multilineTextAlignment(.center)
                Button("Ir al recetario →") { router.tab = .recipes }
                    .buttonStyle(.pixel(.candle))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private var planPanel: some View {
        @Bindable var state = state
        let entries = state.plan.keys.sorted {
            state.data.itemName(state.data.recipe($0)?.output ?? $0) < state.data.itemName(state.data.recipe($1)?.output ?? $1)
        }
        return Panel(title: "Plan de trabajo") {
            ForEach(entries, id: \.self) { id in
                let recipe = state.data.recipe(id)
                let item = recipe.flatMap { state.data.item($0.output) }
                HStack(spacing: 8) {
                    Button { router.openRecipe(id) } label: {
                        HStack(spacing: 10) {
                            PixelIcon(name: item?.icon ?? "skull", image: item?.image, size: 32)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item?.name ?? id)
                                Text(recipe?.station ?? "").font(.pixelBody(18)).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 4)
                    HStack(spacing: 4) {
                        Button("−") { state.setCount(state.count(of: id) - 1, for: id) }
                            .buttonStyle(.pixel(.button, compact: true))
                            .accessibilityLabel("Menos")
                        Text("\(state.count(of: id))").frame(minWidth: 26)
                        Button("+") { state.setCount(state.count(of: id) + 1, for: id) }
                            .buttonStyle(.pixel(.button, compact: true))
                            .accessibilityLabel("Más")
                    }
                }
            }
            Toggle("Desglosar hasta materias primas", isOn: $state.deepBreakdown)
                .toggleStyle(PixelCheckboxStyle())
                .padding(.top, 6)
            Button("× Vaciar plan") { state.clearPlan() }
                .buttonStyle(.pixel(.blood))
        }
    }
}

private struct MaterialsPanel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let data = state.data
        let requirements = state.requirements
        let rows = requirements.materials.sorted { data.itemName($0.key) < data.itemName($1.key) }
        let missing = rows.filter { state.owned[$0.key, default: 0] < $0.value }.count

        Panel(style: .parchment) {
            Text("Materiales").font(.pixelTitle(16))
            Text(missing == 0 ? "✓ Tienes todo lo necesario." : "Te faltan \(missing) de \(rows.count) materiales.")
                .foregroundStyle(Theme.parchmentMuted)

            VStack(spacing: 0) {
                ForEach(rows, id: \.key) { itemId, qty in
                    MaterialRow(itemId: itemId, needed: qty)
                    Rectangle().fill(.tertiary).frame(height: 2)
                }
            }

            if state.deepBreakdown, !requirements.steps.isEmpty {
                SectionTitle("Orden de fabricación")
                ForEach(Array(requirements.steps.enumerated()), id: \.element.recipeId) { index, step in
                    if let recipe = data.recipe(step.recipeId) {
                        Text("\(index + 1). Fabrica \(step.crafts)× \(data.itemName(recipe.output)) en \(recipe.station)")
                            + Text("  (→ \(step.crafts * recipe.outputQty) uds.)").foregroundColor(Theme.parchmentMuted)
                    }
                }
                Text("\(requirements.steps.count + 1). Por último, las recetas de tu plan.")
            }
        }
    }
}

private struct MaterialRow: View {
    let itemId: String
    let needed: Int
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let have = state.owned[itemId, default: 0]
        let missing = max(0, needed - have)

        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ItemChip(itemId: itemId)
                    Spacer(minLength: 8)
                    numbers(have: have, missing: missing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ItemChip(itemId: itemId)
                    numbers(have: have, missing: missing)
                }
            }
            whereToGet
        }
        .padding(.vertical, 10)
        .opacity(missing == 0 ? 0.6 : 1)
    }

    private func numbers(have: Int, missing: Int) -> some View {
        HStack(spacing: 14) {
            labeled("Necesito") { Text("\(needed)").font(.pixelBody(26)) }
            labeled("Tengo") { CountField(value: have) { state.setOwned($0, for: itemId) } }
            labeled("Faltan") {
                Text(missing == 0 ? "✓" : "\(missing)")
                    .font(.pixelBody(26))
                    .foregroundStyle(missing == 0 ? Theme.moss : Theme.blood)
            }
        }
    }

    private func labeled<V: View>(_ label: String, @ViewBuilder _ value: () -> V) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased()).font(.pixelTitle(7)).foregroundStyle(Theme.parchmentMuted)
            value()
        }
    }

    @ViewBuilder private var whereToGet: some View {
        let sources = state.data.item(itemId)?.sources ?? []
        let sellers = state.data.sellers(of: itemId)
        if !sources.isEmpty || !sellers.isEmpty {
            FlowLayout(spacing: 10) {
                ForEach(sources, id: \.self) { Text($0).font(.pixelBody(19)) }
                ForEach(sellers) { npc in
                    let here = npc.isAvailable(on: state.today)
                    Button { router.openCharacter(npc.id) } label: {
                        Text("\(here ? "● " : "")\(npc.name) (\(daysText(npc)))")
                            .font(.pixelBody(19))
                            .underline(pattern: .dot)
                            .foregroundStyle(here ? Color(hex: 0x3a5a1a) : Theme.parchmentMuted)
                    }
                    .buttonStyle(.plain)
                    .help(here ? "Está disponible hoy" : "")
                }
            }
        }
    }

    private func daysText(_ npc: NPC) -> String {
        npc.days.isEmpty ? "todos los días" : npc.days.compactMap { state.data.day($0)?.short }.joined(separator: ", ")
    }
}

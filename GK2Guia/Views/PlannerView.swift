import GK2Core
import SwiftUI

struct PlannerView: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var expanded: Set<String> = []

    var body: some View {
        SingleScreen(title: "Qué necesito") {
            if state.plan.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    controls
                    cards
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

    private var controls: some View {
        @Bindable var state = state
        return Panel(title: "Plan de trabajo") {
            PixelTextField(placeholder: "Buscar receta o material…", text: $query)
            Toggle("Desglosar hasta materias primas", isOn: $state.deepBreakdown)
                .toggleStyle(PixelCheckboxStyle())
            Button("× Vaciar plan") { state.clearPlan() }
                .buttonStyle(.pixel(.blood))
        }
    }

    /// Recetas del plan que casan con la búsqueda, de más a menos avanzadas.
    private var cards: some View {
        let data = state.data
        let matching = Set(data.searchRecipes(query).map(\.id))
        let entries = state.plan.keys
            .filter { matching.contains($0) }
            .map { id in
                let requirements = Planner.requirements(for: [id: state.count(of: id)], recipes: data.recipes, deep: state.deepBreakdown)
                return (id: id, requirements: requirements, progress: requirements.progress(owned: state.owned))
            }
            .sorted {
                $0.progress != $1.progress
                    ? $0.progress > $1.progress
                    : data.itemName(data.recipe($0.id)?.output ?? $0.id) < data.itemName(data.recipe($1.id)?.output ?? $1.id)
            }

        return VStack(spacing: 12) {
            if entries.isEmpty {
                Panel { Text("Ninguna receta del plan coincide con «\(query)».") }
            }
            ForEach(entries, id: \.id) { entry in
                PlanCard(
                    recipeId: entry.id,
                    requirements: entry.requirements,
                    progress: entry.progress,
                    expanded: Binding(
                        get: { expanded.contains(entry.id) },
                        set: { if $0 { expanded.insert(entry.id) } else { expanded.remove(entry.id) } }
                    )
                )
            }
        }
    }
}

/// Una receta del plan: cabecera con su progreso y, al desplegarla, sus materiales y pasos.
private struct PlanCard: View {
    let recipeId: String
    let requirements: Requirements
    let progress: Double
    @Binding var expanded: Bool
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        let data = state.data
        let recipe = data.recipe(recipeId)
        let item = recipe.flatMap { data.item($0.output) }
        let percent = Int((progress * 100).rounded(.down))
        let rows = requirements.materials.sorted { data.itemName($0.key) < data.itemName($1.key) }

        Panel(style: .parchment) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 10) {
                    Text(expanded ? "▼" : "▶").font(.pixelBody(18)).foregroundStyle(Theme.parchmentMuted)
                    PixelIcon(name: item?.icon ?? "skull", image: item?.image, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item?.name ?? recipeId)
                        Text(recipe?.station ?? "").font(.pixelBody(18)).foregroundStyle(Theme.parchmentMuted)
                    }
                    Spacer(minLength: 4)
                    Text(percent == 100 ? "✓" : "\(percent)%")
                        .font(.pixelTitle(11))
                        .foregroundStyle(percent == 100 ? Theme.moss : Theme.parchmentInk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item?.name ?? recipeId), \(percent) por ciento")
            .accessibilityHint(expanded ? "Pliega los materiales" : "Despliega los materiales")

            HStack(spacing: 12) {
                ProgressBar(fraction: progress).frame(height: 10)
                CountField(value: state.count(of: recipeId)) { state.setCount($0, for: recipeId) }
                Button("×") { state.setCount(0, for: recipeId) }
                    .buttonStyle(.pixel(.blood, compact: true))
                    .help("Quitar del plan")
                    .accessibilityLabel("Quitar \(item?.name ?? recipeId) del plan")
            }

            if expanded {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.key) { itemId, qty in
                        Rectangle().fill(.tertiary).frame(height: 2)
                        MaterialRow(itemId: itemId, needed: qty)
                    }
                }
                if let recipe {
                    SectionTitle("Instrucciones")
                    ForEach(Array(requirements.steps.enumerated()), id: \.element.recipeId) { index, step in
                        if let intermediate = data.recipe(step.recipeId) {
                            Text("\(index + 1). Fabrica \(step.crafts)× \(data.itemName(intermediate.output)) en \(intermediate.station)")
                                + Text("  (→ \(step.crafts * intermediate.outputQty) uds.)").foregroundColor(Theme.parchmentMuted)
                        }
                    }
                    Text("\(requirements.steps.count + 1). Fabrica \(state.count(of: recipeId))× \(data.itemName(recipe.output)) en \(recipe.station).")
                    Button("Ver receta →") { router.openRecipe(recipeId) }
                        .buttonStyle(.pixel(.button, compact: true))
                }
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
                    Button { router.openCharacter(npc.id) } label: {
                        // sin días en el juego (GK2), solo el nombre
                        (state.data.days.isEmpty ? Text(npc.name) : Text("\(npc.name) (\(daysText(npc)))"))
                            .font(.pixelBody(19))
                            .underline(pattern: .dot)
                            .foregroundStyle(Theme.parchmentMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func daysText(_ npc: NPC) -> Text {
        guard !npc.days.isEmpty else { return Text("todos los días") }
        return npc.days.compactMap { state.data.day($0) }
            .reduce(Text(verbatim: "")) { Text("\($0)\(Text(dayIcon: $1, height: 16))") }
    }
}

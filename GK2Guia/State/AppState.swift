import Foundation
import GK2Core
import Observation

/// Estado del jugador. Se guarda en UserDefaults en cada cambio.
@MainActor @Observable
final class AppState {
    /// juego elegido; cada uno tiene sus datos y su propia partida guardada
    var game: Game {
        didSet {
            guard game != oldValue else { return }
            save(game, key: Keys.game)
            data = .bundled(for: game)
            loadProgress()
        }
    }
    private(set) var data: GameData
    private let defaults: UserDefaults

    var plan: Plan { didSet { save(plan, key: Self.key(Keys.plan, for: game)) } }
    var owned: [String: Int] { didSet { save(owned, key: Self.key(Keys.owned, for: game)) } }
    var deepBreakdown: Bool { didSet { save(deepBreakdown, key: Keys.deep) } }
    /// encargos completados, como "personaje/misión"
    var doneQuests: Set<String> { didSet { save(doneQuests, key: Self.key(Keys.quests, for: game)) } }
    /// tecnologías investigadas, como "árbol/tecnología"
    var researched: Set<String> { didSet { save(researched, key: Self.key(Keys.researched, for: game)) } }
    /// ids de los logros conseguidos
    var achieved: Set<String> { didSet { save(achieved, key: Self.key(Keys.achieved, for: game)) } }
    /// ids de los pasos hechos de la guía para principiantes
    var walkthroughDone: Set<String> { didSet { save(walkthroughDone, key: Self.key(Keys.walkthrough, for: game)) } }
    /// baúles del jugador, en el orden en que los creó
    var chests: [Chest] { didSet { save(chests, key: Self.key(Keys.chests, for: game)) } }

    /// Claves de la partida del juego actual. GK1 conserva las de antes de haber varios juegos.
    private enum Keys {
        static let game = "gk2.game", deep = "gk2.deep"
        static let plan = "plan", owned = "owned", quests = "doneQuests"
        static let researched = "researched", achieved = "achieved", chests = "chests"
        static let walkthrough = "walkthrough"
    }

    private static func key(_ name: String, for game: Game) -> String {
        game == .gk1 ? "gk2.\(name)" : "gk2.\(game.rawValue).\(name)"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // el antiguo «día de hoy» ya no se usa
        defaults.removeObject(forKey: "gk2.today")
        let game: Game = Self.load(Keys.game, from: defaults) ?? .gk1
        self.game = game
        data = .bundled(for: game)
        deepBreakdown = Self.load(Keys.deep, from: defaults) ?? true
        plan = Self.load(Self.key(Keys.plan, for: game), from: defaults) ?? [:]
        owned = Self.load(Self.key(Keys.owned, for: game), from: defaults) ?? [:]
        doneQuests = Self.load(Self.key(Keys.quests, for: game), from: defaults) ?? []
        researched = Self.load(Self.key(Keys.researched, for: game), from: defaults) ?? []
        achieved = Self.load(Self.key(Keys.achieved, for: game), from: defaults) ?? []
        walkthroughDone = Self.load(Self.key(Keys.walkthrough, for: game), from: defaults) ?? []
        chests = Self.load(Self.key(Keys.chests, for: game), from: defaults) ?? []
    }

    /// Carga la partida guardada del juego actual.
    private func loadProgress() {
        plan = load(Keys.plan) ?? [:]
        owned = load(Keys.owned) ?? [:]
        doneQuests = load(Keys.quests) ?? []
        researched = load(Keys.researched) ?? []
        achieved = load(Keys.achieved) ?? []
        walkthroughDone = load(Keys.walkthrough) ?? []
        chests = load(Keys.chests) ?? []
    }

    var planSize: Int { plan.values.reduce(0, +) }

    var requirements: Requirements {
        Planner.requirements(for: plan, recipes: data.recipes, deep: deepBreakdown)
    }

    func count(of recipeId: String) -> Int { plan[recipeId] ?? 0 }

    func setCount(_ count: Int, for recipeId: String) {
        plan[recipeId] = count > 0 ? count : nil
    }

    func addToPlan(_ recipeId: String) { setCount(count(of: recipeId) + 1, for: recipeId) }
    func clearPlan() { plan = [:] }

    func setOwned(_ qty: Int, for itemId: String) { owned[itemId] = max(0, qty) }

    func isDone(_ quest: Quest, of npc: NPC) -> Bool { doneQuests.contains("\(npc.id)/\(quest.id)") }

    func setDone(_ done: Bool, _ quest: Quest, of npc: NPC) {
        let key = "\(npc.id)/\(quest.id)"
        if done { doneQuests.insert(key) } else { doneQuests.remove(key) }
    }

    func isResearched(_ tech: Technology, in tree: TechTree) -> Bool { researched.contains("\(tree.id)/\(tech.id)") }

    func setResearched(_ done: Bool, _ tech: Technology, in tree: TechTree) {
        let key = "\(tree.id)/\(tech.id)"
        if done { researched.insert(key) } else { researched.remove(key) }
    }

    func isAchieved(_ achievement: Achievement) -> Bool { achieved.contains(achievement.id) }

    func setAchieved(_ done: Bool, _ achievement: Achievement) {
        if done { achieved.insert(achievement.id) } else { achieved.remove(achievement.id) }
    }

    func isDone(_ step: WalkthroughStep) -> Bool { walkthroughDone.contains(step.id) }

    func setDone(_ done: Bool, _ step: WalkthroughStep) {
        if done { walkthroughDone.insert(step.id) } else { walkthroughDone.remove(step.id) }
    }

    // MARK: - Baúles

    func chest(_ id: String) -> Chest? { chests.first { $0.id == id } }

    /// Crea un baúl vacío; sin nombre se llama «Baúl N».
    @discardableResult
    func addChest(named name: String) -> Chest {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let chest = Chest(name: trimmed.isEmpty ? "Baúl \(chests.count + 1)" : trimmed)
        chests.append(chest)
        return chest
    }

    func renameChest(_ id: String, to name: String) {
        guard let index = chests.firstIndex(where: { $0.id == id }) else { return }
        chests[index].name = name
    }

    func deleteChest(_ id: String) { chests.removeAll { $0.id == id } }

    func setCount(_ count: Int, of itemId: String, inChest id: String) {
        guard let index = chests.firstIndex(where: { $0.id == id }) else { return }
        chests[index].setCount(count, of: itemId)
    }

    func addToChest(_ itemId: String, chest id: String) {
        setCount((chest(id)?.count(of: itemId) ?? 0) + 1, of: itemId, inChest: id)
    }

    /// Baúles que guardan el objeto, con sus unidades.
    func chests(containing itemId: String) -> [(chest: Chest, count: Int)] {
        chests.compactMap { chest in
            let count = chest.count(of: itemId)
            return count > 0 ? (chest, count) : nil
        }
    }

    /// Unidades del objeto guardadas entre todos los baúles.
    func storedCount(of itemId: String) -> Int { chests.reduce(0) { $0 + $1.count(of: itemId) } }

    /// Lo que tengo encima (`owned`) más lo guardado en los baúles, para saber lo que falta del plan.
    var stock: [String: Int] {
        chests.reduce(into: owned) { stock, chest in
            for (itemId, count) in chest.items { stock[itemId, default: 0] += count }
        }
    }

    /// Baúles cuyo nombre, o el de algún objeto que guardan, contiene la búsqueda (sin distinguir tildes).
    /// `items` son los objetos que casan, para decir dónde está lo que se busca.
    func searchChests(_ query: String) -> [(chest: Chest, items: [String])] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        guard !q.isEmpty else { return chests.map { ($0, []) } }
        return chests.compactMap { chest in
            let items = chest.items.keys
                .filter { data.item($0)?.matches(q) ?? $0.contains(q) }
                .sorted { data.itemName($0).localizedCompare(data.itemName($1)) == .orderedAscending }
            return chest.name.folded.contains(q) || !items.isEmpty ? (chest, items) : nil
        }
    }

    /// «Sótano ×3, Cocina ×1», o nil si el objeto no está en ningún baúl.
    func chestSummary(of itemId: String) -> String? {
        let stored = chests(containing: itemId)
        guard !stored.isEmpty else { return nil }
        return stored.map { "\($0.chest.name) ×\($0.count)" }.joined(separator: ", ")
    }

    // MARK: - Progreso de la partida

    struct Progress {
        let done: Int
        let total: Int
        var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }

    /// Solo cuenta claves que siguen existiendo en los datos (los ids guardados pueden quedar obsoletos).
    private static func progress(_ marked: Set<String>, of all: [String]) -> Progress {
        Progress(done: Set(all).intersection(marked).count, total: all.count)
    }

    var questProgress: Progress {
        Self.progress(doneQuests, of: data.characters.flatMap { npc in (npc.quests ?? []).map { "\(npc.id)/\($0.id)" } })
    }

    var techProgress: Progress {
        Self.progress(researched, of: data.technologies.flatMap { tree in tree.technologies.map { "\(tree.id)/\($0.id)" } })
    }

    var achievementProgress: Progress {
        Self.progress(achieved, of: data.guide.flatMap { $0.achievements.map(\.id) })
    }

    /// Porcentaje de juego completado: media de misiones, tecnologías y logros,
    /// para que las tecnologías (las más numerosas) no dominen el total.
    var completion: Double {
        let parts = [questProgress, techProgress, achievementProgress].filter { $0.total > 0 }
        return parts.isEmpty ? 0 : parts.map(\.fraction).reduce(0, +) / Double(parts.count)
    }

    // MARK: - Persistencia

    private func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private func load<T: Decodable>(_ name: String) -> T? {
        Self.load(Self.key(name, for: game), from: defaults)
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

import Foundation
import GK2Core
import Observation

/// Estado del jugador. Se guarda en UserDefaults en cada cambio.
@MainActor @Observable
final class AppState {
    let data: GameData
    private let defaults: UserDefaults

    var plan: Plan { didSet { save(plan, key: Keys.plan) } }
    var owned: [String: Int] { didSet { save(owned, key: Keys.owned) } }
    var today: String { didSet { save(today, key: Keys.today) } }
    var deepBreakdown: Bool { didSet { save(deepBreakdown, key: Keys.deep) } }
    /// encargos completados, como "personaje/misión"
    var doneQuests: Set<String> { didSet { save(doneQuests, key: Keys.quests) } }

    private enum Keys {
        static let plan = "gk2.plan", owned = "gk2.owned", today = "gk2.today", deep = "gk2.deep"
        static let quests = "gk2.doneQuests"
    }

    init(data: GameData = .bundled, defaults: UserDefaults = .standard) {
        self.data = data
        self.defaults = defaults
        plan = Self.load(Keys.plan, from: defaults) ?? [:]
        owned = Self.load(Keys.owned, from: defaults) ?? [:]
        deepBreakdown = Self.load(Keys.deep, from: defaults) ?? true
        doneQuests = Self.load(Keys.quests, from: defaults) ?? []
        let savedDay: String? = Self.load(Keys.today, from: defaults)
        today = savedDay.flatMap { data.day($0)?.id } ?? data.days[0].id
    }

    var todayDay: Day { data.day(today) ?? data.days[0] }
    var tomorrow: Day { data.day(after: today) }
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

    func sleep() { today = tomorrow.id }

    func isDone(_ quest: Quest, of npc: NPC) -> Bool { doneQuests.contains("\(npc.id)/\(quest.id)") }

    func setDone(_ done: Bool, _ quest: Quest, of npc: NPC) {
        let key = "\(npc.id)/\(quest.id)"
        if done { doneQuests.insert(key) } else { doneQuests.remove(key) }
    }

    // MARK: - Persistencia

    private func save<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

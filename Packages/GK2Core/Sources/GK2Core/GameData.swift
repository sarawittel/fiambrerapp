import Foundation

/// Todos los datos del juego, cargados desde los JSON de `Resources/`.
public struct GameData: Sendable {
    public let items: [Item]
    public let recipes: [Recipe]
    public let days: [Day]
    public let characters: [NPC]
    public let stationList: [Station]

    private let itemsById: [String: Item]
    private let recipesById: [String: Recipe]
    private let charactersById: [String: NPC]
    private let daysById: [String: Day]
    private let producers: [String: Recipe]
    private let stationsByName: [String: Station]

    public init(items: [Item], recipes: [Recipe], days: [Day], characters: [NPC], stations: [Station] = []) {
        self.items = items
        stationList = stations
        stationsByName = Dictionary(stations.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.recipes = recipes
        self.days = days
        self.characters = characters
        itemsById = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        recipesById = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        charactersById = Dictionary(characters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        daysById = Dictionary(days.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // la primera receta que produce cada objeto
        producers = Dictionary(recipes.map { ($0.output, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Datos incluidos en el paquete.
    public static let bundled: GameData = {
        do {
            return try GameData(
                items: load("items"), recipes: load("recipes"),
                days: load("days"), characters: load("characters"),
                stations: load("stations")
            )
        } catch {
            fatalError("No se pudieron cargar los datos del juego: \(error)")
        }
    }()

    static func load<T: Decodable>(_ name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    /// URL de una imagen de `Resources/Images`.
    public static func imageURL(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/Images")
    }

    // MARK: - Consultas

    public func item(_ id: String) -> Item? { itemsById[id] }
    public func recipe(_ id: String) -> Recipe? { recipesById[id] }
    public func character(_ id: String) -> NPC? { charactersById[id] }
    public func day(_ id: String) -> Day? { daysById[id] }

    public func recipe(producing itemId: String) -> Recipe? { producers[itemId] }
    public func stationImage(_ name: String) -> String? { stationsByName[name]?.image }

    public func itemName(_ id: String) -> String { itemsById[id]?.name ?? id }

    public var stations: [String] {
        Set(recipes.map(\.station)).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    public func sellers(of itemId: String) -> [NPC] {
        characters.filter { $0.sells?.contains(itemId) == true }
    }

    public func buyers(of itemId: String) -> [NPC] {
        characters.filter { $0.buys?.contains(itemId) == true }
    }

    /// Encargos en los que aparece el objeto, como recompensa o como parte de la misión.
    /// `key` = "personaje/misión", único en todo el juego.
    public func quests(involving itemId: String) -> [(key: String, npc: NPC, quest: Quest)] {
        characters.flatMap { npc in
            (npc.quests ?? [])
                .filter { ($0.rewards ?? []).contains(itemId) || ($0.items ?? []).contains(itemId) }
                .map { ("\(npc.id)/\($0.id)", npc, $0) }
        }
    }

    public func recipes(using itemId: String) -> [Recipe] {
        recipes.filter { $0.ingredients.contains { $0.item == itemId } }
    }

    public func day(after dayId: String) -> Day {
        let index = days.firstIndex { $0.id == dayId } ?? 0
        return days[(index + 1) % days.count]
    }

    /// Búsqueda por nombre del producto o de sus ingredientes, sin distinguir tildes.
    public func searchRecipes(_ query: String, station: String? = nil) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        return recipes.filter { r in
            if let station, r.station != station { return false }
            if q.isEmpty { return true }
            return ([r.output] + r.ingredients.map(\.item)).contains { itemName($0).folded.contains(q) }
        }
    }

    /// Objetos por nombre, sin distinguir tildes, en orden alfabético.
    /// `craftable` filtra por si tienen receta (`nil` = todos).
    public func searchItems(_ query: String, category: ItemCategory? = nil, craftable: Bool? = nil) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        return items
            .filter { item in
                if let category, item.category != category { return false }
                if let craftable, (producers[item.id] != nil) != craftable { return false }
                return q.isEmpty || item.name.folded.contains(q)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

extension String {
    /// Minúsculas y sin tildes.
    public var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}

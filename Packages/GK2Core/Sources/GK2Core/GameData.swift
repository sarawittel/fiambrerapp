import Foundation

/// Todos los datos del juego, cargados desde los JSON de `Data/`.
public struct GameData: Sendable {
    public let items: [Item]
    public let recipes: [Recipe]
    public let days: [Day]
    public let characters: [NPC]
    public let stationList: [Station]
    public let technologies: [TechTree]
    public let guide: [GuideSection]

    private let itemsById: [String: Item]
    private let recipesById: [String: Recipe]
    private let charactersById: [String: NPC]
    private let daysById: [String: Day]
    private let producers: [String: Recipe]
    private let stationsByName: [String: Station]
    private let treesById: [String: TechTree]
    private let sectionsById: [String: GuideSection]

    public init(items: [Item], recipes: [Recipe], days: [Day], characters: [NPC], stations: [Station] = [], technologies: [TechTree] = [], guide: [GuideSection] = []) {
        self.items = items
        self.technologies = technologies
        self.guide = guide
        sectionsById = Dictionary(guide.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        treesById = Dictionary(technologies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
                stations: load("stations"), technologies: load("technologies"),
                guide: load("guide")
            )
        } catch {
            fatalError("No se pudieron cargar los datos del juego: \(error)")
        }
    }()

    /// Datos incluidos en el paquete para un juego.
    public static func bundled(for game: Game) -> GameData {
        switch game {
        case .gk1: bundled
        case .gk2: bundledGK2
        }
    }

    /// GK2 tiene sus propios datos en `Data/GK2` (scripts/wiki_gk2), sin nada de GK1.
    /// De momento objetos, recetas y personajes (sin días: la wiki de GK2 no dice cuándo están).
    static let bundledGK2: GameData = {
        do {
            return try GameData(
                items: load("items", in: "GK2"), recipes: load("recipes", in: "GK2"),
                days: [], characters: load("characters", in: "GK2")
            )
        } catch {
            fatalError("No se pudieron cargar los datos de GK2: \(error)")
        }
    }()

    /// `folder`: subcarpeta de `Data` con los JSON de otro juego (p. ej. "GK2")
    static func load<T: Decodable>(_ name: String, in folder: String? = nil) throws -> T {
        let subdirectory = folder.map { "Data/\($0)" } ?? "Data"
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: subdirectory) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    /// URL de una imagen de `Data/Images`; `"GK2/<nombre>"` es una de `Data/GK2/Images`.
    public static func imageURL(_ name: String) -> URL? {
        let parts = name.split(separator: "/", maxSplits: 1)
        if parts.count == 2 {
            return Bundle.module.url(forResource: String(parts[1]), withExtension: "png", subdirectory: "Data/\(parts[0])/Images")
        }
        return Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Data/Images")
    }

    // MARK: - Consultas

    public func item(_ id: String) -> Item? { itemsById[id] }
    public func recipe(_ id: String) -> Recipe? { recipesById[id] }
    public func character(_ id: String) -> NPC? { charactersById[id] }
    public func day(_ id: String) -> Day? { daysById[id] }
    public func techTree(_ id: String) -> TechTree? { treesById[id] }
    public func guideSection(_ id: String) -> GuideSection? { sectionsById[id] }

    public func recipe(producing itemId: String) -> Recipe? { producers[itemId] }
    public func stationImage(_ name: String) -> String? { stationsByName[name]?.image }

    public func itemName(_ id: String) -> String { itemsById[id]?.name ?? id }

    /// true si el objeto es una estación de trabajo o algo que se construye en un lugar
    /// (recetas «Construcción · …»): no se puede guardar en un baúl.
    public func isStation(_ itemId: String) -> Bool {
        if let item = itemsById[itemId], stationsByName[item.name] != nil { return true }
        return producers[itemId]?.station.hasPrefix(Self.buildStationPrefix) == true
    }

    /// prefijo de las recetas de construcción sacadas de las páginas de lugares
    static let buildStationPrefix = "Construcción · "

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

    /// Tecnologías que desbloquean el objeto (su receta, su plano o su extracción).
    public func technologies(unlocking itemId: String) -> [(tree: TechTree, tech: Technology)] {
        technologies.flatMap { tree in
            tree.technologies
                .filter { $0.unlocks?.contains { $0.item == itemId } == true }
                .map { (tree, $0) }
        }
    }

    public func recipes(using itemId: String) -> [Recipe] {
        recipes.filter { $0.ingredients.contains { $0.item == itemId } }
    }

    /// Qué distingue a una receta de las otras del mismo producto en `among`, para mostrarlo junto al nombre:
    /// `nil` si es la única; la estación si es la única en ella; si no, los ingredientes que solo lleva
    /// ella («Cebolla (bronce)»), y si tampoco, lo que produce («×7»).
    public func distinguishing(_ recipe: Recipe, among recipes: [Recipe]) -> String? {
        let same = recipes.filter { $0.output == recipe.output && $0.id != recipe.id }
        if same.isEmpty { return nil }
        let sameStation = same.filter { $0.station == recipe.station }
        if sameStation.isEmpty { return recipe.station }
        let others = Set(sameStation.flatMap { $0.ingredients.map(\.item) })
        let own = recipe.ingredients.map(\.item).filter { !others.contains($0) }
        let detail = own.isEmpty ? "×\(recipe.outputQty)" : own.map(itemName).joined(separator: ", ")
        return "\(recipe.station) · \(detail)"
    }

    /// Búsqueda por nombre (en español o el de la wiki) del producto o de sus ingredientes, sin distinguir tildes.
    /// En orden alfabético del producto; las del mismo producto, por estación y luego en el orden de los datos.
    public func searchRecipes(_ query: String, station: String? = nil) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        let found = recipes.enumerated().filter { _, r in
            if let station, r.station != station { return false }
            if q.isEmpty { return true }
            return ([r.output] + r.ingredients.map(\.item)).contains { itemsById[$0]?.matches(q) ?? $0.contains(q) }
        }
        return found.sorted { a, b in
            let byName = itemName(a.element.output).localizedCompare(itemName(b.element.output))
            if byName != .orderedSame { return byName == .orderedAscending }
            let byStation = a.element.station.localizedCompare(b.element.station)
            if byStation != .orderedSame { return byStation == .orderedAscending }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Objetos por nombre (en español o el de la wiki), sin distinguir tildes, en orden alfabético.
    /// `craftable` filtra por si tienen receta (`nil` = todos); `storable`, por si caben en un baúl (sin estaciones).
    public func searchItems(_ query: String, category: ItemCategory? = nil, craftable: Bool? = nil, storable: Bool = false) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        return items
            .filter { item in
                if let category, item.category != category { return false }
                if let craftable, (producers[item.id] != nil) != craftable { return false }
                if storable, isStation(item.id) { return false }
                return q.isEmpty || item.matches(q)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Personajes por nombre (en español o el de la wiki), papel o lugar, sin distinguir tildes.
    public func searchCharacters(_ query: String) -> [NPC] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        guard !q.isEmpty else { return characters }
        return characters.filter { npc in
            [npc.name, npc.wikiName, npc.title, npc.location].contains { $0?.folded.contains(q) == true }
        }
    }

    /// Tecnologías por su nombre o por lo que desbloquean (nombre del objeto en español o el de la wiki),
    /// sin distinguir tildes, en el orden de los árboles.
    public func searchTechnologies(_ query: String) -> [(tree: TechTree, tech: Technology)] {
        let q = query.trimmingCharacters(in: .whitespaces).folded
        guard !q.isEmpty else { return [] }
        return technologies.flatMap { tree in
            tree.technologies
                .filter { tech in
                    tech.name.folded.contains(q) || (tech.unlocks ?? []).contains { unlock in
                        unlock.name.folded.contains(q) || unlock.item.flatMap { itemsById[$0] }?.matches(q) == true
                    }
                }
                .map { (tree, $0) }
        }
    }
}

extension String {
    /// Minúsculas y sin tildes.
    public var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}

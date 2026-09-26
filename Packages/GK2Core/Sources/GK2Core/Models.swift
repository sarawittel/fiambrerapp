import Foundation

public enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case material, comida, alquimia, funerario, herramienta
}

public struct Item: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// nombre en español
    public let name: String
    /// nombre en la wiki (inglés), si es distinto
    public var wikiName: String?
    public let category: ItemCategory
    public let icon: String
    /// Dónde se obtiene si no se fabrica (texto libre).
    public var sources: [String]?
    public var description: String?
    /// imagen de la wiki en `Resources/Images` (sin extensión); si falta se usa `icon`
    public var image: String?
    /// niveles de calidad (bronce, plata, oro), si el objeto los tiene
    public var quality: [ItemQuality]?
    /// lo que cuesta y da estudiarlo en la mesa de estudio
    public var study: ItemStudy?

    /// true si el nombre en español o el de la wiki contiene `query` (ya pasado por `folded`)
    public func matches(_ query: String) -> Bool {
        name.folded.contains(query) || wikiName?.folded.contains(query) == true
    }
}

/// Un nivel de calidad de un objeto. Los precios van en monedas de cobre (100 cobre = 1 plata).
public struct ItemQuality: Codable, Hashable, Sendable {
    public enum Level: String, Codable, CaseIterable, Sendable {
        case copper, silver, gold
    }

    public let level: Level
    /// energía que da al consumirlo (negativa si la quita)
    public var energy: Int?
    /// lo que cuesta comprarlo
    public var buy: Int?
    /// lo que te pagan al venderlo
    public var sell: Int?
    /// precio de la tabla de calidad de la wiki, cuando no hay tabla de comercio que lo aclare
    public var value: Int?
}

/// Estudio de un objeto en la mesa de estudio.
public struct ItemStudy: Codable, Hashable, Sendable {
    /// puntos de tecnología que da
    public let points: TechCost
    public var faith: Int?
    public var science: Int?
    /// energía que gasta
    public var energy: Int?
    /// ids de los objetos en los que se descompone al estudiarlo
    public var decomposes: [String]?
}

/// Baúl del jugador, con nombre propio y los objetos que guarda.
public struct Chest: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    /// id de objeto → unidades (solo cantidades positivas)
    public private(set) var items: [String: Int]

    public init(id: String = UUID().uuidString, name: String, items: [String: Int] = [:]) {
        self.id = id
        self.name = name
        self.items = items.filter { $0.value > 0 }
    }

    /// unidades guardadas en total
    public var total: Int { items.values.reduce(0, +) }

    public func count(of itemId: String) -> Int { items[itemId] ?? 0 }

    /// Fija las unidades de un objeto; con 0 o menos lo saca del baúl.
    public mutating func setCount(_ count: Int, of itemId: String) {
        items[itemId] = count > 0 ? count : nil
    }
}

public struct Ingredient: Codable, Hashable, Sendable {
    public let item: String
    public let qty: Int
}

public struct Recipe: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// id del objeto que produce
    public let output: String
    /// unidades producidas por cada fabricación
    public let outputQty: Int
    public let station: String
    public let ingredients: [Ingredient]
    /// duración según la wiki, p. ej. "2:30"
    public var time: String?
    public var notes: String?

    public init(id: String, output: String, outputQty: Int, station: String, ingredients: [Ingredient], time: String? = nil, notes: String? = nil) {
        self.id = id
        self.output = output
        self.outputQty = outputQty
        self.station = station
        self.ingredients = ingredients
        self.time = time
        self.notes = notes
    }
}

public struct Day: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let short: String
    public let icon: String
    /// color en hexadecimal, p. ej. "#e0a83a"
    public let color: String
    public var image: String?
}

/// Estación de trabajo, para mostrar su imagen junto a las recetas.
public struct Station: Codable, Hashable, Sendable {
    /// nombre en español, el mismo que `Recipe.station`
    public let name: String
    /// nombre en la wiki (inglés), si es distinto
    public var wikiName: String?
    public var image: String?
}

public struct NPC: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    /// nombre propio (en inglés, como en la wiki) u oficio traducido («Apicultor»)
    public let name: String
    /// nombre en la wiki (inglés), si es distinto
    public var wikiName: String?
    public let title: String
    public let location: String
    public let icon: String
    /// ids de día; vacío = todos los días
    public let days: [String]
    public var sells: [String]?
    public var buys: [String]?
    public var notes: String?
    public var image: String?
    public var quests: [Quest]?
    /// niveles de amistad que desbloquean algo, de menor a mayor
    public var friendship: [FriendshipMilestone]?

    public func isAvailable(on dayId: String) -> Bool {
        days.isEmpty || days.contains(dayId)
    }

    /// `title` salvo que repita el nombre (p. ej. el Apicultor, cuyo papel es «Apicultor»)
    public var role: String? {
        title.folded == name.folded ? nil : title
    }
}

/// Encargo de un personaje, tal como lo cuenta la wiki.
public struct Quest: Codable, Identifiable, Hashable, Sendable {
    /// único dentro del personaje
    public let id: String
    public let name: String
    /// párrafos en Markdown en línea: objetos y personajes como `[**nombre**](gk2://item/<id>)` o `gk2://character/<id>`, amistad como «10 ♥»
    public let text: [String]
    /// DLC al que pertenece, p. ej. "Stranger Sins"
    public var dlc: String?
    /// amistad que se gana al completarlo
    public var friendship: Int?
    /// objetos que te dan o que desbloquea
    public var rewards: [String]?
    /// otros objetos que aparecen (lo que te piden, sobre todo)
    public var items: [String]?
    /// otros personajes implicados
    public var characters: [String]?
}

/// Lo que se desbloquea al llegar a cierto nivel de amistad con un personaje.
public struct FriendshipMilestone: Codable, Hashable, Sendable {
    public let level: Int
    /// Markdown en línea, como `Quest.text`
    public let text: String
    public var items: [String]?
}

/// Árbol de tecnología (Anatomy and Alchemy, Theology…), en el orden de la wiki.
public struct TechTree: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// párrafos en Markdown en línea, como `Quest.text`
    public var text: [String]?
    public var dlc: String?
    public var image: String?
    public let branches: [TechBranch]

    public var technologies: [Technology] { branches.flatMap(\.techs) }
}

/// Rama de un árbol; `name` es nil si el árbol no tiene ramas.
public struct TechBranch: Codable, Hashable, Sendable {
    public var name: String?
    public var text: [String]?
    public let techs: [Technology]
}

public struct Technology: Codable, Identifiable, Hashable, Sendable {
    /// único dentro del árbol
    public let id: String
    public let name: String
    /// puntos de tecnología que cuesta
    public var cost: TechCost?
    /// otra condición para desbloquearla (hablar con alguien, comprarla…), en Markdown en línea
    public var condition: String?
    /// ids de tecnologías del mismo árbol que hay que tener antes
    public var requires: [String]?
    public var dlc: String?
    public var unlocks: [TechUnlock]?
}

public struct TechCost: Codable, Hashable, Sendable {
    public var red: Int?
    public var green: Int?
    public var blue: Int?
    public var soul: Int?
    public var violet: Int?

    /// (color, puntos) de los que no son cero, en el orden del juego
    public var points: [(color: String, value: Int)] {
        [("red", red), ("green", green), ("blue", blue), ("soul", soul), ("violet", violet)]
            .compactMap { color, value in value.map { (color, $0) } }
    }
}

/// Lo que desbloquea una tecnología.
public struct TechUnlock: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case blueprint, create, extract, gathering, perk, recipe
    }

    public let kind: Kind
    public let name: String
    /// id del objeto, si existe en `items.json`
    public var item: String?
}

/// Apartado de la guía de logros («Starting Out», «Questlines»…), en el orden de la wiki.
public struct GuideSection: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// la wiki lo marca como spoiler (la tabla sale plegada)
    public var spoiler: Bool?
    public let achievements: [Achievement]
}

public struct Achievement: Codable, Identifiable, Hashable, Sendable {
    /// único en toda la guía
    public let id: String
    public let name: String
    /// nombre en la wiki (inglés) cuando `name` está traducido
    public var wikiName: String?
    /// párrafos en Markdown en línea, como `Quest.text`
    public let text: [String]
    /// se puede perder para siempre si no se hace a tiempo
    public var missable: Bool?
    public var dlc: String?
    public var image: String?
    /// objetos y personajes que aparecen en la descripción
    public var items: [String]?
    public var characters: [String]?
}

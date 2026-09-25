import Foundation

public enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case material, comida, alquimia, funerario, herramienta
}

public struct Item: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: ItemCategory
    public let icon: String
    /// Dónde se obtiene si no se fabrica (texto libre).
    public var sources: [String]?
    public var description: String?
    /// imagen de la wiki en `Resources/Images` (sin extensión); si falta se usa `icon`
    public var image: String?
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
    public let name: String
    public var image: String?
}

public struct NPC: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
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

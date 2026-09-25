import Foundation

public enum ItemCategory: String, Codable, Sendable {
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

    public func isAvailable(on dayId: String) -> Bool {
        days.isEmpty || days.contains(dayId)
    }
}

import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case recipes, items, planner, chests, technologies, guide, characters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recipes: "Recetas"
        case .items: "Objetos"
        case .technologies: "Tecnologías"
        case .planner: "Qué necesito"
        case .characters: "Personajes"
        case .guide: "Guía"
        case .chests: "Baúles"
        }
    }

    var shortTitle: String {
        switch self {
        case .recipes: "Recetas"
        case .items: "Objetos"
        case .technologies: "Tecno"
        case .planner: "Necesito"
        case .characters: "Gente"
        case .guide: "Guía"
        case .chests: "Baúles"
        }
    }

    var icon: String {
        switch self {
        case .recipes: "cauldron"
        case .items: "scroll"
        case .technologies: "candle"
        case .planner: "sack"
        case .characters: "person"
        case .guide: "crown"
        case .chests: "chest"
        }
    }
}

/// Navegación compartida para poder saltar entre secciones (p. ej. de un ingrediente a su receta).
/// Cada pestaña tiene su pila de navegación (`*Path`).
@MainActor @Observable
final class Router {
    var tab: AppTab = .recipes
    var recipePath: [String] = []
    var itemPath: [String] = []
    var characterPath: [String] = []
    var techTreePath: [String] = []
    /// tecnología a la que desplazarse dentro del árbol abierto
    var techId: String?
    var guidePath: [String] = []
    var chestPath: [String] = []

    /// Vuelve a las listas, p. ej. al cambiar de juego (lo abierto podría no existir en el otro).
    func reset() {
        recipePath = []
        itemPath = []
        characterPath = []
        techTreePath = []
        techId = nil
        guidePath = []
        chestPath = []
    }

    func openRecipe(_ id: String) {
        if tab != .recipes { recipePath = [] }
        tab = .recipes
        if recipePath.last != id { recipePath.append(id) }
    }

    func openItem(_ id: String) {
        if tab != .items { itemPath = [] }
        tab = .items
        if itemPath.last != id { itemPath.append(id) }
    }

    func openTechTree(_ id: String, tech: String? = nil) {
        if tab != .technologies { techTreePath = [] }
        tab = .technologies
        techId = tech
        if techTreePath.last != id { techTreePath.append(id) }
    }

    func openGuideSection(_ id: String) {
        if tab != .guide { guidePath = [] }
        tab = .guide
        if guidePath.last != id { guidePath.append(id) }
    }

    func openChest(_ id: String) {
        if tab != .chests { chestPath = [] }
        tab = .chests
        if chestPath.last != id { chestPath.append(id) }
    }

    func openCharacter(_ id: String) {
        if tab != .characters { characterPath = [] }
        tab = .characters
        if characterPath.last != id { characterPath.append(id) }
    }
}

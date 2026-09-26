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
/// En pantallas anchas se usa la selección; en iPhone, la pila de navegación (`*Path`).
@MainActor @Observable
final class Router {
    var tab: AppTab = .recipes
    var recipeId: String?
    var recipePath: [String] = []
    var itemId: String?
    var itemPath: [String] = []
    var characterId: String?
    var characterPath: [String] = []
    var techTreeId: String?
    var techTreePath: [String] = []
    /// tecnología a la que desplazarse dentro del árbol abierto
    var techId: String?
    var guideSectionId: String?
    var guidePath: [String] = []
    var chestId: String?
    var chestPath: [String] = []

    /// Vuelve a las listas, p. ej. al cambiar de juego (las selecciones podrían no existir en el otro).
    func reset() {
        recipeId = nil
        recipePath = []
        itemId = nil
        itemPath = []
        characterId = nil
        characterPath = []
        techTreeId = nil
        techTreePath = []
        techId = nil
        guideSectionId = nil
        guidePath = []
        chestId = nil
        chestPath = []
    }

    func openRecipe(_ id: String) {
        if tab != .recipes { recipePath = [] }
        tab = .recipes
        recipeId = id
        if recipePath.last != id { recipePath.append(id) }
    }

    func openItem(_ id: String) {
        if tab != .items { itemPath = [] }
        tab = .items
        itemId = id
        if itemPath.last != id { itemPath.append(id) }
    }

    func openTechTree(_ id: String, tech: String? = nil) {
        if tab != .technologies { techTreePath = [] }
        tab = .technologies
        techTreeId = id
        techId = tech
        if techTreePath.last != id { techTreePath.append(id) }
    }

    func openGuideSection(_ id: String) {
        if tab != .guide { guidePath = [] }
        tab = .guide
        guideSectionId = id
        if guidePath.last != id { guidePath.append(id) }
    }

    func openChest(_ id: String) {
        if tab != .chests { chestPath = [] }
        tab = .chests
        chestId = id
        if chestPath.last != id { chestPath.append(id) }
    }

    func openCharacter(_ id: String) {
        if tab != .characters { characterPath = [] }
        tab = .characters
        characterId = id
        if characterPath.last != id { characterPath.append(id) }
    }
}

import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case recipes, items, planner, calendar, characters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recipes: "Recetas"
        case .items: "Objetos"
        case .planner: "Qué necesito"
        case .calendar: "Calendario"
        case .characters: "Personajes"
        }
    }

    var shortTitle: String {
        switch self {
        case .recipes: "Recetas"
        case .items: "Objetos"
        case .planner: "Necesito"
        case .calendar: "Semana"
        case .characters: "Gente"
        }
    }

    var icon: String {
        switch self {
        case .recipes: "cauldron"
        case .items: "scroll"
        case .planner: "sack"
        case .calendar: "moon"
        case .characters: "person"
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

    func openCharacter(_ id: String) {
        if tab != .characters { characterPath = [] }
        tab = .characters
        characterId = id
        if characterPath.last != id { characterPath.append(id) }
    }
}

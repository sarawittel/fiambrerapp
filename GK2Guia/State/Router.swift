import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case recipes, planner, calendar, characters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recipes: "Recetas"
        case .planner: "Qué necesito"
        case .calendar: "Calendario"
        case .characters: "Personajes"
        }
    }

    var shortTitle: String {
        switch self {
        case .recipes: "Recetas"
        case .planner: "Necesito"
        case .calendar: "Semana"
        case .characters: "Gente"
        }
    }

    var icon: String {
        switch self {
        case .recipes: "cauldron"
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
    var characterId: String?
    var characterPath: [String] = []

    func openRecipe(_ id: String) {
        if tab != .recipes { recipePath = [] }
        tab = .recipes
        recipeId = id
        if recipePath.last != id { recipePath.append(id) }
    }

    func openCharacter(_ id: String) {
        if tab != .characters { characterPath = [] }
        tab = .characters
        characterId = id
        if characterPath.last != id { characterPath.append(id) }
    }
}

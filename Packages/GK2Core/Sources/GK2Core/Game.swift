/// Juego de la saga que cubre la guía.
public enum Game: String, CaseIterable, Codable, Identifiable, Sendable {
    case gk1, gk2

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gk1: "Graveyard Keeper"
        case .gk2: "Graveyard Keeper 2"
        }
    }

    public var shortTitle: String {
        switch self {
        case .gk1: "GK1"
        case .gk2: "GK2"
        }
    }
}

import Foundation

/// recipeId → número de veces que se quiere fabricar
public typealias Plan = [String: Int]

public struct CraftStep: Equatable, Sendable {
    public let recipeId: String
    public let crafts: Int
}

public struct Requirements: Equatable, Sendable {
    /// itemId → cantidad total necesaria
    public var materials: [String: Int]
    /// fabricaciones intermedias, en orden de ejecución (dependencias primero)
    public var steps: [CraftStep]
}

public enum Planner {
    /// Calcula los materiales necesarios para un plan.
    /// Con `deep`, desglosa los ingredientes fabricables hasta materias primas,
    /// reaprovechando el excedente (p. ej. 1 tronco da 2 tablones).
    public static func requirements(for plan: Plan, recipes: [Recipe], deep: Bool) -> Requirements {
        let byId = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let producer = Dictionary(recipes.map { ($0.output, $0) }, uniquingKeysWith: { first, _ in first })

        var materials: [String: Int] = [:]
        var surplus: [String: Int] = [:]
        var crafts: [String: Int] = [:]
        var order: [String] = []

        func need(_ itemId: String, _ qty: Int, path: Set<String>) {
            // Sin receta, o receta circular: se trata como materia prima.
            guard deep, let recipe = producer[itemId], !path.contains(recipe.id) else {
                materials[itemId, default: 0] += qty
                return
            }
            let fromSurplus = min(surplus[itemId, default: 0], qty)
            surplus[itemId, default: 0] -= fromSurplus
            let remaining = qty - fromSurplus
            guard remaining > 0 else { return }

            let times = (remaining + recipe.outputQty - 1) / recipe.outputQty
            surplus[itemId, default: 0] += times * recipe.outputQty - remaining
            craft(recipe, times, path: path)
        }

        func craft(_ recipe: Recipe, _ times: Int, path: Set<String>) {
            let next = path.union([recipe.id])
            for ing in recipe.ingredients { need(ing.item, ing.qty * times, path: next) }
            if crafts[recipe.id] == nil { order.append(recipe.id) }
            crafts[recipe.id, default: 0] += times
        }

        // Orden estable para que el resultado no dependa del orden del diccionario
        for (recipeId, count) in plan.sorted(by: { $0.key < $1.key }) {
            guard let recipe = byId[recipeId], count > 0 else { continue }
            if deep {
                let before = crafts[recipe.id]
                craft(recipe, count, path: [])
                // el objetivo en sí no es un paso intermedio
                if let before { crafts[recipe.id] = before } else {
                    crafts[recipe.id] = nil
                    order.removeAll { $0 == recipe.id }
                }
            } else {
                for ing in recipe.ingredients { materials[ing.item, default: 0] += ing.qty * count }
            }
        }

        let steps = order.compactMap { id in crafts[id].map { CraftStep(recipeId: id, crafts: $0) } }
        return Requirements(materials: materials, steps: steps)
    }
}

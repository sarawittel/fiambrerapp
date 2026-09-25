import Testing
@testable import GK2Core

private let recipes = [
    Recipe(id: "r_plank", output: "plank", outputQty: 2, station: "x", ingredients: [.init(item: "log", qty: 1)]),
    Recipe(id: "r_bar", output: "bar", outputQty: 1, station: "x", ingredients: [.init(item: "ore", qty: 3), .init(item: "log", qty: 1)]),
    Recipe(id: "r_nails", output: "nails", outputQty: 5, station: "x", ingredients: [.init(item: "bar", qty: 1)]),
    Recipe(id: "r_coffin", output: "coffin", outputQty: 1, station: "x", ingredients: [.init(item: "plank", qty: 4), .init(item: "nails", qty: 6)]),
    Recipe(id: "r_shelf", output: "shelf", outputQty: 1, station: "x", ingredients: [.init(item: "plank", qty: 1)]),
]

@Suite("Planner")
struct PlannerTests {
    @Test("sin desglose devuelve los ingredientes directos")
    func shallow() {
        let req = Planner.requirements(for: ["r_coffin": 2], recipes: recipes, deep: false)
        #expect(req.materials == ["plank": 8, "nails": 12])
        #expect(req.steps.isEmpty)
    }

    @Test("desglosa hasta materias primas redondeando por lote")
    func deep() {
        let req = Planner.requirements(for: ["r_coffin": 1], recipes: recipes, deep: true)
        // 4 tablones = 2 troncos; 6 clavos = 2 lotes = 2 lingotes = 6 mineral + 2 troncos
        #expect(req.materials == ["log": 4, "ore": 6])
        #expect(req.steps == [
            CraftStep(recipeId: "r_plank", crafts: 2),
            CraftStep(recipeId: "r_bar", crafts: 2),
            CraftStep(recipeId: "r_nails", crafts: 2),
        ])
    }

    @Test("reaprovecha el excedente entre fabricaciones")
    func surplus() {
        // dos estanterías necesitan 1 tablón cada una: basta 1 tronco
        let req = Planner.requirements(for: ["r_shelf": 2], recipes: recipes, deep: true)
        #expect(req.materials == ["log": 1])
    }

    @Test("un objetivo que también es intermedio cuenta como paso")
    func targetAlsoIntermediate() {
        let req = Planner.requirements(for: ["r_plank": 1, "r_shelf": 1], recipes: recipes, deep: true)
        #expect(req.materials == ["log": 2])
        #expect(req.steps == [CraftStep(recipeId: "r_plank", crafts: 1)])
    }

    @Test("no entra en bucle con recetas circulares")
    func cycles() {
        let cyclic = [
            Recipe(id: "a", output: "A", outputQty: 1, station: "x", ingredients: [.init(item: "B", qty: 1)]),
            Recipe(id: "b", output: "B", outputQty: 1, station: "x", ingredients: [.init(item: "A", qty: 1)]),
        ]
        #expect(Planner.requirements(for: ["a": 1], recipes: cyclic, deep: true).materials == ["A": 1])
    }

    @Test("ignora recetas desconocidas y cantidades nulas")
    func ignoresInvalid() {
        #expect(Planner.requirements(for: ["nope": 3, "r_shelf": 0], recipes: recipes, deep: true).materials.isEmpty)
    }
}

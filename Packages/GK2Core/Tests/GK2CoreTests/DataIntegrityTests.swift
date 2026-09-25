import Testing
@testable import GK2Core

/// Comprueba que los JSON editados a mano no tienen referencias rotas.
@Suite("Integridad de datos")
struct DataIntegrityTests {
    let data = GameData.bundled

    @Test func idsUnicos() {
        #expect(Set(data.items.map(\.id)).count == data.items.count)
        #expect(Set(data.recipes.map(\.id)).count == data.recipes.count)
        #expect(Set(data.characters.map(\.id)).count == data.characters.count)
        #expect(!data.days.isEmpty)
    }

    @Test func recetasUsanObjetosExistentes() {
        for r in data.recipes {
            #expect(data.item(r.output) != nil, "\(r.id) → \(r.output)")
            #expect(r.outputQty > 0, "\(r.id) produce 0 unidades")
            for ing in r.ingredients { #expect(data.item(ing.item) != nil, "\(r.id) → \(ing.item)") }
        }
    }

    @Test func personajesUsanDiasYObjetosExistentes() {
        for c in data.characters {
            for d in c.days { #expect(data.day(d) != nil, "\(c.id) → día \(d)") }
            for i in (c.sells ?? []) + (c.buys ?? []) { #expect(data.item(i) != nil, "\(c.id) → \(i)") }
        }
    }

    @Test func iconosExisten() {
        let icons = data.items.map(\.icon) + data.days.map(\.icon) + data.characters.map(\.icon)
        for icon in icons { #expect(Sprites.all[icon] != nil, "icono desconocido: \(icon)") }
    }

    @Test func imagenesExisten() {
        let images = data.items.compactMap(\.image) + data.days.compactMap(\.image)
            + data.characters.compactMap(\.image) + data.stationList.compactMap(\.image)
        #expect(images.count > 600)
        for image in images { #expect(GameData.imageURL(image) != nil, "imagen desconocida: \(image)") }
        #expect(data.stationImage("Furnace") != nil)
    }

    @Test func spritesSon8x8() {
        for (name, rows) in Sprites.all {
            #expect(rows.count == 8 && rows.allSatisfy { $0.count == 8 }, "\(name) no es 8x8")
        }
    }

    @Test func busquedaIgnoraTildesYMayusculas() {
        #expect(data.searchRecipes("WOODEN PLÁNK").contains { $0.id == "r_wooden_plank" })
    }

    @Test func datosDeLaWiki() {
        #expect(data.days.map(\.id) == ["orgullo", "lujuria", "gula", "envidia", "ira", "pereza"])
        #expect(data.items.count > 400)
        #expect(data.recipes.count > 500)
        #expect(data.character("merchant")?.days == ["gula"])
        #expect(data.recipe(producing: "iron_ingot")?.station == "Furnace")
    }

    @Test func elPlanificadorTerminaConTodasLasRecetas() {
        for r in data.recipes {
            let req = Planner.requirements(for: [r.id: 3], recipes: data.recipes, deep: true)
            #expect(!req.materials.isEmpty, "\(r.id) sin materiales")
        }
    }
}

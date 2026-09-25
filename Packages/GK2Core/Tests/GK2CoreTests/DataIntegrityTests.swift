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

    @Test func spritesSon8x8() {
        for (name, rows) in Sprites.all {
            #expect(rows.count == 8 && rows.allSatisfy { $0.count == 8 }, "\(name) no es 8x8")
        }
    }

    @Test func busquedaIgnoraTildes() {
        #expect(data.searchRecipes("ataud").map(\.id) == ["r_coffin"])
    }
}

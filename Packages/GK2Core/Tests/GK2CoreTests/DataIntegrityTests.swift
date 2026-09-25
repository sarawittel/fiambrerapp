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

    @Test func misionesUsanObjetosYPersonajesExistentes() {
        for c in data.characters {
            let quests = c.quests ?? []
            #expect(Set(quests.map(\.id)).count == quests.count, "\(c.id): ids de misión repetidos")
            for q in quests {
                #expect(!q.text.isEmpty, "\(c.id)/\(q.id) sin texto")
                for i in (q.rewards ?? []) + (q.items ?? []) { #expect(data.item(i) != nil, "\(c.id)/\(q.id) → \(i)") }
                for other in q.characters ?? [] { #expect(data.character(other) != nil, "\(c.id)/\(q.id) → \(other)") }
                #expect(Set(q.rewards ?? []).isDisjoint(with: q.items ?? []), "\(c.id)/\(q.id): objeto repetido")
            }
            let levels = (c.friendship ?? []).map(\.level)
            #expect(levels == levels.sorted(), "\(c.id): amistad desordenada")
            for m in c.friendship ?? [] {
                for i in m.items ?? [] { #expect(data.item(i) != nil, "\(c.id) amistad → \(i)") }
            }
        }
    }

    @Test func enlacesDelTextoDeMisionesExisten() throws {
        let link = try Regex(#"\]\(gk2://(\w+)/(\w+)\)"#)
        var count = 0
        for c in data.characters {
            let texts = (c.quests ?? []).flatMap(\.text) + (c.friendship ?? []).map(\.text)
            for text in texts {
                for match in text.matches(of: link) {
                    count += 1
                    let kind = String(text[match.output[1].range!]), id = String(text[match.output[2].range!])
                    switch kind {
                    case "item": #expect(data.item(id) != nil, "\(c.id) → objeto \(id)")
                    case "character": #expect(data.character(id) != nil, "\(c.id) → personaje \(id)")
                    default: Issue.record("\(c.id): enlace desconocido \(kind)/\(id)")
                    }
                }
            }
        }
        #expect(count > 300)
        let letter = try #require(data.character("horadric")?.quests?.first { $0.id == "deliver_the_letter" })
        #expect(letter.text[0].contains("[**A mug of beer**](gk2://item/a_mug_of_beer)"))
    }

    @Test func misionesDeLaWiki() throws {
        let horadric = try #require(data.character("horadric"))
        let quests = horadric.quests ?? []
        #expect(quests.map(\.name).contains("Deliver the Letter"))
        let letter = try #require(quests.first { $0.id == "deliver_the_letter" })
        #expect(letter.friendship == 10)
        #expect(letter.rewards == ["a_mug_of_beer"])
        #expect(quests.first { $0.id == "unlock_the_kitchen_garden" }?.rewards == ["garden_certificate"])
        #expect(horadric.friendship?.contains { $0.level == 30 } == true)
        #expect(data.character("snake")?.friendship?.first { $0.level == 20 }?.items == ["town_pass"])
        #expect(data.quests(involving: "garden_certificate").contains { $0.npc.id == "horadric" && $0.quest.id == "unlock_the_kitchen_garden" })
        #expect(data.characters.reduce(0) { $0 + ($1.quests?.count ?? 0) } > 80)
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

    @Test func busquedaDeObjetosIncluyeLosNoFabricables() {
        let results = data.searchItems("garden cert")
        #expect(results.map(\.id) == ["garden_certificate"])
        #expect(data.recipe(producing: "garden_certificate") == nil)
        #expect(data.searchItems("").count == data.items.count)
        #expect(data.searchItems("", category: .comida).allSatisfy { $0.category == .comida })
        let raw = data.searchItems("", craftable: false)
        #expect(raw.contains { $0.id == "garden_certificate" })
        #expect(raw.allSatisfy { data.recipe(producing: $0.id) == nil })
        #expect(!data.searchItems("", craftable: true).contains { $0.id == "garden_certificate" })
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

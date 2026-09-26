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

    @Test(arguments: Game.allCases) func cadaJuegoTieneDatos(game: Game) {
        let data = GameData.bundled(for: game)
        #expect(!data.items.isEmpty && !data.recipes.isEmpty && !data.characters.isEmpty, "\(game.title) sin datos")
    }

    @Test func gk2CompartePeroSinMisionesAmistadNiLogros() {
        let gk1 = GameData.bundled(for: .gk1), gk2 = GameData.bundled(for: .gk2)
        #expect(gk2.items == gk1.items)
        #expect(gk2.recipes == gk1.recipes)
        #expect(gk2.days == gk1.days)
        #expect(gk2.technologies == gk1.technologies)
        #expect(gk2.characters.map(\.id) == gk1.characters.map(\.id))
        #expect(gk2.characters.allSatisfy { $0.quests == nil && $0.friendship == nil })
        #expect(gk2.guide.isEmpty)
        #expect(gk1.characters.contains { !($0.quests ?? []).isEmpty }, "GK1 conserva sus misiones")
        #expect(gk1.characters.contains { !($0.friendship ?? []).isEmpty }, "GK1 conserva la amistad")
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
                    case "day": #expect(data.day(id) != nil, "\(c.id) → día \(id)")
                    default: Issue.record("\(c.id): enlace desconocido \(kind)/\(id)")
                    }
                }
            }
        }
        #expect(count > 300)
        let letter = try #require(data.character("horadric")?.quests?.first { $0.id == "deliver_the_letter" })
        #expect(letter.text[0].contains("[**Jarra de cerveza**](gk2://item/a_mug_of_beer)"))
    }

    @Test func losDiasDeLaProsaVanComoIcono() throws {
        let smiler = try #require(data.character("smiler")?.quests)
        let text = smiler.flatMap(\.text).joined(separator: " ")
        #expect(text.contains("el próximo ![Orgullo](gk2://day/orgullo)"))
        // el pecado no es el día
        #expect(text.contains("sentido del orgullo"))
    }

    @Test func misionesDeLaWiki() throws {
        let horadric = try #require(data.character("horadric"))
        let quests = horadric.quests ?? []
        #expect(quests.map(\.name).contains("Entrega la carta"))
        #expect(data.character("adam")?.quests?.first?.name == "Fragmentos de arcilla")
        let letter = try #require(quests.first { $0.id == "deliver_the_letter" })
        #expect(letter.friendship == 10)
        #expect(letter.rewards == ["a_mug_of_beer"])
        #expect(quests.first { $0.id == "unlock_the_kitchen_garden" }?.rewards == ["garden_certificate"])
        #expect(horadric.friendship?.contains { $0.level == 30 } == true)
        #expect(data.character("snake")?.friendship?.first { $0.level == 20 }?.items == ["town_pass"])
        #expect(data.quests(involving: "garden_certificate").contains { $0.npc.id == "horadric" && $0.quest.id == "unlock_the_kitchen_garden" })
        #expect(data.characters.reduce(0) { $0 + ($1.quests?.count ?? 0) } > 80)
    }

    @Test func tecnologiasUsanObjetosYTecnologiasExistentes() throws {
        #expect(Set(data.technologies.map(\.id)).count == data.technologies.count)
        let link = try Regex(#"\]\(gk2://(\w+)/(\w+)\)"#)
        for tree in data.technologies {
            let techs = tree.technologies
            let ids = Set(techs.map(\.id))
            #expect(ids.count == techs.count, "\(tree.id): ids de tecnología repetidos")
            for tech in techs {
                for req in tech.requires ?? [] { #expect(ids.contains(req), "\(tree.id)/\(tech.id) → \(req)") }
                #expect(tech.cost != nil || tech.condition != nil, "\(tree.id)/\(tech.id) sin coste")
                for u in tech.unlocks ?? [] {
                    if let item = u.item { #expect(data.item(item) != nil, "\(tree.id)/\(tech.id) → \(item)") }
                }
                for text in [tech.condition].compactMap({ $0 }) + (tree.text ?? []) {
                    for match in text.matches(of: link) {
                        let kind = String(text[match.output[1].range!]), id = String(text[match.output[2].range!])
                        #expect(kind == "item" ? data.item(id) != nil : data.character(id) != nil, "\(tree.id) → \(kind)/\(id)")
                    }
                }
            }
        }
    }

    @Test func tecnologiasDeLaWiki() throws {
        #expect(data.technologies.map(\.id) == [
            "anatomy_and_alchemy", "theology", "book_writing", "farming_and_nature",
            "smithing", "building", "cookery", "spiritualism",
        ])
        #expect(data.technologies.reduce(0) { $0 + $1.technologies.count } > 150)
        let writing = try #require(data.techTree("book_writing")?.technologies.first { $0.id == "writing" })
        #expect(writing.cost == TechCost(red: 5, blue: 5))
        #expect(writing.requires == ["research"])
        #expect(writing.unlocks?.contains(TechUnlock(kind: .create, name: "Capítulo", item: "chapter")) == true)
        // prerrequisito doble: «Hardspares + Softspares»
        let butcher = data.techTree("anatomy_and_alchemy")?.technologies.first { $0.id == "gentle_butcher" }
        #expect(butcher?.requires == ["hardspares", "softspares"])
        #expect(data.techTree("spiritualism")?.dlc == "Better Save Soul")
        #expect(data.technologies(unlocking: "cake").contains { $0.tree.id == "cookery" && $0.tech.id == "cake" })
    }

    @Test func guiaDeLogrosDeLaWiki() throws {
        #expect(data.guide.map(\.id) == [
            "starting_out", "graveyard", "questlines", "crafting_cooking_farming",
            "fishing", "points", "dungeon", "miscellaneous",
        ])
        let achievements = data.guide.flatMap(\.achievements)
        #expect(achievements.count > 60)
        #expect(Set(achievements.map(\.id)).count == achievements.count)
        #expect(data.guideSection("questlines")?.spoiler == true)
        #expect(data.guideSection("fishing")?.spoiler == nil)
        let link = try Regex(#"\]\(gk2://(\w+)/(\w+)\)"#)
        for a in achievements {
            #expect(!a.text.isEmpty, "\(a.id) sin texto")
            for item in a.items ?? [] { #expect(data.item(item) != nil, "\(a.id) → \(item)") }
            for npc in a.characters ?? [] { #expect(data.character(npc) != nil, "\(a.id) → \(npc)") }
            for text in a.text {
                for match in text.matches(of: link) {
                    let kind = String(text[match.output[1].range!]), id = String(text[match.output[2].range!])
                    let exists = switch kind {
                    case "item": data.item(id) != nil
                    case "day": data.day(id) != nil
                    default: data.character(id) != nil
                    }
                    #expect(exists, "\(a.id) → \(kind)/\(id)")
                }
            }
        }
        let trusted = try #require(achievements.first { $0.id == "he_trusted_you" })
        #expect(trusted.missable == true)
        #expect(achievements.first { $0.id == "exterminate" }?.dlc == "Game of Crone")
        // se quitan las notas de editores («### Someone please edit this… ###»)
        #expect(!achievements.contains { $0.text.contains { $0.contains("###") } })
    }

    @Test func textosTraducidosAlEspanol() {
        // los nombres se quedan en inglés; las descripciones y explicaciones, en español (scripts/wiki/es.json)
        #expect(data.item("a_bowl_of_lentils")?.description?.hasPrefix("Un alimento") == true)
        #expect(data.item("a_bowl_of_lentils")?.sources?.contains("Cocina") == true)
        #expect(data.character("bishop")?.title == "Obispo")
        // nombres de objetos en español; el de la wiki se guarda y también se puede buscar
        let lentils = data.item("a_bowl_of_lentils")
        #expect(lentils?.name == "Cuenco de lentejas" && lentils?.wikiName == "A bowl of lentils")
        #expect(data.searchItems("cuenco de lent").contains { $0.id == "a_bowl_of_lentils" })
        #expect(data.searchItems("bowl of lent").contains { $0.id == "a_bowl_of_lentils" })
        #expect(Set(data.items.map(\.name)).count == data.items.count)
        // estaciones y tecnologías, también en español
        #expect(data.stationList.contains { $0.name == "Mesa de cocina" && $0.wikiName == "Cooking table" })
        #expect(data.techTree("anatomy_and_alchemy")?.name == "Anatomía y alquimia")
        #expect(data.guide.first?.achievements.first?.text.first?.contains("autopsia") == true)
        // los enlaces a otras wikis («pt-br:Óleo de semente») no son descripciones
        #expect(!data.items.contains { $0.description?.contains("pt-br:") == true })
    }

    @Test func iconosExisten() {
        let icons = data.items.map(\.icon) + data.days.map(\.icon) + data.characters.map(\.icon)
        for icon in icons { #expect(Sprites.all[icon] != nil, "icono desconocido: \(icon)") }
    }

    @Test func imagenesExisten() {
        let images = data.items.compactMap(\.image) + data.days.compactMap(\.image)
            + data.characters.compactMap(\.image) + data.stationList.compactMap(\.image)
            + data.technologies.compactMap(\.image) + data.guide.flatMap(\.achievements).compactMap(\.image)
        #expect(images.count > 600)
        for image in images { #expect(GameData.imageURL(image) != nil, "imagen desconocida: \(image)") }
        #expect(data.stationImage("Horno") != nil)
    }

    @Test func calidadesYEstudioBienFormados() throws {
        for level in ItemQuality.Level.allCases {
            #expect(GameData.imageURL("star_\(level.rawValue)") != nil, "falta la estrella \(level)")
        }
        let withQuality = data.items.filter { $0.quality != nil }
        #expect(withQuality.count > 40)
        for item in withQuality {
            #expect(item.quality?.map(\.level) == ItemQuality.Level.allCases, "\(item.id): calidades desordenadas")
        }
        for item in data.items {
            guard let study = item.study else { continue }
            #expect(!study.points.points.isEmpty, "\(item.id): estudio sin puntos")
            for part in study.decomposes ?? [] { #expect(data.item(part) != nil, "\(item.id) se descompone en \(part)") }
        }

        let hops = try #require(data.item("hops"))
        #expect(hops.quality?.map(\.buy) == [40, 52, 65])
        #expect(hops.quality?.map(\.sell) == [28, 35, 44])
        #expect(hops.study?.points.green == 40)
        #expect(hops.study?.decomposes == ["slowing_powder", "slowing_solution"])
        #expect(data.item("grapes")?.quality?.map(\.energy) == [20, 30, 35])
        // la descripción es la frase inicial del artículo («<b>Hops</b> are…»), no una de más abajo
        #expect(hops.description == "El lúpulo es un cultivo que se obtiene plantando semillas de lúpulo en el viñedo.")
        #expect(data.item("perfume")?.description?.contains("Ms. Charm") == true)
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

    @Test func busquedaDePersonajes() {
        #expect(data.searchCharacters("").count == data.characters.count)
        #expect(data.searchCharacters("beekeeper").map(\.id) == ["beekeeper"])
        #expect(data.searchCharacters("APICULTOR").contains { $0.id == "beekeeper" })
        #expect(data.searchCharacters("alfarero").contains { $0.id == "adam" })
    }

    @Test func busquedaDeTecnologias() {
        #expect(data.searchTechnologies("").isEmpty)
        #expect(data.searchTechnologies("investigacion").contains { $0.tech.id == "research" })
        // por lo que desbloquea, también con el nombre de la wiki
        let candle = data.searchTechnologies("vela")
        #expect(candle.contains { $0.tree.id == "theology" && $0.tech.id == "light_of_faith" })
        let wikiName = data.item("candle")?.wikiName ?? "candle"
        #expect(data.searchTechnologies(wikiName).contains { $0.tech.id == "light_of_faith" })
    }

    @Test func datosDeLaWiki() {
        #expect(data.days.map(\.id) == ["orgullo", "lujuria", "gula", "envidia", "ira", "pereza"])
        #expect(data.items.count > 400)
        #expect(data.recipes.count > 500)
        #expect(data.character("merchant")?.days == ["gula"])
        #expect(data.recipe(producing: "iron_ingot")?.station == "Horno")
    }

    @Test func elPlanificadorTerminaConTodasLasRecetas() {
        for r in data.recipes {
            let req = Planner.requirements(for: [r.id: 3], recipes: data.recipes, deep: true)
            #expect(!req.materials.isEmpty, "\(r.id) sin materiales")
        }
    }
}

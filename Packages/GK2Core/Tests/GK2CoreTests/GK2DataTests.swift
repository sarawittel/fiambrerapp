import Testing
@testable import GK2Core

/// Datos propios de GK2 (Data/GK2, de scripts/wiki_gk2), sin nada de GK1.
@Suite("Datos de GK2")
struct GK2DataTests {
    let data = GameData.bundled(for: .gk2)

    @Test func noCompartenNadaConGK1() {
        let gk1 = GameData.bundled(for: .gk1)
        #expect(data.items != gk1.items && data.recipes != gk1.recipes)
        #expect(data.days.isEmpty)
        #expect(Set(data.guide.flatMap(\.achievements).map(\.id)).isDisjoint(with: gk1.guide.flatMap(\.achievements).map(\.id)))
        #expect(gk1.walkthrough == nil && data.walkthrough != nil)
        #expect(Set(data.technologies.map(\.id)) != Set(gk1.technologies.map(\.id)))
        #expect(Set(data.characters.map(\.id)).isDisjoint(with: ["horadric", "bishop", "merchant"]))
        // los ids pueden coincidir, los datos no: en GK2 el lingote de hierro sale de la herrería
        #expect(data.recipe(producing: "iron_ingot")?.station == "Herrería I")
        #expect(gk1.recipe(producing: "iron_ingot")?.station == "Horno")
    }

    @Test func idsUnicosYReferenciasExistentes() {
        #expect(Set(data.items.map(\.id)).count == data.items.count)
        #expect(Set(data.recipes.map(\.id)).count == data.recipes.count)
        #expect(Set(data.items.map(\.name)).count == data.items.count)
        for r in data.recipes {
            #expect(data.item(r.output) != nil, "\(r.id) → \(r.output)")
            #expect(r.outputQty > 0, "\(r.id) produce 0 unidades")
            for ing in r.ingredients { #expect(data.item(ing.item) != nil, "\(r.id) → \(ing.item)") }
        }
    }

    @Test func guiaParaPrincipiantes() throws {
        let guide = try #require(data.walkthrough)
        #expect(guide.milestones.map(\.id) == ["first_burial", "graveyard", "first_church_ceremony",
                                                "herberts_preparations", "first_port_battle", "first_workers"])
        #expect(guide.milestones.first?.name == "Primer entierro")
        #expect(guide.steps.first?.id == "bury_a_corpse_and_reach_herbert")
        #expect(guide.steps.count == 7)
        // ids únicos: se guardan los pasos hechos
        #expect(Set(guide.steps.map(\.id)).count == guide.steps.count)
        for step in [guide.checklist] + guide.steps {
            #expect(!step.text.isEmpty && !step.links.isEmpty, "\(step.id) vacío")
            for id in step.items ?? [] { #expect(data.item(id) != nil, "\(step.id) → \(id)") }
            for id in step.characters ?? [] { #expect(data.character(id) != nil, "\(step.id) → \(id)") }
            for link in step.links {
                for match in link.matches(of: #/gk2://(item|character)/([a-z0-9_]+)/#) {
                    let id = String(match.2)
                    #expect(match.1 == "item" ? data.item(id) != nil : data.character(id) != nil, "\(step.id) → \(link)")
                }
            }
        }
        // los nombres del texto en inglés, también en plural («5 Wooden Planks»)
        let food = try #require(guide.steps.first { $0.id == "establish_food_materials_and_a_fishing_rod" })
        #expect(food.items == ["wheat", "wooden_plank", "bronze_detail", "clay_plate", "basic_rod"])
        #expect(food.characters == ["herm", "jack"])
        #expect(food.links.last?.hasPrefix("[**Lingote de hierro**](gk2://item/iron_ingot)") == true)
    }

    @Test func logros() throws {
        #expect(data.guide.map(\.id) == ["crafting_and_gathering", "town_and_graveyard", "story_milestones", "hidden_achievements"])
        #expect(data.guide.map { $0.spoiler == true } == [false, false, true, true])
        let all = data.guide.flatMap(\.achievements)
        #expect(all.count == 38)
        #expect(Set(all.map(\.id)).count == all.count)
        for a in all {
            #expect(!a.text.isEmpty && a.name != a.id, "\(a.id) sin traducir")
            for id in a.characters ?? [] { #expect(data.character(id) != nil, "\(a.id) → \(id)") }
        }
        let farmer = try #require(all.first)
        #expect(farmer.id == "master_farmer" && farmer.name == "Granjero experto" && farmer.wikiName == "Master Farmer")
        #expect(farmer.text == ["Has cosechado 100 cultivos. ¡Hay para todo el pueblo!"])
        #expect(all.first { $0.id == "two_broken_souls" }?.characters == ["jack", "gunter"])
    }

    @Test func misiones() throws {
        let givers = data.characters.filter { $0.quests?.isEmpty == false }
        #expect(givers.flatMap { $0.quests ?? [] }.count == 9)
        for npc in givers {
            let ids = (npc.quests ?? []).map(\.id)
            #expect(Set(ids).count == ids.count, "\(npc.id): misiones repetidas")
            for q in npc.quests ?? [] {
                #expect(q.text.count >= 3, "\(q.id) sin etapas")
                for id in q.items ?? [] { #expect(data.item(id) != nil, "\(q.id) → \(id)") }
                for id in q.characters ?? [] { #expect(data.character(id) != nil, "\(q.id) → \(id)") }
            }
        }
        let herbert = try #require(data.character("herbert")?.quests)
        #expect(herbert.map(\.id) == ["certificate_please", "grave_expectations", "fighting_spirit_required", "swords_and_bell"])
        let peas = try #require(data.character("jeffry")?.quests?.first)
        #expect(peas.name == "Como dos gotas de agua" && peas.wikiName == "Two Peas in a Pod")
        // los nombres de misiones en los textos también van en español
        let food = try #require(data.walkthrough?.steps[1])
        #expect(food.text[0].contains("«Sembrado y entregado» sugiere"))
        #expect(food.links[0].hasPrefix("**Sembrado y entregado** — "))
        // «Clay» no sale de «Clay Plates»
        #expect(peas.items == ["clay_plate", "basic_rod"])
        #expect(peas.text[1].hasPrefix("**Busca a los hermanos.** Cruza el puente"))
    }

    @Test func talentos() throws {
        // el último árbol de la pestaña Tecnologías: las inspiraciones de primer nivel
        let tree = try #require(data.technologies.last)
        #expect(tree.id == "talents_and_inspirations" && tree.name == "Talentos e inspiraciones")
        #expect(tree.image.flatMap(GameData.imageURL) != nil)
        #expect(tree.text?.isEmpty == false)
        #expect(tree.technologies.map(\.id) == ["lumberjack_i", "woodcutter_i", "carpenter_i", "rock_breaker_i",
                                                 "home_sweet_home_i", "shop_owner_i", "furniture_maker_i", "marble_madness_i"])
        for tech in tree.technologies { #expect(tech.cost == nil && tech.condition != nil, "\(tech.id)") }
        let carpenter = try #require(tree.technologies.first { $0.id == "carpenter_i" }?.condition)
        #expect(carpenter.hasPrefix("Completa tandas de carpintería que cuenten. Objetivo del primer nivel: 10."))
        #expect(carpenter.contains("Silla cómoda"))
        #expect(tree.technologies.first { $0.id == "marble_madness_i" }?.condition?
            .hasSuffix("Necesita la tecnología El concepto del mármol.") == true)
    }

    @Test func iconosEImagenesExisten() {
        for item in data.items { #expect(Sprites.all[item.icon] != nil, "icono desconocido: \(item.icon)") }
        let images = data.items.compactMap(\.image)
        #expect(images.count > 30)
        for image in images { #expect(GameData.imageURL(image) != nil, "imagen desconocida: \(image)") }
    }

    @Test func materialesDeLaWiki() throws {
        // los de «Items and Materials», en el orden de la página
        #expect(Array(data.items.prefix(3).map(\.id)) == ["board", "short_log", "wooden_plank"])
        for id in ["special_wood", "golden_ingot", "faith", "hypno_device", "blue_crystal", "magic_bell", "flax"] {
            #expect(data.item(id) != nil, "falta \(id)")
        }
        let board = try #require(data.item("board"))
        #expect(board.name == "Tabla" && board.wikiName == "Board" && board.image == "GK2/board")
        let recipe = try #require(data.recipe(producing: "board"))
        #expect(recipe.outputQty == 4 && recipe.station == "Caballete de aserrar")
        #expect(recipe.ingredients == [Ingredient(item: "log", qty: 1)])
        #expect(recipe.notes == "Tecnología: El concepto de la madera.")
        // la receta principal del lingote de oro es la de fundir pepitas (guide.json)
        let gold = try #require(data.recipe(producing: "golden_ingot"))
        #expect(gold.ingredients.map(\.item) == ["golden_nugget", "fuel"])
        #expect(gold.notes?.contains("3 con la ventaja Fogonero") == true)
        // las páginas que son guías llevan su primer párrafo como descripción y su origen
        #expect(data.item("coal")?.description?.hasPrefix("Lo saca un Minero zombi") == true)
        #expect(data.item("steel_ingot")?.sources?.first?.contains("Obispo") == true)
    }

    @Test func recetasDeCraftingRecipes() throws {
        // las de las páginas por familia de estaciones (Woodworking, Metalworking…)
        #expect(data.recipes.count > 120)
        let axe = try #require(data.recipe(producing: "iron_axe"))
        #expect(axe.station == "Yunque de hierro" && axe.ingredients.map(\.item) == ["stick", "iron_detail", "iron_ingot"])
        #expect(data.item("iron_axe")?.category == .herramienta)
        // las repetidas entre la página del objeto y la de su familia se juntan
        #expect(data.recipes.filter { $0.output == "board" }.count == 2)
        // collares de la Mesa de joyería
        let collar = try #require(data.recipe(producing: "steel_zombie_collar"))
        #expect(collar.station == "Mesa de joyería" && collar.notes == "Maestría 12.")
        #expect(collar.ingredients.contains(Ingredient(item: "faith", qty: 10)))
        // el combustible sale de la leña, así que el planificador llega hasta los troncos
        #expect(data.recipe(producing: "fuel")?.ingredients == [Ingredient(item: "firewood", qty: 2)])
        let glass = try #require(data.recipes.first { $0.output == "glass" && $0.station == "Horno I" })
        let req = Planner.requirements(for: [glass.id: 1], recipes: data.recipes, deep: true)
        #expect(req.materials["log"] != nil)
    }

    @Test func recetasDeCocina() throws {
        let bread = try #require(data.recipe(producing: "bread"))
        #expect(bread.station == "Horno de cocina" && bread.outputQty == 4)
        // «10 Fuel (5 with Heat Saver)»: 10 de combustible, y la rebaja en las notas
        #expect(bread.ingredients == [Ingredient(item: "dough", qty: 4), Ingredient(item: "fuel", qty: 10)])
        #expect(bread.notes?.contains("5 de combustible con la ventaja Ahorro de calor") == true)
        #expect(data.item("bread")?.category == .comida)
        // las calidades son objetos distintos
        #expect(data.item("wine_silver")?.name == "Vino (plata)")
        #expect(data.recipe(producing: "wine_silver")?.ingredients.first?.item == "wine_bronze")
        #expect(data.recipes.filter { $0.output == "cabbage_soup" }.map(\.outputQty) == [4, 7, 10])
    }

    @Test func recetasDeAlquimia() throws {
        // son recetas como las demás, en el laboratorio; la fórmula de runas va en las notas
        let healing = try #require(data.recipe(producing: "healing_potion"))
        #expect(healing.station == "Laboratorio I" && healing.outputQty == 1)
        // «Clay + Clay»: cada ingrediente ocupa un hueco
        #expect(healing.ingredients == [Ingredient(item: "clay", qty: 2)])
        #expect(healing.notes?.contains("Runas: 2 rojas, 0 verdes y 0 azules") == true)
        #expect(data.item("healing_potion")?.category == .alquimia)
        // las de guide.json se juntan con las de la tabla: una sola receta de Pintura, con su tecnología y sus runas
        let paint = data.recipes.filter { $0.output == "paint" }
        #expect(paint.count == 1 && paint[0].notes?.contains("Tecnología: Pintura") == true && paint[0].notes?.contains("Runas") == true)
        #expect(data.recipe(producing: "philosopher_stone")?.ingredients.map(\.item) == ["tin", "hops", "salt"])
    }

    @Test func recetasEnOrdenAlfabetico() {
        let names = data.searchRecipes("").map { data.itemName($0.output) }
        #expect(names == names.sorted { $0.localizedCompare($1) == .orderedAscending })
        // las del mismo producto, por estación
        let board = data.searchRecipes("").filter { $0.output == "board" }.map(\.station)
        #expect(board == ["Caballete de aserrar", "Sierra circular"])
        // el orden de los datos no cambia: sigue decidiendo la receta principal
        #expect(data.recipe(producing: "golden_ingot")?.station == "Horno II")
    }

    @Test func queDistingueRecetasDelMismoProducto() {
        let all = data.recipes
        let rings = all.filter { $0.output == "onion_rings" }
        // misma estación: el ingrediente que solo lleva cada una
        #expect(rings.map { data.distinguishing($0, among: all) } == [
            "Horno de cocina · Cebolla (bronce)", "Horno de cocina · Cebolla (plata)", "Horno de cocina · Cebolla (oro)",
        ])
        // distinta estación: basta la estación
        let board = all.filter { $0.output == "board" }
        #expect(board.map { data.distinguishing($0, among: all) } == ["Caballete de aserrar", "Sierra circular"])
        // la única receta del producto no necesita nada
        #expect(data.recipe(producing: "bread").map { data.distinguishing($0, among: all) } == .some(nil))
    }

    @Test func construcciones() throws {
        let builds = data.recipes.filter { $0.station.hasPrefix(GameData.buildStationPrefix) }
        #expect(builds.count > 100)
        // una sola receta para el baúl sencillo, que se construye igual en las cuatro zonas
        let chests = data.recipes.filter { $0.output == "simple_chest" }
        #expect(chests.count == 1 && chests[0].station == "Construcción · Iglesia")
        #expect(chests[0].notes?.hasPrefix("También en: Cementerio, Morgue, Laboratorio de alquimia") == true)
        // las guías de estación dicen la zona: pesan más que las tablas «Construction uses», que no la dicen
        let jewelry = try #require(data.recipe(producing: "jewelry_table"))
        #expect(jewelry.station == "Construcción · Sala de escritura" && jewelry.ingredients.first == Ingredient(item: "wooden_plank", qty: 4))
        #expect(data.recipes.filter { $0.output == "jewelry_table" }.count == 1)
        // sin zona y con costes distintos: los dos, con aviso
        let furnace = data.recipes.filter { $0.output == "furnace_ii" }
        #expect(furnace.count == 2 && furnace.allSatisfy { $0.station == "Construcción · Zona sin indicar" && $0.notes?.contains("costes distintos") == true })
        // la wiki de GK2 no tiene imágenes de estaciones: se copia la de GK1 si la misma estación existe allí
        #expect(data.item("sawhorse")?.image == "GK2/sawhorse" && GameData.imageURL("GK2/sawhorse") != nil)
        #expect(data.item("furnace_i")?.image == "GK2/furnace_i")  // «Furnace» en GK1
        #expect(data.item("church_shrine_i")?.image == nil && data.item("church_shrine_i")?.icon == "blueprint")
        // objetos sin icono en ninguna página: el de la wiki de GK2 si se sabe cuál es, si no el de GK1;
        // las calidades usan el del objeto base
        for id in ["skull", "wine_gold", "beer", "cabbage_silver", "faith"] {
            #expect(data.item(id)?.image == "GK2/\(id)", "\(id) sin imagen")
        }
        // son estaciones: no van en los baúles
        #expect(data.isStation("sawhorse") && data.item("sawhorse")?.name == "Caballete de aserrar")
        #expect(!data.searchItems("", storable: true).contains { $0.id == "sawhorse" })
    }

    @Test func personajesYComercio() throws {
        #expect(Set(data.characters.map(\.id)).count == data.characters.count)
        for c in data.characters {
            for i in (c.sells ?? []) + (c.buys ?? []) { #expect(data.item(i) != nil, "\(c.id) → \(i)") }
            if let image = c.image { #expect(GameData.imageURL(image) != nil, "imagen desconocida: \(image)") }
            #expect(c.days.isEmpty)
        }
        // los de «Characters», con su retrato, y los comerciantes de «Where to Buy Materials»
        let herm = try #require(data.character("herm"))
        #expect(herm.location == "Herm's Store" && herm.image == "GK2/npc_herm")
        #expect(herm.notes?.contains("Vende desde el nivel 1: Chatarra de bronce, Semilla de trigo.") == true)
        // «Flax Seed» en una página y «Flax Seeds» en otra: el mismo objeto
        #expect(herm.sells?.contains("flax_seeds") == true && data.item("flax_seed") == nil)
        #expect(data.character("builder")?.name == "Constructor")
        #expect(data.sellers(of: "board").map(\.id) == ["builder"])
        #expect(data.buyers(of: "board").map(\.id) == ["herm"])
        #expect(data.sellers(of: "blue_crystal").map(\.id) == ["gunter"])
    }

    @Test func tecnologias() throws {
        // un árbol por página de «Technology Costs», en su orden, y al final los talentos
        #expect(data.technologies.map(\.id) == ["building", "metallurgy", "farming", "theology", "anatomy_and_alchemy", "cooking",
                                                "talents_and_inspirations"])
        #expect(data.technologies.dropLast().map(\.technologies.count).reduce(0, +) == 226)
        for tree in data.technologies {
            let ids = Set(tree.technologies.map(\.id))
            #expect(ids.count == tree.technologies.count, "\(tree.id): ids repetidos")
            #expect(tree.image.flatMap(GameData.imageURL) != nil, "\(tree.id) sin imagen")
            #expect(tree.text?.isEmpty == false)
            for tech in tree.technologies {
                for r in tech.requires ?? [] { #expect(ids.contains(r), "\(tree.id)/\(tech.id) → \(r)") }
                for u in tech.unlocks ?? [] { #expect(u.item.flatMap(data.item) != nil, "\(tree.id)/\(tech.id) → \(u.name)") }
            }
        }
        let building = try #require(data.techTree("building"))
        #expect(building.name == "Construcción")
        let chopping = try #require(building.technologies.first { $0.id == "chopping" })
        #expect(chopping.name == "Corte de leña" && chopping.cost == TechCost(red: 8) && chopping.requires == ["the_concept_of_wood"])
        // la reputación y las ocultas van en la condición
        let saw = try #require(building.technologies.first { $0.id == "circular_saw" })
        #expect(saw.condition == "Necesita 40 de reputación con [**Jack**](gk2://character/jack).")
        #expect(building.technologies.first { $0.id == "market_stalls_i" }?.cost == nil)
        // lo que desbloquea sale de las recetas que piden la tecnología
        #expect(data.technologies(unlocking: "board").map(\.tech.id) == ["the_concept_of_wood"])
        #expect(data.technologies(unlocking: "furnace_i").first?.tech.unlocks?.first { $0.item == "furnace_i" }?.kind == .blueprint)
        // «Fabric» está en dos árboles: la receta es de la de Construcción
        #expect(data.technologies(unlocking: "supply_fabric").map(\.tree.id) == ["building"])
        // la cocina no cuesta puntos: cada una dice cómo se desbloquea
        let cooking = try #require(data.techTree("cooking"))
        #expect(cooking.technologies.allSatisfy { $0.cost == nil && $0.condition != nil })
        #expect(data.searchTechnologies("tarta").contains { $0.tech.id == "first_dishes" })
    }

    @Test func elPlanificadorTerminaConTodasLasRecetas() {
        for r in data.recipes {
            let req = Planner.requirements(for: [r.id: 3], recipes: data.recipes, deep: true)
            #expect(!req.materials.isEmpty, "\(r.id) sin materiales")
        }
    }
}

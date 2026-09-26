import Testing
@testable import GK2Core

private func item(_ id: String, _ name: String) -> Item {
    Item(id: id, name: name, category: .material, icon: "log")
}

private let data = GameData(
    items: [item("log", "Tronco"), item("plank", "Tablón"), item("anvil", "Yunque"), item("lantern", "Farol")],
    recipes: [
        Recipe(id: "r_plank", output: "plank", outputQty: 2, station: "Caballete", ingredients: [.init(item: "log", qty: 1)]),
        Recipe(id: "r_anvil", output: "anvil", outputQty: 1, station: "Banco", ingredients: [.init(item: "log", qty: 2)]),
        Recipe(id: "r_lantern", output: "lantern", outputQty: 1, station: "Construcción · Cementerio", ingredients: [.init(item: "log", qty: 1)]),
    ],
    days: [], characters: [],
    stations: [Station(name: "Yunque")]
)

@Suite("Baúles")
struct ChestTests {
    @Test("las estaciones y las construcciones no caben en un baúl")
    func stations() {
        #expect(data.isStation("anvil"))
        #expect(data.isStation("lantern"))
        #expect(!data.isStation("plank"))
        #expect(!data.isStation("log"))
        #expect(data.searchItems("", storable: true).map(\.id) == ["plank", "log"])
    }

    @Test("sin «storable» la búsqueda sigue incluyendo las estaciones")
    func searchKeepsStations() {
        #expect(data.searchItems("").count == 4)
    }

    @Test("poner 0 unidades saca el objeto del baúl")
    func setCount() {
        var chest = Chest(name: "Sótano", items: ["log": 3, "plank": 0])
        #expect(chest.items == ["log": 3])
        chest.setCount(5, of: "plank")
        #expect(chest.total == 8)
        chest.setCount(0, of: "log")
        chest.setCount(-2, of: "plank")
        #expect(chest.items.isEmpty)
        #expect(chest.count(of: "log") == 0)
    }

    @Test("todos los datos tienen objetos guardables y estaciones")
    func bundled() {
        let data = GameData.bundled
        let storable = data.searchItems("", storable: true)
        #expect(!storable.isEmpty)
        #expect(storable.count < data.items.count)
    }
}

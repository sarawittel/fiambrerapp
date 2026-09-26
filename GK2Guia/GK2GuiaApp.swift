import SwiftUI

@main
struct GK2GuiaApp: App {
    @State private var state = AppState()
    @State private var router = Router()

    init() {
        FontLoader.registerBundledFonts()
        Self.styleNavigationBar()
    }

    /// Barra de navegación de madera con título pixelado.
    private static func styleNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.woodDark)
        appearance.shadowColor = UIColor(Theme.outline)
        appearance.titleTextAttributes = [
            .font: UIFont(name: "PressStart2P-Regular", size: 12) ?? .boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor(Theme.candle),
        ]
        let buttonFont = UIFont(name: "VT323-Regular", size: 22) ?? .systemFont(ofSize: 17)
        appearance.buttonAppearance.normal.titleTextAttributes = [.font: buttonFont]
        appearance.backButtonAppearance.normal.titleTextAttributes = [.font: buttonFont]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup("Guía del Guardián") {
            ContentView()
                .environment(state)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Theme.candle)
        }
    }
}

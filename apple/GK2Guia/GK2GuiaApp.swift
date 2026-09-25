import SwiftUI

/// Color de fondo de la web (#14100d), para que no haya destellos al cargar.
let gkBackground = Color(red: 0x14 / 255, green: 0x10 / 255, blue: 0x0d / 255)

@main
struct GK2GuiaApp: App {
    var body: some Scene {
        WindowGroup("Guía del Guardián") {
            GuideWebView()
                .background(gkBackground.ignoresSafeArea())
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 820)
        #endif
    }
}

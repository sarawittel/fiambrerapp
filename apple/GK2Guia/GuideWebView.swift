import SwiftUI
import WebKit

/// WKWebView que sirve la web empaquetada en el bundle mediante el esquema gk2://
struct GuideWebView {
    static let startURL = URL(string: "\(BundleSchemeHandler.scheme)://app/index.html")!

    func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)
        // Almacén persistente: el plan, el inventario y el día actual sobreviven entre sesiones
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #else
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        webView.load(URLRequest(url: Self.startURL))
        return webView
    }
}

#if os(iOS)
extension GuideWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
extension GuideWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView() }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif

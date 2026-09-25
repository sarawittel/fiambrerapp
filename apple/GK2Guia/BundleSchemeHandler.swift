import Foundation
import WebKit

/// Sirve los archivos de `dist/` del bundle. Se usa un esquema propio en vez de file://
/// porque WebKit bloquea los módulos ES cargados desde file://.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "gk2"

    private let root = Bundle.main.resourceURL!.appendingPathComponent("dist").standardizedFileURL

    private static let mimeTypes = [
        "html": "text/html", "js": "text/javascript", "css": "text/css",
        "svg": "image/svg+xml", "png": "image/png", "json": "application/json",
        "woff": "font/woff", "woff2": "font/woff2",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let path = url.path.isEmpty || url.path == "/" ? "/index.html" : url.path
        let file = root.appendingPathComponent(path).standardizedFileURL

        guard file.path.hasPrefix(root.path), let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mime = Self.mimeTypes[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime, "Content-Length": String(data.count)]
        )!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

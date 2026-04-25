import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct GameWebView: UIViewRepresentable {
    let gameURL: URL
    let gameName: String
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Register custom scheme handler for game files
        let handler = GameURLSchemeHandler(baseDirectory: gameURL)
        config.setURLSchemeHandler(handler, forURLScheme: "game")
        
        // Allow inline media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        
        // 1. Inject Save Data from Native to JS
        let saves = UserDefaults.standard.dictionary(forKey: "\(gameName)_saves") as? [String: String] ?? [:]
        var injectSavesJS = "window.tyrano_save = {};"
        for (key, value) in saves {
            // value is already URL encoded or JSON string, escape single quotes
            let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
            injectSavesJS += "window.tyrano_save['\(key)'] = decodeURIComponent('\(escapedValue)');"
        }
        let saveScript = WKUserScript(source: injectSavesJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(saveScript)
        
        // 2. Load hooks from bundle
        if let tyranoHookPath = Bundle.main.path(forResource: "__tyrano__", ofType: "js"),
           let tyranoHook = try? String(contentsOfFile: tyranoHookPath) {
            let script = WKUserScript(source: tyranoHook, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            userContentController.addUserScript(script)
        }
        
        if let rpgHookPath = Bundle.main.path(forResource: "__rpg__", ofType: "js"),
           let rpgHook = try? String(contentsOfFile: rpgHookPath) {
            let script = WKUserScript(source: rpgHook, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            userContentController.addUserScript(script)
        }
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        
        // Load index.html via custom scheme
        if let url = URL(string: "game://localhost/index.html") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GameWebView
        
        init(_ parent: GameWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Intercept Tyrano save/load URL schemes
            if url.scheme == "tyranoplayer-save" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems {
                    let key = queryItems.first(where: { $0.name == "key" })?.value ?? ""
                    let data = queryItems.first(where: { $0.name == "data" })?.value ?? ""
                    
                    var saves = UserDefaults.standard.dictionary(forKey: "\(parent.gameName)_saves") as? [String: String] ?? [:]
                    saves[key] = data
                    UserDefaults.standard.set(saves, forKey: "\(parent.gameName)_saves")
                }
                decisionHandler(.cancel)
                return
            } else if url.scheme == "tyranoplayer-back" {
                DispatchQueue.main.async {
                    self.parent.dismiss()
                }
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}

class GameURLSchemeHandler: NSObject, WKURLSchemeHandler {
    let baseDirectory: URL
    
    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        super.init()
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "GameURLSchemeHandler", code: 400, userInfo: nil))
            return
        }
        
        let path = url.path
        let fileURL = baseDirectory.appendingPathComponent(path)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let mimeType = mimeTypeForURL(fileURL)
                
                let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch {
                urlSchemeTask.didFailWithError(error)
            }
        } else {
            urlSchemeTask.didFailWithError(NSError(domain: "GameURLSchemeHandler", code: 404, userInfo: nil))
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
    
    private func mimeTypeForURL(_ url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

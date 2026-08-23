import Foundation

/// Sélection du transport au démarrage.
///
/// Ordre de résolution :
/// 1. `PARLA_PROXY_URL` dans `Config.plist` → `ProxyTransport` (le mode de production).
/// 2. `ANTHROPIC_API_KEY` dans `Config.plist` ou l'environnement → transport direct, **debug seulement**.
/// 3. Rien → `MockTransport`, pour que l'app se lance et se démo sans réseau.
enum AppConfiguration {
    static func makeTransport() -> LLMTransport {
        if let proxy = value(for: "PARLA_PROXY_URL"), let url = URL(string: proxy) {
            return ProxyTransport(baseURL: url, userTokenProvider: { value(for: "PARLA_USER_TOKEN") })
        }

        #if DEBUG
        if let key = value(for: "ANTHROPIC_API_KEY") ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return DirectAnthropicTransport(apiKey: key)
        }
        #endif

        return MockTransport()
    }

    /// `true` quand aucune configuration n'a été trouvée : l'app affiche alors
    /// une bannière « mode démo » plutôt que d'échouer silencieusement.
    static var isRunningOnMock: Bool {
        if value(for: "PARLA_PROXY_URL") != nil { return false }
        #if DEBUG
        if value(for: "ANTHROPIC_API_KEY") != nil { return false }
        if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil { return false }
        #endif
        return true
    }

    private static func value(for key: String) -> String? {
        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let value = plist[key] as? String,
            !value.isEmpty,
            !value.hasPrefix("$(")
        else { return nil }
        return value
    }
}

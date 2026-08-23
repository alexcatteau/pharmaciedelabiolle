import Foundation

/// Persistance locale, en JSON, dans le conteneur de l'app.
///
/// Volontairement simple : le volume de données est minuscule (un profil, quelques
/// centaines de cartes, l'historique des sessions) et tout tient en mémoire.
/// SwiftData ou CoreData deviendront pertinents le jour où il faudra synchroniser
/// entre appareils — pas avant, et ça ne change rien à la forme des modèles.
struct Store {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = base.appendingPathComponent("Parla", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Decodable>(_ type: T.Type, from file: StoreFile) -> T? {
        guard let data = try? Data(contentsOf: url(for: file)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to file: StoreFile) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: file), options: .atomic)
    }

    func wipe() {
        for file in StoreFile.allCases {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }

    private func url(for file: StoreFile) -> URL {
        directory.appendingPathComponent(file.rawValue).appendingPathExtension("json")
    }
}

enum StoreFile: String, CaseIterable {
    case profile
    case cards
    case sessions
}

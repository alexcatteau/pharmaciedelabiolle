import Foundation

/// Petit type JSON dynamique, uniquement pour les schémas de sortie structurée :
/// on doit pouvoir écrire un JSON Schema arbitraire dans le corps de la requête
/// sans définir un `Encodable` par schéma.
indirect enum JSONValue: Encodable, Hashable {
    case string(String)
    case number(Double)
    case integer(Int)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .integer(value) }
}

/// Helpers de construction de schéma, pour que les schémas restent lisibles
/// à l'endroit où on les écrit.
enum Schema {
    static func object(
        properties: [String: JSONValue],
        required: [String]
    ) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map { .string($0) }),
            // Exigé par la sortie structurée stricte de l'API.
            "additionalProperties": .bool(false)
        ])
    }

    static func string(_ description: String? = nil, enumValues: [String]? = nil) -> JSONValue {
        var fields: [String: JSONValue] = ["type": .string("string")]
        if let description { fields["description"] = .string(description) }
        if let enumValues { fields["enum"] = .array(enumValues.map { .string($0) }) }
        return .object(fields)
    }

    static func boolean(_ description: String? = nil) -> JSONValue {
        var fields: [String: JSONValue] = ["type": .string("boolean")]
        if let description { fields["description"] = .string(description) }
        return .object(fields)
    }

    static func array(of items: JSONValue, description: String? = nil) -> JSONValue {
        var fields: [String: JSONValue] = ["type": .string("array"), "items": items]
        if let description { fields["description"] = .string(description) }
        return .object(fields)
    }

    /// Un champ optionnel au sens de l'API stricte : le champ reste `required`,
    /// mais son type accepte `null`. C'est le seul moyen d'avoir un champ
    /// facultatif avec `additionalProperties: false`.
    static func nullableString(_ description: String? = nil) -> JSONValue {
        var fields: [String: JSONValue] = [
            "type": .array([.string("string"), .string("null")])
        ]
        if let description { fields["description"] = .string(description) }
        return .object(fields)
    }
}

import Foundation

// Canonical vocabulary model for app data (words, meaning IDs, annotations, assets).

enum WordDataPartOfSpeech: String, Codable, CaseIterable {
    case noun
    case verb
    case adjective
    case adverb
    case phrase
    case other
}

enum WordDataCategory: String, Codable, CaseIterable {
    case basic
    case action
    case object
    case family
    case color
    case food
    case nature
    case vehicle
    case toy
    case bodyPart
    case other
}

enum WordDataAssetKind: String, Codable, CaseIterable {
    case image
    case audio
}

struct WordDataTranslation: Codable, Hashable {
    var language: String
    var text: String
}

struct WordDataDefinition: Codable, Hashable {
    var language: String
    var text: String
    var source: String?
}

struct WordDataAsset: Codable, Hashable {
    var kind: WordDataAssetKind
    var language: String?
    var uri: String
    var rotationDegrees: Int?
}

struct WordDataEntry: Codable, Hashable, Identifiable {
    var id: String
    var spelling: String
    var meaningKey: String?
    var partOfSpeech: WordDataPartOfSpeech?
    var category: WordDataCategory?
    var tags: [String]
    var translations: [WordDataTranslation]
    var definitions: [WordDataDefinition]
    var assets: [WordDataAsset]

    func translation(language: String) -> String? {
        translations.first(where: { $0.language.lowercased() == language.lowercased() })?.text
    }
}

struct WordDataSet: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var wordIDs: [String]
}

struct WordDataCatalog: Codable {
    var version: Int
    var source: String?
    var entries: [WordDataEntry]
    var sets: [WordDataSet]
}

extension WordDataCatalog {
    static func makeWordID(spelling: String, meaningKey: String?) -> String {
        let base = spelling.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let meaning = (meaningKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return meaning.isEmpty ? base : "\(base)|\(meaning)"
    }

    static func splitWordID(_ id: String) -> (spelling: String, meaningKey: String?) {
        let parts = id.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let meaning = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (String(parts[0]), meaning.isEmpty ? nil : meaning)
        }
        return (id, nil)
    }

    static func decode(from data: Data) throws -> WordDataCatalog {
        let decoder = JSONDecoder()
        var canonical = try decoder.decode(WordDataCatalog.self, from: data)
        canonical.normalizeEntries()
        return canonical
    }

    mutating func normalizeEntries() {
        entries = entries.map { entry in
            var normalized = entry
            if normalized.spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let split = Self.splitWordID(normalized.id)
                normalized.spelling = split.spelling
            }
            if normalized.meaningKey == nil {
                normalized.meaningKey = Self.splitWordID(normalized.id).meaningKey
            }
            normalized.id = Self.makeWordID(spelling: normalized.spelling, meaningKey: normalized.meaningKey)
            return normalized
        }
    }
}

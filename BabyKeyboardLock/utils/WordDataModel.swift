import Foundation

// Canonical vocabulary model for app data (words, meaning IDs, annotations, assets).
// Runtime components can map this to legacy view models while migration is in progress.

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
        if var canonical = try? decoder.decode(WordDataCatalog.self, from: data) {
            canonical.normalizeEntries()
            return canonical
        }
        return try decodeLegacy(from: data, decoder: decoder)
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

    private static func decodeLegacy(from data: Data, decoder: JSONDecoder) throws -> WordDataCatalog {
        let legacy = try decoder.decode(LegacyWordCatalog.self, from: data)
        var translationVariants: [String: Set<String>] = [:]

        for legacySet in legacy.sets {
            for legacyWord in legacySet.words {
                let spelling = normalize(spelling: legacyWord.english)
                let translation = normalize(meaningKey: legacyWord.translation)
                guard !spelling.isEmpty, !translation.isEmpty else { continue }
                translationVariants[spelling, default: Set<String>()].insert(translation)
            }
        }

        var entriesByID: [String: WordDataEntry] = [:]
        var orderedEntryIDs: [String] = []
        var sets: [WordDataSet] = []

        for (setIndex, legacySet) in legacy.sets.enumerated() {
            let setID = "set-\(slug(legacySet.name))-\(setIndex)"
            var wordIDs: [String] = []

            for legacyWord in legacySet.words {
                let spellingRaw = legacyWord.english.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !spellingRaw.isEmpty else { continue }

                let spelling = normalize(spelling: spellingRaw)
                let translationRaw = legacyWord.translation.trimmingCharacters(in: .whitespacesAndNewlines)
                let translation = normalize(meaningKey: translationRaw)
                let hasAmbiguousMeaning = (translationVariants[spelling]?.count ?? 0) > 1
                let meaningKey = hasAmbiguousMeaning ? (translation.isEmpty ? "meaning" : translation) : nil
                let wordID = makeWordID(spelling: spellingRaw, meaningKey: meaningKey)
                wordIDs.append(wordID)

                if entriesByID[wordID] == nil {
                    let translations: [WordDataTranslation] = translationRaw.isEmpty
                        ? []
                        : [WordDataTranslation(language: "ru", text: translationRaw)]
                    entriesByID[wordID] = WordDataEntry(
                        id: wordID,
                        spelling: spellingRaw,
                        meaningKey: meaningKey,
                        partOfSpeech: nil,
                        category: nil,
                        tags: [],
                        translations: translations,
                        definitions: [],
                        assets: []
                    )
                    orderedEntryIDs.append(wordID)
                }
            }

            sets.append(WordDataSet(id: setID, name: legacySet.name, wordIDs: wordIDs))
        }

        let entries = orderedEntryIDs.compactMap { entriesByID[$0] }
        return WordDataCatalog(
            version: max(legacy.version ?? 1, 2),
            source: legacy.source,
            entries: entries,
            sets: sets
        )
    }

    private static func normalize(spelling: String) -> String {
        spelling.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalize(meaningKey: String) -> String {
        let lowered = meaningKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.isEmpty {
            return ""
        }
        let allowed = CharacterSet.alphanumerics
        var result = ""
        var previousWasSeparator = false
        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func slug(_ value: String) -> String {
        let normalized = normalize(meaningKey: value)
        return normalized.isEmpty ? "set" : normalized
    }
}

private struct LegacyWordCatalog: Codable {
    var version: Int?
    var source: String?
    var sets: [LegacyWordSet]
}

private struct LegacyWordSet: Codable {
    var name: String
    var words: [LegacyWord]
}

private struct LegacyWord: Codable {
    var english: String
    var translation: String
}

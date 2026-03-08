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

    enum CodingKeys: String, CodingKey {
        case language
        case text
        case lang
        case value
    }

    init(language: String, text: String) {
        self.language = language
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = (
            try container.decodeIfPresent(String.self, forKey: .language)
                ?? container.decodeIfPresent(String.self, forKey: .lang)
                ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        text = (
            try container.decodeIfPresent(String.self, forKey: .text)
                ?? container.decodeIfPresent(String.self, forKey: .value)
                ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(text, forKey: .text)
    }
}

struct WordDataDefinition: Codable, Hashable {
    var language: String
    var text: String
    var source: String?

    enum CodingKeys: String, CodingKey {
        case language
        case text
        case source
        case lang
        case value
    }

    init(language: String, text: String, source: String? = nil) {
        self.language = language
        self.text = text
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = (
            try container.decodeIfPresent(String.self, forKey: .language)
                ?? container.decodeIfPresent(String.self, forKey: .lang)
                ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        text = (
            try container.decodeIfPresent(String.self, forKey: .text)
                ?? container.decodeIfPresent(String.self, forKey: .value)
                ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(source, forKey: .source)
    }
}

struct WordDataAsset: Codable, Hashable {
    var kind: WordDataAssetKind
    var language: String?
    var uri: String
    var rotationDegrees: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case language
        case uri
        case rotationDegrees
        case rotation_degrees
    }

    init(kind: WordDataAssetKind, language: String?, uri: String, rotationDegrees: Int? = nil) {
        self.kind = kind
        self.language = language
        self.uri = uri
        self.rotationDegrees = rotationDegrees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawKind = try container.decodeIfPresent(String.self, forKey: .kind)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           let decodedKind = WordDataAssetKind(rawValue: rawKind) {
            kind = decodedKind
        } else {
            kind = .image
        }
        language = try container.decodeIfPresent(String.self, forKey: .language)
        uri = (try container.decodeIfPresent(String.self, forKey: .uri) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        rotationDegrees = try container.decodeIfPresent(Int.self, forKey: .rotationDegrees)
            ?? container.decodeIfPresent(Int.self, forKey: .rotation_degrees)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(uri, forKey: .uri)
        try container.encodeIfPresent(rotationDegrees, forKey: .rotationDegrees)
    }
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

    enum CodingKeys: String, CodingKey {
        case id
        case spelling
        case meaningKey
        case partOfSpeech
        case category
        case tags
        case translations
        case definitions
        case assets
        case word
        case meaning_key
        case part_of_speech
    }

    init(
        id: String,
        spelling: String,
        meaningKey: String?,
        partOfSpeech: WordDataPartOfSpeech?,
        category: WordDataCategory?,
        tags: [String],
        translations: [WordDataTranslation],
        definitions: [WordDataDefinition],
        assets: [WordDataAsset]
    ) {
        self.id = id
        self.spelling = spelling
        self.meaningKey = meaningKey
        self.partOfSpeech = partOfSpeech
        self.category = category
        self.tags = tags
        self.translations = translations
        self.definitions = definitions
        self.assets = assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTranslations = try container.decodeIfPresent([WordDataTranslation].self, forKey: .translations) ?? []
        let translationSpellingFallback = decodedTranslations
            .first(where: {
                $0.language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("en")
                    && !$0.text.isEmpty
            })?
            .text

        let rawID = (try container.decodeIfPresent(String.self, forKey: .id) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let split = WordDataCatalog.splitWordID(rawID)

        let rawSpelling = (
            try container.decodeIfPresent(String.self, forKey: .spelling)
                ?? container.decodeIfPresent(String.self, forKey: .word)
                ?? translationSpellingFallback
                ?? split.spelling
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let decodedMeaningKey = (
            try container.decodeIfPresent(String.self, forKey: .meaningKey)
                ?? container.decodeIfPresent(String.self, forKey: .meaning_key)
                ?? split.meaningKey
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        spelling = rawSpelling.isEmpty ? split.spelling : rawSpelling
        meaningKey = decodedMeaningKey?.isEmpty == true ? nil : decodedMeaningKey
        id = rawID.isEmpty
            ? WordDataCatalog.makeWordID(spelling: spelling, meaningKey: meaningKey)
            : rawID

        let partRaw = (
            try container.decodeIfPresent(String.self, forKey: .partOfSpeech)
                ?? container.decodeIfPresent(String.self, forKey: .part_of_speech)
        )?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        partOfSpeech = partRaw.flatMap { WordDataPartOfSpeech(rawValue: $0) } ?? (partRaw == nil ? nil : .other)

        let categoryRaw = try container.decodeIfPresent(String.self, forKey: .category)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        category = categoryRaw.flatMap { WordDataCategory(rawValue: $0) } ?? (categoryRaw == nil ? nil : .other)

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        translations = decodedTranslations
        definitions = try container.decodeIfPresent([WordDataDefinition].self, forKey: .definitions) ?? []
        assets = try container.decodeIfPresent([WordDataAsset].self, forKey: .assets) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(meaningKey, forKey: .meaningKey)
        try container.encodeIfPresent(partOfSpeech, forKey: .partOfSpeech)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(translations, forKey: .translations)
        try container.encode(definitions, forKey: .definitions)
        try container.encode(assets, forKey: .assets)
    }

    func translation(language: String) -> String? {
        translations.first(where: { $0.language.lowercased() == language.lowercased() })?.text
    }
}

struct WordDataSet: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var wordIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case wordIDs
        case wordIds
        case word_ids
    }

    init(id: String, name: String, wordIDs: [String]) {
        self.id = id
        self.name = name
        self.wordIDs = wordIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try container.decodeIfPresent(String.self, forKey: .id) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = (try container.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        wordIDs = try container.decodeIfPresent([String].self, forKey: .wordIDs)
            ?? container.decodeIfPresent([String].self, forKey: .wordIds)
            ?? container.decodeIfPresent([String].self, forKey: .word_ids)
            ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wordIDs, forKey: .wordIDs)
    }
}

struct WordDataCatalog: Codable {
    var version: Int
    var source: String?
    var entries: [WordDataEntry]
    var sets: [WordDataSet]

    enum CodingKeys: String, CodingKey {
        case version
        case source
        case entries
        case sets
        case words
        case wordSets
    }

    init(version: Int, source: String?, entries: [WordDataEntry], sets: [WordDataSet]) {
        self.version = version
        self.source = source
        self.entries = entries
        self.sets = sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
        source = try container.decodeIfPresent(String.self, forKey: .source)
        entries = try container.decodeIfPresent([WordDataEntry].self, forKey: .entries)
            ?? container.decodeIfPresent([WordDataEntry].self, forKey: .words)
            ?? []
        sets = try container.decodeIfPresent([WordDataSet].self, forKey: .sets)
            ?? container.decodeIfPresent([WordDataSet].self, forKey: .wordSets)
            ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(entries, forKey: .entries)
        try container.encode(sets, forKey: .sets)
    }
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
            let split = Self.splitWordID(normalized.id)

            let englishCanonical = normalized.translations.first(where: {
                $0.language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("en")
                    && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })?.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if let englishCanonical, !englishCanonical.isEmpty {
                normalized.spelling = englishCanonical
            } else if normalized.spelling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.spelling = split.spelling.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if normalized.meaningKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                normalized.meaningKey = split.meaningKey
            }

            let idSpelling = split.spelling.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonicalSpellingForID = idSpelling.isEmpty ? normalized.spelling : idSpelling
            let canonicalMeaningForID = split.meaningKey ?? normalized.meaningKey
            normalized.id = Self.makeWordID(spelling: canonicalSpellingForID, meaningKey: canonicalMeaningForID)
            return normalized
        }
    }
}

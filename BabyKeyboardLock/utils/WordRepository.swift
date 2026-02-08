import Foundation

final class WordRepository {
    static let shared = WordRepository()

    private var catalog: WordDataCatalog?
    private var entriesByID: [String: WordDataEntry] = [:]
    private var entriesBySpelling: [String: [WordDataEntry]] = [:]

    private init() {
        reloadBundledCatalog()
    }

    func reloadBundledCatalog() {
        guard let url = bundledCatalogURL() else {
            catalog = nil
            entriesByID = [:]
            entriesBySpelling = [:]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try WordDataCatalog.decode(from: data)
            setCatalog(decoded)
        } catch {
            debugPrint("Failed to load bundled catalog: \(error)")
            catalog = nil
            entriesByID = [:]
            entriesBySpelling = [:]
        }
    }

    func randomWordSets(defaultTranslationLanguageCode: String = "ru") -> [RandomWordSet] {
        guard let catalog = catalog else {
            return []
        }

        var mapped: [RandomWordSet] = []
        for set in catalog.sets {
            let words: [RandomWord] = set.wordIDs.compactMap { wordID in
                guard let entry = entriesByID[wordID] else { return nil }
                let translation = translation(
                    for: entry,
                    languageCandidates: normalizedLanguageCandidates(defaultTranslationLanguageCode)
                ) ?? entry.translations.first?.text ?? entry.spelling
                let clarification = (entry.meaningKey ?? "").isEmpty ? nil : entry.meaningKey
                return RandomWord(
                    english: entry.spelling,
                    translation: translation,
                    clarification: clarification
                )
            }
            if !words.isEmpty {
                mapped.append(RandomWordSet(name: set.name, words: words))
            }
        }
        return mapped
    }

    func translation(english: String, meaningKey: String?, languageCode: String) -> String? {
        let candidates = normalizedLanguageCandidates(languageCode)
        if candidates.isEmpty {
            return nil
        }

        if let meaningKey = meaningKey?.trimmingCharacters(in: .whitespacesAndNewlines), !meaningKey.isEmpty {
            let wordID = WordDataCatalog.makeWordID(spelling: english, meaningKey: meaningKey)
            if let entry = entriesByID[wordID],
               let value = translation(for: entry, languageCandidates: candidates) {
                return value
            }
        }

        let spellingKey = english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let list = entriesBySpelling[spellingKey] else {
            return nil
        }
        for entry in list {
            if let value = translation(for: entry, languageCandidates: candidates) {
                return value
            }
        }
        return nil
    }

    func entry(english: String, meaningKey: String?) -> WordDataEntry? {
        if let meaningKey = meaningKey?.trimmingCharacters(in: .whitespacesAndNewlines), !meaningKey.isEmpty {
            let wordID = WordDataCatalog.makeWordID(spelling: english, meaningKey: meaningKey)
            if let byID = entriesByID[wordID] {
                return byID
            }
        }

        let spellingKey = english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entriesBySpelling[spellingKey]?.first
    }

    private func setCatalog(_ catalog: WordDataCatalog) {
        self.catalog = catalog
        entriesByID = Dictionary(uniqueKeysWithValues: catalog.entries.map { ($0.id, $0) })
        var grouped: [String: [WordDataEntry]] = [:]
        for entry in catalog.entries {
            let key = entry.spelling.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            grouped[key, default: []].append(entry)
        }
        entriesBySpelling = grouped
    }

    private func bundledCatalogURL() -> URL? {
        Bundle.main.url(forResource: "word_sets", withExtension: "json", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "word_sets", withExtension: "json")
    }

    private func normalizedLanguageCandidates(_ languageCode: String) -> [String] {
        let normalized = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return []
        }
        let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if base == normalized {
            return [normalized]
        }
        return [normalized, base]
    }

    private func translation(for entry: WordDataEntry, languageCandidates: [String]) -> String? {
        for candidate in languageCandidates {
            if let exact = entry.translations.first(where: { $0.language.lowercased() == candidate }),
               !exact.text.isEmpty {
                return exact.text
            }
        }
        for candidate in languageCandidates {
            if let prefix = entry.translations.first(where: { translation in
                let lower = translation.language.lowercased()
                return lower.hasPrefix(candidate + "-")
            }), !prefix.text.isEmpty {
                return prefix.text
            }
        }
        return nil
    }
}

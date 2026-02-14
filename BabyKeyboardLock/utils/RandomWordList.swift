import Foundation
import Combine
import AppKit

struct RandomWord: Codable, Hashable, Identifiable {
    let id: String
    let english: String
    let translation: String
    let clarification: String?

    init(english: String, translation: String, clarification: String? = nil) {
        let normalizedClarification: String?
        if let clarification,
           !clarification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedClarification = clarification
        } else {
            normalizedClarification = nil
        }
        self.id = WordDataCatalog.makeWordID(spelling: english, meaningKey: normalizedClarification)
        self.english = english
        self.translation = translation
        self.clarification = normalizedClarification
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case english
        case translation
        case clarification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        english = try container.decode(String.self, forKey: .english)
        translation = try container.decode(String.self, forKey: .translation)
        clarification = try container.decodeIfPresent(String.self, forKey: .clarification)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? WordDataCatalog.makeWordID(spelling: english, meaningKey: clarification)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(english, forKey: .english)
        try container.encode(translation, forKey: .translation)
        try container.encodeIfPresent(clarification, forKey: .clarification)
    }
}

struct CustomWordImage: Codable, Hashable, Identifiable {
    var id = UUID()
    let word: String  // The word this image is for
    var imagePaths: [String]  // Paths to custom images
    var imageRotations: [Int]  // Degrees for each image path (0/90/180/270)

    init(word: String, imagePaths: [String], imageRotations: [Int]? = nil) {
        self.word = word
        self.imagePaths = imagePaths
        self.imageRotations = imageRotations ?? Array(repeating: 0, count: imagePaths.count)
    }

    init(word: String, imagePath: String) {
        self.word = word
        self.imagePaths = [imagePath]
        self.imageRotations = [0]
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case word
        case imagePaths
        case imagePath
        case imageRotations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        word = try container.decode(String.self, forKey: .word)
        if let paths = try container.decodeIfPresent([String].self, forKey: .imagePaths) {
            imagePaths = paths
        } else if let path = try container.decodeIfPresent(String.self, forKey: .imagePath) {
            imagePaths = [path]
        } else {
            imagePaths = []
        }
        imageRotations = (try? container.decode([Int].self, forKey: .imageRotations)) ?? []
        if imageRotations.count < imagePaths.count {
            imageRotations.append(contentsOf: Array(repeating: 0, count: imagePaths.count - imageRotations.count))
        } else if imageRotations.count > imagePaths.count {
            imageRotations = Array(imageRotations.prefix(imagePaths.count))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(word, forKey: .word)
        try container.encode(imagePaths, forKey: .imagePaths)
        try container.encode(imageRotations, forKey: .imageRotations)
    }
}

struct CustomImageSelection {
    let url: URL
    let rotationDegrees: Double
}

struct RandomWordSet: Codable, Hashable, Identifiable {
    var id = UUID()
    let name: String
    let words: [RandomWord]

    init(name: String, words: [RandomWord]) {
        self.id = UUID()
        self.name = name
        self.words = words
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case words
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        words = try container.decode([RandomWord].self, forKey: .words)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(words, forKey: .words)
    }
}

struct LearningWord: Hashable, Identifiable {
    var id: String
    var word: String
    var clarification: String
    var translation: String
    var tags: [String]
    var known: Bool
    var favorite: Bool
    var seenCount: Int
    var lastSeen: Date?
}

class RandomWordList: ObservableObject {
    static let shared = RandomWordList()

    private let enabledSetsKey = "enabledRandomWordSets"
    private let babyNameKey = "babyName"
    private let babyNameTranslationKey = "babyNameTranslation"
    private let babyNameProbabilityKey = "babyNameProbability"
    private let babyImagePathKey = "babyImagePath"
    private let babyImageBookmarkKey = "babyImageBookmark"
    private let customWordImagesKey = "customWordImages"
    private let customWordImageBookmarksKey = "customWordImageBookmarks"
    private let customImagesFolderPathKey = "customImagesFolderPath"
    private let customImagesFolderBookmarkKey = "customImagesFolderBookmark"
    private let learningRotationEnabledKey = "learningRotationEnabled"
    private let learningKnownRatioKey = "learningKnownRatio"
    private let learningFavoriteRatioKey = "learningFavoriteRatio"
    private let learningTagRatiosKey = "learningTagRatios"
    private let learningLastSyncKey = "learningLastSync"
    private let learningPoolSizeKey = "learningPoolSize"
    private let learningPoolKeysKey = "learningPoolKeys"

    @Published var wordSets: [RandomWordSet] = []
    @Published var enabledSetIndices: Set<Int> = []
    private(set) var babyName: String = ""
    private(set) var babyNameTranslation: String = ""
    @Published var babyNameProbability: Double = 0.125 // Default 12.5% (1 in 8)
    @Published var babyImagePath: String = ""
    private var babyImageBookmark: Data?
    @Published var customWordImages: [CustomWordImage] = []
    private var customWordImageBookmarks: [String: [Data]] = [:] // word -> bookmark data
    @Published private(set) var customImagesFolderPath: String = ""
    private var customImagesFolderBookmark: Data?
    private var customImageQueues: [String: [Int]] = [:]
    private var babyNameRngAccumulator: Double = 0.0
    private var recentWordHistory: [String] = []
    private var learningWords: [String: LearningWord] = [:]
    private var learningPoolKeys: [String] = []
    private var lastSelectedRandomWord: RandomWord?
    private let wordCatalogStore = WordCatalogStore()
    private let learningStateStore = LearningStateStore()
    private let favoriteWords: Set<String> = [
        "mama", "papa", "mom", "dad",
        "grandma", "grandpa",
        "grandgrandma", "grandgrandpa", "uncle", "aunt"
    ]
    private let learningTags: [String] = ["basic", "cool", "action", "family"]

    @Published var learningRotationEnabled: Bool = false
    @Published var learningKnownRatio: Double = 0.5
    @Published var learningFavoriteRatio: Double = 0.2
    @Published var learningTagRatios: [String: Double] = [:]
    @Published var learningPoolSize: Int = 25
    @Published private(set) var learningLastSync: Date? = nil

    var words: [RandomWord] {
        var allWords: [RandomWord] = []
        for index in enabledSetIndices.sorted() {
            guard index < wordSets.count else { continue }
            allWords.append(contentsOf: wordSets[index].words)
        }
        return allWords
    }

    var enabledWordSetNames: String {
        let names = enabledSetIndices.sorted().compactMap { (index: Int) -> String? in
            guard index < wordSets.count else { return nil }
            return wordSets[index].name
        }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    func isSetEnabled(at index: Int) -> Bool {
        enabledSetIndices.contains(index)
    }

    func toggleSet(at index: Int) {
        if enabledSetIndices.contains(index) {
            enabledSetIndices.remove(index)
        } else {
            enabledSetIndices.insert(index)
        }
        saveEnabledSets()
        syncLearningWordsIfNeeded(force: true)
        objectWillChange.send()
        NotificationCenter.default.post(name: .init("RandomWordSetChanged"), object: nil)
    }

    init() {
        purgeLegacyWordStorageKeys()
        loadCatalogAndWordSets()
        loadBabyName()
        loadBabyNameTranslation()
        loadBabyNameProbability()
        loadBabyImagePath()
        loadCustomWordImages()
        loadCustomImagesFolder()
        loadEnabledSets()
        loadLearningSettings()
        loadLearningLastSync()
        loadLearningWords()
        loadLearningPoolKeys()
        syncCustomImagesFromFolder()
        ensureEnabledSetDefaultsIfNeeded()
    }

    private func purgeLegacyWordStorageKeys() {
        UserDefaults.standard.removeObject(forKey: "randomWordSets")
        UserDefaults.standard.removeObject(forKey: "randomWords")
        UserDefaults.standard.removeObject(forKey: "selectedRandomWordSetIndex")
    }

    private func createDefaultWordSets() -> [RandomWordSet] {
        loadBundledWordSets()
    }

    private func loadCatalogAndWordSets() {
        var didNormalizeCatalog = false
        if let localCatalog = wordCatalogStore.loadCatalog() {
            var normalized = localCatalog
            didNormalizeCatalog = normalizeFamilyWordAliases(in: &normalized)
            WordRepository.shared.replaceCatalog(normalized)
            if didNormalizeCatalog {
                _ = wordCatalogStore.saveCatalog(normalized)
            }
        } else {
            WordRepository.shared.reloadBundledCatalog()
            if var bundledCatalog = WordRepository.shared.catalogSnapshot() {
                didNormalizeCatalog = normalizeFamilyWordAliases(in: &bundledCatalog)
                WordRepository.shared.replaceCatalog(bundledCatalog)
            }
        }
        wordSets = createDefaultWordSets()
    }

    private func normalizeFamilyWordAliases(in catalog: inout WordDataCatalog) -> Bool {
        let granddadID = WordDataCatalog.makeWordID(spelling: "granddad", meaningKey: nil)
        let grandpaID = WordDataCatalog.makeWordID(spelling: "grandpa", meaningKey: nil)
        var changed = false

        let originalEntryCount = catalog.entries.count
        catalog.entries.removeAll { entry in
            let normalizedSpelling = entry.spelling.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return entry.id == granddadID || normalizedSpelling == "granddad"
        }
        if catalog.entries.count != originalEntryCount {
            changed = true
        }

        for index in catalog.sets.indices {
            let original = catalog.sets[index].wordIDs
            var mapped: [String] = []
            mapped.reserveCapacity(original.count)
            for wordID in original {
                let nextID = wordID == granddadID ? grandpaID : wordID
                if !mapped.contains(nextID) {
                    mapped.append(nextID)
                }
            }
            if mapped != original {
                catalog.sets[index].wordIDs = mapped
                changed = true
            }
            if catalog.sets[index].name == "Family (12 words)" {
                catalog.sets[index].name = "Family (11 words)"
                changed = true
            }
        }

        return changed
    }

    private func ensureEnabledSetDefaultsIfNeeded() {
        if wordSets.isEmpty {
            wordSets = createDefaultWordSets()
        }
        if enabledSetIndices.isEmpty, !wordSets.isEmpty {
            enabledSetIndices = [0]
            saveEnabledSets()
        }
    }

    private func loadBundledWordSets() -> [RandomWordSet] {
        let sets = WordRepository.shared.randomWordSets(defaultTranslationLanguageCode: "ru")
        return sets
    }

    private func persistCatalogFromWordSets() {
        var catalog = WordRepository.shared.catalogSnapshot()
            ?? WordDataCatalog(version: 2, source: "user", entries: [], sets: [])
        var entriesByID = Dictionary(uniqueKeysWithValues: catalog.entries.map { ($0.id, $0) })
        var updatedSets: [WordDataSet] = []

        for (index, set) in wordSets.enumerated() {
            var wordIDs: [String] = []
            wordIDs.reserveCapacity(set.words.count)
            for word in set.words {
                let meaningKey = normalizedMeaningKey(word.clarification)
                let wordID = WordDataCatalog.makeWordID(spelling: word.english, meaningKey: meaningKey)
                wordIDs.append(wordID)

                var entry = entriesByID[wordID]
                    ?? WordDataEntry(
                        id: wordID,
                        spelling: word.english,
                        meaningKey: meaningKey,
                        partOfSpeech: nil,
                        category: nil,
                        tags: defaultTags(for: set.name),
                        translations: [],
                        definitions: [],
                        assets: []
                    )

                entry.id = wordID
                entry.spelling = word.english.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.meaningKey = meaningKey
                mergeTranslation(text: word.translation, into: &entry)
                entriesByID[wordID] = entry
            }

            updatedSets.append(
                WordDataSet(
                    id: makeWordSetID(name: set.name, index: index),
                    name: set.name,
                    wordIDs: wordIDs
                )
            )
        }

        catalog.version = max(2, catalog.version)
        catalog.source = "user"
        catalog.entries = Array(entriesByID.values).sorted { $0.id < $1.id }
        catalog.sets = updatedSets
        catalog.normalizeEntries()
        WordRepository.shared.replaceCatalog(catalog)
        _ = wordCatalogStore.saveCatalog(catalog)
    }

    private func normalizedMeaningKey(_ clarification: String?) -> String? {
        guard let clarification else { return nil }
        let trimmed = clarification.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mergeTranslation(text: String, into entry: inout WordDataEntry) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = entry.translations.firstIndex(where: { $0.language.lowercased() == "ru" }) {
            entry.translations[index].text = trimmed
            return
        }

        if entry.translations.isEmpty {
            entry.translations = [WordDataTranslation(language: "ru", text: trimmed)]
            return
        }

        if let firstIndex = entry.translations.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            entry.translations[firstIndex] = WordDataTranslation(language: "ru", text: trimmed)
            return
        }

        entry.translations.append(WordDataTranslation(language: "ru", text: trimmed))
    }

    private func makeWordSetID(name: String, index: Int) -> String {
        let normalized = String(name.lowercased().map { character in
            character.isLetter || character.isNumber ? character : "-"
        })
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if normalized.isEmpty {
            return "set-\(index)"
        }
        return "\(normalized)-\(index)"
    }
    
    func getRandomWord(useLearningRotation: Bool = true) -> RandomWord? {
        refreshLearningPoolIfStale()

        if useLearningRotation && learningRotationEnabled {
            if let learningWord = getLearningRandomWord() {
                return learningWord
            }
        }
        // If baby name is set, include it in the random selection based on configured probability
        if shouldPickBabyName() {
            let translation = babyNameTranslation.isEmpty ? babyName : babyNameTranslation
            let word = RandomWord(english: babyName, translation: translation)
            lastSelectedRandomWord = word
            return word
        }

        guard !words.isEmpty else { return nil }
        refreshRecentHistoryIfNeeded()
        if let chosen = selectWeightedWord(from: words) {
            lastSelectedRandomWord = chosen
            return chosen
        }
        return nil
    }
    
    func findWord(english: String, clarification: String? = nil) -> RandomWord? {
        if english.lowercased() == babyName.lowercased() {
            let translation = babyNameTranslation.isEmpty ? babyName : babyNameTranslation
            return RandomWord(english: babyName, translation: translation)
        }
        if let clarification = clarification, !clarification.isEmpty {
            return words.first {
                $0.english.lowercased() == english.lowercased() &&
                ($0.clarification ?? "").lowercased() == clarification.lowercased()
            }
        }
        return words.first { $0.english.lowercased() == english.lowercased() }
    }
    
    func updateWordSet(at index: Int, newWords: [RandomWord]) {
        guard index >= 0 && index < wordSets.count else { return }
        let currentSetName = wordSets[index].name
        wordSets[index] = RandomWordSet(name: currentSetName, words: newWords)
        persistCatalogFromWordSets()
        objectWillChange.send()
        NotificationCenter.default.post(name: .init("RandomWordsUpdated"), object: nil)
    }

    func addWordSet(name: String, words: [RandomWord]) {
        let newSet = RandomWordSet(name: name, words: words)
        wordSets.append(newSet)
        persistCatalogFromWordSets()
        objectWillChange.send()
    }

    func deleteWordSet(at index: Int) {
        guard index >= 0 && index < wordSets.count else { return }
        wordSets.remove(at: index)
        // Remove from enabled sets if it was enabled
        enabledSetIndices.remove(index)
        // Adjust indices for sets that were after the deleted one
        let adjustedIndices = enabledSetIndices.compactMap { oldIndex -> Int? in
            if oldIndex > index {
                return oldIndex - 1
            } else if oldIndex == index {
                return nil
            } else {
                return oldIndex
            }
        }
        enabledSetIndices = Set(adjustedIndices)
        persistCatalogFromWordSets()
        saveEnabledSets()
        objectWillChange.send()
    }

    func renameWordSet(at index: Int, to newName: String) {
        guard index >= 0 && index < wordSets.count else { return }
        let currentWords = wordSets[index].words
        wordSets[index] = RandomWordSet(name: newName, words: currentWords)
        persistCatalogFromWordSets()
        objectWillChange.send()
    }

    func setBabyName(_ name: String) {
        babyName = name
        saveBabyName()
        NotificationCenter.default.post(name: .init("BabyNameUpdated"), object: nil)
    }

    func setBabyNameTranslation(_ translation: String) {
        babyNameTranslation = translation
        saveBabyNameTranslation()
        NotificationCenter.default.post(name: .init("BabyNameUpdated"), object: nil)
    }

    func setBabyNameProbability(_ probability: Double) {
        babyNameProbability = max(0.0, min(1.0, probability)) // Clamp between 0 and 1
        babyNameRngAccumulator = 0.0
        saveBabyNameProbability()
    }

    func setBabyImagePath(_ path: String) {
        babyImagePath = path
        saveBabyImagePath()
        NotificationCenter.default.post(name: .init("BabyImageUpdated"), object: nil)
    }

    func setBabyImageURL(_ url: URL) {
        babyImagePath = url.path

        // Create security-scoped bookmark for sandboxed access
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            babyImageBookmark = bookmarkData
            UserDefaults.standard.set(bookmarkData, forKey: babyImageBookmarkKey)
        } catch {
            debugPrint("Failed to create bookmark for baby image: \(error)")
            babyImageBookmark = nil
        }

        saveBabyImagePath()
        NotificationCenter.default.post(name: .init("BabyImageUpdated"), object: nil)
    }

    func getBabyImageURL() -> URL? {
        // Try to resolve from security-scoped bookmark first
        if let bookmarkData = babyImageBookmark {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    debugPrint("Baby image bookmark is stale, recreating...")
                    // Try to recreate the bookmark
                    if let newBookmarkData = try? url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        babyImageBookmark = newBookmarkData
                        UserDefaults.standard.set(newBookmarkData, forKey: babyImageBookmarkKey)
                    }
                }

                return url
            } catch {
                debugPrint("Failed to resolve baby image bookmark: \(error)")
            }
        }

        // Fallback to path-based access (for non-sandboxed or development)
        if !babyImagePath.isEmpty {
            return URL(fileURLWithPath: babyImagePath)
        }

        return nil
    }

    func resetToDefaults() {
        wordCatalogStore.clearCatalog()
        WordRepository.shared.reloadBundledCatalog()
        wordSets = createDefaultWordSets()
        enabledSetIndices = wordSets.isEmpty ? [] : [0]
        saveEnabledSets()
        objectWillChange.send()
        NotificationCenter.default.post(name: .init("RandomWordSetChanged"), object: nil)
    }

    private func saveEnabledSets() {
        let array = Array(enabledSetIndices)
        if let encoded = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(encoded, forKey: enabledSetsKey)
        }
    }

    private func loadEnabledSets() {
        if let savedData = UserDefaults.standard.data(forKey: enabledSetsKey),
           let decodedArray = try? JSONDecoder().decode([Int].self, from: savedData) {
            enabledSetIndices = Set(decodedArray)
            return
        }
        if !wordSets.isEmpty {
            enabledSetIndices = [0]
            saveEnabledSets()
        }
    }

    private func saveBabyName() {
        UserDefaults.standard.set(babyName, forKey: babyNameKey)
    }

    private func loadBabyName() {
        babyName = UserDefaults.standard.string(forKey: babyNameKey) ?? ""
    }

    private func saveBabyNameTranslation() {
        UserDefaults.standard.set(babyNameTranslation, forKey: babyNameTranslationKey)
    }

    private func loadBabyNameTranslation() {
        babyNameTranslation = UserDefaults.standard.string(forKey: babyNameTranslationKey) ?? ""
    }

    private func saveBabyNameProbability() {
        UserDefaults.standard.set(babyNameProbability, forKey: babyNameProbabilityKey)
    }

    private func loadBabyNameProbability() {
        let savedProbability = UserDefaults.standard.double(forKey: babyNameProbabilityKey)
        // If no value is saved (returns 0), use default
        if savedProbability == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains(babyNameProbabilityKey) {
            babyNameProbability = 0.125 // Default 12.5%
        } else {
            babyNameProbability = savedProbability
        }
    }

    private func saveBabyImagePath() {
        UserDefaults.standard.set(babyImagePath, forKey: babyImagePathKey)
    }

    private func loadBabyImagePath() {
        babyImagePath = UserDefaults.standard.string(forKey: babyImagePathKey) ?? ""
        babyImageBookmark = UserDefaults.standard.data(forKey: babyImageBookmarkKey)
    }

    private func loadLearningSettings() {
        learningRotationEnabled = UserDefaults.standard.bool(forKey: learningRotationEnabledKey)
        if let stored = UserDefaults.standard.object(forKey: learningKnownRatioKey) as? Double {
            learningKnownRatio = stored
        }
        if let stored = UserDefaults.standard.object(forKey: learningFavoriteRatioKey) as? Double {
            learningFavoriteRatio = stored
        }
        if let data = UserDefaults.standard.data(forKey: learningTagRatiosKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            learningTagRatios = decoded
        }
        if learningTagRatios.isEmpty {
            let defaultValue = 1.0 / Double(max(1, learningTags.count))
            learningTagRatios = Dictionary(uniqueKeysWithValues: learningTags.map { ($0, defaultValue) })
        }
        let storedPoolSize = UserDefaults.standard.integer(forKey: learningPoolSizeKey)
        if storedPoolSize > 0 {
            learningPoolSize = storedPoolSize
        }
    }

    private func loadLearningLastSync() {
        if let stored = UserDefaults.standard.object(forKey: learningLastSyncKey) as? Double {
            learningLastSync = Date(timeIntervalSince1970: stored)
        }
    }

    private func saveLearningLastSync(_ date: Date) {
        learningLastSync = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: learningLastSyncKey)
    }

    func setLearningRotationEnabled(_ enabled: Bool) {
        learningRotationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: learningRotationEnabledKey)
    }

    func setLearningKnownRatio(_ value: Double) {
        learningKnownRatio = min(1.0, max(0.0, value))
        UserDefaults.standard.set(learningKnownRatio, forKey: learningKnownRatioKey)
    }

    func setLearningFavoriteRatio(_ value: Double) {
        learningFavoriteRatio = min(1.0, max(0.0, value))
        UserDefaults.standard.set(learningFavoriteRatio, forKey: learningFavoriteRatioKey)
    }

    func setLearningTagRatio(tag: String, value: Double) {
        learningTagRatios[tag] = min(1.0, max(0.0, value))
        if let encoded = try? JSONEncoder().encode(learningTagRatios) {
            UserDefaults.standard.set(encoded, forKey: learningTagRatiosKey)
        }
    }

    func setLearningPoolSize(_ value: Int) {
        let clamped = min(200, max(5, value))
        learningPoolSize = clamped
        UserDefaults.standard.set(clamped, forKey: learningPoolSizeKey)
        refreshLearningPool(force: true)
    }

    func getLearningTags() -> [String] {
        learningTags
    }

    func openLearningDatabase() {
        if learningWords.isEmpty {
            syncLearningWordsIfNeeded(force: true)
        }
        saveLearningWords()
        guard let url = learningStateStore.databaseFileURL() else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func getLearningWordList() -> [LearningWord] {
        syncLearningWordsIfNeeded()
        return learningWords.values.sorted { $0.word < $1.word }
    }

    func updateLearningWord(_ word: LearningWord) {
        let newId = wordKey(word: word.word, clarification: word.clarification)
        var updated = word
        updated.id = newId
        if newId != word.id {
            learningWords.removeValue(forKey: word.id)
        }
        learningWords[newId] = updated
        saveLearningWords()
    }

    func getLearningWordId(for word: LearningWord) -> String {
        wordKey(word: word.word, clarification: word.clarification)
    }

    func getLastSelectedRandomWord() -> RandomWord? {
        lastSelectedRandomWord
    }

    private func wordKey(word: String, clarification: String?) -> String {
        WordDataCatalog.makeWordID(spelling: word, meaningKey: clarification)
    }

    private func splitWordKey(_ key: String) -> (String, String) {
        let split = WordDataCatalog.splitWordID(key)
        return (split.spelling, split.meaningKey ?? "")
    }

    private func loadLearningWords() {
        if let dbWords = learningStateStore.loadLearningWords(), !dbWords.isEmpty {
            var loaded: [String: LearningWord] = [:]
            for word in dbWords {
                loaded[word.id] = word
            }
            learningWords = loaded
            syncLearningWordsIfNeeded(force: true)
            return
        }
        seedLearningWordsIfNeeded()
    }

    private func saveLearningWords() {
        let words = Array(learningWords.values).sorted { $0.word < $1.word }
        learningStateStore.saveLearningWords(words)
    }

    private func seedLearningWordsIfNeeded() {
        if !learningWords.isEmpty {
            return
        }
        syncLearningWordsIfNeeded(force: true)
    }

    private func syncLearningWordsIfNeeded(force: Bool = false) {
        if force || learningWords.isEmpty || shouldSyncLearningWords() {
            syncLearningWordsWithCurrentWords()
            saveLearningWords()
            saveLearningLastSync(Date())
            rebuildLearningPoolIfNeeded(force: true)
        }
    }

    private func refreshLearningPoolIfStale() {
        if shouldSyncLearningWords() {
            syncLearningWordsIfNeeded(force: true)
        }
    }

    private func shouldSyncLearningWords() -> Bool {
        guard let lastSync = learningLastSync else { return true }
        return Date().timeIntervalSince(lastSync) >= 86_400
    }

    func refreshLearningPool(force: Bool = true) {
        syncLearningWordsIfNeeded(force: force)
        rebuildLearningPoolIfNeeded(force: force)
    }

    func getLearningPoolInfo() -> (count: Int, lastSync: Date?) {
        let poolCount = currentLearningPool().count
        return (poolCount, learningLastSync)
    }

    func getCurrentLearningPool() -> [LearningWord] {
        return currentLearningPool()
    }

    private func loadLearningPoolKeys() {
        if let data = UserDefaults.standard.data(forKey: learningPoolKeysKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            learningPoolKeys = decoded
        }
    }

    private func saveLearningPoolKeys() {
        if let encoded = try? JSONEncoder().encode(learningPoolKeys) {
            UserDefaults.standard.set(encoded, forKey: learningPoolKeysKey)
        }
    }

    private func rebuildLearningPoolIfNeeded(force: Bool = false) {
        let desiredCount = min(learningPoolSize, learningWords.count)
        let poolValid = learningPoolKeys.allSatisfy { learningWords[$0] != nil }
        if force || learningPoolKeys.count != desiredCount || !poolValid {
            buildLearningPool()
        }
    }

    private func buildLearningPool() {
        let allWords = Array(learningWords.values)
        guard !allWords.isEmpty else {
            learningPoolKeys = []
            saveLearningPoolKeys()
            return
        }
        let targetSize = min(learningPoolSize, allWords.count)
        if allWords.count <= targetSize {
            learningPoolKeys = allWords.map { $0.id }
            saveLearningPoolKeys()
            return
        }
        var rng = SystemRandomNumberGenerator()
        let shuffled = allWords.shuffled(using: &rng)
        learningPoolKeys = shuffled.prefix(targetSize).map { $0.id }
        saveLearningPoolKeys()
    }

    private func currentLearningPool() -> [LearningWord] {
        refreshLearningPoolIfStale()
        rebuildLearningPoolIfNeeded()
        return learningPoolKeys.compactMap { learningWords[$0] }
    }

    private func syncLearningWordsWithCurrentWords() {
        var updated = learningWords
        let enabledSets = enabledSetIndices.sorted().compactMap { index -> RandomWordSet? in
            guard index < wordSets.count else { return nil }
            return wordSets[index]
        }

        for set in enabledSets {
            for word in set.words {
                let repositoryEntry = WordRepository.shared.entry(
                    english: word.english,
                    meaningKey: word.clarification
                )
                let clarification = word.clarification
                    ?? repositoryEntry?.meaningKey
                    ?? defaultClarification(
                        for: word.english,
                        setName: set.name,
                        translations: [],
                        translation: word.translation
                    )
                let key = wordKey(word: word.english, clarification: clarification)
                if updated[key] == nil {
                    updated[key] = LearningWord(
                        id: key,
                        word: word.english,
                        clarification: clarification ?? "",
                        translation: word.translation,
                        tags: tagsForLearningWord(setName: set.name, repositoryEntry: repositoryEntry),
                        known: false,
                        favorite: defaultFavorite(for: key, word: word.english),
                        seenCount: 0,
                        lastSeen: nil
                    )
                }
            }
        }
        for customImage in customWordImages {
            let parts = splitWordKey(customImage.word)
            let key = wordKey(word: parts.0, clarification: parts.1)
        if updated[key] == nil {
            updated[key] = LearningWord(
                id: key,
                word: parts.0,
                clarification: parts.1,
                translation: "",
                tags: ["family"],
                known: true,
                favorite: true,
                seenCount: 0,
                lastSeen: nil
            )
        }
        }
        if !babyName.isEmpty {
            let key = wordKey(word: babyName, clarification: nil)
            if updated[key] == nil {
                let translation = babyNameTranslation.isEmpty ? babyName : babyNameTranslation
                updated[key] = LearningWord(
                    id: key,
                    word: babyName,
                    clarification: "",
                    translation: translation,
                    tags: ["family"],
                    known: true,
                    favorite: true,
                    seenCount: 0,
                    lastSeen: nil
                )
            }
        }
        learningWords = updated
    }

    private func tagsForLearningWord(setName: String, repositoryEntry: WordDataEntry?) -> [String] {
        guard let repositoryEntry = repositoryEntry else {
            return defaultTags(for: setName)
        }
        var tags = repositoryEntry.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if let category = repositoryEntry.category {
            tags.append(category.rawValue.lowercased())
        }
        let unique = Array(Set(tags))
        if unique.isEmpty {
            return defaultTags(for: setName)
        }
        return unique.sorted()
    }

    private func defaultClarification(
        for word: String,
        setName: String,
        translations: Set<String>,
        translation: String
    ) -> String? {
        let lowerSet = setName.lowercased()
        if lowerSet.contains("color") || lowerSet.contains("colour") {
            return "color"
        }
        if translations.count > 1 {
            return translation
        }
        return nil
    }

    private func defaultTags(for setName: String) -> [String] {
        let lower = setName.lowercased()
        if lower.contains("family") {
            return ["family"]
        }
        if lower.contains("action") {
            return ["action"]
        }
        return ["basic"]
    }

    private func defaultFavorite(for key: String, word: String) -> Bool {
        if favoriteWords.contains(word.lowercased()) {
            return true
        }
        if let _ = getCustomImageURL(for: word, clarification: splitWordKey(key).1) {
            return true
        }
        if word.lowercased() == babyName.lowercased(), !babyName.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Custom Word Images Management

    func setCustomWordImage(word: String, url: URL) {
        setCustomWordImage(word: word, clarification: nil, url: url)
    }

    func setCustomWordImage(word: String, clarification: String?, url: URL) {
        // Remove existing image for this word if any
        let lowercasedWord = wordKey(word: word, clarification: clarification)
        customWordImages.removeAll { $0.word.lowercased() == lowercasedWord }
        customImageQueues.removeValue(forKey: lowercasedWord)

        // Add new image
        let customImage = CustomWordImage(word: lowercasedWord, imagePath: url.path)
        customWordImages.append(customImage)

        // Create security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            customWordImageBookmarks[lowercasedWord] = [bookmarkData]
            saveCustomWordImageBookmarks()
        } catch {
            debugPrint("Failed to create bookmark for custom image: \(error)")
        }

        saveCustomWordImages()
        NotificationCenter.default.post(name: .init("CustomWordImagesUpdated"), object: nil)
        markLearningFavorite(word: word, clarification: clarification)
    }

    func addCustomWordImage(word: String, url: URL) {
        addCustomWordImage(word: word, clarification: nil, url: url)
    }

    func addCustomWordImage(word: String, clarification: String?, url: URL) {
        let lowercasedWord = wordKey(word: word, clarification: clarification)
        var didAppendPath = false
        if let index = customWordImages.firstIndex(where: { $0.word.lowercased() == lowercasedWord }) {
            if !customWordImages[index].imagePaths.contains(url.path) {
                customWordImages[index].imagePaths.append(url.path)
                if customWordImages[index].imageRotations.count < customWordImages[index].imagePaths.count - 1 {
                    normalizeCustomImageRotations(&customWordImages[index])
                }
                customWordImages[index].imageRotations.append(0)
                didAppendPath = true
            }
        } else {
            let customImage = CustomWordImage(word: lowercasedWord, imagePath: url.path)
            customWordImages.append(customImage)
            didAppendPath = true
        }

        if didAppendPath {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                var bookmarks = customWordImageBookmarks[lowercasedWord] ?? []
                bookmarks.append(bookmarkData)
                customWordImageBookmarks[lowercasedWord] = bookmarks
                saveCustomWordImageBookmarks()
            } catch {
                debugPrint("Failed to create bookmark for custom image: \(error)")
            }
        }

        customImageQueues.removeValue(forKey: lowercasedWord)
        saveCustomWordImages()
        NotificationCenter.default.post(name: .init("CustomWordImagesUpdated"), object: nil)
        markLearningFavorite(word: word, clarification: clarification)
    }

    func removeCustomWordImage(word: String) {
        removeCustomWordImage(word: word, clarification: nil)
    }

    func removeCustomWordImage(word: String, clarification: String?) {
        let lowercasedWord = wordKey(word: word, clarification: clarification)
        customWordImages.removeAll { $0.word.lowercased() == lowercasedWord }
        customWordImageBookmarks.removeValue(forKey: lowercasedWord)
        customImageQueues.removeValue(forKey: lowercasedWord)
        saveCustomWordImages()
        saveCustomWordImageBookmarks()
        NotificationCenter.default.post(name: .init("CustomWordImagesUpdated"), object: nil)
    }

    func removeCustomWordImage(word: String, imagePath: String) {
        removeCustomWordImage(word: word, clarification: nil, imagePath: imagePath)
    }

    func removeCustomWordImage(word: String, clarification: String?, imagePath: String) {
        let lowercasedWord = wordKey(word: word, clarification: clarification)
        guard let index = customWordImages.firstIndex(where: { $0.word.lowercased() == lowercasedWord }) else {
            return
        }
        if let pathIndex = customWordImages[index].imagePaths.firstIndex(of: imagePath) {
            customWordImages[index].imagePaths.remove(at: pathIndex)
            if pathIndex < customWordImages[index].imageRotations.count {
                customWordImages[index].imageRotations.remove(at: pathIndex)
            }
            if var bookmarks = customWordImageBookmarks[lowercasedWord], pathIndex < bookmarks.count {
                bookmarks.remove(at: pathIndex)
                customWordImageBookmarks[lowercasedWord] = bookmarks.isEmpty ? nil : bookmarks
            }
        }
        if customWordImages[index].imagePaths.isEmpty {
            customWordImages.remove(at: index)
            customWordImageBookmarks.removeValue(forKey: lowercasedWord)
        }
        customImageQueues.removeValue(forKey: lowercasedWord)
        saveCustomWordImages()
        saveCustomWordImageBookmarks()
        NotificationCenter.default.post(name: .init("CustomWordImagesUpdated"), object: nil)
    }

    func getCustomImageSelection(for word: String, clarification: String? = nil) -> CustomImageSelection? {
        let key = wordKey(word: word, clarification: clarification)
        let lowercasedWord = key.lowercased()
        let fallbackWord = word.lowercased()
        guard let index = customWordImages.firstIndex(where: {
            $0.word.lowercased() == lowercasedWord || $0.word.lowercased() == fallbackWord
        }) else { return nil }

        var customImage = customWordImages[index]
        if normalizeCustomImageRotations(&customImage) {
            customWordImages[index] = customImage
            saveCustomWordImages()
        }

        let paths = customImage.imagePaths
        guard !paths.isEmpty else { return nil }
        let bookmarkKey = customImage.word.lowercased()
        let imageIndex = nextCustomImageIndex(for: bookmarkKey, count: paths.count)
        let rotationDegrees = imageIndex < customImage.imageRotations.count
            ? Double(customImage.imageRotations[imageIndex])
            : 0.0

        // Try to resolve from security-scoped bookmark first
        if let bookmarkData = bookmarkDataForWord(bookmarkKey, imageIndex: imageIndex) {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    debugPrint("Custom image bookmark is stale for '\(word)', recreating...")
                    if let newBookmarkData = try? url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        setBookmarkData(newBookmarkData, word: lowercasedWord, imageIndex: imageIndex)
                        saveCustomWordImageBookmarks()
                    }
                }

                return CustomImageSelection(url: url, rotationDegrees: rotationDegrees)
            } catch {
                debugPrint("Failed to resolve custom image bookmark for '\(word)': \(error)")
            }
        }

        if imageIndex < paths.count {
            let url = URL(fileURLWithPath: paths[imageIndex])
            return CustomImageSelection(url: url, rotationDegrees: rotationDegrees)
        }

        return nil
    }

    func getCustomImageURL(for word: String, clarification: String? = nil) -> URL? {
        getCustomImageSelection(for: word, clarification: clarification)?.url
    }

    func getCustomImageRotation(for word: String, clarification: String?, imagePath: String) -> Double {
        let key = wordKey(word: word, clarification: clarification).lowercased()
        guard let index = customWordImages.firstIndex(where: { $0.word.lowercased() == key }) else {
            return 0.0
        }
        var customImage = customWordImages[index]
        if normalizeCustomImageRotations(&customImage) {
            customWordImages[index] = customImage
            saveCustomWordImages()
        }
        if let pathIndex = customImage.imagePaths.firstIndex(of: imagePath),
           pathIndex < customImage.imageRotations.count {
            return Double(customImage.imageRotations[pathIndex])
        }
        return 0.0
    }

    func rotateCustomWordImage(word: String, clarification: String?, imagePath: String, clockwise: Bool) {
        let key = wordKey(word: word, clarification: clarification).lowercased()
        guard let index = customWordImages.firstIndex(where: { $0.word.lowercased() == key }) else {
            return
        }
        var customImage = customWordImages[index]
        if normalizeCustomImageRotations(&customImage) {
            customWordImages[index] = customImage
        }
        guard let pathIndex = customImage.imagePaths.firstIndex(of: imagePath) else { return }
        let current = pathIndex < customImage.imageRotations.count ? customImage.imageRotations[pathIndex] : 0
        let delta = clockwise ? 90 : -90
        var next = (current + delta) % 360
        if next < 0 { next += 360 }
        if pathIndex < customImage.imageRotations.count {
            customImage.imageRotations[pathIndex] = next
        } else {
            normalizeCustomImageRotations(&customImage)
            if pathIndex < customImage.imageRotations.count {
                customImage.imageRotations[pathIndex] = next
            }
        }
        customWordImages[index] = customImage
        saveCustomWordImages()
        objectWillChange.send()
        NotificationCenter.default.post(name: .init("CustomWordImagesUpdated"), object: nil)
    }

    private func markLearningFavorite(word: String, clarification: String?) {
        let key = wordKey(word: word, clarification: clarification)
        if var entry = learningWords[key] {
            entry.favorite = true
            learningWords[key] = entry
            saveLearningWords()
        }
    }

    // MARK: - Custom Images Folder Sync

    func setCustomImagesFolderURL(_ url: URL) {
        customImagesFolderPath = url.path
        UserDefaults.standard.set(customImagesFolderPath, forKey: customImagesFolderPathKey)
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            customImagesFolderBookmark = bookmarkData
            UserDefaults.standard.set(bookmarkData, forKey: customImagesFolderBookmarkKey)
        } catch {
            debugPrint("Failed to create bookmark for custom images folder: \(error)")
        }
    }

    func clearCustomImagesFolder() {
        customImagesFolderPath = ""
        customImagesFolderBookmark = nil
        UserDefaults.standard.removeObject(forKey: customImagesFolderPathKey)
        UserDefaults.standard.removeObject(forKey: customImagesFolderBookmarkKey)
    }

    @discardableResult
    func syncCustomImagesFromFolder() -> Int {
        guard let folderURL = getCustomImagesFolderURL() else {
            return 0
        }

        let didStartAccessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let urls = discoverImageFiles(in: folderURL)
        if urls.isEmpty {
            return 0
        }

        var imported = 0
        for url in urls.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
            guard let parsed = parseFolderImageName(url.deletingPathExtension().lastPathComponent) else {
                continue
            }
            let key = wordKey(word: parsed.word, clarification: parsed.clarification)
            let exists = customWordImages.first(where: { $0.word.lowercased() == key })?.imagePaths.contains(url.path) ?? false
            if exists {
                continue
            }
            addCustomWordImage(word: parsed.word, clarification: parsed.clarification, url: url)
            imported += 1
        }

        return imported
    }

    private func saveCustomWordImages() {
        if let encoded = try? JSONEncoder().encode(customWordImages) {
            UserDefaults.standard.set(encoded, forKey: customWordImagesKey)
        }
    }

    private func loadCustomWordImages() {
        if let savedImages = UserDefaults.standard.data(forKey: customWordImagesKey),
           let decodedImages = try? JSONDecoder().decode([CustomWordImage].self, from: savedImages) {
            customWordImages = decodedImages
        }

        if let savedBookmarks = UserDefaults.standard.data(forKey: customWordImageBookmarksKey) {
            if let decodedBookmarks = try? JSONDecoder().decode([String: [Data]].self, from: savedBookmarks) {
                customWordImageBookmarks = decodedBookmarks
            } else if let decodedBookmarks = try? JSONDecoder().decode([String: Data].self, from: savedBookmarks) {
                customWordImageBookmarks = decodedBookmarks.mapValues { [$0] }
            }
        }

        normalizeCustomImageRotationsIfNeeded()
        rebuildCustomImageBookmarksIfNeeded()
    }

    private func loadCustomImagesFolder() {
        customImagesFolderPath = UserDefaults.standard.string(forKey: customImagesFolderPathKey) ?? ""
        customImagesFolderBookmark = UserDefaults.standard.data(forKey: customImagesFolderBookmarkKey)
    }

    private func getCustomImagesFolderURL() -> URL? {
        if let bookmarkData = customImagesFolderBookmark {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if isStale {
                    if let newBookmarkData = try? url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        customImagesFolderBookmark = newBookmarkData
                        UserDefaults.standard.set(newBookmarkData, forKey: customImagesFolderBookmarkKey)
                    }
                }
                customImagesFolderPath = url.path
                if customImagesFolderPath != UserDefaults.standard.string(forKey: customImagesFolderPathKey) {
                    UserDefaults.standard.set(customImagesFolderPath, forKey: customImagesFolderPathKey)
                }
                return url
            } catch {
                debugPrint("Failed to resolve custom images folder bookmark: \(error)")
            }
        }

        if !customImagesFolderPath.isEmpty {
            return URL(fileURLWithPath: customImagesFolderPath, isDirectory: true)
        }
        return nil
    }

    private func discoverImageFiles(in folderURL: URL) -> [URL] {
        let allowedExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff"])
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values.isRegularFile == true {
                    files.append(fileURL)
                }
            } catch {
                continue
            }
        }
        return files
    }

    private func parseFolderImageName(_ fileBaseName: String) -> (word: String, clarification: String?)? {
        var raw = fileBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return nil
        }

        if let range = raw.range(of: "__", options: .backwards) {
            let suffix = raw[range.upperBound...]
            if !suffix.isEmpty && suffix.allSatisfy({ $0.isNumber }) {
                raw = String(raw[..<range.lowerBound])
            }
        }

        let parts = splitWordKey(raw)
        let normalizedWord = parts.0.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedClarification = parts.1.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedWord.isEmpty {
            return nil
        }
        return (normalizedWord, normalizedClarification.isEmpty ? nil : normalizedClarification)
    }

    private func saveCustomWordImageBookmarks() {
        if let encoded = try? JSONEncoder().encode(customWordImageBookmarks) {
            UserDefaults.standard.set(encoded, forKey: customWordImageBookmarksKey)
        }
    }

    private func normalizeCustomImageRotationsIfNeeded() {
        var didUpdate = false
        for index in customWordImages.indices {
            var customImage = customWordImages[index]
            if normalizeCustomImageRotations(&customImage) {
                customWordImages[index] = customImage
                didUpdate = true
            }
        }
        if didUpdate {
            saveCustomWordImages()
        }
    }

    private func normalizeCustomImageRotations(_ customImage: inout CustomWordImage) -> Bool {
        let count = customImage.imagePaths.count
        if customImage.imageRotations.count < count {
            customImage.imageRotations.append(contentsOf: Array(repeating: 0, count: count - customImage.imageRotations.count))
            return true
        }
        if customImage.imageRotations.count > count {
            customImage.imageRotations = Array(customImage.imageRotations.prefix(count))
            return true
        }
        return false
    }

    private func rebuildCustomImageBookmarksIfNeeded() {
        var didUpdate = false
        for customImage in customWordImages {
            let key = customImage.word.lowercased()
            let paths = customImage.imagePaths
            guard !paths.isEmpty else { continue }
            var bookmarks = customWordImageBookmarks[key] ?? []
            if bookmarks.count >= paths.count { continue }
            for index in bookmarks.count..<paths.count {
                let path = paths[index]
                let url = URL(fileURLWithPath: path)
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    bookmarks.append(bookmarkData)
                    didUpdate = true
                } catch {
                    debugPrint("Failed to rebuild bookmark for custom image '\(key)': \(error)")
                }
            }
            customWordImageBookmarks[key] = bookmarks
        }
        if didUpdate {
            saveCustomWordImageBookmarks()
        }
    }

    private func shouldPickBabyName() -> Bool {
        guard !babyName.isEmpty else { return false }
        guard babyNameProbability > 0 else { return false }
        babyNameRngAccumulator = min(1.0, babyNameRngAccumulator + babyNameProbability)
        if Double.random(in: 0.0...1.0) < babyNameRngAccumulator {
            babyNameRngAccumulator = 0.0
            return true
        }
        return false
    }

    private func refreshRecentHistoryIfNeeded() {
        guard !recentWordHistory.isEmpty else { return }
        let currentWords = Set(words.map { wordKey(word: $0.english, clarification: $0.clarification) })
        recentWordHistory = recentWordHistory.filter { currentWords.contains($0) }
        let limit = recentHistoryLimit(for: currentWords.count)
        if recentWordHistory.count > limit {
            recentWordHistory.removeFirst(recentWordHistory.count - limit)
        }
    }

    private func selectWeightedWord(from words: [RandomWord]) -> RandomWord? {
        guard !words.isEmpty else { return nil }
        let limit = recentHistoryLimit(for: words.count)
        let maxDistance = max(1, limit - 1)
        var weights: [Double] = []
        weights.reserveCapacity(words.count)
        var totalWeight: Double = 0.0

        for word in words {
            let key = wordKey(word: word.english, clarification: word.clarification)
            let weight: Double
            if let index = recentWordHistory.lastIndex(of: key) {
                let distance = recentWordHistory.count - 1 - index
                let normalized = min(Double(distance) / Double(maxDistance), 1.0)
                weight = 0.2 + 0.8 * normalized
            } else {
                weight = 1.2
            }
            weights.append(weight)
            totalWeight += weight
        }

        guard totalWeight > 0 else { return words.randomElement() }
        let target = Double.random(in: 0.0..<totalWeight)
        var running: Double = 0.0
        for (index, weight) in weights.enumerated() {
            running += weight
            if running >= target {
                let chosen = words[index]
                let chosenKey = wordKey(word: chosen.english, clarification: chosen.clarification)
                recordRecentWord(chosenKey)
                return chosen
            }
        }

        let fallback = words.randomElement()
        if let fallbackWord = fallback {
            let key = wordKey(word: fallbackWord.english, clarification: fallbackWord.clarification)
            recordRecentWord(key)
        }
        return fallback
    }

    private func getLearningRandomWord() -> RandomWord? {
        syncLearningWordsIfNeeded()
        let allWords = currentLearningPool()
        guard !allWords.isEmpty else { return nil }

        let favorites = allWords.filter { $0.favorite }
        let known = allWords.filter { $0.known && !$0.favorite }
        let unknown = allWords.filter { !$0.known && !$0.favorite }

        let pickFavorite = !favorites.isEmpty && Double.random(in: 0.0...1.0) < learningFavoriteRatio
        let selectedPool: [LearningWord]
        if pickFavorite {
            selectedPool = favorites
        } else {
            let pickKnown = !known.isEmpty && (unknown.isEmpty || Double.random(in: 0.0...1.0) < learningKnownRatio)
            if pickKnown {
                selectedPool = !known.isEmpty ? known : unknown
            } else {
                selectedPool = !unknown.isEmpty ? unknown : known
            }
        }

        let tag = pickTag()
        let taggedPool = selectedPool.filter { tagsForWord($0).contains(tag) }
        let pool = taggedPool.isEmpty ? selectedPool : taggedPool
        guard var chosen = selectLearningWord(from: pool) else { return nil }
        chosen.seenCount += 1
        chosen.lastSeen = Date()
        learningWords[chosen.id] = chosen
        saveLearningWords()

        let clarification = chosen.clarification.isEmpty ? nil : chosen.clarification
        let result = RandomWord(english: chosen.word, translation: chosen.translation, clarification: clarification)
        lastSelectedRandomWord = result
        return result
    }

    private func selectLearningWord(from words: [LearningWord]) -> LearningWord? {
        guard !words.isEmpty else { return nil }
        var weights: [Double] = []
        weights.reserveCapacity(words.count)
        var total: Double = 0.0

        for word in words {
            let daysSince: Double
            if let lastSeen = word.lastSeen {
                daysSince = max(0.0, Date().timeIntervalSince(lastSeen) / 86_400.0)
            } else {
                daysSince = 10.0
            }
            let weight = 1.0 + min(daysSince, 10.0)
            weights.append(weight)
            total += weight
        }

        guard total > 0 else { return words.randomElement() }
        let target = Double.random(in: 0.0..<total)
        var running: Double = 0.0
        for (index, weight) in weights.enumerated() {
            running += weight
            if running >= target {
                return words[index]
            }
        }
        return words.randomElement()
    }

    private func pickTag() -> String {
        let ratios = normalizedTagRatios()
        let total = ratios.values.reduce(0.0, +)
        if total <= 0 {
            return learningTags.first ?? "basic"
        }
        let target = Double.random(in: 0.0..<total)
        var running: Double = 0.0
        for tag in learningTags {
            let weight = ratios[tag] ?? 0.0
            running += weight
            if running >= target {
                return tag
            }
        }
        return learningTags.first ?? "basic"
    }

    private func normalizedTagRatios() -> [String: Double] {
        let total = learningTagRatios.values.reduce(0.0, +)
        if total <= 0 {
            return learningTagRatios
        }
        var normalized: [String: Double] = [:]
        for (tag, value) in learningTagRatios {
            normalized[tag] = value / total
        }
        return normalized
    }

    private func tagsForWord(_ word: LearningWord) -> Set<String> {
        let tags = word.tags.map { $0.lowercased() }.filter { !$0.isEmpty }
        if tags.isEmpty {
            return ["basic"]
        }
        return Set(tags)
    }

    private func recordRecentWord(_ key: String) {
        recentWordHistory.append(key)
        let limit = recentHistoryLimit(for: words.count)
        if recentWordHistory.count > limit {
            recentWordHistory.removeFirst(recentWordHistory.count - limit)
        }
    }

    private func recentHistoryLimit(for wordCount: Int) -> Int {
        return min(12, max(3, wordCount / 3))
    }

    private func nextCustomImageIndex(for word: String, count: Int) -> Int {
        if count <= 1 {
            return 0
        }
        if var queue = customImageQueues[word], !queue.isEmpty {
            let nextIndex = queue.removeFirst()
            customImageQueues[word] = queue
            return nextIndex
        }
        var indices = Array(0..<count)
        indices.shuffle()
        let nextIndex = indices.removeFirst()
        customImageQueues[word] = indices
        return nextIndex
    }

    private func bookmarkDataForWord(_ word: String, imageIndex: Int) -> Data? {
        guard let bookmarks = customWordImageBookmarks[word] else {
            return nil
        }
        if imageIndex < bookmarks.count {
            return bookmarks[imageIndex]
        }
        return nil
    }

    private func setBookmarkData(_ bookmarkData: Data, word: String, imageIndex: Int) {
        var bookmarks = customWordImageBookmarks[word] ?? []
        if imageIndex < bookmarks.count {
            bookmarks[imageIndex] = bookmarkData
        } else {
            bookmarks.append(bookmarkData)
        }
        customWordImageBookmarks[word] = bookmarks
    }
}

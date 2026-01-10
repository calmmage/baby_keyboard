//
//  TypingGameState.swift
//  BabyKeyboardLock
//
//  Created by Claude on 24.10.2025.
//
import Foundation
import Combine

enum TypingValidationResult {
    case correct           // Letter matches
    case incorrect         // Letter doesn't match
    case wordComplete      // Word fully typed
}

class TypingGameState: ObservableObject {
    static let shared = TypingGameState()

    @Published var currentWord: String = ""
    @Published var currentEnglishWord: String = ""
    @Published var currentWordClarification: String? = nil
    @Published var currentWordTranslation: String = ""
    @Published var typedSoFar: String = ""
    @Published var resetOnError: Bool = false
    @Published var isWordComplete: Bool = false
    @Published var selectedTypingLanguages: Set<TranslationLanguage> = [.english]
    @Published var currentTypingLanguage: TranslationLanguage = .english

    private let customWordSetsManager = CustomWordSetsManager.shared
    private let randomWordList = RandomWordList.shared
    private let eventEffectHandler = EventEffectHandler()

    private init() {
        // Load reset on error setting from UserDefaults
        self.resetOnError = UserDefaults.standard.bool(forKey: "typingGameResetOnError")
        if let savedLanguages = UserDefaults.standard.array(forKey: "typingGameLanguages") as? [String] {
            let languages = savedLanguages.compactMap { TranslationLanguage(rawValue: $0) }
            if !languages.isEmpty {
                self.selectedTypingLanguages = Set(languages)
            }
        }
    }

    func setResetOnError(_ value: Bool) {
        resetOnError = value
        UserDefaults.standard.set(value, forKey: "typingGameResetOnError")
    }

    func setTypingLanguage(_ language: TranslationLanguage, enabled: Bool) {
        if enabled {
            selectedTypingLanguages.insert(language)
        } else {
            selectedTypingLanguages.remove(language)
        }
        if selectedTypingLanguages.isEmpty {
            selectedTypingLanguages = [.english]
        }
        let rawValues = selectedTypingLanguages.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: "typingGameLanguages")
    }

    // Validate a key press against the current word
    func validateKeyPress(_ key: String) -> TypingValidationResult {
        guard !currentWord.isEmpty else {
            return .incorrect
        }

        let nextExpectedIndex = typedSoFar.count

        // Check if we've already completed the word
        if nextExpectedIndex >= currentWord.count {
            return .wordComplete
        }

        // Get the next expected character
        let currentWordLower = currentWord.lowercased()
        let keyLower = key.lowercased()
        let expectedChar = String(currentWordLower[currentWordLower.index(currentWordLower.startIndex, offsetBy: nextExpectedIndex)])

        if keyLower == expectedChar {
            // Correct letter - add to typed progress
            typedSoFar += String(currentWord[currentWord.index(currentWord.startIndex, offsetBy: nextExpectedIndex)])

            // Check if word is now complete
            if typedSoFar.count == currentWord.count {
                isWordComplete = true
                return .wordComplete
            }

            return .correct
        } else {
            // Incorrect letter
            if resetOnError {
                // Reset progress
                typedSoFar = ""
            }
            return .incorrect
        }
    }

    // Select a new word from the available word sets
    func selectNewWord(wordSetType: WordSetType, secondaryLanguage: TranslationLanguage) {
        // Reset state
        typedSoFar = ""
        isWordComplete = false
        currentWordTranslation = ""
        currentEnglishWord = ""
        currentWordClarification = nil

        let typingLanguage = selectedTypingLanguages.randomElement() ?? .english
        currentTypingLanguage = typingLanguage

        var englishWord: String = ""
        var fallbackTranslation: String? = nil

        if wordSetType == .mainWords {
            // Use custom word sets
            if let wordPairs = customWordSetsManager.currentWordSet?.words, !wordPairs.isEmpty {
                let randomPair = wordPairs.randomElement()!
                englishWord = randomPair.english
                fallbackTranslation = randomPair.translation
            } else {
                // Fallback to simple words
                selectFromSimpleWords(secondaryLanguage: secondaryLanguage)
                return
            }
        } else if wordSetType == .randomShortWords {
            // Use random word list
            if let randomWord = randomWordList.getRandomWord(useLearningRotation: false) {
                englishWord = randomWord.english
                fallbackTranslation = randomWord.translation
                currentWordClarification = randomWord.clarification
            } else {
                // Fallback to simple words
                selectFromSimpleWords(secondaryLanguage: secondaryLanguage)
                return
            }
        } else {
            // Fallback
            selectFromSimpleWords(secondaryLanguage: secondaryLanguage)
            return
        }

        currentEnglishWord = englishWord
        currentWord = eventEffectHandler.resolveWordForLanguage(
            english: englishWord,
            fallbackTranslation: fallbackTranslation,
            language: typingLanguage
        ) ?? englishWord

        if secondaryLanguage != .none && secondaryLanguage != typingLanguage {
            currentWordTranslation = eventEffectHandler.resolveWordForLanguage(
                english: englishWord,
                fallbackTranslation: fallbackTranslation,
                language: secondaryLanguage
            ) ?? ""
        } else if typingLanguage != .english {
            currentWordTranslation = englishWord
        }

        debugPrint("TypingGame: Selected new word '\(currentWord)'")
    }

    private func selectFromSimpleWords(secondaryLanguage: TranslationLanguage) {
        // Fallback to built-in simple words
        let simpleWords = ["cat", "dog", "sun", "moon", "star", "ball", "cup", "hat", "pig", "cow"]
        let englishWord = simpleWords.randomElement() ?? "cat"
        currentEnglishWord = englishWord
        let typingLanguage = selectedTypingLanguages.randomElement() ?? .english
        currentTypingLanguage = typingLanguage
        currentWord = eventEffectHandler.resolveWordForLanguage(
            english: englishWord,
            fallbackTranslation: nil,
            language: typingLanguage
        ) ?? englishWord

        if secondaryLanguage != .none && secondaryLanguage != typingLanguage,
           let translation = eventEffectHandler.getTranslation(word: englishWord, language: secondaryLanguage) {
            currentWordTranslation = translation
        } else if typingLanguage != .english {
            currentWordTranslation = englishWord
        }
    }

    // Reset the current typing progress
    func reset() {
        typedSoFar = ""
        isWordComplete = false
    }

    // Get the remaining letters to type
    func getRemainingLetters() -> String {
        guard !currentWord.isEmpty else { return "" }
        let remaining = String(currentWord.dropFirst(typedSoFar.count))
        return remaining
    }
}

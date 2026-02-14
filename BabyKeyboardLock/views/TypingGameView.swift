//
//  TypingGameView.swift
//  BabyKeyboardLock
//
//  Created by Claude on 24.10.2025.
//
import SwiftUI

struct TypingGameView: View {
    @ObservedObject var eventHandler = EventHandler.shared
    @ObservedObject var typingGameState = TypingGameState.shared
    @AppStorage("showFlashcards") private var showFlashcards: Bool = false
    @AppStorage("showVideoCards") private var showVideoCards: Bool = false
    @AppStorage("flashcardStyle") private var flashcardStyleStorage: String = FlashcardStyle.noImageToken
    @AppStorage("flashcardImageSize") private var flashcardImageSize: Double = 150.0
    @State private var showCelebration: Bool = false
    @State private var celebrationOpacity: Double = 0.0
    @State private var currentImageURL: URL? = nil
    @State private var currentImageRotation: Double = 0.0
    @State private var currentVideoURL: URL? = nil
    @State private var activeFlashcardStyle: FlashcardStyle? = nil

    private var enabledFlashcardStyles: Set<FlashcardStyle> {
        FlashcardStyle.pool(from: flashcardStyleStorage)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main typing display
                VStack(spacing: 40) {
                    Spacer()

                    // Target word display with typed letters highlighted
                    if !typingGameState.currentWord.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(typingGameState.currentWord.enumerated()), id: \.offset) { index, char in
                                Text(String(char))
                                    .font(.system(size: 80, weight: .bold, design: .rounded))
                                    .foregroundColor(index < typingGameState.typedSoFar.count ? .green : .gray.opacity(0.5))
                                    .scaleEffect(index == typingGameState.typedSoFar.count - 1 ? 1.3 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: typingGameState.typedSoFar.count)
                            }
                        }
                        .padding()
                    }

                    // Flashcard image if enabled
                    if showFlashcards && activeFlashcardStyle != nil {
                        flashcardMediaView(size: CGFloat(flashcardImageSize))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Completion overlay
                if showCelebration {
                    VStack {
                        VStack(spacing: 16) {
                            if showFlashcards && activeFlashcardStyle != nil {
                                flashcardMediaView(size: CGFloat(flashcardImageSize))
                            }

                            Text(typingGameState.currentWord)
                                .font(.system(size: 48, weight: .bold, design: .rounded))

                            if !typingGameState.currentWordTranslation.isEmpty {
                                Text(typingGameState.currentWordTranslation)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.6))
                        )
                        .opacity(celebrationOpacity)
                        .scaleEffect(celebrationOpacity)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: celebrationOpacity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onChange(of: typingGameState.isWordComplete) { oldValue, newValue in
                if newValue {
                    // Trigger celebration animation
                    withAnimation {
                        showCelebration = true
                        celebrationOpacity = 1.0
                    }

                    // Fade out after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            celebrationOpacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showCelebration = false
                        }
                    }
                }
            }
            .onAppear {
                refreshMediaSelection()
            }
            .onChange(of: typingGameState.currentWord) { _, _ in
                refreshMediaSelection()
            }
            .onChange(of: typingGameState.currentEnglishWord) { _, _ in
                refreshMediaSelection()
            }
            .onChange(of: typingGameState.currentWordClarification) { _, _ in
                refreshMediaSelection()
            }
            .onChange(of: showVideoCards) { _, _ in
                refreshMediaSelection()
            }
            .onChange(of: flashcardStyleStorage) { _, _ in
                refreshMediaSelection()
            }
        }
    }

    @ViewBuilder
    private func flashcardMediaView(size: CGFloat) -> some View {
        if showVideoCards, let videoURL = currentVideoURL {
            LoopingVideoView(url: videoURL)
                .frame(width: size, height: size)
                .shadow(radius: 10)
        } else if let imageURL = currentImageURL,
                  let nsImage = loadImage(from: imageURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(radius: 10)
                .rotationEffect(.degrees(currentImageRotation))
        }
    }

    private func refreshMediaSelection() {
        activeFlashcardStyle = FlashcardStyle.randomStyle(from: enabledFlashcardStyles)

        guard let activeFlashcardStyle else {
            currentVideoURL = nil
            currentImageURL = nil
            currentImageRotation = 0.0
            return
        }

        if let selection = getMediaSelection(style: activeFlashcardStyle) {
            if selection.url.isFlashcardVideoFile {
                currentVideoURL = selection.url
                currentImageURL = nil
                currentImageRotation = 0.0
            } else {
                currentVideoURL = nil
                currentImageURL = selection.url
                currentImageRotation = selection.rotation
            }
        } else {
            currentVideoURL = nil
            currentImageURL = nil
            currentImageRotation = 0.0
        }
    }

    private func getMediaSelection(style: FlashcardStyle) -> (url: URL, rotation: Double)? {
        let word = typingGameState.currentEnglishWord.isEmpty
            ? typingGameState.currentWord.lowercased()
            : typingGameState.currentEnglishWord.lowercased()

        if showVideoCards {
            if let customVideoSelection = RandomWordList.shared.getCustomImageSelection(
                for: word,
                clarification: typingGameState.currentWordClarification,
                preferVideo: true
            ), customVideoSelection.url.isFlashcardVideoFile {
                return (customVideoSelection.url, 0.0)
            }

            let randomWord = RandomWord(
                english: word,
                translation: typingGameState.currentWordTranslation,
                clarification: typingGameState.currentWordClarification
            )
            if let bundledVideoURL = randomWord.flashcardVideoURL(style: style) {
                return (bundledVideoURL, 0.0)
            }
        }

        if let customImageSelection = RandomWordList.shared.getCustomImageSelection(
            for: word,
            clarification: typingGameState.currentWordClarification,
            preferVideo: false
        ), !customImageSelection.url.isFlashcardVideoFile {
            return (customImageSelection.url, customImageSelection.rotationDegrees)
        }

        // Check for baby image if word matches baby name
        if word == RandomWordList.shared.babyName.lowercased(),
           let babyImageURL = RandomWordList.shared.getBabyImageURL() {
            return (babyImageURL, 0.0)
        }

        let sanitizedWord = word.replacingOccurrences(of: " ", with: "_")
        let styledBaseName = "\(style.rawValue)_\(sanitizedWord)"

        if let bundledImageURL = Bundle.main.url(forResource: styledBaseName, withExtension: "png") {
            return (bundledImageURL, 0.0)
        }

        // Try to find image in Resources
        if let resourcePath = Bundle.main.resourcePath {
            let styledImagePath = "\(resourcePath)/Resources/FlashcardImages/\(style.rawValue)/\(styledBaseName).png"
            if FileManager.default.fileExists(atPath: styledImagePath) {
                return (URL(fileURLWithPath: styledImagePath), 0.0)
            }

            let prefixedPath = "\(resourcePath)/Resources/\(styledBaseName).png"
            if FileManager.default.fileExists(atPath: prefixedPath) {
                return (URL(fileURLWithPath: prefixedPath), 0.0)
            }

            let imagePath = "\(resourcePath)/Resources/\(word).png"
            if FileManager.default.fileExists(atPath: imagePath) {
                return (URL(fileURLWithPath: imagePath), 0.0)
            }
        }

        return nil
    }

    private func loadImage(from url: URL) -> NSImage? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return NSImage(contentsOf: url)
    }
}

#Preview {
    TypingGameView()
        .frame(width: 800, height: 600)
}

import SwiftUI
import Combine
import AVKit
import AVFoundation

struct WordDisplayView: View {
    @ObservedObject var eventHandler: EventHandler = EventHandler.shared
    @State private var word: String = ""
    @State private var translation: String = ""
    @State private var showWord: Bool = false
    @AppStorage("wordDisplayDuration") private var wordDisplayDuration: Double = DEFAULT_WORD_DISPLAY_DURATION
    @AppStorage("showFlashcards") private var showFlashcards: Bool = false
    @AppStorage("showVideoCards") private var showVideoCards: Bool = false
    @AppStorage("videoCardDemoMode") private var videoCardDemoMode: Bool = false
    @AppStorage("videoCardDemoWord") private var videoCardDemoWord: String = "cat"
    @AppStorage("flashcardStyle") private var flashcardStyleStorage: String = FlashcardStyle.noImageToken
    @AppStorage("flashcardImageSize") private var flashcardImageSize: Double = 150.0
    @State private var windowSize: CGSize = .zero
    @State private var englishWordForImage: String = ""
    @State private var clarificationForImage: String? = nil
    @State private var customImageURL: URL? = nil
    @State private var customImageRotation: Double = 0.0
    @State private var availableVideoURL: URL? = nil
    @State private var activeFlashcardStyle: FlashcardStyle? = nil
    @State private var isCurrentCardVideoActivated: Bool = false
    
    // For more reliable timeout handling
    @State private var hideWorkItem: DispatchWorkItem? = nil

    private var enabledFlashcardStyles: Set<FlashcardStyle> {
        FlashcardStyle.pool(from: flashcardStyleStorage)
    }
    
    // Calculate dynamic background size based on content
    private var backgroundSize: CGSize {
        let hasImage = activeFlashcardStyle != nil
        let hasTranslation = !translation.isEmpty

        // Padding/buffer values
        let horizontalPadding: CGFloat = 100
        let verticalPadding: CGFloat = 60 // for top/bottom
        let wordTextHeight: CGFloat = 60
        let translationTextHeight: CGFloat = hasTranslation ? 40 : 0

        if hasImage {
            let width = flashcardImageSize + 2 * horizontalPadding
            let height = flashcardImageSize + verticalPadding + wordTextHeight + translationTextHeight
            // Ensure minimums for small images
            return CGSize(
                width: max(width, 400),
                height: max(height, 250)
            )
        } else {
            // No image, just use minimums
            return CGSize(width: 400, height: hasTranslation ? 250 : 200)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Show typing game view for typing game mode
            if eventHandler.isLocked && eventHandler.selectedLockEffect == .typingGame {
                TypingGameView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            else if eventHandler.isLocked,
                    eventHandler.selectedLockEffect == .speakRandomWord,
                    eventHandler.gamifyRandomWordEnabled,
                    !eventHandler.gamifyRandomWordTarget.isEmpty,
                    !showWord {
                let bgSize = backgroundSize
                let maxWidth = min(geometry.size.width * 0.6, bgSize.width)
                let maxHeight = min(geometry.size.height * 0.6, bgSize.height)

                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .frame(width: maxWidth, height: maxHeight)

                    VStack(spacing: 16) {
                        Text("Find the letter")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.gray)
                        Text(eventHandler.gamifyRandomWordTarget.uppercased())
                            .font(.system(size: 120, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .transition(.opacity)
            }
            else if showWord && !word.isEmpty && showFlashcards {
                let bgSize = backgroundSize
                let maxWidth = min(geometry.size.width * 0.9, bgSize.width)
                let maxHeight = min(geometry.size.height * 0.9, bgSize.height)
                
                ZStack {
                    // White background
                    Rectangle()
                        .fill(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .frame(width: maxWidth, height: maxHeight)
                    
                    VStack(spacing: 20) {
                        // Flashcard image if available
                        if let activeFlashcardStyle {
                            let imageLookupWord = englishWordForImage.isEmpty ? word : englishWordForImage
                            let clarification = clarificationForImage
                            let wordForMedia = RandomWord(
                                english: imageLookupWord,
                                translation: translation,
                                clarification: clarification
                            )
                            let cardHeight = min(flashcardImageSize, maxHeight - 150)

                            if showVideoCards,
                               isCurrentCardVideoActivated,
                               let videoURL = availableVideoURL {
                                LoopingVideoView(url: videoURL)
                                    .frame(height: cardHeight)
                            }
                            // First check for custom image (for any word including baby's name)
                            else if let customImage = loadImage(from: customImageURL) {
                                Image(nsImage: customImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: cardHeight)
                                    .rotationEffect(.degrees(customImageRotation))
                            }
                            // Fallback to baby image if it's the baby's name (backward compatibility)
                            else if imageLookupWord.lowercased() == RandomWordList.shared.babyName.lowercased(),
                                    let babyImage = loadBabyImage() {
                                Image(nsImage: babyImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: cardHeight)
                            }
                            // Finally try generated flashcard images
                            else if let image = wordForMedia.flashcardImage(style: activeFlashcardStyle) {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: cardHeight)
                            }
                        }

                        // Main word
                        Text(word.uppercased())
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        // Translation if available
                        if !translation.isEmpty {
                            Text(translation.uppercased())
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                    .frame(width: maxWidth, height: maxHeight)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .transition(.opacity)
            }
        }
        .fullscreenTransparentWindow()
        .onAppear {
            // Add observer for screen parameter changes
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateWindowSize()
            }
            updateWindowSize()
        }
        .onChange(of: windowSize) { _, newSize in
            updateWindowSize()
        }
        .onReceive(eventHandler.$lastKeyString) { newValue in
            if eventHandler.isLocked && (eventHandler.selectedLockEffect == .speakAKeyWord || eventHandler.selectedLockEffect == .speakRandomWord) && !newValue.isEmpty {
                if shouldActivateVideoOnSecondKeyPress() {
                    activateVideoForCurrentCard()
                    return
                }

                hideWorkItem?.cancel()

                let incomingEnglishWord = newValue
                let lastRandomWord = RandomWordList.shared.getLastSelectedRandomWord()
                let lastMatches = lastRandomWord?.english.lowercased() == incomingEnglishWord.lowercased()
                let englishWord = resolvedEnglishWordForDisplay(incomingWord: incomingEnglishWord)
                englishWordForImage = englishWord
                clarificationForImage = (eventHandler.selectedLockEffect == .speakRandomWord && lastMatches && !videoCardDemoMode)
                    ? lastRandomWord?.clarification
                    : nil

                var fallbackTranslation: String? = nil
                if eventHandler.selectedLockEffect == .speakRandomWord,
                   lastMatches,
                   let randomWordObj = lastRandomWord,
                   !videoCardDemoMode {
                    fallbackTranslation = randomWordObj.translation
                }

                let primaryWord = eventHandler.eventEffectHandler.resolveWordForLanguage(
                    english: englishWord,
                    fallbackTranslation: fallbackTranslation,
                    language: eventHandler.selectedPrimaryLanguage,
                    meaningKey: clarificationForImage
                ) ?? englishWord
                let secondaryWord = eventHandler.eventEffectHandler.resolveWordForLanguage(
                    english: englishWord,
                    fallbackTranslation: fallbackTranslation,
                    language: eventHandler.selectedTranslationLanguage,
                    meaningKey: clarificationForImage
                )
                self.word = primaryWord
                if let secondaryWord = secondaryWord, secondaryWord != primaryWord {
                    self.translation = secondaryWord
                } else {
                    self.translation = ""
                }

                activeFlashcardStyle = FlashcardStyle.randomStyle(from: enabledFlashcardStyles)
                updateMediaAvailability(
                    englishWord: englishWord,
                    clarification: clarificationForImage,
                    style: activeFlashcardStyle
                )
                isCurrentCardVideoActivated = false

                withAnimation(.easeIn(duration: 0.3)) {
                    showWord = true
                }

                scheduleHide(after: wordDisplayDuration)
            }
        }
        .onReceive(Just(wordDisplayDuration)) { newDuration in
            // If a word is currently shown, update the timer with the new duration
            if showWord && hideWorkItem != nil {
                scheduleHide(after: newDuration)
            }
        }
        .onChange(of: flashcardStyleStorage) { _, _ in
            activeFlashcardStyle = FlashcardStyle.randomStyle(from: enabledFlashcardStyles)

            if showWord {
                let imageWord = englishWordForImage.isEmpty ? word : englishWordForImage
                updateMediaAvailability(
                    englishWord: imageWord,
                    clarification: clarificationForImage,
                    style: activeFlashcardStyle
                )
            }
        }
        .onDisappear {
            // Clean up when view disappears
            hideWorkItem?.cancel()
            hideWorkItem = nil
            isCurrentCardVideoActivated = false
            availableVideoURL = nil
            activeFlashcardStyle = nil
        }
    }
    
    private func updateWindowSize() {
        guard let mainScreen = NSScreen.main else { return }
        let newSize = mainScreen.frame.size

        // Only update if size actually changed
        if newSize != windowSize {
            windowSize = newSize

            // Update window frame
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == WordDisplayWindowID }) {
                    let frame = NSRect(x: 0, y: 0, width: mainScreen.frame.width, height: mainScreen.frame.height)
                    window.setFrame(frame, display: true)
                }
            }
        }
    }

    private func shouldActivateVideoOnSecondKeyPress() -> Bool {
        showWord &&
            showFlashcards &&
            activeFlashcardStyle != nil &&
            showVideoCards &&
            !isCurrentCardVideoActivated &&
            availableVideoURL != nil
    }

    private func activateVideoForCurrentCard() {
        guard shouldActivateVideoOnSecondKeyPress() else { return }

        hideWorkItem?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            isCurrentCardVideoActivated = true
        }
        scheduleHide(after: max(wordDisplayDuration, 2.0))
    }

    private func resolvedEnglishWordForDisplay(incomingWord: String) -> String {
        guard videoCardDemoMode else { return incomingWord }
        let demoWord = videoCardDemoWord
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return demoWord.isEmpty ? incomingWord : demoWord
    }

    private func updateMediaAvailability(
        englishWord: String,
        clarification: String?,
        style: FlashcardStyle?
    ) {
        guard let style else {
            customImageURL = nil
            customImageRotation = 0.0
            availableVideoURL = nil
            return
        }

        let stillSelection = RandomWordList.shared.getCustomImageSelection(
            for: englishWord,
            clarification: clarification,
            preferVideo: false
        )
        if let stillSelection, !stillSelection.url.isFlashcardVideoFile {
            customImageURL = stillSelection.url
            customImageRotation = stillSelection.rotationDegrees
        } else {
            customImageURL = nil
            customImageRotation = 0.0
        }

        let customVideoSelection = RandomWordList.shared.getCustomImageSelection(
            for: englishWord,
            clarification: clarification,
            preferVideo: true
        )
        if let customVideoSelection, customVideoSelection.url.isFlashcardVideoFile {
            availableVideoURL = customVideoSelection.url
            return
        }

        availableVideoURL = RandomWord(
            english: englishWord,
            translation: translation,
            clarification: clarification
        ).flashcardVideoURL(style: style)
    }

    private func scheduleHide(after delay: Double) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                showWord = false
            }
            isCurrentCardVideoActivated = false
            activeFlashcardStyle = nil
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func loadBabyImage() -> NSImage? {
        guard let babyImageURL = RandomWordList.shared.getBabyImageURL() else {
            return nil
        }

        // Start accessing security-scoped resource
        let didStartAccessing = babyImageURL.startAccessingSecurityScopedResource()

        // Load the image
        let image = NSImage(contentsOf: babyImageURL)

        // Stop accessing if we started
        if didStartAccessing {
            babyImageURL.stopAccessingSecurityScopedResource()
        }

        return image
    }

    private func loadImage(from url: URL?) -> NSImage? {
        guard let imageURL = url else { return nil }
        // Start accessing security-scoped resource
        let didStartAccessing = imageURL.startAccessingSecurityScopedResource()

        // Load the image
        let image = NSImage(contentsOf: imageURL)

        // Stop accessing if we started
        if didStartAccessing {
            imageURL.stopAccessingSecurityScopedResource()
        }

        return image
    }
}

struct LoopingVideoView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspect
        context.coordinator.configure(playerView: playerView, url: url)
        return playerView
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        context.coordinator.configure(playerView: playerView, url: url)
    }

    static func dismantleNSView(_ playerView: AVPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        playerView.player = nil
    }

    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?
        private var scopedURL: URL?
        private var isAccessingSecurityScope: Bool = false

        func configure(playerView: AVPlayerView, url: URL) {
            if currentURL == url {
                player?.play()
                return
            }

            stop()

            currentURL = url
            scopedURL = url
            isAccessingSecurityScope = url.startAccessingSecurityScopedResource()

            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true

            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            playerView.player = queuePlayer
            queuePlayer.play()
        }

        func stop() {
            player?.pause()
            player = nil
            looper = nil
            currentURL = nil
            if isAccessingSecurityScope {
                scopedURL?.stopAccessingSecurityScopedResource()
            }
            scopedURL = nil
            isAccessingSecurityScope = false
        }
    }
}

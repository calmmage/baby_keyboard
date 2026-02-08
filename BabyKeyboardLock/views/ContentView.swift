//
//  ContentView.swift
//  BabyKeyboardLock
//
//  Created by Fangxing Xiong on 15.12.2024.
//

import SwiftUI
import AppKit
import AVFoundation

struct HoverableMenuStyle: MenuStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}

struct ContentView: View {
    @State private var animationWindow: NSWindow?
    @ObservedObject var eventHandler: EventHandler = EventHandler.shared
    @State private var selectedCategory: EffectCategory = .none
    @AppStorage("showFlashcards") private var showFlashcards: Bool = false
    @AppStorage("flashcardStyle") private var flashcardStyle: FlashcardStyle = .none

    @AppStorage("lockKeyboardOnLaunch") private var lockKeyboardOnLaunch: Bool = false
    @AppStorage("launchOnStartup") private var launchOnStartup: Bool = false {
        didSet {
            LaunchAtStartup.shared.setEnabled(launchOnStartup)
        }
    }
    @AppStorage("selectedLockEffect") var selectedLockEffect: LockEffect = .speakRandomWord
    @AppStorage("selectedPrimaryLanguage") var selectedPrimaryLanguage: TranslationLanguage = .english
    @AppStorage("selectedTranslationLanguage") var selectedTranslationLanguage: TranslationLanguage = .none
    @AppStorage("selectedWordSetType") var savedWordSetType: String = WordSetType.randomShortWords.rawValue
    @AppStorage("wordDisplayDuration") var wordDisplayDuration: Double = DEFAULT_WORD_DISPLAY_DURATION
    @AppStorage("usePersonalVoice") var usePersonalVoice: Bool = false
    @AppStorage("throttleInterval") private var savedThrottleInterval: Double = 1.0
    @AppStorage("wordsThrottleInterval") private var savedWordsThrottleInterval: Double = 1.5
    @AppStorage("confettiFadeTime") private var savedConfettiFadeTime: Double = 5.0
    @AppStorage("wordTranslationDelay") private var savedWordTranslationDelay: Double = 0.8
    @AppStorage("flashcardImageSize") private var flashcardImageSize: Double = 150.0

    @State private var showWordSetEditor = false
    @State private var showRandomWordEditor = false
    @State private var showCustomWordImageEditor = false
    @State private var showLearningWordEditor = false
    @State private var showLearningPoolPreview = false
    @StateObject private var customWordSetsManager = CustomWordSetsManager.shared
    @StateObject private var randomWordList = RandomWordList.shared

    @State var hoveringMoreButton: Bool = false
    @State private var babyName: String = ""
    @State private var babyNameTranslation: String = ""
    @State private var babyNameProbability: Double = 0.125
    @State private var babyImagePath: String = ""
    private let learningPoolDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        let primaryLanguages = TranslationLanguage.allCases.filter { $0 != .none }
        VStack(alignment: .leading, spacing: 0) {
            // Top bar with lock toggle and quit button
            HStack {
                Toggle(isOn: $eventHandler.isLocked)
                {
                    Label(
                        "Lock Keyboard",
                        image: eventHandler.isLocked ? "keyboard.locked" : "keyboard.unlocked"
                    )
                    .font(.title)
                    .foregroundColor(eventHandler.accessibilityPermissionGranted ? .primary : .gray)
                }
                .toggleStyle(SwitchToggleStyle(tint: .red))
                .disabled(!eventHandler.accessibilityPermissionGranted)
                .onChange(of: eventHandler.isLocked) { oldVal, newVal in
                    playLockSound(isLocked: newVal)

                    if eventHandler.isLocked {
                        playLockSound(isLocked: true)
                    }
                }

                Spacer()

                Button("Exit App") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, eventHandler.accessibilityPermissionGranted ? 20 : 10)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                if !eventHandler.accessibilityPermissionGranted {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This app needs Accessibility access to work.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button("Grant Accessibility Access") {
                                NSApp.activate(ignoringOtherApps: true)
                                _ = eventHandler.requestAccessibilityPermissions()
                            }

                            Button("Open System Settings…") {
                                NSApp.activate(ignoringOtherApps: true)
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                
                // Category selector
                Picker("Category", selection: $selectedCategory) {
                    ForEach(EffectCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 10)
                
                // Effect selector based on category
                if selectedCategory != .none {
                    let availableEffects = LockEffect.allCases.filter { $0.category == selectedCategory }
                    Picker("Effect", selection: $eventHandler.selectedLockEffect) {
                        ForEach(availableEffects) { effect in
                            Text(effect.localizedString).tag(effect)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Visual effects settings
                if selectedCategory == .visual {
                    if eventHandler.selectedLockEffect == .confettiCannon {
                        Group {
                            Text("Delay between confetti (seconds)")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            HStack {
                                Slider(value: $eventHandler.throttleInterval, in: 0.1...2.0, step: 0.1)
                                    .onChange(of: eventHandler.throttleInterval) { _, newValue in
                                        savedThrottleInterval = newValue
                                    }
                                Text(String(format: "%.1f", eventHandler.throttleInterval))
                                    .frame(width: 35)
                            }
                            
                            Text("Confetti fade time (seconds)")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .padding(.top, 8)
                            
                            HStack {
                                Slider(value: $eventHandler.confettiFadeTime, in: 1.0...10.0, step: 0.5)
                                    .onChange(of: eventHandler.confettiFadeTime) { _, newValue in
                                        savedConfettiFadeTime = newValue
                                    }
                                Text(String(format: "%.1f", eventHandler.confettiFadeTime))
                                    .frame(width: 35)
                            }
                        }
                    }
                }
                
                // Words mode settings
                if selectedCategory == .words {
                    Toggle(isOn: $showFlashcards) {
                        Text("Show Flashcards")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    if showFlashcards {
                        Text("Flashcard Style")
                            .foregroundColor(.secondary)
                            .font(.subheadline)

                        FlashcardStylePicker(selectedStyle: $flashcardStyle)
                    }

                    Toggle(isOn: $eventHandler.usePersonalVoice) {
                        HStack {
                            Text("Use Personal Voice")
                            
                            Button(action: {
                                let alert = NSAlert()
                                alert.messageText = "About Personal Voice"
                                alert.informativeText = "Personal Voice uses your own voice created in System Settings > Accessibility > Personal Voice. You need to create a Personal Voice before using this feature."
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .onChange(of: eventHandler.usePersonalVoice) { oldVal, newVal in
                        usePersonalVoice = newVal
                    }
                    
                    // Words throttle setting
                    Text("Delay between words (seconds)")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding(.top, 8)
                    
                    HStack {
                        Slider(value: $eventHandler.wordsThrottleInterval, in: 0.1...3.0, step: 0.1)
                            .onChange(of: eventHandler.wordsThrottleInterval) { _, newValue in
                                savedWordsThrottleInterval = newValue
                            }
                        Text(String(format: "%.1f", eventHandler.wordsThrottleInterval))
                            .frame(width: 35)
                    }
                    
                    // Language pickers
                    Picker("Primary", selection: $eventHandler.selectedPrimaryLanguage) {
                        ForEach(primaryLanguages) { language in
                            Text(language.localizedString)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: eventHandler.selectedPrimaryLanguage) { oldVal, newVal in
                        selectedPrimaryLanguage = newVal
                    }

                    Picker("Secondary", selection: $eventHandler.selectedTranslationLanguage) {
                        ForEach(TranslationLanguage.allCases) { language in
                            Text(language.localizedString)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: eventHandler.selectedTranslationLanguage) { oldVal, newVal in
                        selectedTranslationLanguage = newVal
                    }
                    
                    // Baby's name input fields
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Baby's Name")
                                .foregroundColor(.secondary)
                                .font(.subheadline)

                            Spacer()

                            TextField("Enter name", text: $babyName, onCommit: {
                                // Do nothing, prevents form submission behavior
                            })
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                                .onChange(of: babyName) { oldValue, newValue in
                                    RandomWordList.shared.setBabyName(newValue)
                                }
                        }

                        HStack {
                            Text("Second Language Name")
                                .foregroundColor(.secondary)
                                .font(.subheadline)

                            Spacer()

                            TextField("Enter translation", text: $babyNameTranslation, onCommit: {
                                // Do nothing, prevents form submission behavior
                            })
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 150)
                                .onChange(of: babyNameTranslation) { oldValue, newValue in
                                    RandomWordList.shared.setBabyNameTranslation(newValue)
                                }
                        }

                        HStack {
                            Text("Baby's Image")
                                .foregroundColor(.secondary)
                                .font(.subheadline)

                            Spacer()

                            if !babyImagePath.isEmpty {
                                Text(URL(fileURLWithPath: babyImagePath).lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 100)
                            }

                            Button(action: selectBabyImage) {
                                Text(babyImagePath.isEmpty ? "Select Image" : "Change")
                            }
                            .buttonStyle(.plain)

                            if !babyImagePath.isEmpty {
                                Button(action: {
                                    babyImagePath = ""
                                    RandomWordList.shared.setBabyImagePath("")
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Other Custom Images")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Text("Add images for mama, papa, family, etc.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !randomWordList.customWordImages.isEmpty {
                                    Text("\(randomWordList.customWordImages.count) custom image(s)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: {
                                showCustomWordImageEditor = true
                            }) {
                                Image(systemName: "photo.on.rectangle.angled")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Baby name probability slider (only for random word mode)
                    if eventHandler.selectedLockEffect == .speakRandomWord {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Baby Name Frequency: \(String(format: "%.0f%%", babyNameProbability * 100))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("0%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Slider(value: $babyNameProbability, in: 0...1, step: 0.01)
                                    .onChange(of: babyNameProbability) { _, newValue in
                                        RandomWordList.shared.setBabyNameProbability(newValue)
                                    }

                                Text("100%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 5)
                    }

                    if eventHandler.selectedLockEffect == .speakRandomWord {
                        Toggle(isOn: Binding(
                            get: { eventHandler.gamifyRandomWordEnabled },
                            set: { eventHandler.setGamifyRandomWordEnabled($0) }
                        )) {
                            Text("Gamify: find the letter before reward")
                        }
                        .toggleStyle(CheckboxToggleStyle())
                    }

                    // Word display duration settings
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Word Display Duration: \(String(format: "%.1f", wordDisplayDuration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("1s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $wordDisplayDuration, in: 1...10, step: 0.5)
                            
                            Text("10s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 5)
                    
                    // Random words editor button
                    if eventHandler.selectedLockEffect == .speakRandomWord {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Word Sets")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Text("\(randomWordList.enabledSetIndices.count) enabled (\(randomWordList.words.count) words)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !randomWordList.enabledWordSetNames.isEmpty && randomWordList.enabledWordSetNames != "None" {
                                    Text(randomWordList.enabledWordSetNames)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Button(action: {
                                showRandomWordEditor = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Toggle(isOn: Binding(
                            get: { randomWordList.learningRotationEnabled },
                            set: { randomWordList.setLearningRotationEnabled($0) }
                        )) {
                            Text("Learning Rotation")
                        }
                        .toggleStyle(CheckboxToggleStyle())

                        let poolInfo = randomWordList.getLearningPoolInfo()
                        VStack(alignment: .leading, spacing: 4) {
                            let lastSync = poolInfo.lastSync.map { learningPoolDateFormatter.string(from: $0) } ?? "never"
                            Text("Pool: \(poolInfo.count) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .help(learningPoolTooltipText())
                            Text("Refresh: daily (last: \(lastSync))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Button("Refresh pool now") {
                                randomWordList.refreshLearningPool(force: true)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)

                            Button("Manage words") {
                                showLearningPoolPreview = true
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pool size: \(randomWordList.learningPoolSize)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(
                                value: Binding(
                                    get: { Double(randomWordList.learningPoolSize) },
                                    set: { randomWordList.setLearningPoolSize(Int($0)) }
                                ),
                                in: 5.0...200.0,
                                step: 5.0
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Known mix: \(Int(randomWordList.learningKnownRatio * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(
                                value: Binding(
                                    get: { randomWordList.learningKnownRatio },
                                    set: { randomWordList.setLearningKnownRatio($0) }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Favorites mix: \(Int(randomWordList.learningFavoriteRatio * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(
                                value: Binding(
                                    get: { randomWordList.learningFavoriteRatio },
                                    set: { randomWordList.setLearningFavoriteRatio($0) }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tag mix")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(randomWordList.getLearningTags(), id: \.self) { tag in
                                VStack(alignment: .leading, spacing: 4) {
                                    let ratio = randomWordList.learningTagRatios[tag] ?? 0.0
                                    Text("\(tag): \(Int(ratio * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: Binding(
                                            get: { randomWordList.learningTagRatios[tag] ?? 0.0 },
                                            set: { randomWordList.setLearningTagRatio(tag: tag, value: $0) }
                                        ),
                                        in: 0.0...1.0,
                                        step: 0.05
                                    )
                                }
                            }
                        }

                        Button("Open Learning CSV") {
                            randomWordList.openLearningCSV()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button("Edit Learning Words") {
                            showLearningWordEditor = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        // Image size slider for random word mode
                        if showFlashcards && flashcardStyle != .none {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Image Size: \(Int(flashcardImageSize))px")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("50px")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $flashcardImageSize, in: 50...1000, step: 50)
                                    
                                    Text("1000px")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }

                // Game mode settings
                if selectedCategory == .games {
                    Toggle(isOn: Binding(
                        get: { TypingGameState.shared.resetOnError },
                        set: { TypingGameState.shared.setResetOnError($0) }
                    )) {
                        Text("Reset on error")
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    Text("Typing Languages")
                        .foregroundColor(.secondary)
                        .font(.subheadline)

                    let typingLanguages = TranslationLanguage.allCases.filter { $0 != .none }
                    ForEach(typingLanguages) { language in
                        Toggle(isOn: Binding(
                            get: { TypingGameState.shared.selectedTypingLanguages.contains(language) },
                            set: { TypingGameState.shared.setTypingLanguage(language, enabled: $0) }
                        )) {
                            Text(language.localizedString)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                    }

                    // Word set selection
                    Picker("Word Set", selection: $eventHandler.selectedWordSetType) {
                        ForEach(WordSetType.allCases) { type in
                            Text(type.localizedString).tag(type)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: eventHandler.selectedWordSetType) { _, newValue in
                        savedWordSetType = newValue.rawValue
                    }

                    // Show flashcards toggle
                    Toggle(isOn: $showFlashcards) {
                        Text("Show Flashcards")
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    if showFlashcards {
                        Text("Flashcard Style")
                            .foregroundColor(.secondary)
                            .font(.subheadline)

                        FlashcardStylePicker(selectedStyle: $flashcardStyle)

                        // Image size slider
                        if flashcardStyle != .none {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Image Size: \(Int(flashcardImageSize))px")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text("50px")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Slider(value: $flashcardImageSize, in: 50...1000, step: 50)

                                    Text("1000px")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }

                Toggle(isOn: $lockKeyboardOnLaunch) {
                    Text("Lock keyboard on launch")
                }
                .toggleStyle(CheckboxToggleStyle())

                Toggle(isOn: $launchOnStartup) {
                    Text("Launch on startup")
                }
                .toggleStyle(CheckboxToggleStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard shortcut: Ctrl + Option + U")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button("Settings") {
                            AdvancedSettingsView().openInWindow(id: "Settings", sender: self, focus: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        Button("About") {
                            AboutView().openInWindow(id: "About", sender: self, focus: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Set initial values first
            if let type = WordSetType(rawValue: savedWordSetType) {
                eventHandler.selectedWordSetType = type
            }
            babyName = RandomWordList.shared.babyName
            babyNameTranslation = RandomWordList.shared.babyNameTranslation
            babyNameProbability = RandomWordList.shared.babyNameProbability
            babyImagePath = RandomWordList.shared.babyImagePath
            eventHandler.usePersonalVoice = usePersonalVoice
            launchOnStartup = LaunchAtStartup.shared.isEnabled()

            // Set initial category based on current effect
            selectedCategory = eventHandler.selectedLockEffect.category

            // Set speak random word as default for word mode
            if selectedCategory == .words && eventHandler.selectedLockEffect == .speakAKeyWord {
                eventHandler.selectedLockEffect = .speakRandomWord
            }

            // Request accessibility permissions if needed
            if !eventHandler.accessibilityPermissionGranted {
                NSApp.activate(ignoringOtherApps: true)
                _ = eventHandler.requestAccessibilityPermissions()
            }
        }
        .onChange(of: eventHandler.isLocked) { oldVal, newVal in
            playLockSound(isLocked: newVal)
        }
        .onReceive(eventHandler.$isLocked) { newVal in
            playLockSound(isLocked: newVal)
        }
        .onChange(of: eventHandler.selectedLockEffect) { oldVal, newVal in
            selectedLockEffect = newVal
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            // When changing category, only switch if current effect is incompatible
            let availableEffects = LockEffect.allCases.filter { $0.category == newValue }

            if newValue == .none {
                eventHandler.selectedLockEffect = .none
            } else if !availableEffects.contains(eventHandler.selectedLockEffect) {
                // Current effect doesn't match category, preserve user preference if possible
                if newValue == .visual {
                    eventHandler.selectedLockEffect = .confettiCannon
                } else if newValue == .words {
                    eventHandler.selectedLockEffect = .speakRandomWord
                } else if newValue == .games {
                    eventHandler.selectedLockEffect = .typingGame
                }
            }
            // If current effect is compatible with new category, keep it unchanged
        }
        .sheet(isPresented: $showWordSetEditor) {
            WordSetEditorView()
        }
        .sheet(isPresented: $showRandomWordEditor) {
            RandomWordEditorView()
        }
        .sheet(isPresented: $showCustomWordImageEditor) {
            CustomWordImageEditorView()
        }
        .sheet(isPresented: $showLearningWordEditor) {
            LearningWordEditorView()
        }
        .sheet(isPresented: $showLearningPoolPreview) {
            LearningWordEditorView(initialShowOnlyPool: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeMenusRequested)) { _ in
            showWordSetEditor = false
            showRandomWordEditor = false
            showCustomWordImageEditor = false
            showLearningWordEditor = false
        }
    }
    

    
    private func learningPoolTooltipText() -> String {
        let labels = randomWordList.getCurrentLearningPool().map { word in
            let clarification = word.clarification.trimmingCharacters(in: .whitespacesAndNewlines)
            if clarification.isEmpty {
                return word.word
            }
            return "\(word.word) (\(clarification))"
        }
        let sorted = labels.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if sorted.isEmpty {
            return "Current pool is empty"
        }
        return sorted.joined(separator: "\n")
    }

    private func selectBabyImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select an image for your baby"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                babyImagePath = url.path
                RandomWordList.shared.setBabyImageURL(url)
            }
        }
    }

    private func playLockSound(isLocked: Bool) {
        if isLocked {
            NSSound(named: "light-switch-on")?.play()
        } else {
            guard let nsSound = NSSound(named: "light-switch-off") else { return }

            nsSound.play()
        }
    }
    
    private func showOrCloseAnimationWindow(isLocked: Bool) {
        if (!isLocked) {
            NSApp.windows.forEach { window in
                if window.identifier?.rawValue == AnimationWindowID || window.identifier?.rawValue == WordDisplayWindowID {
                    window.close()
                }
            }
            return
        }
           
        // Check if animation window exists
        let existingAnimationWindow = NSApp.windows.first { $0.identifier?.rawValue == AnimationWindowID }
        if existingAnimationWindow != nil {
            existingAnimationWindow?.orderFront(self)
        } else {
            // Create the animation window
            animationWindow = AnimationView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Make the window transparent
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == AnimationWindowID }) else { return }
                    window.isOpaque = false
                    window.level = .floating
                    window.titlebarAppearsTransparent = true
                }
                .openInWindow(id: AnimationWindowID, sender: self)
        }
        
        // Check if word display window exists
        let existingWordDisplayWindow = NSApp.windows.first { $0.identifier?.rawValue == WordDisplayWindowID }
        if existingWordDisplayWindow != nil {
            existingWordDisplayWindow?.orderFront(self)
        } else {
            // Create the word display window
            WordDisplayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Make the window transparent
                    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == WordDisplayWindowID }) else { return }
                    window.isOpaque = false
                    window.backgroundColor = NSColor.clear
                    window.level = .floating
                    window.ignoresMouseEvents = true
                    window.titlebarAppearsTransparent = true
                }
                .openInWindow(id: WordDisplayWindowID, sender: self)
        }
    }
    
}

struct WordSetEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var customWordSetsManager = CustomWordSetsManager.shared
    @State private var words: [CustomWordPair] = []
    @State private var newEnglishWord: String = ""
    @State private var newTranslation: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Main Words")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            Text("Edit the words used in 'Main Words' set")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            List {
                ForEach(words) { word in
                    HStack {
                        Text(word.english)
                        Spacer()
                        Text(word.translation)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteWord)
            }
            .listStyle(PlainListStyle())
            .frame(height: 200)
            
            HStack {
                TextField("English word", text: $newEnglishWord)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Translation", text: $newTranslation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addWord) {
                    Image(systemName: "plus")
                }
                .disabled(newEnglishWord.isEmpty || newTranslation.isEmpty)
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }

                Spacer()

                Button("Save") {
                    customWordSetsManager.updateMainWords(words: words)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(words.isEmpty)
            }
        } 
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            centerMenuWindow()
            if let currentSet = customWordSetsManager.currentWordSet {
                words = currentSet.words
            }
        }
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func addWord() {
        guard !newEnglishWord.isEmpty && !newTranslation.isEmpty else { return }
        
        let newWord = CustomWordPair(english: newEnglishWord, translation: newTranslation) 
        words.append(newWord)
        
        // Clear the input fields
        newEnglishWord = ""
        newTranslation = ""
    }
    
    private func deleteWord(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
    }

    private func centerMenuWindow() {
        if let window = NSApp.windows.first(where: { $0.isSheet }) {
            window.center()
        }
    }
}

struct CustomWordImageEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var customImages: [CustomWordImage] = []
    @State private var newWord: String = ""
    @State private var newClarification: String = ""
    @State private var showImagePreview = false
    @State private var previewWordKey: String = ""
    @State private var previewImagePaths: [String] = []
    @State private var previewImageIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Custom Word Images")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            Text("Add custom images for specific words (e.g., 'mama', 'papa', family members)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach(customImages) { customImage in
                    HStack {
                        Text(displayLabel(for: customImage.word))
                            .font(.body)
                        Spacer()
                        Text("\(customImage.imagePaths.count) image(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)

                        Button(action: {
                            openPreview(for: customImage)
                        }) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            let parts = splitKey(customImage.word)
                            selectImageForWord(parts.word, clarification: parts.clarification, replaceExisting: false)
                        }) {
                            Image(systemName: "photo.badge.plus")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            let parts = splitKey(customImage.word)
                            selectImageForWord(parts.word, clarification: parts.clarification, replaceExisting: true)
                        }) {
                            Image(systemName: "photo")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            let parts = splitKey(customImage.word)
                            randomWordList.removeCustomWordImage(word: parts.word, clarification: parts.clarification)
                            loadCustomImages()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: 200)

            HStack {
                TextField("Word (e.g., mama, papa)", text: $newWord)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Clarification (optional)", text: $newClarification)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    if !newWord.isEmpty {
                        selectImageForWord(newWord, clarification: newClarification, replaceExisting: false)
                    }
                }) {
                    Image(systemName: "plus")
                }
                .disabled(newWord.isEmpty)
            }

            Divider()
                .padding(.vertical, 8)

            HStack {
                Text("Quick Add:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Mama") {
                    addQuickWord("mama")
                }
                .buttonStyle(.plain)

                Button("Papa") {
                    addQuickWord("papa")
                }
                .buttonStyle(.plain)

                Button("Grandma") {
                    addQuickWord("grandma")
                }
                .buttonStyle(.plain)

                Button("Grandpa") {
                    addQuickWord("grandpa")
                }
                .buttonStyle(.plain)

                Button("Granddad") {
                    addQuickWord("granddad")
                }
                .buttonStyle(.plain)

                Button("GrandGrandma") {
                    addQuickWord("grandgrandma")
                }
                .buttonStyle(.plain)

                Button("GrandGrandpa") {
                    addQuickWord("grandgrandpa")
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 550, height: 450)
        .onAppear {
            centerMenuWindow()
            loadCustomImages()
        }
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
        }
        .sheet(isPresented: $showImagePreview) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Image Preview")
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        showImagePreview = false
                    }
                }

                if let imagePath = currentPreviewPath(),
                   let image = loadImageFromPath(imagePath) {
                    let rotation = currentPreviewRotation()
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(rotation))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Image not available")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Button(action: previousPreviewImage) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(previewImagePaths.count <= 1)

                    Text(previewImagePaths.isEmpty ? "0/0" : "\(previewImageIndex + 1)/\(previewImagePaths.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: nextPreviewImage) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(previewImagePaths.count <= 1)

                    Spacer()

                    Button(action: { rotatePreview(clockwise: false) }) {
                        Image(systemName: "rotate.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(previewImagePaths.isEmpty)

                    Button(action: { rotatePreview(clockwise: true) }) {
                        Image(systemName: "rotate.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(previewImagePaths.isEmpty)
                }
            }
            .padding()
            .frame(width: 640, height: 520)
            .onAppear {
                centerMenuWindow()
            }
        }
    }

    private func loadCustomImages() {
        customImages = randomWordList.customWordImages
    }

    private func addQuickWord(_ word: String) {
        // Check if word already exists
        if customImages.contains(where: { $0.word.lowercased() == word.lowercased() }) {
            // Just select new image
            selectImageForWord(word, clarification: "", replaceExisting: false)
        } else {
            newWord = word
            newClarification = ""
            selectImageForWord(word, clarification: "", replaceExisting: false)
        }
    }

    private func selectImageForWord(_ word: String, clarification: String, replaceExisting: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select an image for '\(word)'"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if replaceExisting {
                    randomWordList.setCustomWordImage(word: word, clarification: clarification, url: url)
                } else {
                    randomWordList.addCustomWordImage(word: word, clarification: clarification, url: url)
                }
                loadCustomImages()
                newWord = ""
                newClarification = ""
            }
        }
    }

    private func centerMenuWindow() {
        if let window = NSApp.windows.first(where: { $0.isSheet }) {
            window.center()
        }
    }

    private func displayLabel(for key: String) -> String {
        let parts = splitKey(key)
        if parts.clarification.isEmpty {
            return parts.word
        }
        return "\(parts.word) (\(parts.clarification))"
    }

    private func splitKey(_ key: String) -> (word: String, clarification: String) {
        let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        }
        return (key, "")
    }

    private func openPreview(for customImage: CustomWordImage) {
        previewWordKey = customImage.word
        previewImagePaths = customImage.imagePaths
        previewImageIndex = 0
        showImagePreview = true
    }

    private func currentPreviewPath() -> String? {
        guard previewImageIndex >= 0, previewImageIndex < previewImagePaths.count else { return nil }
        return previewImagePaths[previewImageIndex]
    }

    private func currentPreviewRotation() -> Double {
        guard let imagePath = currentPreviewPath() else { return 0.0 }
        let parts = splitKey(previewWordKey)
        return randomWordList.getCustomImageRotation(
            for: parts.word,
            clarification: parts.clarification,
            imagePath: imagePath
        )
    }

    private func rotatePreview(clockwise: Bool) {
        guard let imagePath = currentPreviewPath() else { return }
        let parts = splitKey(previewWordKey)
        randomWordList.rotateCustomWordImage(
            word: parts.word,
            clarification: parts.clarification,
            imagePath: imagePath,
            clockwise: clockwise
        )
        loadCustomImages()
    }

    private func previousPreviewImage() {
        guard !previewImagePaths.isEmpty else { return }
        previewImageIndex = (previewImageIndex - 1 + previewImagePaths.count) % previewImagePaths.count
    }

    private func nextPreviewImage() {
        guard !previewImagePaths.isEmpty else { return }
        previewImageIndex = (previewImageIndex + 1) % previewImagePaths.count
    }

    private func loadImageFromPath(_ path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        let image = NSImage(contentsOf: url)
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
        return image
    }
}

#Preview {
    ContentView(eventHandler: EventHandler(isLocked: false))
}

//
//  AdvancedSettingsView.swift
//  BabyKeyboardLock
//
//  Native macOS Settings window
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            SpeechSettingsView()
                .tabItem {
                    Label("Speech", systemImage: "waveform")
                }

            LibrarySettingsView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            MediaSettingsView()
                .tabItem {
                    Label("Media", systemImage: "photo.on.rectangle")
                }
        }
        .frame(width: 720, height: 560)
    }
}

struct GeneralSettingsView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @AppStorage("lockKeyboardOnLaunch") private var lockKeyboardOnLaunch: Bool = false
    @AppStorage("launchOnStartup") private var launchOnStartup: Bool = false {
        didSet {
            LaunchAtStartup.shared.setEnabled(launchOnStartup)
        }
    }
    @State private var babyName: String = ""
    @State private var babyNameTranslation: String = ""
    @State private var babyNameProbability: Double = 0.125

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Lock keyboard on launch", isOn: $lockKeyboardOnLaunch)
                Toggle("Launch on startup", isOn: $launchOnStartup)
            }

            Section("Baby Name") {
                TextField("Name", text: $babyName)
                    .onChange(of: babyName) { _, newValue in
                        randomWordList.setBabyName(newValue)
                    }

                TextField("Second language name", text: $babyNameTranslation)
                    .onChange(of: babyNameTranslation) { _, newValue in
                        randomWordList.setBabyNameTranslation(newValue)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Baby name frequency (random mode): \(String(format: "%.0f%%", babyNameProbability * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $babyNameProbability, in: 0...1, step: 0.01)
                        .onChange(of: babyNameProbability) { _, newValue in
                            randomWordList.setBabyNameProbability(newValue)
                        }
                }
            }

            Section("Shortcuts") {
                Text("Keyboard shortcut: Ctrl + Option + U")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            launchOnStartup = LaunchAtStartup.shared.isEnabled()
            babyName = randomWordList.babyName
            babyNameTranslation = randomWordList.babyNameTranslation
            babyNameProbability = randomWordList.babyNameProbability
        }
    }
}

struct SpeechSettingsView: View {
    @ObservedObject private var eventHandler: EventHandler = EventHandler.shared
    @AppStorage("usePersonalVoice") private var usePersonalVoice: Bool = false
    @AppStorage("wordsThrottleInterval") private var savedWordsThrottleInterval: Double = 1.5
    @AppStorage("selectedPrimaryLanguage") private var selectedPrimaryLanguage: TranslationLanguage = .english
    @AppStorage("selectedTranslationLanguage") private var selectedTranslationLanguage: TranslationLanguage = .none
    @AppStorage("wordTranslationDelay") private var wordTranslationDelay: Double = 0.8
    @AppStorage("wordDisplayDuration") private var wordDisplayDuration: Double = DEFAULT_WORD_DISPLAY_DURATION

    var body: some View {
        let primaryLanguages = TranslationLanguage.allCases.filter { $0 != .none }

        Form {
            Section("Language") {
                Picker("Primary", selection: $eventHandler.selectedPrimaryLanguage) {
                    ForEach(primaryLanguages) { language in
                        Text(language.localizedString)
                    }
                }
                .onChange(of: eventHandler.selectedPrimaryLanguage) { _, newValue in
                    selectedPrimaryLanguage = newValue
                }

                Picker("Secondary", selection: $eventHandler.selectedTranslationLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.localizedString)
                    }
                }
                .onChange(of: eventHandler.selectedTranslationLanguage) { _, newValue in
                    selectedTranslationLanguage = newValue
                }
            }

            Section("Voice") {
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
                        .buttonStyle(.plain)
                    }
                }
                .onChange(of: eventHandler.usePersonalVoice) { _, newValue in
                    usePersonalVoice = newValue
                }
            }

            Section("Timing") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Delay between words: \(String(format: "%.1f", eventHandler.wordsThrottleInterval))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $eventHandler.wordsThrottleInterval, in: 0.1...3.0, step: 0.1)
                        .onChange(of: eventHandler.wordsThrottleInterval) { _, newValue in
                            savedWordsThrottleInterval = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Secondary-language delay: \(String(format: "%.1f", wordTranslationDelay))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $wordTranslationDelay, in: 0.0...2.5, step: 0.1)
                        .onChange(of: wordTranslationDelay) { _, newValue in
                            eventHandler.wordTranslationDelay = newValue
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Word card duration: \(String(format: "%.1f", wordDisplayDuration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $wordDisplayDuration, in: 1.0...15.0, step: 0.5)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            eventHandler.usePersonalVoice = usePersonalVoice
            eventHandler.selectedPrimaryLanguage = selectedPrimaryLanguage
            eventHandler.selectedTranslationLanguage = selectedTranslationLanguage
            eventHandler.wordsThrottleInterval = savedWordsThrottleInterval
            eventHandler.wordTranslationDelay = wordTranslationDelay
        }
    }
}

struct LibrarySettingsView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @ObservedObject private var eventHandler: EventHandler = EventHandler.shared
    @AppStorage("selectedWordSetType") private var savedWordSetType: String = WordSetType.randomShortWords.rawValue
    @State private var showRandomWordEditor = false
    @State private var showMainWordsEditor = false
    @State private var learningPoolWindow: NSWindow?
    @State private var featuredWordsWindow: NSWindow?

    var body: some View {
        Form {
            Section("Word Source") {
                Picker("Mode", selection: Binding(
                    get: { randomWordList.wordSourceMode },
                    set: { randomWordList.setWordSourceMode($0) }
                )) {
                    ForEach(WordSourceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(randomWordList.wordSourceMode == .poolFeatured
                     ? "Mode 1 uses learning pool + featured topics + extra words."
                     : "Mode 2 uses explicit legacy set selection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Word Set Type") {
                Picker("Engine", selection: $eventHandler.selectedWordSetType) {
                    ForEach(WordSetType.allCases) { type in
                        Text(type.localizedString).tag(type)
                    }
                }
                .onChange(of: eventHandler.selectedWordSetType) { _, newValue in
                    savedWordSetType = newValue.rawValue
                }
            }

            if randomWordList.wordSourceMode == .poolFeatured {
                Section("Featured Topics") {
                    if randomWordList.allWordSetNamesSorted.isEmpty {
                        Text("No topics found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(randomWordList.allWordSetNamesSorted, id: \.self) { setName in
                            Toggle(
                                "\(setName) (\(randomWordList.wordCountForSet(named: setName)))",
                                isOn: Binding(
                                    get: { randomWordList.isTopicFeatured(setName: setName) },
                                    set: { randomWordList.setTopicFeatured($0, setName: setName) }
                                )
                            )
                        }
                    }
                }

                Section("Extra Pool Words") {
                    Text("\(randomWordList.getFeaturedWords().count) extra word(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Edit extra words") {
                        openFeaturedWordsWindow()
                    }
                    .buttonStyle(.plain)
                }

                Section("Pool Controls") {
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

                    HStack(spacing: 14) {
                        Button("Refresh pool now") {
                            randomWordList.refreshLearningPool(force: true)
                        }
                        .buttonStyle(.plain)

                        Button("Manage pool words") {
                            openLearningPoolWindow()
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Section("Legacy Sets") {
                    Text("\(randomWordList.enabledSetIndices.count) enabled (\(randomWordList.words.count) words)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Edit random sets") {
                        showRandomWordEditor = true
                    }
                    .buttonStyle(.plain)

                    Button("Edit main words") {
                        showMainWordsEditor = true
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .sheet(isPresented: $showRandomWordEditor) {
            RandomWordEditorView()
        }
        .sheet(isPresented: $showMainWordsEditor) {
            WordSetEditorView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeMenusRequested)) { _ in
            showRandomWordEditor = false
            showMainWordsEditor = false
        }
        .onAppear {
            if let parsed = WordSetType(rawValue: savedWordSetType) {
                eventHandler.selectedWordSetType = parsed
            }
        }
    }

    private func openLearningPoolWindow() {
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == LearningPoolWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            learningPoolWindow = existingWindow
            return
        }

        let host = NSHostingController(rootView: LearningWordEditorView(initialShowOnlyPool: true))
        let window = NSWindow(contentViewController: host)
        window.title = "Learning Rotation"
        window.identifier = NSUserInterfaceItemIdentifier(LearningPoolWindowID)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 520)
        window.setContentSize(NSSize(width: 1300, height: 850))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        learningPoolWindow = window
    }

    private func openFeaturedWordsWindow() {
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == FeaturedWordsWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            featuredWordsWindow = existingWindow
            return
        }

        let host = NSHostingController(rootView: FeaturedWordsEditorView())
        let window = NSWindow(contentViewController: host)
        window.title = "Featured Words"
        window.identifier = NSUserInterfaceItemIdentifier(FeaturedWordsWindowID)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 760, height: 520)
        window.setContentSize(NSSize(width: 920, height: 680))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        featuredWordsWindow = window
    }
}

struct MediaSettingsView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @AppStorage("showFlashcards") private var showFlashcards: Bool = false
    @AppStorage("showVideoCards") private var showVideoCards: Bool = false
    @AppStorage("videoCardDemoMode") private var videoCardDemoMode: Bool = false
    @AppStorage("videoCardDemoWord") private var videoCardDemoWord: String = "cat"
    @AppStorage("flashcardStyle") private var flashcardStyleStorage: String = FlashcardStyle.noImageToken
    @AppStorage("flashcardImageSize") private var flashcardImageSize: Double = 150.0
    @State private var babyImagePath: String = ""
    @State private var customImagesFolderStatus: String = ""
    @State private var showCustomWordImageEditor = false

    private var enabledFlashcardStyles: Set<FlashcardStyle> {
        FlashcardStyle.pool(from: flashcardStyleStorage)
    }

    private var flashcardStylesBinding: Binding<Set<FlashcardStyle>> {
        Binding(
            get: { enabledFlashcardStyles },
            set: { flashcardStyleStorage = FlashcardStyle.serializedPool($0) }
        )
    }

    var body: some View {
        Form {
            Section("Flashcards") {
                Toggle("Show Flashcards", isOn: $showFlashcards)

                if showFlashcards {
                    FlashcardStylePicker(enabledStyles: flashcardStylesBinding)
                        .disabled(videoCardDemoMode && showVideoCards)

                    Toggle("Show Video Cards", isOn: $showVideoCards)

                    if showVideoCards {
                        Toggle("Video Demo: Force Single Word", isOn: $videoCardDemoMode)
                        if videoCardDemoMode {
                            TextField("Demo word", text: $videoCardDemoWord)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Card size: \(Int(flashcardImageSize))px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $flashcardImageSize, in: 50...1000, step: 50)
                    }
                }
            }

            Section("Images") {
                HStack {
                    Text("Baby image")
                    Spacer()
                    if !babyImagePath.isEmpty {
                        Text(URL(fileURLWithPath: babyImagePath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 220, alignment: .trailing)
                    }

                    Button(babyImagePath.isEmpty ? "Select" : "Change") {
                        selectBabyImage()
                    }
                    .buttonStyle(.plain)

                    if !babyImagePath.isEmpty {
                        Button("Clear") {
                            babyImagePath = ""
                            randomWordList.setBabyImagePath("")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Other custom images")
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
                    Button("Manage") {
                        showCustomWordImageEditor = true
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Images Folder Sync") {
                HStack {
                    if randomWordList.customImagesFolderPath.isEmpty {
                        Text("No folder selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(URL(fileURLWithPath: randomWordList.customImagesFolderPath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button(randomWordList.customImagesFolderPath.isEmpty ? "Select folder" : "Change folder") {
                        selectCustomImagesFolder()
                    }
                    .buttonStyle(.plain)

                    Button("Sync now") {
                        syncCustomImagesFolder()
                    }
                    .buttonStyle(.plain)
                    .disabled(randomWordList.customImagesFolderPath.isEmpty)

                    if !randomWordList.customImagesFolderPath.isEmpty {
                        Button("Clear") {
                            clearCustomImagesFolder()
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !customImagesFolderStatus.isEmpty {
                    Text(customImagesFolderStatus)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .sheet(isPresented: $showCustomWordImageEditor) {
            CustomWordImageEditorView()
        }
        .onAppear {
            babyImagePath = randomWordList.babyImagePath
            customImagesFolderStatus = ""
            enforceDemoFlashcardStyleIfNeeded()
        }
        .onChange(of: videoCardDemoMode) { _, _ in
            enforceDemoFlashcardStyleIfNeeded()
        }
        .onChange(of: flashcardStyleStorage) { _, _ in
            enforceDemoFlashcardStyleIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeMenusRequested)) { _ in
            showCustomWordImageEditor = false
        }
    }

    private func enforceDemoFlashcardStyleIfNeeded() {
        guard videoCardDemoMode else { return }
        let simpleOnly = FlashcardStyle.serializedPool(Set([.simple]))
        if flashcardStyleStorage != simpleOnly {
            flashcardStyleStorage = simpleOnly
        }
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
                randomWordList.setBabyImageURL(url)
            }
        }
    }

    private func selectCustomImagesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Select a folder with word images/videos (filename should match word or word|meaning)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                randomWordList.setCustomImagesFolderURL(url)
                syncCustomImagesFolder()
            }
        }
    }

    private func syncCustomImagesFolder() {
        let imported = randomWordList.syncCustomImagesFromFolder()
        if imported == 0 {
            customImagesFolderStatus = "No new media files imported."
        } else {
            customImagesFolderStatus = "Imported \(imported) media file(s) from folder."
        }
    }

    private func clearCustomImagesFolder() {
        randomWordList.clearCustomImagesFolder()
        customImagesFolderStatus = "Folder sync disabled."
    }
}

struct VoiceSettingsView: View {
    @ObservedObject private var eventHandler: EventHandler = EventHandler.shared
    @AppStorage("usePersonalVoice") private var usePersonalVoice: Bool = false
    @AppStorage("wordsThrottleInterval") private var savedWordsThrottleInterval: Double = 1.5

    var body: some View {
        Form {
            Section("Voice") {
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
                        .buttonStyle(.plain)
                    }
                }
                .onChange(of: eventHandler.usePersonalVoice) { _, newValue in
                    usePersonalVoice = newValue
                }
            }

            Section("Word Timing") {
                Text("Delay between words (seconds)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Slider(value: $eventHandler.wordsThrottleInterval, in: 0.1...3.0, step: 0.1)
                        .onChange(of: eventHandler.wordsThrottleInterval) { _, newValue in
                            savedWordsThrottleInterval = newValue
                        }
                    Text(String(format: "%.1f", eventHandler.wordsThrottleInterval))
                        .frame(width: 35)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            eventHandler.usePersonalVoice = usePersonalVoice
        }
    }
}

struct LanguageSettingsView: View {
    @ObservedObject private var eventHandler: EventHandler = EventHandler.shared
    @AppStorage("selectedPrimaryLanguage") private var selectedPrimaryLanguage: TranslationLanguage = .english
    @AppStorage("selectedTranslationLanguage") private var selectedTranslationLanguage: TranslationLanguage = .none

    var body: some View {
        let primaryLanguages = TranslationLanguage.allCases.filter { $0 != .none }

        Form {
            Section("Language") {
                Picker("Primary", selection: $eventHandler.selectedPrimaryLanguage) {
                    ForEach(primaryLanguages) { language in
                        Text(language.localizedString)
                    }
                }
                .onChange(of: eventHandler.selectedPrimaryLanguage) { _, newValue in
                    selectedPrimaryLanguage = newValue
                }

                Picker("Secondary", selection: $eventHandler.selectedTranslationLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.localizedString)
                    }
                }
                .onChange(of: eventHandler.selectedTranslationLanguage) { _, newValue in
                    selectedTranslationLanguage = newValue
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct BabyProfileSettingsView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var babyName: String = ""
    @State private var babyNameTranslation: String = ""
    @State private var babyNameProbability: Double = 0.125
    @State private var babyImagePath: String = ""
    @State private var customImagesFolderStatus: String = ""
    @State private var showCustomWordImageEditor = false

    var body: some View {
        Form {
            Section("Baby Name") {
                TextField("Name", text: $babyName)
                    .onChange(of: babyName) { _, newValue in
                        randomWordList.setBabyName(newValue)
                    }

                TextField("Second language name", text: $babyNameTranslation)
                    .onChange(of: babyNameTranslation) { _, newValue in
                        randomWordList.setBabyNameTranslation(newValue)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Baby name frequency (random mode): \(String(format: "%.0f%%", babyNameProbability * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $babyNameProbability, in: 0...1, step: 0.01)
                        .onChange(of: babyNameProbability) { _, newValue in
                            randomWordList.setBabyNameProbability(newValue)
                        }
                }
            }

            Section("Images") {
                HStack {
                    Text("Baby image")
                    Spacer()
                    if !babyImagePath.isEmpty {
                        Text(URL(fileURLWithPath: babyImagePath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150, alignment: .trailing)
                    }

                    Button(babyImagePath.isEmpty ? "Select" : "Change") {
                        selectBabyImage()
                    }
                    .buttonStyle(.plain)

                    if !babyImagePath.isEmpty {
                        Button("Clear") {
                            babyImagePath = ""
                            randomWordList.setBabyImagePath("")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Other custom images")
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
                    Button("Manage") {
                        showCustomWordImageEditor = true
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Images Folder Sync") {
                HStack {
                    if randomWordList.customImagesFolderPath.isEmpty {
                        Text("No folder selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(URL(fileURLWithPath: randomWordList.customImagesFolderPath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button(randomWordList.customImagesFolderPath.isEmpty ? "Select folder" : "Change folder") {
                        selectCustomImagesFolder()
                    }
                    .buttonStyle(.plain)

                    Button("Sync now") {
                        syncCustomImagesFolder()
                    }
                    .buttonStyle(.plain)
                    .disabled(randomWordList.customImagesFolderPath.isEmpty)

                    if !randomWordList.customImagesFolderPath.isEmpty {
                        Button("Clear") {
                            clearCustomImagesFolder()
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !customImagesFolderStatus.isEmpty {
                    Text(customImagesFolderStatus)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .sheet(isPresented: $showCustomWordImageEditor) {
            CustomWordImageEditorView()
        }
        .onAppear {
            babyName = randomWordList.babyName
            babyNameTranslation = randomWordList.babyNameTranslation
            babyNameProbability = randomWordList.babyNameProbability
            babyImagePath = randomWordList.babyImagePath
            customImagesFolderStatus = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeMenusRequested)) { _ in
            showCustomWordImageEditor = false
        }
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
                randomWordList.setBabyImageURL(url)
            }
        }
    }

    private func selectCustomImagesFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Select a folder with word images/videos (filename should match word or word|meaning)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                randomWordList.setCustomImagesFolderURL(url)
                syncCustomImagesFolder()
            }
        }
    }

    private func syncCustomImagesFolder() {
        let imported = randomWordList.syncCustomImagesFromFolder()
        if imported == 0 {
            customImagesFolderStatus = "No new media files imported."
        } else {
            customImagesFolderStatus = "Imported \(imported) media file(s) from folder."
        }
    }

    private func clearCustomImagesFolder() {
        randomWordList.clearCustomImagesFolder()
        customImagesFolderStatus = "Folder sync disabled."
    }
}

struct LearningPoolSettingsView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var showActivePoolPreview = false
    @State private var learningPoolWindow: NSWindow?
    @State private var featuredWordsWindow: NSWindow?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        let poolInfo = randomWordList.getLearningPoolInfo()
        let lastSync = poolInfo.lastSync.map { dateFormatter.string(from: $0) } ?? "never"

        Form {
            Section("Featured Words") {
                let featuredCount = randomWordList.getFeaturedWords().count
                Text("\(featuredCount) featured word(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let updatedAt = randomWordList.getFeaturedWordsLastUpdated() {
                    Text("Last updated: \(dateFormatter.string(from: updatedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 14) {
                    Button("Edit featured words") {
                        openFeaturedWordsWindow()
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Rotation") {
                Toggle(
                    isOn: Binding(
                        get: { randomWordList.learningRotationEnabled },
                        set: { randomWordList.setLearningRotationEnabled($0) }
                    )
                ) {
                    Text("Learning Rotation")
                }

                Text("Pool: \(poolInfo.count) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(learningPoolTooltipText())

                Text("Refresh: daily (last: \(lastSync))")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Button("Refresh pool now") {
                        randomWordList.refreshLearningPool(force: true)
                    }
                    .buttonStyle(.plain)

                    Button("View active pool") {
                        showActivePoolPreview = true
                    }
                    .buttonStyle(.plain)

                    Button("Manage words") {
                        openLearningPoolWindow()
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Mix") {
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
                    let thresholdLabel = randomWordList.learningKnownViewsThreshold == 0
                        ? "off"
                        : "\(randomWordList.learningKnownViewsThreshold) views"
                    Text("Auto-mark known after: \(thresholdLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper(
                        value: Binding(
                            get: { randomWordList.learningKnownViewsThreshold },
                            set: { randomWordList.setLearningKnownViewsThreshold($0) }
                        ),
                        in: 0...200,
                        step: 1
                    ) {
                        Text("Threshold")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
            }

            Section("Data") {
                Button("Open Learning Data") {
                    randomWordList.openLearningDatabase()
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .sheet(isPresented: $showActivePoolPreview) {
            ActivePoolPreviewView(
                words: sortedLearningPoolWords(),
                onManageWords: {
                    openLearningPoolWindow()
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeMenusRequested)) { _ in
            showActivePoolPreview = false
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

    private func openLearningPoolWindow() {
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == LearningPoolWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            learningPoolWindow = existingWindow
            return
        }

        let host = NSHostingController(rootView: LearningWordEditorView(initialShowOnlyPool: true))
        let window = NSWindow(contentViewController: host)
        window.title = "Learning Rotation"
        window.identifier = NSUserInterfaceItemIdentifier(LearningPoolWindowID)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 520)
        window.setContentSize(NSSize(width: 1300, height: 850))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        learningPoolWindow = window
    }

    private func openFeaturedWordsWindow() {
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == FeaturedWordsWindowID }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            featuredWordsWindow = existingWindow
            return
        }

        let host = NSHostingController(rootView: FeaturedWordsEditorView())
        let window = NSWindow(contentViewController: host)
        window.title = "Featured Words"
        window.identifier = NSUserInterfaceItemIdentifier(FeaturedWordsWindowID)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 760, height: 520)
        window.setContentSize(NSSize(width: 920, height: 680))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        featuredWordsWindow = window
    }

    private func sortedLearningPoolWords() -> [LearningWord] {
        randomWordList.getCurrentLearningPool().sorted { lhs, rhs in
            lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
    }
}

struct FeaturedWordsEditorView: View {
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var query: String = ""
    @State private var translation: String = ""
    @State private var clarification: String = ""
    @State private var draftBatch: [RandomWord] = []

    private var suggestions: [FeaturedWordSuggestion] {
        randomWordList.featuredWordSuggestions(query: query)
    }

    private var hasExactSuggestion: Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return false }
        return suggestions.contains { suggestion in
            suggestion.word.english.lowercased() == normalizedQuery
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Featured Words")
                    .font(.headline)
                Spacer()
                Button("Apply batch") {
                    randomWordList.setFeaturedWordsBatch(draftBatch)
                }
                .buttonStyle(.plain)
                .disabled(draftBatch.isEmpty && randomWordList.getFeaturedWords().isEmpty)
            }

            Text("These words are always included in random mode and learning rotation.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Search existing words", text: $query)
                    .textFieldStyle(.roundedBorder)

                TextField("Translation (for new word)", text: $translation)
                    .textFieldStyle(.roundedBorder)

                TextField("Meaning / clarification", text: $clarification)
                    .textFieldStyle(.roundedBorder)
            }

            if !hasExactSuggestion {
                HStack(spacing: 8) {
                    Text("Not found in catalog.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add new word") {
                        addNewWordFromInput()
                    }
                    .buttonStyle(.plain)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if suggestions.isEmpty {
                        Text("Start typing to see hints.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List(suggestions) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayLabel(for: suggestion.word))
                                    Text(suggestion.word.translation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let definition = suggestion.definition,
                                       !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(definition)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    if suggestion.hasImage {
                                        Text("Has flashcard")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button("Add") {
                                    addWordToDraft(suggestion.word)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                        .listStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current batch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if draftBatch.isEmpty {
                        Text("No featured words yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(draftBatch) { word in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayLabel(for: word))
                                        Text(word.translation)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Remove") {
                                        draftBatch.removeAll { $0.id == word.id }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }

            HStack {
                Button("Restore last saved batch") {
                    draftBatch = randomWordList.getFeaturedWords()
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Clear batch") {
                    draftBatch = []
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .onAppear {
            draftBatch = randomWordList.getFeaturedWords()
        }
    }

    private func addWordToDraft(_ word: RandomWord) {
        if draftBatch.contains(where: { $0.id == word.id }) {
            return
        }
        draftBatch.append(word)
    }

    private func addNewWordFromInput() {
        let english = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let translated = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = clarification.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !english.isEmpty, !translated.isEmpty else { return }
        let newWord = randomWordList.upsertFeaturedWord(
            english: english,
            translation: translated,
            clarification: meaning.isEmpty ? nil : meaning
        )
        addWordToDraft(newWord)
        query = ""
        translation = ""
        clarification = ""
    }

    private func displayLabel(for word: RandomWord) -> String {
        let clarified = word.clarification?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if clarified.isEmpty {
            return word.english
        }
        return "\(word.english) (\(clarified))"
    }
}

#Preview {
    AdvancedSettingsView()
}

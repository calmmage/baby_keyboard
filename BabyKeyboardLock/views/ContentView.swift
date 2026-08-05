//
//  ContentView.swift
//  BabyKeyboardLock
//
//  Created by Fangxing Xiong on 15.12.2024.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

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
    @AppStorage("videoCardDemoMode") private var videoCardDemoMode: Bool = false
    @AppStorage("flashcardStyle") private var flashcardStyleStorage: String = FlashcardStyle.noImageToken

    @AppStorage("selectedLockEffect") var selectedLockEffect: LockEffect = .speakRandomWord
    @AppStorage("selectedWordSetType") var savedWordSetType: String = WordSetType.randomShortWords.rawValue
    @AppStorage("throttleInterval") private var savedThrottleInterval: Double = 1.0
    @AppStorage("confettiFadeTime") private var savedConfettiFadeTime: Double = 5.0

    @StateObject private var randomWordList = RandomWordList.shared

    @State var hoveringMoreButton: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar with lock toggle and quit button
            HStack {
                Toggle(isOn: lockKeyboardBinding) {
                    Label(
                        "Lock Keyboard",
                        image: eventHandler.isLocked ? "keyboard.locked" : "keyboard.unlocked"
                    )
                    .font(.title)
                    .foregroundColor(eventHandler.isBlockerReady ? .primary : .gray)
                }
                .toggleStyle(SwitchToggleStyle(tint: .red))
                // Unlock always allowed when locked; lock only when foundation is ready.
                // Avoids Toggle set→reject→get loops that AttributeGraph reports as cycles.
                .disabled(!eventHandler.isLocked && !eventHandler.isBlockerReady)
                .help(eventHandler.permissionStatusMessage)

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
                AccessibilityStatusPanel(eventHandler: eventHandler)
                
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
                    if eventHandler.selectedLockEffect == .speakRandomWord {
                        Toggle(isOn: Binding(
                            get: { eventHandler.gamifyRandomWordEnabled },
                            set: { eventHandler.setGamifyRandomWordEnabled($0) }
                        )) {
                            Text("Gamify: find the letter before reward")
                        }
                        .toggleStyle(CheckboxToggleStyle())
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Word source mode: \(randomWordList.wordSourceMode.title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if randomWordList.wordSourceMode == .legacySets {
                            Text("Legacy sets: \(randomWordList.enabledWordSetNames)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Featured topics: \(randomWordList.featuredTopicSummary)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Extra words: \(randomWordList.getFeaturedWords().count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Word, speech, and media controls moved to Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SettingsLink {
                            Text("Open Settings")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
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
                    Text("Typing languages, set mode, and flashcards are in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SettingsLink {
                        Text("Open Settings")
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard shortcut: Ctrl + Option + U")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        SettingsLink {
                            Text("Settings")
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        Button("Shared library") {
                            SharedLibraryView().openInWindow(
                                title: "Daria Shared Library",
                                id: SharedLibraryWindowID,
                                sender: self,
                                focus: true
                            )
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
            // Set initial category based on current effect
            selectedCategory = eventHandler.selectedLockEffect.category

            // Set speak random word as default for word mode
            if selectedCategory == .words && eventHandler.selectedLockEffect == .speakAKeyWord {
                eventHandler.selectedLockEffect = .speakRandomWord
            }

            enforceDemoFlashcardStyleIfNeeded()

            // Refresh silent status only — launch prompt is owned by EventHandler.run()
            // so we do not stack multiple system dialogs on appear.
            eventHandler.refreshPermissionStatus()
        }
        // Single isLocked observer (was onChange + onReceive + Toggle onChange → triple fire).
        .onChange(of: eventHandler.isLocked) { _, newVal in
            playLockSound(isLocked: newVal)
        }
        .onChange(of: eventHandler.selectedLockEffect) { oldVal, newVal in
            selectedLockEffect = newVal
        }
        .onChange(of: videoCardDemoMode) { _, _ in
            enforceDemoFlashcardStyleIfNeeded()
        }
        .onChange(of: flashcardStyleStorage) { _, _ in
            enforceDemoFlashcardStyleIfNeeded()
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
    }

    /// Binding that never no-ops into a rejected Toggle write (setLocked is idempotent).
    private var lockKeyboardBinding: Binding<Bool> {
        Binding(
            get: { eventHandler.isLocked },
            set: { newValue in
                guard newValue != eventHandler.isLocked else { return }
                eventHandler.setLocked(isLocked: newValue)
            }
        )
    }

    private func playLockSound(isLocked: Bool) {
        if isLocked {
            NSSound(named: "light-switch-on")?.play()
        } else {
            guard let nsSound = NSSound(named: "light-switch-off") else { return }

            nsSound.play()
        }
    }

    private func enforceDemoFlashcardStyleIfNeeded() {
        guard videoCardDemoMode else { return }
        let simpleOnly = FlashcardStyle.serializedPool(Set([.simple]))
        if flashcardStyleStorage != simpleOnly {
            flashcardStyleStorage = simpleOnly
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

/// In-app Accessibility + event-tap status with actionable instructions.
struct AccessibilityStatusPanel: View {
    @ObservedObject var eventHandler: EventHandler
    @State private var showDiagnostics = false
    /// Cached so body evaluation never shells out to codesign / rebuild diagnostics mid-render.
    @State private var instructionLines: [String] = []
    @State private var diagnosticLines: [String] = []

    private var needsAttention: Bool {
        !eventHandler.accessibilityPermissionGranted || !eventHandler.eventTapState.isBlockingReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                    .foregroundColor(statusColor)
                Text(statusTitle)
                    .font(.headline)
                Spacer()
            }

            Text(eventHandler.permissionStatusMessage)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                statusChip(
                    title: "Accessibility",
                    ok: eventHandler.accessibilityPermissionGranted
                )
                statusChip(
                    title: "Event tap",
                    ok: eventHandler.eventTapState.isBlockingReady,
                    detail: eventHandler.eventTapState.statusLabel
                )
                statusChip(
                    title: "Lock",
                    ok: eventHandler.isLocked,
                    detail: eventHandler.isLocked ? "on" : "off"
                )
            }

            if needsAttention {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(instructionLines.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button("Grant Accessibility Access") {
                        NSApp.activate(ignoringOtherApps: true)
                        _ = eventHandler.requestAccessibilityPermissions(prompt: true)
                        refreshCachedDiagnostics()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open System Settings…") {
                        AccessibilityPermission.openSystemSettingsAccessibilityPane()
                    }

                    Button("Recheck") {
                        eventHandler.refreshPermissionStatus()
                        if eventHandler.accessibilityPermissionGranted {
                            eventHandler.startEventLoop()
                        }
                        refreshCachedDiagnostics()
                    }
                }
            }

            DisclosureGroup("Diagnostics (signing / path / bundle)", isExpanded: $showDiagnostics) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(diagnosticLines, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Text("Note: Debug and Release are different bundle IDs in System Settings.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(needsAttention ? Color.orange.opacity(0.12) : Color.green.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(needsAttention ? Color.orange.opacity(0.35) : Color.green.opacity(0.25), lineWidth: 1)
        )
        .onAppear { refreshCachedDiagnostics() }
        .onChange(of: eventHandler.accessibilityPermissionGranted) { _, _ in refreshCachedDiagnostics() }
        .onChange(of: eventHandler.eventTapState) { _, _ in refreshCachedDiagnostics() }
        .onChange(of: eventHandler.isLocked) { _, _ in refreshCachedDiagnostics() }
        .onChange(of: eventHandler.permissionStatusMessage) { _, _ in
            // Status line can change without trust/tap transitions (e.g. lock messages).
            // Instructions/summary usually stable; only refresh when attention surface needs it.
            if needsAttention || showDiagnostics {
                refreshCachedDiagnostics()
            }
        }
    }

    private func refreshCachedDiagnostics() {
        let diag = eventHandler.currentDiagnostics()
        instructionLines = diag.instructions
        diagnosticLines = diag.summaryLines
    }

    private var statusTitle: String {
        if !eventHandler.accessibilityPermissionGranted {
            return "Accessibility required"
        }
        if !eventHandler.eventTapState.isBlockingReady {
            return "Event tap not ready"
        }
        return "Blocker foundation ready"
    }

    private var statusSymbol: String {
        if eventHandler.isBlockerReady {
            return "checkmark.shield.fill"
        }
        if eventHandler.accessibilityPermissionGranted {
            return "exclamationmark.shield.fill"
        }
        return "lock.shield.fill"
    }

    private var statusColor: Color {
        if eventHandler.isBlockerReady { return .green }
        if eventHandler.accessibilityPermissionGranted { return .orange }
        return .red
    }

    private func statusChip(title: String, ok: Bool, detail: String? = nil) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ok ? Color.green : Color.red.opacity(0.85))
                .frame(width: 7, height: 7)
            Text(detail.map { "\(title): \($0)" } ?? "\(title): \(ok ? "ok" : "no")")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }
}

struct ActivePoolPreviewView: View {
    let words: [LearningWord]
    let onManageWords: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredWords: [LearningWord] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return words
        }
        let normalizedQuery = query.lowercased()
        return words.filter { word in
            displayLabel(for: word).lowercased().contains(normalizedQuery) ||
            word.translation.lowercased().contains(normalizedQuery)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Pool")
                    .font(.headline)
                Text("\(filteredWords.count)/\(words.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Copy list") {
                    copyCurrentListToClipboard()
                }
                .buttonStyle(.plain)

                Button("Manage words") {
                    onManageWords()
                    dismiss()
                }
                .buttonStyle(.plain)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            TextField("Filter by word or translation", text: $query)
                .textFieldStyle(.roundedBorder)

            if filteredWords.isEmpty {
                Text("No words in the current pool.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(filteredWords) { word in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayLabel(for: word))
                            if !word.translation.isEmpty {
                                Text(word.translation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("seen \(word.seenCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .frame(width: 720, height: 520)
    }

    private func displayLabel(for word: LearningWord) -> String {
        let clarification = word.clarification.trimmingCharacters(in: .whitespacesAndNewlines)
        if clarification.isEmpty {
            return word.word
        }
        return "\(word.word) (\(clarification))"
    }

    private func copyCurrentListToClipboard() {
        let lines = filteredWords.map { word in
            let label = displayLabel(for: word)
            if word.translation.isEmpty {
                return label
            }
            return "\(label) - \(word.translation)"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
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

                Button("Brother") {
                    addQuickWord("brother")
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
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .movie]
        panel.message = replaceExisting
            ? "Select one or more images/videos to replace '\(word)'"
            : "Select one or more images/videos for '\(word)'"

        panel.begin { response in
            if response == .OK {
                let selectedURLs = panel.urls
                guard !selectedURLs.isEmpty else { return }

                if replaceExisting {
                    randomWordList.setCustomWordImage(
                        word: word,
                        clarification: clarification,
                        url: selectedURLs[0]
                    )
                    if selectedURLs.count > 1 {
                        for url in selectedURLs.dropFirst() {
                            randomWordList.addCustomWordImage(
                                word: word,
                                clarification: clarification,
                                url: url
                            )
                        }
                    }
                } else {
                    for url in selectedURLs {
                        randomWordList.addCustomWordImage(
                            word: word,
                            clarification: clarification,
                            url: url
                        )
                    }
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

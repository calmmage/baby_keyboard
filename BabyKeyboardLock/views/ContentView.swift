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
    
    @AppStorage("lockKeyboardOnLaunch") private var lockKeyboardOnLaunch: Bool = false
    @AppStorage("selectedLockEffect") var selectedLockEffect: LockEffect = .none
    @AppStorage("selectedTranslationLanguage") var selectedTranslationLanguage: TranslationLanguage = .none
    @AppStorage("selectedWordSetType") var savedWordSetType: String = WordSetType.randomShortWords.rawValue
    @AppStorage("wordDisplayDuration") var wordDisplayDuration: Double = DEFAULT_WORD_DISPLAY_DURATION
    @AppStorage("usePersonalVoice") var usePersonalVoice: Bool = false
    
    @State private var showWordSetEditor = false
    @State private var showRandomWordEditor = false
    @StateObject private var customWordSetsManager = CustomWordSetsManager.shared
    
    @State var hoveringMoreButton: Bool = false
    @State private var babyName: String = ""
    
    var body: some View {
       VStack(alignment: .leading, spacing: 22) {
            HStack{
                Spacer() // push the button to right
                Menu() {
                    Button("About") {
                        AboutView().openInWindow(id: "About", sender: self, focus: true)
                    }
                    
                    Button("Quit \(Bundle.applicationName)") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Label("", systemImage: "ellipsis").font(.callout)
                        .onHover { _ in
                            // TODO
                        }
                }
                .menuStyle(HoverableMenuStyle())
                .menuStyle(BorderlessButtonMenuStyle())
                .apply {
                    if #available(macOS 12.0, *) {
                          $0.menuIndicator(.hidden)
                      } else {
                          $0
                      }
                }
                .fixedSize()
                .onHover { _ in
                    hoveringMoreButton = true
                }
            }
            
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
            .scaledToFill()
            .disabled(!eventHandler.accessibilityPermissionGranted)
            .padding(.bottom, eventHandler.accessibilityPermissionGranted ? 20 : 5)
            .onChange(of: eventHandler.isLocked) { oldVal, newVal in
                playLockSound(isLocked: newVal)
            }.onAppear(){
                if eventHandler.isLocked {
                    playLockSound(isLocked: true)
                }
            }
            
            if !eventHandler.accessibilityPermissionGranted {
                Text("accessibility_permission_grant_hint \(Bundle.applicationName)")
                    .opacity(eventHandler.accessibilityPermissionGranted ? 0 : 1)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker("Effect", selection: $eventHandler.selectedLockEffect) {
                ForEach(LockEffect.allCases) { effect in
                    Text(effect.localizedString)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: eventHandler.selectedLockEffect) { oldVal, newVal in
                selectedLockEffect = newVal
            }
            
            // Add Personal Voice option for effects that use speech
            if eventHandler.selectedLockEffect == .speakTheKey || 
               eventHandler.selectedLockEffect == .speakAKeyWord || 
               eventHandler.selectedLockEffect == .speakRandomWord {
                
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
            }
            
            if eventHandler.selectedLockEffect == .speakAKeyWord {
                Picker("Translation", selection: $eventHandler.selectedTranslationLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.localizedString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: eventHandler.selectedTranslationLanguage) { oldVal, newVal in
                    selectedTranslationLanguage = newVal
                }
                
                // Baby's name input field
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
                
                // Word set selection
                Picker("Word Set", selection: $eventHandler.selectedWordSetType) {
                    ForEach(WordSetType.allCases) { type in
                        Text(type.localizedString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: eventHandler.selectedWordSetType) { oldVal, newVal in
                    savedWordSetType = newVal.rawValue
                    if newVal == .mainWords && customWordSetsManager.wordSets.isEmpty {
                        // If switching to mainWords but no sets exist, show editor
                        showWordSetEditor = true
                    }
                }
                
                if eventHandler.selectedWordSetType == .mainWords {
                    HStack {
                        Text("Main words")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            showWordSetEditor = true
                        }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let currentSet = customWordSetsManager.currentWordSet {
                        Text("Contains \(currentSet.words.count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Word display duration settings - moved outside the if block to always appear in speakAKeyWord mode
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
            }
            
            if eventHandler.selectedLockEffect == .speakRandomWord {
                Picker("Translation", selection: $eventHandler.selectedTranslationLanguage) {
                    ForEach(TranslationLanguage.allCases) { language in
                        Text(language.localizedString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: eventHandler.selectedTranslationLanguage) { oldVal, newVal in
                    selectedTranslationLanguage = newVal
                }
                
                // Baby's name input field
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
                    Text("Random words")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: {
                        showRandomWordEditor = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text("Contains \(RandomWordList.shared.words.count) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            }
            
            Toggle(isOn: $lockKeyboardOnLaunch) {
                Text("Lock keyboard on launch")
            }
            .toggleStyle(CheckboxToggleStyle())
            // .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            Text("unlock_shortcut_hint")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 300, height: 600)
        .onChange(of: eventHandler.isLocked) { oldVal, newVal in
            showOrCloseAnimationWindow(isLocked: newVal)
        }.onReceive(eventHandler.$isLocked) { newVal in
            showOrCloseAnimationWindow(isLocked: newVal)
        }.onAppear() {
            // Update the event handler with the saved word set type
            if let type = WordSetType(rawValue: savedWordSetType) {
                eventHandler.selectedWordSetType = type
            }
            
            // Load the baby's name
            babyName = RandomWordList.shared.babyName
            
            // Update personal voice setting
            eventHandler.usePersonalVoice = usePersonalVoice
            
            debugPrint("onAppear --- ")
            // Check if main window exists but don't create an unused variable
            _ = NSApp.windows.first(where: { $0.identifier?.rawValue == MainWindowID })
        }
        .sheet(isPresented: $showWordSetEditor) {
            WordSetEditorView()
        }
        .sheet(isPresented: $showRandomWordEditor) {
            RandomWordEditorView()
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
            Text("Main Words")
                .font(.headline)
            
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
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
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
            if let currentSet = customWordSetsManager.currentWordSet {
                words = currentSet.words
            }
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
}

#Preview {
    ContentView(eventHandler: EventHandler(isLocked: false))
}

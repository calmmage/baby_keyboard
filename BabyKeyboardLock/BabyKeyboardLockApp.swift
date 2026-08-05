//
//  BabyKeyboardLockApp.swift
//  BabyKeyboardLock
//
//  Created by Fangxing Xiong on 15.12.2024.
//

import SwiftUI
import Combine

let AnimationWindowID = "animationTransparentWindow"
let WordDisplayWindowID = "wordDisplayTransparentWindow"
let VisualEffectsWindowID = "visualEffectsTransparentWindow"
let MainWindowID = "main"
let LearningPoolWindowID = "learningPoolWindow"
let FeaturedWordsWindowID = "featuredWordsWindow"

@main
struct BabyKeyboardLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isLaunched: Bool = false
    
    @AppStorage("lockKeyboardOnLaunch") var lockKeyboardOnLaunch = false
    @AppStorage("selectedLockEffect") var selectedLockEffect: LockEffect = .speakRandomWord
    @AppStorage("selectedPrimaryLanguage") var selectedPrimaryLanguage: TranslationLanguage = .english
    @AppStorage("selectedTranslationLanguage") var selectedTranslationLanguage: TranslationLanguage = .none
    @ObservedObject var eventHandler: EventHandler = EventHandler.shared

    var body: some Scene {
        Settings {
            AdvancedSettingsView()
        }
    }
    
    init() {
        eventHandler.setLocked(isLocked: lockKeyboardOnLaunch)
        eventHandler.selectedLockEffect = selectedLockEffect
        eventHandler.selectedPrimaryLanguage = selectedPrimaryLanguage
        eventHandler.selectedTranslationLanguage = selectedTranslationLanguage
    }
}

// hide from dock
// https://stackoverflow.com/questions/70697737/hide-app-icon-from-macos-menubar-on-launch
// https://stackoverflow.com/questions/68884499/make-swiftui-app-appear-in-the-macos-dock
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: Any?
    
    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// <#Description#>
    /// - Parameter notification: <#notification description#>
    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app (LSUIElement): stay out of the Dock, but keep a real main window.
        // Do not switch to .regular — that would add a Dock icon and change activation semantics.
        NSApp.setActivationPolicy(.accessory)

        // Add screen configuration change observer
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowFrames()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(named: EventHandler.shared.isLocked ? "keyboard.locked" : "keyboard.unlocked")
            statusButton.image?.accessibilityDescription = Bundle.applicationName
            statusButton.sendAction(on: [.rightMouseUp, .leftMouseUp])
            statusButton.target = self
            statusButton.action = #selector(handleStatusBarClick)
        }
        
        // Add observer for isLocked changes
        EventHandler.shared.$isLocked
            .sink { [weak self] isLocked in
                if let statusButton = self?.statusItem.button {
                    statusButton.image = NSImage(named: isLocked ? "keyboard.locked" : "keyboard.unlocked")
                }
            }
            .store(in: &cancellables)

        // Show the real settings window first so AX prompt / System Settings handoff
        // has a visible owner window, then start the event-tap foundation.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.35) {
            self.showMainWindow()
            EventHandler.shared.run()
            self.validateCatalogTranslations()
            self.installOverlayWindows()
        }
    }

    /// Transparent effect overlays — never become the only "app window".
    private func installOverlayWindows() {
        // Create the animation window for confetti animations
        let animationWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 1200, height: NSScreen.main?.frame.height ?? 800),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        animationWindow.identifier = NSUserInterfaceItemIdentifier(AnimationWindowID)
        animationWindow.backgroundColor = .clear
        animationWindow.isReleasedWhenClosed = false
        animationWindow.center()
        animationWindow.setFrameAutosaveName("Animation Window")
        animationWindow.contentView = NSHostingView(rootView: AnimationView())
        animationWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationWindow.orderFrontRegardless()

        // Create the word display window for showing words and translations
        let wordDisplayWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 1200, height: NSScreen.main?.frame.height ?? 800),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        wordDisplayWindow.identifier = NSUserInterfaceItemIdentifier(WordDisplayWindowID)
        wordDisplayWindow.backgroundColor = .clear
        wordDisplayWindow.isReleasedWhenClosed = false
        wordDisplayWindow.center()
        wordDisplayWindow.setFrameAutosaveName("Word Display Window")
        wordDisplayWindow.contentView = NSHostingView(rootView: WordDisplayView())
        wordDisplayWindow.level = .floating // Ensure it appears above other windows
        wordDisplayWindow.ignoresMouseEvents = true // Prevent mouse interaction
        wordDisplayWindow.titlebarAppearsTransparent = true
        wordDisplayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        wordDisplayWindow.orderFrontRegardless()

        // Create the visual effects window for additional animations
        let visualEffectsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 1200, height: NSScreen.main?.frame.height ?? 800),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        visualEffectsWindow.identifier = NSUserInterfaceItemIdentifier(VisualEffectsWindowID)
        visualEffectsWindow.backgroundColor = .clear
        visualEffectsWindow.isReleasedWhenClosed = false
        visualEffectsWindow.center()
        visualEffectsWindow.setFrameAutosaveName("Visual Effects Window")
        visualEffectsWindow.contentView = NSHostingView(rootView: VisualEffectsView())
        visualEffectsWindow.level = .floating
        visualEffectsWindow.ignoresMouseEvents = true
        visualEffectsWindow.titlebarAppearsTransparent = true
        visualEffectsWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        visualEffectsWindow.orderFrontRegardless()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        EventHandler.shared.stop()
        debugPrint("-------- applicationWillTerminate --------")
    }

    func showMainWindow() {
        if let window = mainWindow {
            configureMainWindow(window)
            positionMainWindowTopRight(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView(eventHandler: EventHandler.shared)
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = Bundle.applicationName
        window.identifier = NSUserInterfaceItemIdentifier(MainWindowID)
        window.setFrameAutosaveName("Main Window")
        window.isReleasedWhenClosed = false
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        configureMainWindow(window)
        // Sensible default so first launch is not a tiny empty chrome.
        if window.frame.width < 480 || window.frame.height < 520 {
            window.setContentSize(NSSize(width: 520, height: 640))
        }
        positionMainWindowTopRight(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    private func configureMainWindow(_ window: NSWindow) {
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.level = .normal
        window.isOpaque = true
        // Closing the main window must not kill the menu-bar blocker.
        window.isReleasedWhenClosed = false
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }
    
    @discardableResult
    func hidePopover() -> Bool {
        return false
    }
    
    @objc func handleStatusBarClick(_ sender: NSStatusBarButton? = nil) {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .leftMouseUp:
            EventHandler.shared.setLocked(isLocked: !EventHandler.shared.isLocked)
        case .rightMouseUp:
            // if popover.isShown {
            //     hidePopover()
            // } else {
                showMainWindow()
            // }
        default:
            return
        }
    }
    
    private func updateWindowFrames() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = NSRect(x: 0, y: 0, width: mainScreen.frame.width, height: mainScreen.frame.height)
        
        // Update all transparent windows
        NSApp.windows.forEach { window in
            if let identifier = window.identifier?.rawValue,
               [AnimationWindowID, WordDisplayWindowID, VisualEffectsWindowID].contains(identifier) {
                window.setFrame(frame, display: true)
            }
        }
    }

    private func positionMainWindowTopRight(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let inset: CGFloat = 20
        let origin = NSPoint(
            x: visibleFrame.maxX - window.frame.width - inset,
            y: visibleFrame.maxY - window.frame.height - inset
        )
        window.setFrameOrigin(origin)
    }

    private func validateCatalogTranslations() {
        let requiredLanguages = ["ru", "de", "fr", "es", "it", "ja", "zh"]
        let missingCounts = WordRepository.shared.missingTranslationCounts(languageCodes: requiredLanguages)
        let missingSummary = requiredLanguages.compactMap { language -> String? in
            guard let count = missingCounts[language], count > 0 else { return nil }
            return "\(language): \(count)"
        }

        guard !missingSummary.isEmpty else { return }
        let message = "Catalog has missing translations (\(missingSummary.joined(separator: ", ")))."
        NSLog("%@", "WARNING: \(message)")
    }
}

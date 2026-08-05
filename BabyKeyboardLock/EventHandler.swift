import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import CoreData
import SwiftData
import Combine
import AVFoundation

extension Notification.Name {
    static let closeMenusRequested = Notification.Name("CloseMenusRequested")
    static let criticalDataWarning = Notification.Name("CriticalDataWarning")
    static let learningRewardEarned = Notification.Name("LearningRewardEarned")
}

enum KeyCode: CGKeyCode, CaseIterable, Identifiable {
    case u = 0x20
    case delete = 0x33
    case up = 0x7e
    case left = 0x7b
    case right = 0x7c
    case down = 0x7d
    case escape = 0x35
    case tab = 0x30
    case enter = 0x24
    
    var id: Self {
        return self
    }
}

class EventHandler: ObservableObject {
    private let lock = NSLock()
    let eventEffectHandler = EventEffectHandler()
    private var eventLoopStarted = false
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var accessibilityPollWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var selectedLockEffect: LockEffect = .none
    @Published var selectedPrimaryLanguage: TranslationLanguage = .english {
        didSet {
            eventEffectHandler.primaryLanguage = selectedPrimaryLanguage
        }
    }
    @Published var selectedTranslationLanguage: TranslationLanguage = .none {
        didSet {
            eventEffectHandler.translationLanguage = selectedTranslationLanguage
        }
    }
    @Published var selectedWordSetType: WordSetType = .randomShortWords {
        didSet {
            eventEffectHandler.setWordSetType(selectedWordSetType)
        }
    }
    @Published var gamifyRandomWordEnabled: Bool = false
    @Published var gamifyRandomWordTarget: String = ""
    @Published var usePersonalVoice: Bool = false {
        didSet {
            eventEffectHandler.usePersonalVoice = usePersonalVoice
            if usePersonalVoice {
                requestPersonalVoicePermission()
            }
        }
    }
    @Published var isLocked = true
    @Published var accessibilityPermissionGranted = false
    /// Event-tap lifecycle for UI + diagnostics (never fatal-errors the process).
    @Published var eventTapState: EventTapLifecycleState = .notStarted
    /// Last human-readable permission / tap status line for the main window.
    @Published var permissionStatusMessage: String = "Checking Accessibility permission…"
    @Published var personalVoiceAvailable: Bool = false
    @Published var lastKeyString: String = "a" // fix onReceive won't work as expected for first key press

    private var lastEventTime: Date = Date()
    @Published var throttleInterval: TimeInterval = 1.0 // seconds (for visual effects)
    @Published var wordsThrottleInterval: TimeInterval = 1.5 // seconds (for word effects)
    @Published var confettiFadeTime: TimeInterval = 3.0 // seconds
    @Published var wordTranslationDelay: TimeInterval = 0.8 // seconds
    private var gamifyRewardCooldownUntil: Date?
    
    private func isThrottled(effectType: LockEffect) -> Bool {
        let now = Date()
        let timeSinceLastEvent = now.timeIntervalSince(lastEventTime)
        
        // Use different throttle intervals based on effect category
        let currentThrottleInterval = effectType.category == .words ? wordsThrottleInterval : throttleInterval
      
        if timeSinceLastEvent >= currentThrottleInterval {
            lastEventTime = now
            return false
        }
        debugPrint("Throttled >>>>> timeSinceLastEvent: \(String(format: "%.2f", timeSinceLastEvent)), threshold: \(String(format: "%.2f", currentThrottleInterval))")
        return true
    }
    
    static let shared = EventHandler()
    
    init(isLocked: Bool = true) {
        self.isLocked = isLocked
        // Silent check only — never prompt from init (avoids dialog spam / behind-window prompts).
        self.accessibilityPermissionGranted = AccessibilityPermission.isTrusted()
        if !self.accessibilityPermissionGranted {
            self.isLocked = false
            self.permissionStatusMessage = "Accessibility permission required to lock the keyboard."
        } else {
            self.permissionStatusMessage = "Accessibility permission granted."
        }
        self.lastKeyString = lastKeyString
        
        // Initialize throttle interval from UserDefaults
        self.throttleInterval = UserDefaults.standard.double(forKey: "throttleInterval")
        if self.throttleInterval == 0 { // If not set yet
            self.throttleInterval = 1.0
        }
        
        // Initialize words throttle interval from UserDefaults
        self.wordsThrottleInterval = UserDefaults.standard.double(forKey: "wordsThrottleInterval")
        if self.wordsThrottleInterval == 0 { // If not set yet
            self.wordsThrottleInterval = 1.5
        }
        
        // Initialize fade time from UserDefaults
        self.confettiFadeTime = UserDefaults.standard.double(forKey: "confettiFadeTime")
        if self.confettiFadeTime == 0 { // If not set yet
            self.confettiFadeTime = 3.0
        }

        // Initialize word translation delay from UserDefaults
        self.wordTranslationDelay = UserDefaults.standard.double(forKey: "wordTranslationDelay")
        if self.wordTranslationDelay == 0 { // If not set yet
            self.wordTranslationDelay = 0.8
        }
        
        // Initialize wordSetType from UserDefaults
        if let savedTypeRaw = UserDefaults.standard.string(forKey: "selectedWordSetType"),
           let savedType = WordSetType(rawValue: savedTypeRaw) {
            self.selectedWordSetType = savedType
        }
        eventEffectHandler.setWordSetType(self.selectedWordSetType)

        if let savedPrimaryRaw = UserDefaults.standard.string(forKey: "selectedPrimaryLanguage"),
           let savedPrimary = TranslationLanguage(rawValue: savedPrimaryRaw) {
            self.selectedPrimaryLanguage = savedPrimary
        }
        eventEffectHandler.primaryLanguage = self.selectedPrimaryLanguage

        if let savedSecondaryRaw = UserDefaults.standard.string(forKey: "selectedTranslationLanguage"),
           let savedSecondary = TranslationLanguage(rawValue: savedSecondaryRaw) {
            self.selectedTranslationLanguage = savedSecondary
        }
        eventEffectHandler.translationLanguage = self.selectedTranslationLanguage

        self.gamifyRandomWordEnabled = UserDefaults.standard.bool(forKey: "gamifyRandomWordEnabled")
        eventEffectHandler.setGamifyRandomWordEnabled(self.gamifyRandomWordEnabled)
        self.gamifyRandomWordTarget = eventEffectHandler.getGamifyTargetLetter()
        
        // Initialize personal voice setting from UserDefaults
        self.usePersonalVoice = UserDefaults.standard.bool(forKey: "usePersonalVoice")
        eventEffectHandler.usePersonalVoice = self.usePersonalVoice
        
        // Check if personal voice is available
        if self.usePersonalVoice {
            checkPersonalVoiceAvailability()
        }
        
        // Observe changes to the main words set
        NotificationCenter.default.publisher(for: .init("MainWordsUpdated"))
            .sink { [weak self] _ in
                // Refresh UI when main words change
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe changes to the random words list
        NotificationCenter.default.publisher(for: .init("RandomWordsUpdated"))
            .sink { [weak self] _ in
                // Refresh UI when random words change
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Lock only when Accessibility is granted AND the event tap is ready (or can start).
    /// Published fields are only written when the value actually changes (avoids SwiftUI thrash/cycles).
    func setLocked(isLocked: Bool) {
        if isLocked {
            guard accessibilityPermissionGranted else {
                assignIsLocked(false)
                assignPermissionStatusMessage("Cannot lock: grant Accessibility permission first.")
                return
            }
            if !eventLoopStarted {
                startEventLoop()
            }
            guard eventTapState.isBlockingReady else {
                assignIsLocked(false)
                assignPermissionStatusMessage("Cannot lock: event tap is \(eventTapState.statusLabel).")
                return
            }
            assignIsLocked(true)
            assignPermissionStatusMessage("Keyboard locked. Unlock via toggle, menu bar, or Ctrl+Option+U.")
        } else {
            assignIsLocked(false)
            if accessibilityPermissionGranted {
                assignPermissionStatusMessage("Keyboard unlocked.")
            }
        }
    }

    /// Whether the blocker can safely intercept keys right now.
    var isBlockerReady: Bool {
        accessibilityPermissionGranted && eventTapState.isBlockingReady
    }

    func refreshPermissionStatus() {
        let trusted = AccessibilityPermission.isTrusted()
        applyTrustState(trusted: trusted, source: "refresh")
    }

    func currentDiagnostics() -> AccessibilityRuntimeDiagnostics {
        AccessibilityPermission.diagnostics(eventTapState: eventTapState, isLocked: isLocked)
    }

    func checkAccessibilityPermission() {
        debugPrint("------ Checking Accessibility Permission ------")
        // Heal a system-disabled tap without tearing everything down.
        if let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) {
            debugPrint("Event tap disabled by system, re-enabling…")
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) {
                assignEventTapState(.active)
            } else {
                // Recreate once if re-enable failed.
                teardownEventTap(keepLockPreference: isLocked)
                _ = setupEventTap()
            }
        }

        let processTrusted = AccessibilityPermission.isTrusted()
        if !processTrusted && self.accessibilityPermissionGranted {
            // Permission revoked in System Settings — unlock safely, keep app alive.
            debugPrint("Accessibility permission lost; unlocking and stopping event tap.")
            handlePermissionRevoked()
            scheduleAccessibilityPoll()
            return
        }
        if processTrusted {
            applyTrustState(trusted: true, source: "poll")
            if !self.eventLoopStarted {
                self.startEventLoop()
            }
            // Keep a light poll so we notice revocation / tap disable without terminating.
            scheduleAccessibilityPoll(intervalSeconds: 5)
            return
        }

        applyTrustState(trusted: false, source: "poll")
        scheduleAccessibilityPoll(intervalSeconds: 2)
    }
    
    func run() {
        // One controlled prompt on launch if still denied, after the main window is up.
        if !AccessibilityPermission.isTrusted() {
            _ = requestAccessibilityPermissions(prompt: true)
        } else {
            assignAccessibilityPermissionGranted(true)
        }

        checkAccessibilityPermission()

        if accessibilityPermissionGranted {
            startEventLoop()
        } else {
            assignIsLocked(false)
            assignPermissionStatusMessage("Please grant Accessibility permission in System Settings.")
            debugPrint("Please grant accessibility permissions in System Settings")
        }
    }
    
    func stop() {
        assignIsLocked(false)
        teardownEventTap(keepLockPreference: false)
        accessibilityPollWorkItem?.cancel()
        accessibilityPollWorkItem = nil
        eventLoopStarted = false
        assignPermissionStatusMessage("Event monitoring stopped.")
    }
    
    func startEventLoop() {
        if eventLoopStarted { return }
        if !accessibilityPermissionGranted { return }
        lock.lock()
        defer { lock.unlock() }

        if setupEventTap() {
            eventLoopStarted = true
        } else {
            eventLoopStarted = false
            assignIsLocked(false)
        }
    }

    /// Creates the HID event tap. Returns false on failure (no crash).
    @discardableResult
    private func setupEventTap() -> Bool {
        // Replace any previous tap cleanly.
        if eventTap != nil {
            teardownEventTap(keepLockPreference: isLocked)
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << 14) // search / dictation key
        )

        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalKeyEventHandler,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            let reason = AccessibilityPermission.isTrusted()
                ? "CGEvent.tapCreate returned nil (check code signing / sandbox / re-grant Accessibility for this exact binary)."
                : "CGEvent.tapCreate returned nil because Accessibility is not granted."
            assignEventTapState(.failed(reason))
            assignPermissionStatusMessage("Event tap failed: \(reason)")
            debugPrint("Failed to create event tap: \(reason)")
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            newTap,
            0
        )
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        eventTap = newTap
        eventTapRunLoopSource = runLoopSource

        if CGEvent.tapIsEnabled(tap: newTap) {
            assignEventTapState(.active)
            assignPermissionStatusMessage("Event tap active. Toggle Lock Keyboard to block input.")
            return true
        } else {
            assignEventTapState(.disabled)
            assignPermissionStatusMessage("Event tap created but disabled by the system.")
            return false
        }
    }

    private func teardownEventTap(keepLockPreference: Bool) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            eventTapRunLoopSource = nil
        }
        eventTap = nil
        eventLoopStarted = false
        assignEventTapState(.notStarted)
        // Cannot block without a live tap regardless of preference.
        assignIsLocked(false)
        _ = keepLockPreference
    }

    private func handlePermissionRevoked() {
        assignAccessibilityPermissionGranted(false)
        assignIsLocked(false)
        teardownEventTap(keepLockPreference: false)
        assignPermissionStatusMessage("Accessibility permission was revoked. Keyboard unlocked.")
        assignEventTapState(.notStarted)
    }

    private func applyTrustState(trusted: Bool, source: String) {
        let previous = accessibilityPermissionGranted
        // Only publish when the value changes — poll used to re-assign `true` every few
        // seconds and thrash every @ObservedObject view (AttributeGraph pressure / cycles).
        assignAccessibilityPermissionGranted(trusted)
        if trusted {
            if !previous {
                assignPermissionStatusMessage("Accessibility permission granted.")
                debugPrint("Accessibility granted (\(source))")
            }
        } else {
            assignIsLocked(false)
            if previous {
                assignPermissionStatusMessage("Accessibility permission not granted.")
            }
        }
    }

    private func scheduleAccessibilityPoll(intervalSeconds: Int = 2) {
        accessibilityPollWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.checkAccessibilityPermission()
        }
        accessibilityPollWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(intervalSeconds), execute: work)
    }

    // MARK: - Idempotent published setters (SwiftUI-safe)

    private func assignIsLocked(_ value: Bool) {
        if isLocked != value {
            isLocked = value
        }
    }

    private func assignAccessibilityPermissionGranted(_ value: Bool) {
        if accessibilityPermissionGranted != value {
            accessibilityPermissionGranted = value
        }
    }

    private func assignEventTapState(_ value: EventTapLifecycleState) {
        if eventTapState != value {
            eventTapState = value
        }
    }

    private func assignPermissionStatusMessage(_ value: String) {
        if permissionStatusMessage != value {
            permissionStatusMessage = value
        }
    }
    
    func handleKeyEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disable events first — re-enable without dropping the process.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            debugPrint("Event tap disabled (\(type.rawValue)), attempting to re-enable…")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                let enabled = CGEvent.tapIsEnabled(tap: tap)
                DispatchQueue.main.async {
                    self.assignEventTapState(enabled ? .active : .disabled)
                    if !enabled {
                        self.assignIsLocked(false)
                        self.assignPermissionStatusMessage("Event tap was disabled by the system; keyboard unlocked.")
                    }
                }
            }
            return Unmanaged.passRetained(event)
        }

        // Let Esc close menus before any lock handling.
        if (type == .keyDown || type == .keyUp),
           event.getIntegerValueField(.keyboardEventKeycode) == KeyCode.escape.rawValue,
           closeActiveMenusIfNeeded() {
            return nil
        }
        
        // If not locked, pass through ALL events immediately without any processing
        guard isLocked else {
            return Unmanaged.passRetained(event)
        }
        
        // Handle keyboard events only when locked
        if type == .keyDown || type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let controlFlag = event.flags.contains(.maskControl)
            let optionFlag = event.flags.contains(.maskAlternate)
            
            // Toggle keyboard lock with Ctrl + Option + U
            if optionFlag && controlFlag && keyCode == KeyCode.u.rawValue && type == .keyDown {
                debugPrint("Keyboard locked: \(isLocked)")
                self.isLocked = false
                return nil
            }

            // Handle normal keyboard events when locked
            if type != .keyUp { return nil }
            if selectedLockEffect == .speakRandomWord && gamifyRandomWordEnabled {
                if let cooldownUntil = gamifyRewardCooldownUntil, Date() < cooldownUntil {
                    return nil
                }
            }
            if isThrottled(effectType: selectedLockEffect) { return nil }
            
            self.lastKeyString = eventEffectHandler.handle(
                event: event, eventType: type, selectedLockEffect: selectedLockEffect
            )
            if selectedLockEffect == .speakRandomWord && gamifyRandomWordEnabled && !lastKeyString.isEmpty {
                gamifyRewardCooldownUntil = Date().addingTimeInterval(currentWordDisplayDuration())
            }
            if selectedLockEffect == .speakRandomWord && gamifyRandomWordEnabled {
                self.gamifyRandomWordTarget = eventEffectHandler.getGamifyTargetLetter()
            }
            let earnedReward: String?
            if selectedLockEffect == .speakRandomWord,
               gamifyRandomWordEnabled,
               !lastKeyString.isEmpty {
                earnedReward = lastKeyString
            } else if selectedLockEffect == .typingGame,
                      TypingGameState.shared.isWordComplete {
                earnedReward = TypingGameState.shared.currentEnglishWord
            } else {
                earnedReward = nil
            }
            if let earnedReward {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .learningRewardEarned,
                        object: nil,
                        userInfo: ["word": earnedReward]
                    )
                }
            }
            debugPrint("keyup------- \(lastKeyString)")
            return nil
        }
        
        return Unmanaged.passRetained(event)
    }

    @discardableResult
    private func closeActiveMenusIfNeeded() -> Bool {
        var closed = false
        if let appDelegate = NSApp.delegate as? AppDelegate {
            closed = appDelegate.hidePopover() || closed
        }

        let hasSheet = NSApp.windows.contains(where: { $0.isSheet }) || (NSApp.keyWindow?.isSheet ?? false)
        if hasSheet {
            NotificationCenter.default.post(name: .closeMenusRequested, object: nil)
            closed = true
        }

        return closed
    }
    
    /// Check Accessibility trust. When `prompt` is true, show the system dialog if still denied.
    @discardableResult
    func requestAccessibilityPermissions(prompt: Bool = true) -> Bool {
        let trusted: Bool
        if prompt {
            trusted = AccessibilityPermission.requestTrustPromptingIfNeeded(activateApp: true)
        } else {
            trusted = AccessibilityPermission.isTrusted()
        }
        applyTrustState(trusted: trusted, source: prompt ? "prompt" : "silent")
        if trusted && !eventLoopStarted {
            startEventLoop()
        }
        return trusted
    }

    func setGamifyRandomWordEnabled(_ enabled: Bool) {
        gamifyRandomWordEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "gamifyRandomWordEnabled")
        eventEffectHandler.setGamifyRandomWordEnabled(enabled)
        gamifyRandomWordTarget = eventEffectHandler.getGamifyTargetLetter()
        gamifyRewardCooldownUntil = nil
    }

    func setPrimaryLanguage(_ language: TranslationLanguage) {
        selectedPrimaryLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedPrimaryLanguage")
    }

    private func currentWordDisplayDuration() -> TimeInterval {
        let savedDuration = UserDefaults.standard.double(forKey: "wordDisplayDuration")
        if savedDuration == 0 {
            return DEFAULT_WORD_DISPLAY_DURATION
        }
        return savedDuration
    }

    private func requestPersonalVoicePermission() {
        if #available(macOS 14.0, *) {
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.personalVoiceAvailable = true
                    } else {
                        // If not authorized, disable the feature
                        self.personalVoiceAvailable = false
                        if self.usePersonalVoice {
                            // Only show message if user has explicitly enabled the feature
                            let alert = NSAlert()
                            alert.messageText = "Personal Voice Not Available"
                            alert.informativeText = "Please enable Personal Voice in System Settings > Accessibility > Personal Voice and make sure you've created a Personal Voice."
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        } else {
            // Personal Voice is not available on this version of macOS
            self.personalVoiceAvailable = false
            if self.usePersonalVoice {
                let alert = NSAlert()
                alert.messageText = "Personal Voice Not Supported"
                alert.informativeText = "Personal Voice requires macOS 14.0 or newer."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                // Disable the feature since not supported
                self.usePersonalVoice = false
            }
        }
    }
    
    private func checkPersonalVoiceAvailability() {
        if #available(macOS 14.0, *) {
            // Check if any personal voices are available
            let personalVoices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
                return voice.voiceTraits.contains(.isPersonalVoice)
            }
            
            DispatchQueue.main.async {
                self.personalVoiceAvailable = !personalVoices.isEmpty
                
                // If no personal voices available but feature is enabled, show alert
                if personalVoices.isEmpty && self.usePersonalVoice {
                    let alert = NSAlert()
                    alert.messageText = "No Personal Voice Found"
                    alert.informativeText = "You need to create a Personal Voice in System Settings > Accessibility > Personal Voice before using this feature."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    
                    // Disable the feature since no voice is available
                    self.usePersonalVoice = false
                }
            }
        } else {
            // Personal Voice is not available on this version of macOS
            DispatchQueue.main.async {
                self.personalVoiceAvailable = false
                
                if self.usePersonalVoice {
                    let alert = NSAlert()
                    alert.messageText = "Personal Voice Not Supported"
                    alert.informativeText = "Personal Voice requires macOS 14.0 or newer."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    
                    // Disable the feature since not supported
                    self.usePersonalVoice = false
                }
            }
        }
    }

}
func globalKeyEventHandler(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    let mySelf = Unmanaged<EventHandler>.fromOpaque(refcon).takeUnretainedValue()
    return mySelf.handleKeyEvent(proxy: proxy, type: type, event: event)
}

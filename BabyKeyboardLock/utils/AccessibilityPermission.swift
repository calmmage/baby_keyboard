//
//  AccessibilityPermission.swift
//  BabyKeyboardLock
//
//  TCC trust checks, one-shot system prompts, and runtime diagnostics
//  for the keyboard event-tap foundation.
//

import AppKit
import ApplicationServices
import Foundation

/// High-level trust state used by UI and EventHandler.
enum AccessibilityTrustState: String, Equatable, Sendable {
    case granted
    case denied

    var isGranted: Bool { self == .granted }
}

/// Lifecycle of the CGEvent tap that implements the keyboard blocker.
enum EventTapLifecycleState: Equatable, Sendable {
    case notStarted
    case active
    case disabled
    case failed(String)

    var isBlockingReady: Bool {
        if case .active = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .notStarted: return "Not started"
        case .active: return "Active"
        case .disabled: return "Disabled"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}

/// Snapshot of identity + trust facts that commonly explain "permission looks broken".
struct AccessibilityRuntimeDiagnostics: Equatable, Sendable {
    let isTrusted: Bool
    let trustState: AccessibilityTrustState
    let bundleIdentifier: String
    let executablePath: String
    let appPath: String
    let displayName: String
    let isUIElement: Bool
    let teamIdentifier: String?
    let codeSigningStatus: String
    let sandboxHint: String
    let instructions: [String]

    var summaryLines: [String] {
        [
            "Trust: \(isTrusted ? "granted" : "denied")",
            "Bundle ID: \(bundleIdentifier)",
            "App path: \(appPath)",
            "Executable: \(executablePath)",
            "LSUIElement (agent): \(isUIElement ? "yes" : "no")",
            "Team: \(teamIdentifier ?? "unknown")",
            "Code sign: \(codeSigningStatus)",
            "Sandbox: \(sandboxHint)",
        ]
    }
}

enum AccessibilityPermission {
    /// Silent trust check — never shows the system dialog.
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func trustState() -> AccessibilityTrustState {
        isTrusted() ? .granted : .denied
    }

    /// Prompt once via the system Accessibility dialog when still denied.
    /// Must run on the main thread with the app active for the dialog to appear reliably.
    @discardableResult
    static func requestTrustPromptingIfNeeded(activateApp: Bool = true) -> Bool {
        if isTrusted() {
            return true
        }

        let prompt: () -> Bool = {
            if activateApp {
                NSApp.activate(ignoringOtherApps: true)
            }
            // takeUnretainedValue: kAXTrustedCheckOptionPrompt is a global CFString constant.
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        if Thread.isMainThread {
            return prompt()
        }

        var result = false
        DispatchQueue.main.sync {
            result = prompt()
        }
        return result
    }

    /// Opens Privacy & Security → Accessibility in System Settings (Ventura+) with a fallback.
    static func openSystemSettingsAccessibilityPane() {
        NSApp.activate(ignoringOtherApps: true)
        let candidates = [
            // macOS 13+ System Settings deep link
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    static func diagnostics(
        eventTapState: EventTapLifecycleState = .notStarted,
        isLocked: Bool = false
    ) -> AccessibilityRuntimeDiagnostics {
        let trusted = isTrusted()
        let bundleId = Bundle.main.bundleIdentifier ?? "(missing bundle id)"
        let execPath = Bundle.main.executablePath ?? "(missing executable path)"
        let appPath = Bundle.main.bundlePath
        let displayName = Bundle.applicationName
        let isUIElement = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool
            ?? (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? String == "YES")
        let signing = codeSigningSummary(for: appPath)
        let sandboxHint = sandboxHintFromEntitlements(appPath: appPath)

        var steps: [String] = []
        if !trusted {
            steps.append("Click “Grant Accessibility Access” to show the system prompt (if macOS still offers it).")
            steps.append("Or open System Settings → Privacy & Security → Accessibility.")
            steps.append("Find “\(displayName)” (bundle \(bundleId)) and enable the toggle.")
            steps.append("If the app is missing, click +, then select this build at:\n\(appPath)")
            steps.append("Debug and Release use different bundle IDs — enable the one you actually launched.")
            steps.append("Re-signing or moving between DerivedData and /Applications can require re-enabling the toggle.")
        } else if !eventTapState.isBlockingReady {
            steps.append("Accessibility is granted, but the keyboard event tap is not active yet.")
            steps.append("Try Lock Keyboard again, or quit and relaunch the app.")
            if case .failed(let reason) = eventTapState {
                steps.append("Event tap error: \(reason)")
            }
        } else if !isLocked {
            steps.append("Permission OK and event tap active. Toggle Lock Keyboard to block input.")
        } else {
            steps.append("Blocker ready: Accessibility granted, event tap active, lock on.")
            steps.append("Unlock with the toggle, menu-bar click, or Ctrl+Option+U.")
        }

        return AccessibilityRuntimeDiagnostics(
            isTrusted: trusted,
            trustState: trusted ? .granted : .denied,
            bundleIdentifier: bundleId,
            executablePath: execPath,
            appPath: appPath,
            displayName: displayName,
            isUIElement: isUIElement,
            teamIdentifier: signing.team,
            codeSigningStatus: signing.status,
            sandboxHint: sandboxHint,
            instructions: steps
        )
    }

    // MARK: - Private helpers

    private static func codeSigningSummary(for appPath: String) -> (status: String, team: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=2", appPath]
        let err = Pipe()
        let out = Pipe()
        process.standardError = err
        process.standardOutput = out
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ("codesign unavailable: \(error.localizedDescription)", nil)
        }

        let data = err.fileHandleForReading.readDataToEndOfFile()
            + out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            return ("unsigned or invalid (\(process.terminationStatus))", nil)
        }

        var team: String?
        for line in text.split(separator: "\n") {
            if line.hasPrefix("TeamIdentifier=") {
                let value = line.dropFirst("TeamIdentifier=".count)
                if value != "not set" {
                    team = String(value)
                }
            }
        }

        let authority = text
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Authority=") })
            .map { String($0.dropFirst("Authority=".count)) }

        if let authority {
            return (authority, team)
        }
        if text.contains("Signature=adhoc") || text.contains("flags=0x2(adhoc)") {
            return ("ad-hoc (TCC may not stick across rebuilds)", team)
        }
        return ("signed", team)
    }

    private static func sandboxHintFromEntitlements(appPath: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "--entitlements", ":-", appPath]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "unknown"
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        if text.contains("com.apple.security.app-sandbox</key>") {
            if text.contains("<true/>") {
                // crude but good enough for diagnostics
                if text.range(of: "com.apple.security.app-sandbox</key>\\s*<true/>", options: .regularExpression) != nil {
                    return "enabled (Release-style)"
                }
            }
            if text.contains("com.apple.security.app-sandbox") && text.contains("<false/>") {
                return "disabled (Debug-style)"
            }
        }
        if text.isEmpty {
            return "none reported"
        }
        return text.contains("app-sandbox") ? "see entitlements dump" : "not present"
    }
}

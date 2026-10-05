//
//  authorization.swift
//  BabyKeyboardLock
//
//  Thin compatibility wrapper. Prefer AccessibilityPermission for new code.
//  The old Main.storyboard-based window path was removed (storyboard is gone).
//

import AppKit
import Foundation

/// Legacy type kept so older call sites/docs stay meaningful.
/// New code should use `AccessibilityPermission`.
final class AccessibilityAuthorization {
    /// Silent check only. Use `AccessibilityPermission.requestTrustPromptingIfNeeded()` to prompt.
    func checkAccessibility(completion: @escaping () -> Void) -> Bool {
        if AccessibilityPermission.isTrusted() {
            completion()
            return true
        }
        pollAccessibility(completion: completion)
        return false
    }

    private func pollAccessibility(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if AccessibilityPermission.isTrusted() {
                completion()
            } else {
                self.pollAccessibility(completion: completion)
            }
        }
    }

    func showAuthorizationWindow() {
        // No dedicated storyboard window anymore; main ContentView owns the UI.
        NSApp.activate(ignoringOtherApps: true)
        AccessibilityPermission.openSystemSettingsAccessibilityPane()
    }
}

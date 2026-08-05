@testable import BabyKeyboardLock
import Testing

struct AccessibilityFoundationTests {
    @Test func trustStateMirrorsIsTrustedBool() {
        let trusted = AccessibilityPermission.isTrusted()
        #expect(AccessibilityPermission.trustState().isGranted == trusted)
        #expect((AccessibilityPermission.trustState() == .granted) == trusted)
        #expect((AccessibilityPermission.trustState() == .denied) == !trusted)
    }

    @Test func diagnosticsAlwaysIncludeIdentityFields() {
        let diag = AccessibilityPermission.diagnostics()
        #expect(!diag.bundleIdentifier.isEmpty)
        #expect(!diag.appPath.isEmpty)
        #expect(!diag.executablePath.isEmpty)
        #expect(!diag.displayName.isEmpty)
        #expect(!diag.summaryLines.isEmpty)
        #expect(diag.trustState.isGranted == diag.isTrusted)
        #expect(!diag.instructions.isEmpty)
    }

    @Test func diagnosticsReflectEventTapFailureInstructions() {
        let failed = AccessibilityPermission.diagnostics(
            eventTapState: .failed("unit-test-reason"),
            isLocked: false
        )
        if failed.isTrusted {
            #expect(failed.instructions.contains(where: { $0.contains("unit-test-reason") }))
        } else {
            #expect(failed.instructions.contains(where: { $0.localizedCaseInsensitiveContains("Accessibility") }))
        }
    }

    @Test func eventTapLifecycleStateLabels() {
        #expect(EventTapLifecycleState.notStarted.statusLabel == "Not started")
        #expect(EventTapLifecycleState.active.statusLabel == "Active")
        #expect(EventTapLifecycleState.disabled.statusLabel == "Disabled")
        #expect(EventTapLifecycleState.failed("x").statusLabel == "Failed: x")
        #expect(EventTapLifecycleState.active.isBlockingReady)
        #expect(!EventTapLifecycleState.notStarted.isBlockingReady)
        #expect(!EventTapLifecycleState.disabled.isBlockingReady)
        #expect(!EventTapLifecycleState.failed("nope").isBlockingReady)
    }

    @Test func setLockedRequiresAccessibilityPermission() {
        let handler = EventHandler(isLocked: false)
        handler.accessibilityPermissionGranted = false
        handler.eventTapState = .notStarted
        handler.setLocked(isLocked: true)
        #expect(!handler.isLocked)
        #expect(handler.permissionStatusMessage.localizedCaseInsensitiveContains("Accessibility"))
    }

    @Test func setLockedRequiresActiveEventTap() {
        let handler = EventHandler(isLocked: false)
        handler.accessibilityPermissionGranted = true
        handler.eventTapState = .failed("simulated")
        // startEventLoop is skipped when already failed and setup may re-attempt;
        // force a non-active state after any setup attempt.
        handler.eventTapState = .failed("simulated")
        handler.setLocked(isLocked: true)
        // Without a live tap, lock must not engage.
        if !handler.eventTapState.isBlockingReady {
            #expect(!handler.isLocked)
        }
    }

    @Test func unlockAlwaysAllowed() {
        let handler = EventHandler(isLocked: true)
        handler.isLocked = true
        handler.setLocked(isLocked: false)
        #expect(!handler.isLocked)
    }

    @Test func isBlockerReadyRequiresTrustAndActiveTap() {
        let handler = EventHandler(isLocked: false)
        handler.accessibilityPermissionGranted = true
        handler.eventTapState = .active
        #expect(handler.isBlockerReady)

        handler.eventTapState = .disabled
        #expect(!handler.isBlockerReady)

        handler.eventTapState = .active
        handler.accessibilityPermissionGranted = false
        #expect(!handler.isBlockerReady)
    }

    @Test func stopClearsLockAndResetsTapState() {
        let handler = EventHandler(isLocked: false)
        handler.isLocked = true
        handler.eventTapState = .active
        handler.stop()
        #expect(!handler.isLocked)
        #expect(handler.eventTapState == .notStarted)
    }

    @Test func setLockedIsIdempotentWhenAlreadyUnlocked() {
        let handler = EventHandler(isLocked: false)
        handler.accessibilityPermissionGranted = false
        handler.isLocked = false
        let before = handler.permissionStatusMessage
        handler.setLocked(isLocked: false)
        #expect(!handler.isLocked)
        // Already unlocked + no permission: message should stay put (idempotent assign).
        #expect(handler.permissionStatusMessage == before)
    }

    @Test func setLockedRejectDoesNotLeaveLockEngaged() {
        let handler = EventHandler(isLocked: false)
        handler.accessibilityPermissionGranted = false
        handler.eventTapState = .notStarted
        handler.setLocked(isLocked: true)
        #expect(!handler.isLocked)
        handler.setLocked(isLocked: true)
        #expect(!handler.isLocked)
    }

    @Test func refreshPermissionStatusIsIdempotentWhenTrustUnchanged() {
        let handler = EventHandler(isLocked: false)
        let trusted = AccessibilityPermission.isTrusted()
        handler.refreshPermissionStatus()
        let grantedAfterFirst = handler.accessibilityPermissionGranted
        let messageAfterFirst = handler.permissionStatusMessage
        handler.refreshPermissionStatus()
        #expect(handler.accessibilityPermissionGranted == grantedAfterFirst)
        #expect(handler.accessibilityPermissionGranted == trusted)
        #expect(handler.permissionStatusMessage == messageAfterFirst)
    }
}

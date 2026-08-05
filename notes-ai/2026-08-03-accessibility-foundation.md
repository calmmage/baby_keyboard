# Accessibility foundation — 2026-08-03

> **Scope correction from Petr (2026-08-03):** the original Baby Keyboard already worked. The failed product was **Baby Button Blocker**. This work was applied to the Baby Keyboard donor repository and must not be reported as a fix for Baby Button Blocker. Preserve it as experimental migration material until the unified Daria ecosystem has a chosen canonical repository; do not archive or revert it implicitly.

Narrow hardening of the native Baby Keyboard **button-blocker foundation**: TCC Accessibility trust, CGEvent tap lifecycle, visible main window under `LSUIElement`, diagnostics/tests. Not vocabulary/AI/web product work.

## What was broken / fragile

| Area | Before | Risk |
|------|--------|------|
| AX prompt | `kAXTrustedCheckOptionPrompt.takeRetainedValue()` + prompt from init / `run` / `ContentView.onAppear` | Wrong CF lifetime; stacked dialogs; prompt behind other windows |
| Tap create failure | `fatalError("Failed to create event tap")` | App crash when TCC/signing mismatch |
| Permission revoked | `NSApplication.shared.terminate` | Quiet death instead of recoverable unlock |
| Tap teardown | Nil’d port, left run-loop source | Leaky / hard-to-recreate tap |
| Status UI | One line + two buttons | No event-tap / signing / path diagnostics |
| Storyboard onboarding | `authorization.swift` → `Main` storyboard | Dead path (no storyboard) |
| Info.plist | Fake key `Privacy - Accessibility API Enabled` | Misleading; does not grant TCC |
| Unit tests | Test target team `SQ5HJJDHG9` vs app `5XCYR4LUMD` | Tests could not sign/build locally |
| Identity | Debug vs Release different bundle IDs + sandbox on/off | TCC “looks broken” when launching the other build |

## What we changed

### Code

- **`BabyKeyboardLock/utils/AccessibilityPermission.swift`** (new)
  - Silent `isTrusted()` / `trustState()`
  - One-shot `requestTrustPromptingIfNeeded` with `takeUnretainedValue` + app activation
  - System Settings deep-link helper
  - `AccessibilityRuntimeDiagnostics` (bundle id, path, LSUIElement, team, codesign, sandbox hint, instructions)
  - `EventTapLifecycleState` (`notStarted` / `active` / `disabled` / `failed`)

- **`EventHandler.swift`**
  - Silent trust check in `init` (no prompt)
  - Single controlled prompt in `run()` after main window is up
  - Non-fatal `setupEventTap` + published `eventTapState` / `permissionStatusMessage`
  - Safe `teardownEventTap` (disable + remove run-loop source)
  - Permission loss → unlock + stop tap, **keep app running**
  - Poll heals system-disabled taps; no terminate
  - `setLocked` requires Accessibility **and** active tap
  - `isBlockerReady` for UI
  - **Idempotent published assigns** (`assignIsLocked` / trust / tap state / status message) so the 2–5s AX poll no longer re-publishes identical `true` every tick

- **`ContentView.swift`**
  - Lock toggle routes through idempotent `setLocked` Binding (no rejected Toggle write loop)
  - Toggle disabled when not locked and foundation not ready (unlock always allowed)
  - `AccessibilityStatusPanel`: chips + instructions + diagnostics disclosure
  - Diagnostics **cached** (`@State`); refresh on appear / trust / tap / lock change — never `codesign` mid-`body`
  - Single `onChange(isLocked)` for lock sound (removed triple onChange+onReceive+Toggle handlers)
  - `onAppear` only refreshes silently (no re-prompt spam)

- **`BabyKeyboardLockApp.swift`**
  - Explicit `.accessory` activation policy (menu-bar agent, no Dock)
  - Real titled/closable main window first, then `run()`, then overlay windows
  - Closing main window does not quit; overlays stay non-interactive floaters

- **`authorization.swift`** — storyboard path removed; thin wrapper over `AccessibilityPermission`

- **`BabyKeyboardLock-Info.plist`** — removed fake Accessibility key

- **`project.pbxproj`** — unit-test `DEVELOPMENT_TEAM` aligned to app (`5XCYR4LUMD`)

- **Tests** — `AccessibilityFoundationTests.swift`; flaky `testEventHandlerInitialState` made AX-aware

- **`scripts/verify_accessibility_foundation.sh`** + `make verify-ax`
  - Deterministic app product resolution (exact `BabyKeyboardLock Debug.app` name first; never `*UITests*` / `*Runner*`)
  - Asserts `CFBundleIdentifier`, `LSUIElement`, Debug `app-sandbox=false` on **that** product

### Unchanged by design

- Blocker still only swallows keys when `isLocked &&` tap callback runs; unlock still Ctrl+Option+U / toggle / menu-bar left click
- `LSUIElement=YES` kept (no Dock icon)
- Release sandbox **not** flipped in this pass (documented below)
- Unrelated dirty edit: `scripts/cleanup_archive_clone.sh` (archive path) left alone

## Signing / entitlements / launch-path assumptions

| Item | Value | TCC implication |
|------|-------|-----------------|
| Debug bundle id | `com.fangxing.BabyKeyboardLockDebug` | Separate Accessibility toggle from Release |
| Release bundle id | `com.fangxing.BabyKeyboardLock` | Separate toggle |
| Debug entitlements | sandbox **false** | Prefer for event taps while developing |
| Release entitlements | sandbox **true** | If `tapCreate` fails only in Release, suspect sandbox; try Debug binary or align entitlements |
| Team | `5XCYR4LUMD` (app + tests after fix) | Codesign identity must match what user enabled in Privacy |
| LSUIElement | YES | Agent app: menu bar + windows, no Dock; still needs a visible main window for onboarding |
| Ad-hoc re-sign | `archive/scripts_legacy/fix-signature.sh` | **Resets code identity → re-enable Accessibility** |
| Launch path | DerivedData vs `/Applications` | Same signature/team usually OK; ad-hoc or different build → re-toggle |

There is **no** Info.plist usage string that replaces the Accessibility TCC toggle. User must enable the app in System Settings (or accept the system prompt when still offered).

## Build / test / launch verification

### `make verify-ax` (re-run after follow-up fixes)

- **build-for-testing**: succeeded
- **App product resolved**:  
  `build/verify-ax/Build/Products/Debug/BabyKeyboardLock Debug.app`  
  (explicitly **not** `BabyKeyboardLockUITests Debug-Runner.app`)
- **Asserts on that product**:
  - `CFBundleIdentifier=com.fangxing.BabyKeyboardLockDebug` — OK
  - `LSUIElement=true` — OK
  - Debug entitlements `com.apple.security.app-sandbox` = **false** — OK
  - codesign TeamIdentifier=`5XCYR4LUMD`, Authority=Apple Development
- **Unit tests**: `AccessibilityFoundationTests` + `EventHandlerUnitTests` → `** TEST EXECUTE SUCCEEDED **` (incl. idempotent setLocked/refresh tests)
- **Summary**: pass=14, warn=1 (Release sandbox still true — expected/product decision), fail=0
- **Not automated / not done here**: TCC toggle mutation; live “keys blocked” interaction after human grant

### Independent human launch (prior verification)

- Launched exact path `…/BabyKeyboardLock Debug.app`; process PID stayed alive.
- Unified logs immediately after launch included repeated  
  `com.apple.attributegraph: error Cycle detected through attribute`  
  (that run was on the **pre-follow-up** binary).

### AttributeGraph cycle — attribution and fix

**Attributable to this foundation work (fixed):**

| Mechanism | Evidence | Fix |
|-----------|----------|-----|
| Custom `Toggle` Binding → `setLocked` that could reject lock while Switch style expects write to stick | New Binding replaced `$eventHandler.isLocked`; classic AG cycle pattern when `set` reverts | Idempotent `setLocked`; disable lock-on unless `isBlockerReady`; no-op if value unchanged |
| `applyTrustState` / poll re-assigned `@Published accessibilityPermissionGranted = true` every 2–5s | Poll always wrote published fields even when unchanged → thrash every `@ObservedObject` view | `assign*` helpers only write on change |
| `AccessibilityStatusPanel` called `currentDiagnostics()` (codesign `Process`) inside `body` / `ForEach` | New panel; body re-entry on every publish ran subprocesses mid-attribute update | Cache lines in `@State`; refresh on explicit transitions |
| Triple `isLocked` sound observers (Toggle onChange + view onChange + onReceive) | Amplified thrash when lock published; one path was pre-existing, Toggle path in our edit surface | Single `onChange(of: isLocked)` |

**Not claimed fixed without residual risk:**

- Other pre-existing SwiftUI graphs (category picker / `@AppStorage` effect sync / overlay windows) can still emit AG noise; we did not rewrite those.
- Brief post-fix launch (`open` app ~5s + `log stream` for `Cycle detected`) produced an **empty** capture (PID was alive). That is weak negative evidence only (log stream permissions/filters), not a formal AG regression test.

### Human-only remaining

1. Launch **only**:  
   `build/verify-ax/Build/Products/Debug/BabyKeyboardLock Debug.app`  
   (or Release deploy product — different bundle id).
2. Confirm main titled window + menu bar; no Dock icon.
3. **TCC click**: System Settings → Privacy & Security → Accessibility → enable this exact Debug identity (`com.fangxing.BabyKeyboardLockDebug`) if not already.
4. In-app: Accessibility ok + Event tap Active; lock/unlock smoke; Ctrl+Option+U.
5. Optional: Console / `log stream` for `Cycle detected` after this rebuild — expect quiet vs prior run.
6. Do **not** use `tccutil reset` as part of normal verify.

```bash
make verify-ax
```

## Residual risks / follow-ups

1. **Release sandbox true** — leave as product decision; if Release-only tap failures, flip sandbox off to match Debug or document notarized non-sandbox distribution.
2. **Dual bundle IDs** — intentional for Debug icon/name; still confuses TCC list (in-app diagnostics now surface path + bundle id).
3. **Full onboarding wizard** (`dev/notes/actions/02-09-onboarding-first-launch.md`) — not built; status panel is the foundation slice.
4. **Permissions reset CLI** (`dev/notes/tasks.md` item m) — still open; script deliberately does **not** call `tccutil reset`.
5. **AttributeGraph** — foundation thrash paths fixed; re-check Console on a clean launch if cycles reappear.

## Review checklist

- [x] `make verify-ax` selects real app + asserts bundle id / LSUIElement / sandbox
- [x] Unit tests green after follow-up
- [ ] Human Accessibility grant + blocker smoke on this build
- [ ] Optional Console check for AttributeGraph cycles on this build
- [ ] Do **not** commit `scripts/cleanup_archive_clone.sh` with this work unless intended
- [ ] No commit/publish in this task (left ready for review)

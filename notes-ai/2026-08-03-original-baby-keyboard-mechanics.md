# Original Baby Keyboard mechanics — forensic report

Date: 2026-08-03. This report documents the **committed state**: branch `dev` @ `6be2027` ("Backup snapshot 22 Jul 2026"). All Swift line numbers refer to that committed state, which is what was read.

**Working-tree caution (verified 2026-08-03 evening):** besides the pre-existing dirty `scripts/cleanup_archive_clone.sh` (default `ROOT` moved from `/Users/petrlavrov/work/archive/baby_keyboard` to `/Users/petrlavrov/archive/baby_keyboard`; preserved, untouched), a **parallel uncommitted "accessibility-foundation" workstream appeared mid-session**: modified `EventHandler.swift` (+270/-…, non-fatal tap lifecycle, `eventTapState`, no terminate-on-revoke, silent trust check in init), `BabyKeyboardLockApp.swift`, `utils/authorization.swift`, `views/ContentView.swift`, `BabyKeyboardLock-Info.plist`, `project.pbxproj`, `EventHandlerUnitTests.swift`, `Makefile` (new `verify-ax` target), `CHANGELOG.md` (new `accessibility-foundation` line); untracked `utils/AccessibilityPermission.swift`, `BabyKeyboardLockTests/AccessibilityFoundationTests.swift`, `scripts/verify_accessibility_foundation.sh`. That in-flight work implements fixes for several defects documented below (§4, §16) — coordinate before touching those files.

Method: full read of all 30 committed Swift files (~10.5k lines), Xcode project/pbxproj, entitlements, Info.plists, schemes, tests, resources; delegated sweeps of `web/`, scripts/docs/git; plus inspection of the actually-built Debug app in DerivedData and its live UserDefaults. This documents **current behavior only**; recommendations are confined to the final "First coding moves" section.

---

## 1. What the product is

A macOS menu-bar utility ("BabyKeyboard Lock", marketing version 0.3.2, build 4 — `project.pbxproj:448,430`) that grabs the keyboard with a CGEvent tap so a baby can mash keys safely, and turns each key press into an effect: confetti, spoken letters/words (with translations), flashcard images/videos, a typing game, and a networked "shared library" media player. The dominant subsystem (most code, default effect) is **random word mode**: each key press speaks and displays a word chosen from a learning-pool/word-set system.

- App entry: `BabyKeyboardLock/BabyKeyboardLockApp.swift:18-41`
- Effect registry: `BabyKeyboardLock/LockEffect.swift:18-57`
- Event pipeline: `BabyKeyboardLock/EventHandler.swift` → `BabyKeyboardLock/EventEffectHandler.swift`
- Word/data layer: `BabyKeyboardLock/utils/RandomWordList.swift` (2209 lines), `WordRepository.swift`, `WordDataModel.swift`, `WordCatalogStore.swift`, `LearningStateStore.swift`

---

## 2. App lifecycle, windows, menu bar

- SwiftUI `@main` app whose only `Scene` is `Settings { AdvancedSettingsView() }` (`BabyKeyboardLockApp.swift:29-33`). Everything else is AppKit windows created by `AppDelegate`.
- The app is a **menu-bar accessory**: `INFOPLIST_KEY_LSUIElement = YES` for both configs (`project.pbxproj:440,479`) — no Dock icon.
- `applicationDidFinishLaunching` (`BabyKeyboardLockApp.swift:60-145`):
  - Creates an `NSStatusItem` whose icon reflects lock state (`keyboard.locked`/`keyboard.unlocked` symbolsets in `Assets.xcassets`), lines 70-87.
  - **Left-click on the status item toggles the lock; right-click opens the main window** (`handleStatusBarClick`, lines 186-201).
  - After a 0.5 s delay (line 89): shows the main window, calls `EventHandler.shared.run()` (line 91), validates catalog translations (line 92, logs `WARNING: Catalog has missing translations…` via `validateCatalogTranslations`, lines 227-238 — checks ru/de/fr/es/it/ja/zh), then creates **three borderless full-screen overlay windows**:
    - Animation window (confetti) — id `animationTransparentWindow`, lines 95-107
    - Word display window — id `wordDisplayTransparentWindow`, `level = .floating`, `ignoresMouseEvents = true`, lines 110-125
    - Visual effects window — id `visualEffectsTransparentWindow`, lines 128-143
  - All three windows are additionally forced transparent/click-through/screen-saver-level by the `fullscreenTransparentWindow()` modifier applied inside each root view (`views/AnimationView.swift:13-46`: `level = .screenSaver`, `collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]`).
- Main window: `showMainWindow()` (`BabyKeyboardLockApp.swift:156-175`) hosts `ContentView`, 500×600 (`views/ContentView.swift:260`), positioned top-right with 20 pt inset (lines 216-225).
- Screen reconfiguration re-sizes the three overlays (`updateWindowFrames`, lines 203-214). Overlays only track `NSScreen.main` — no multi-display spanning.
- Closing all windows does **not** quit (`applicationShouldTerminateAfterLastWindowClosed` returns false, line 147-149); quit is the "Exit App" button (`ContentView.swift:71-73`) or termination, which stops the tap (`applicationWillTerminate`, line 151-154).
- Auxiliary windows opened on demand: Settings (native Settings scene), Shared Library (`sharedLibraryWindow`, `ContentView.swift:236-245`), About (`ContentView.swift:247-251`), Learning Rotation pool editor (`learningPoolWindow`, `AdvancedSettingsView.swift:355-375`), Featured Words editor (`featuredWordsWindow`, `AdvancedSettingsView.swift:377-397`). `View.openInWindow` closes any prior window with the same id before opening (`views/ViewExtension.swift:11-35`).
- Launch-at-startup: `LaunchAtStartup.swift:10-20` uses `SMAppService.mainApp`. **Bug (present, broken):** `setEnabled(_ enabled: Bool)` ignores its parameter and always calls `register()` — the "Launch on startup" toggle (`AdvancedSettingsView.swift:42-46,55`) can enable but can never disable.

Dead lifecycle code: `hideMainWindow()` (`BabyKeyboardLockApp.swift:177-179`) and `showOrCloseAnimationWindow(isLocked:)` (`ContentView.swift:335-384`) are defined but never called (verified by repo-wide grep).

---

## 3. Keyboard blocking mechanics (and what is NOT blocked)

- The tap: `CGEvent.tapCreate` at `EventHandler.swift:258-265` with `tap: .cghidEventTap`, `place: .headInsertEventTap`, `options: .defaultTap` (i.e. an **active, modifying** tap — returning nil swallows the event).
- Event mask (`EventHandler.swift:252-256`): `keyDown | keyUp | (1 << 14)` — raw type 14 is `NX_SYSDEFINED` (media/system keys; comment says "seacrh and voice key"). **Mouse events are not in the mask; the app never blocks the mouse.** The overlay windows also ignore mouse events, so a baby can still click. Only keyboard + system-defined keys are intercepted.
- Callback flow (`handleKeyEvent`, `EventHandler.swift:280-362`):
  1. `tapDisabledByTimeout`/`tapDisabledByUserInput` → re-enable the tap and pass the event through (lines 286-292).
  2. Esc closes any open app sheet/menu first, event swallowed (lines 295-299, `closeActiveMenusIfNeeded` lines 364-378 posts `.closeMenusRequested`).
  3. Not locked → pass everything through untouched (lines 302-304).
  4. Locked: **Ctrl+Option+U on keyDown unlocks** (lines 313-317; keycode `0x20` = `KeyCode.u`, `EventHandler.swift:17`). This is the only keyboard escape hatch; ContentView advertises it (`ContentView.swift:224`).
  5. All other keyDowns are swallowed silently (line 320 `if type != .keyUp { return nil }`); effects fire on **keyUp** only.
  6. Gamify reward cooldown gate (lines 321-325): while a reward card is showing, keyUps are swallowed without effect (cooldown set at line 332 to the word display duration; commit `ea93595` "Block gamify input during reward timeout").
  7. Throttle (lines 77-90, 326): word-category effects use `wordsThrottleInterval` (default 1.5 s), everything else `throttleInterval` (default 1.0 s). Throttled keyUps are swallowed with no effect.
  8. Surviving keyUps go to `eventEffectHandler.handle(...)` (line 328) whose return string is published as `lastKeyString` — the reactive signal all overlay views listen to.
  9. Learning-reward notification: a successful gamify letter or a completed typing word posts `.learningRewardEarned` with the word (lines 337-356) — consumed only by `SharedLibraryView` (`views/SharedLibraryView.swift:149`).
- Enable/disable:
  - `run()` (`EventHandler.swift:217-228`) → `checkAccessibilityPermission()` + `requestAccessibilityPermissions()`; starts the event loop only if already trusted.
  - `startEventLoop()` (lines 240-248) guards on `accessibilityPermissionGranted`, creates the tap on the **current (main) run loop** (`CFRunLoopAddSource(CFRunLoopGetCurrent(), …)`, line 276) and enables it.
  - `stop()` (lines 230-238) disables and drops the tap, marks unlocked.
  - Locking is purely the `isLocked` flag — the tap stays installed while unlocked and passes events through (line 302-304). `setLocked(true)` is refused when permission is missing (lines 175-181).
  - `checkAccessibilityPermission()` (lines 183-215) re-runs every 3 s until trusted; it also restarts a disabled tap (lines 185-188). **If trust is *lost* after having been granted, the app terminates itself** (lines 190-195: `stop()` then `NSApplication.shared.terminate`).
  - **Crash risk (present):** `setupEventTap` calls `fatalError("Failed to create event tap")` (line 268) if tap creation fails — reachable from the line-185 restart path if the OS refuses a new tap after permission revocation timing races.
- Key→string decoding: `getKeyString` uses `UCKeyTranslate` against the current keyboard layout (`EventEffectHandler.swift:836-870`); a second path uses the Sauce package (`getString`, lines 441-451; Sauce pinned to branch `master` — `project.pbxproj:620-627`, resolved rev `9ed4ca4`).

---

## 4. Accessibility permission (TCC): current flow and why prompting/trust failed before

### 4.1 What the code does now

- `EventHandler.init` (line 96) and `run()` (line 220) call `requestAccessibilityPermissions()` (`EventHandler.swift:380-389`): reads `AXIsProcessTrusted()`, and if false, asynchronously calls `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` and **returns the pre-prompt value**. So the first run always reports "not granted", unlocks the app (lines 97-99), and relies on the 3-second `checkAccessibilityPermission()` poll (lines 205-214) to notice a later grant and then start the event loop (lines 196-203).
- UI affordances when not granted: banner + "Grant Accessibility Access" (calls the same request function) + "Open System Settings…" deep link `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` (`ContentView.swift:86-105`); also auto-requested in `onAppear` (`ContentView.swift:277-280`).
- **Dead code:** `AccessibilityAuthorization` (`utils/authorization.swift:11-48`) is referenced nowhere (repo-wide grep: only its own file). It would also crash if ever used — it instantiates `NSStoryboard(name: "Main", …)` with identifier `AccessibilityWindowController` (`authorization.swift:18`) and **no Main.storyboard exists in the repo**.
- Zero uses of `CGRequestPostEventAccess`/`CGPreflightPostEventAccess`, `tccutil`, or `csrutil` anywhere in the repo (verified by sweep).

### 4.2 Identity of the thing asking for permission

- Debug builds produce `BabyKeyboardLock Debug.app`, bundle id `com.fangxing.BabyKeyboardLockDebug`, display name "BabyKeyboard Lock (Debug)", icon `AppIconDebug` (`project.pbxproj:449,451,438,423`). Release: `com.fangxing.BabyKeyboardLock`, "BabyKeyboard Lock", `AppIcon` (`project.pbxproj:488,489,477,462`).
- Both configs sign **Automatic / Apple Development / team 5XCYR4LUMD**, hardened runtime YES (`project.pbxproj:427-428,433-434,466-467,472-473`).
- Verified on this machine: the actually-built product at `~/Library/Developer/Xcode/DerivedData/BabyKeyboardLock-gzclogmxjmnakpffndspllgwxbos/Build/Products/Debug/BabyKeyboardLock Debug.app` (built Mar 21 2026) is signed `TeamIdentifier=5XCYR4LUMD`, flags `0x10000(runtime)`, and its embedded entitlements are `app-sandbox=false`, `network.client=true`, `automation.apple-events=true`, `get-task-allow=true` (read via `codesign -d --entitlements -`).
- TCC keys a grant to (bundle id, designated code requirement). The Debug and Release apps are therefore **two independent TCC clients**; granting one does nothing for the other.

### 4.3 Why the previous attempt could not prompt or become trusted — exact conditions

Grounded conditions, in decreasing certainty:

1. **Release builds are sandboxed and therefore can never become trusted.** `BabyKeyboardLockRelease.entitlements:5-6` sets `com.apple.security.app-sandbox = true` (Debug's `BabyKeyboardLock.entitlements:5-6` sets it false). App Sandbox forbids using the Accessibility API to observe/control other apps: for a sandboxed process `AXIsProcessTrusted()` stays false and the `kAXTrustedCheckOptionPrompt` prompt is suppressed, and an active `cghidEventTap` cannot be created. So any archived/exported Release build (`scripts/archive.sh:7-11` builds `-configuration Release`; `scripts/export.sh` exports it) silently can't prompt and can't be trusted — matching the "could not prompt or become trusted" symptom exactly. Note the misleading twist: the *build setting* `ENABLE_APP_SANDBOX = NO` at project level (`project.pbxproj:329,397`) is overridden in practice because `CODE_SIGN_ENTITLEMENTS` points at the sandboxed plist for Release (`project.pbxproj:465`).
2. **The prompt fires at most once per TCC record.** `AXIsProcessTrustedWithOptions(prompt: true)` shows the system dialog only if no record exists for the client. After the first ever request (or a user "Deny"), subsequent calls — including the "Grant Accessibility Access" button (`ContentView.swift:93-96`) — do nothing visible. The app has no code to detect "record exists but denied" (no `CGPreflightPostEventAccess`, no reset instructions).
3. **Ad-hoc re-signing invalidated existing grants.** The legacy installer flow (`archive/scripts_legacy/fix-signature.sh:18-21`) ran `xattr -cr` + `codesign --force --deep --sign -` (ad-hoc) over `/Applications/BabyKeyboardLock.app`; the script itself warns it "resets accessibility permissions" (lines 5, 7, 26). An ad-hoc signature has no stable designated requirement, so every re-sign/update produced a new identity: the old TCC row still shows a checked toggle in System Settings while `AXIsProcessTrusted()` returns false for the new binary — the classic "toggle is on but app isn't trusted" state, with no new prompt because the record exists. `scripts/install.sh:11` still tells users to "run: make fix-signature", but the current `Makefile` no longer has that target (only `archive/Makefile.legacy:75-78` did) — the install instructions point at a removed mechanism.
4. **Debug identity churn.** Debug lives in DerivedData; a fresh Xcode (new DerivedData hash), a signing-cert renewal, or switching Debug↔Release bundle ids each creates/orphans TCC rows. The debug app also has a distinct bundle id (`…Debug`), so past grants to the release app never applied to dev builds and vice versa.
5. **Launch context matters.** Running the bare executable from a shell (instead of `open …app`/Finder/Xcode) makes the TCC client the invoking terminal or the raw binary path — the prompt then either doesn't appear or grants the wrong client. (Condition of the API, relevant for agent-driven runs; see §19.)
6. Minor: `Privacy - Accessibility API Enabled` in `BabyKeyboardLock-Info.plist:24-25` is a human-readable label, not a real Info.plist key — it has no effect. There is no `NSAccessibilityUsageDescription` (macOS doesn't use one for AX; nothing missing functionally).

Current on-disk TCC state could not be read from this session (`~/Library/Application Support/com.apple.TCC/TCC.db` unreadable without Full Disk Access — verified error), so per-row state is unverified; check System Settings → Privacy & Security → Accessibility manually.

### 4.4 Historical evidence in git/docs (the failure was real and repeated)

- Commit `a1813a3`: "Accessibility: prompt on launch + settings deep link; start event tap after grant; remove CFRunLoopRun to avoid UI hang; keep main runloop intact. **Debug entitlements: disable sandbox to appear under Accessibility.**" — direct confirmation that with the sandbox on, the app did not even appear in the Accessibility pane; disabling sandbox in Debug was the fix. Release was never given the same fix (§4.3.1).
- Commit `53f773b`: "Add fix-signature script and update documentation" — the ad-hoc re-sign workaround of §4.3.3 was an official install step.
- Commit `af4788e`: "exit app on permission revoking, preventing system freeze" — origin of the terminate-on-revoke behavior (`EventHandler.swift:190-195`): a revoked permission with a live tap froze the system, so the app quits instead.
- Commits `dbfdc62` ("permission handle"), `d0b6b18` ("fix eventLoop is not started after grant permission and turn on lock"), `6321b68` ("Refactor accessibility permission check to stop once granted"), `fef2ef0` ("Don't check accessibility permission in test"), `3992d33` ("Fix accessiblity permission request text") — a long tail of permission-flow churn. `git log --grep TCC`: zero matches — the TCC layer itself was never addressed directly.
- `dev/notes/tasks.md:56-60` (item `m`): "Add permissions reset command … quickly re-set permissions (with sudo) of the app after deploy (delete and re-add)", cue: "I'm tired of manually deleting and re-adding the app in privacy settings" — the per-deploy TCC invalidation of §4.3.3/4.3.4 as lived experience.
- `dev/notes/tasks.md:110-118` (item `v`): deploy on a second Mac (Anna's) failed with `No signing certificate "Mac Development" found … team ID "5XCYR4LUMD"`; `readme.md:80-104` documents the workaround — exporting the personal cert `"Apple Development: petr.b.lavrov@gmail.com (8BH632TKSD)"` as a `.p12`, importing on the other Mac and setting **"Always Trust"**. Cross-machine distribution currently depends on hand-carried developer certificates (no notarization; readme `:115` lists "Notarizing" as an unchecked TODO).
- The in-flight accessibility-foundation workstream (see header) plus its `scripts/verify_accessibility_foundation.sh` audit (checks bundle ids, sandbox flags, the fake `Privacy - Accessibility API Enabled` key, `takeRetainedValue()` on the prompt option, `fatalError` on tap creation, terminate-on-revoke; refuses to touch `tccutil`) is the direct response to this history.

---

## 5. User-visible features and exact mechanics (effects registry)

Registry: `LockEffect` (`LockEffect.swift:18-57`) grouped into categories `none / visual / words / games` (`LockEffect.swift:9-16,35-46`). UI: category segmented picker + per-category effect picker (`ContentView.swift:109-126`). Category switch preserves a compatible effect, else falls back to confetti/speakRandomWord/typingGame (`ContentView.swift:297-314`). Default effect: `.speakRandomWord` (`BabyKeyboardLockApp.swift:24`); `speakAKeyWord` is auto-migrated to `speakRandomWord` at launch (`ContentView.swift:270-272`).

Per effect, on each surviving keyUp (`EventEffectHandler.handle`, `EventEffectHandler.swift:314-439`):

| Effect | Mechanics |
|---|---|
| `.none` | plays NSSound "bottle" (`:321`); no visuals |
| `.confettiCannon` | `AnimationView` fires a ConfettiSwiftUI cannon at a random screen point per letter/digit key, sound pool of 5 copies of `confetti-cannon` (`views/AnimationView.swift:75-113`, cleanup after `confettiFadeTime`, default 3 s / UI slider 1–10 s `ContentView.swift:145-157`) |
| `.speakTheKey` | speaks the pressed character in the primary language (`:326-332`) |
| `.speakAKeyWord` | picks a word starting with the pressed letter from `simpleWordsMap` (`:45-72`) or (in `mainWords` engine) from the custom main-words map, may substitute the baby name (`getRandomWord`, `:453-503`); speaks primary + delayed secondary translation (`:333-366`) |
| `.speakRandomWord` | **the main mode** — ignores which key was pressed; `RandomWordList.shared.getRandomWord()` picks the word (see §6); speaks primary + delayed secondary (`speakRandomWord`, `:782-833`). With **gamify** on (`ContentView.swift:164-172`): a target letter is chosen and announced (`selectNewGamifyTarget`, `:769-780`); wrong keys return "" (no effect, `:376-378`); the correct key clears the target, speaks/shows the reward word, and the next press picks a new target. The overlay shows a white "Find the letter <X>" card while a target is pending (`views/WordDisplayView.swift:73-100`) |
| `.typingGame` | `TypingGameState.shared` (singleton, `TypingGameState.swift:16-199`): picks a word (main words / random list / hardcoded 10-word fallback, `selectNewWord` `:102-164`), the typing language is randomly drawn per word from the enabled `typingGameLanguages` set (`:110`); each key is validated against the next letter (`validateKeyPress` `:63-99`); correct → "bottle" sound + letter spoken, wrong → "Basso" sound (+ optional reset-on-error, toggle `ContentView.swift:207-213`), completion → "Glass" sound + word + delayed translation (`EventEffectHandler.swift:384-434`). `TypingGameView` renders letters green-as-typed with a spring pop, a flashcard/video, and a celebration overlay for 2.5 s (`views/TypingGameView.swift:27-127`) |
| `.bubbles/.stars/.animals/.rainbowTrail` | "(BETA)" suffixed (`LockEffect.swift:48-56`); `VisualEffectsView` spawns 30 gradient bubbles / 40 glowing stars / 3 bouncing animal emojis (8 kinds) / a fading rainbow path segment per keypress at random positions (`views/VisualEffectsView.swift:98-149` dispatch; component views `:157-499`) |

Word display overlay (`views/WordDisplayView.swift`): listens to `lastKeyString` (`:197-258`); resolves primary/secondary display strings through the same translation resolver as speech; shows a white rounded card with word (48 pt bold), translation (32 pt), and optionally a flashcard image sized by `flashcardImageSize` (50–1000 px slider, `AdvancedSettingsView.swift:441-446`); auto-hides after `wordDisplayDuration` (1–15 s slider, default 3.0 — `LockEffect.swift:116`, `AdvancedSettingsView.swift:175-180`) via a cancellable work item (`scheduleHide`, `:391-402`). Card only renders when `showFlashcards` is on (`:101`) — with flashcards off there is **no on-screen word at all**, speech only.

Lock/unlock feedback: "light-switch-on"/"light-switch-off" sounds (`ContentView.swift:317-325`; sound files in `BabyKeyboardLock/sound_effects/`).

---

## 6. Word data layer

### 6.1 Canonical catalog
- Model: `WordDataCatalog { version, source, entries: [WordDataEntry], sets: [WordDataSet] }` (`utils/WordDataModel.swift:313-406`). `WordDataEntry` = `{id, spelling, meaningKey, partOfSpeech, category, tags, translations[{language,text}], definitions, assets[{kind: image|audio, language, uri, rotationDegrees}]}` (`:159-272`). Word id = `"<spelling>|<meaningKey>"` lowercased (`makeWordID`, `:357-361`). Decoders accept many legacy key aliases (`word`, `meaning_key`, `wordSets`, `lang/value`, …).
- Bundled source of truth: `BabyKeyboardLock/Resources/word_sets.json`, loaded by `WordRepository.reloadBundledCatalog` (`utils/WordRepository.swift:14-31`, URL lookup `:167-170` tries subdirectory `Resources` then flat). Contents (verified): `version: 2`, `source: "BabyKeyboardLock/utils/RandomWordList.swift"`, **149 entries, 15 sets**; entries have no `spelling`/`meaningKey` fields on disk (encoded in the compound `id`, e.g. `"mama|mother"` — the Swift decoder reconstructs them, `WordDataModel.swift:207-255`); translations cover 8 languages with articles baked into de/fr/es/it ("die Mama", "la maman"); definitions are template-generated (`A noun meaning "mama".`); every entry has a `frequency` zipf block; `assets` is `[]` for **all** entries (the populated remote-asset variant sits unapplied in `dev/artifacts/word_sets.remote_assets.json`, 135/149 entries with `https://cdn.example.com/...` placeholder URLs — so the remote-asset pipeline of §8.2 currently has nothing to resolve). Data quirks: set "Family (11 words)" actually lists 12 wordIDs; an empty set "Basic Words (Migrated)" (0 words) survives as a migration remnant (empty sets are dropped at load, `WordRepository.swift:64-66`).
- User overlay: a mutated copy is persisted to `~/Library/Application Support/BabyKeyboardLock/word_catalog.json` (`utils/WordCatalogStore.swift:3-63`); on launch the local catalog wins over the bundled one (`RandomWordList.loadCatalogAndWordSets`, `utils/RandomWordList.swift:362-380`). On this machine no `word_catalog.json` exists yet (verified: app-support dir contains only `learning_state.sqlite` + `learning.csv`) → bundled catalog is live.
- A hardcoded migration merges "granddad" into "grandpa" and renames the family set (`normalizeFamilyWordAliases`, `RandomWordList.swift:382-417`).
- Editing any set in the UI round-trips the whole catalog through `persistCatalogFromWordSets` (`RandomWordList.swift:435-490`), stamping `source: "user"` and writing ru translations into entries (`mergeTranslation`, `:498-518`).

### 6.2 Selection pipeline (`RandomWordList`)
- Two **word source modes** (`WordSourceMode`, `RandomWordList.swift:168-182`; UI `AdvancedSettingsView.swift:206-222`): `poolFeatured` ("Pool + Featured", default) and `legacySets`. The active candidate list `words` is: poolFeatured → featured words + featured-topic sets + *all* sets, deduped; legacySets → only enabled sets (`:248-257`).
- `getRandomWord()` (`:533-557`): ① daily-refresh check; ② in poolFeatured mode, try the **learning pool** first (`getLearningRandomWord`, §7) — this practically always supplies the word; ③ baby-name injection: accumulator-based probability (default 12.5%, slider 0–100% `AdvancedSettingsView.swift:69-77`) that guarantees eventual selection (`shouldPickBabyName`, `:1985-1994`); ④ otherwise weighted anti-repeat choice: recently-shown words get weight 0.2→1.0 by distance, unseen words 1.2 (`selectWeightedWord`, `:2006-2047`; history capped at `min(12, max(3, n/3))`, `:2170-2172`; commit `97e2904`).
- `findWord` and `getLastSelectedRandomWord` support the display view's translation lookups (`:559-571,1104-1106`).
- **Fact:** the parameter `useLearningRotation` of `getRandomWord(useLearningRotation:)` (`:533`) is **never read in the body** — `TypingGameState.swift:129` passes `false` expecting to bypass the learning pool but does not.

### 6.3 Translations (multi-source fallback chain)
`EventEffectHandler.getTranslation` (`EventEffectHandler.swift:614-748`), in order: baby-name override → (mainWords engine) custom pair store → canonical catalog by wordID → catalog by spelling/meaning ("catalog spelling/meaning fallback" warning) → random-word ru field → legacy hardcoded dictionaries for fr/ru/de/es/it/ja/zh (`EventEffectHandler.swift:75-276`) → identity fallback (returns the English). Every non-primary path logs a one-shot `WARNING:` NSLog (`warnFallbackUsed`/`warnMissingTranslation`, `:290-312`) — these warnings are the observable telemetry for catalog gaps.
- Languages: `TranslationLanguage` en/fr/ru/de/es/it/ja/zh + none (`LockEffect.swift:59-100`). Primary + secondary pickers in Settings → Speech (`AdvancedSettingsView.swift:110-128`). Secondary is spoken after `wordTranslationDelay` (0–2.5 s, default 0.8).
- Live user state on this machine (defaults domain `com.fangxing.BabyKeyboardLockDebug`): primary = russian, secondary = spanish, engine = mainWords, mode = poolFeatured, flashcards on, style "simple", display duration 6 s.

### 6.4 Legacy "Main Words" engine
`WordSetType` `randomShortWords`/`mainWords` (`LockEffect.swift:102-113`, "Engine" picker `AdvancedSettingsView.swift:224-233`). `mainWords` uses `CustomWordSetsManager` (`utils/CustomWordSet.swift:16-124`): a single UserDefaults-stored set seeded with 30 ru pairs (`:27-65`), edited via `WordSetEditorView` (`ContentView.swift:488-584`). It changes `speakAKeyWord`'s per-letter map (`EventEffectHandler.swift:459-481`) and typing-game word choice (`TypingGameState.swift:116-126`) — it does **not** change `speakRandomWord`, which always goes through `RandomWordList`.

---

## 7. Learning system (pool, rotation, persistence)

- `LearningWord {id, word, clarification, translation, tags, known, favorite, seenCount, lastSeen}` (`RandomWordList.swift:149-159`).
- Sync: `syncLearningWordsWithCurrentWords` (`:1288-1376`) rebuilds the learning dictionary from active sets + featured words (tagged `featured`,`basic`, auto-favorite) + custom-image words (tagged `family`, auto-known/favorite) + baby name; existing known/favorite/seenCount survive. Auto-favorites: hardcoded family words list (`:231-235`), words with custom images, baby name (`defaultFavorite`, `:1422-1433`). Re-sync is daily (`shouldSyncLearningWords`, 86 400 s, `:1157-1160`) or forced by any set/mode change.
- Pool: `learningPoolKeys` — a persisted random subset of eligible words, size `learningPoolSize` (5–200, default 25, `:946-951`), featured words/topics guaranteed in (`buildLearningPool`, `:1200-1235`).
- Per-key selection (`getLearningRandomWord`, `:2049-2092`): favorite bucket with prob `learningFavoriteRatio` (default 0.2) → else known vs unknown by `learningKnownRatio` (default 0.5) → tag-weighted filter over 4 fixed tags `basic/cool/action/family` (`pickTag`, `:2124-2140`) → recency-weighted pick (unseen ≈ weight 11, seen-today ≈ 1; `selectLearningWord`, `:2094-2122`). Increments `seenCount`, auto-marks `known` at `learningKnownViewsThreshold` (default 20, 0 = off), stamps `lastSeen`, saves.
- Persistence: SQLite `~/Library/Application Support/BabyKeyboardLock/learning_state.sqlite`, single table `learning_words`, full delete+reinsert on every save (`utils/LearningStateStore.swift:64-107`, schema `:135-150`). Verified live: 149 rows on this machine. A sibling `learning.csv` exists there (legacy export; nothing in current code reads or writes CSV). "Open Learning Data" opens the sqlite file with the default app (`RandomWordList.openLearningDatabase`, `:957-966`).
- Editors: `LearningWordEditorView` — spreadsheet of word/clarification/translation/tags/seen/known/fav with a "show only current pool" filter (`views/LearningWordEditorView.swift:13-163`); `ActivePoolPreviewView` — read-only pool list with filter and copy-to-clipboard (`ContentView.swift:388-486`); `FeaturedWordsEditorView` — catalog search with suggestions (definition/has-image hints), add-new-word upsert into the catalog, batch apply (`AdvancedSettingsView.swift:1138-1324`, backed by `featuredWordSuggestions`/`upsertFeaturedWord`, `RandomWordList.swift:996-1102`).
- **Unreachable/inert pieces (verified):**
  - `learningRotationEnabled` is written by a toggle that lives only in `LearningPoolSettingsView` (`AdvancedSettingsView.swift:925-933`), and that view is **not in the Settings TabView** (`AdvancedSettingsView.swift:13-37` shows only General/Speech/Library/Media) nor referenced anywhere else. Moreover the flag is **never read by selection logic** — grep shows only definition/persistence sites (`RandomWordList.swift:197,238,884,919-921`). The learning pool is therefore always active in poolFeatured mode regardless of the toggle.
  - Also orphaned (defined, never instantiated): `VoiceSettingsView` (`AdvancedSettingsView.swift:614`), `LanguageSettingsView` (`:668`), `BabyProfileSettingsView` (`:702`), `LearningPoolSettingsView` (`:887`) — leftovers of an earlier Settings layout; the live Library tab re-implements pool controls minus rotation-toggle/threshold/tag-mix (`:264-318`). Consequently **"Auto-mark known after N views" and the tag-mix sliders currently have no reachable UI**, though their stored values still drive selection.

---

## 8. Flashcards & media

### 8.1 Styles and bundled images
- `FlashcardStyle`: 12 cases — crayon, doodle, pencil, simple, watercolor, mosaic, elvish, pastel, clay, chalk, sticker, pixel (`utils/FlashcardStyle.swift:4-16`). The style setting is a serialized multi-select pool (`"none"` token / comma list; legacy `"random"` = all; `:22-59`), edited by a grid of toggle buttons (`views/FlashcardStylePicker.swift`); each shown card randomly draws one enabled style (`FlashcardStyle.randomStyle`, `:57-59`).
- On-disk image dirs exist only for 8 styles (`BabyKeyboardLock/Resources/FlashcardImages/*`, 947 PNGs total): crayon 135, doodle 135, pencil 135, simple 135, elvish 134, mosaic 134, watercolor 134, generated 5. Styles pastel/clay/chalk/sticker/pixel have **no assets** — selecting them yields image-less cards unless a custom/remote asset matches. The corpus is ~1.2 GB (per `dev/notes/artifacts/2026-04-07-asset-storage-and-size-reduction-plan.md`), which motivated the (unfinished) remote-asset migration.
- Naming convention `<style>_<word with _ for spaces>.png`; lookup tries flat bundle, then `Resources/FlashcardImages/<style>/…`, then `Resources/…` fallbacks (`utils/FlashcardAssetStore.swift:37-64`).
- Color words short-circuit everything: an 800×800 color square is generated at render time for 12 color names when clarification is nil/"color" (`FlashcardStyle.swift:155-199`).

### 8.2 Resolution order for a displayed card
`WordDisplayView` (`views/WordDisplayView.swift:126-156` + `updateMediaAvailability` `:350-389`): ① activated video (see 8.4) → ② custom user image (with per-image rotation) → ③ baby image if the word is the baby name (`:143-149`) → ④ generated/bundled style image via `RandomWord.flashcardImage` (`FlashcardStyle.swift:83-96`: color square → `FlashcardAssetStore.imageSelection`). `FlashcardAssetStore.imageSelection` (`FlashcardAssetStore.swift:21-35`) prefers **catalog remote assets**: entry assets with http(s) URIs are cached under `~/Library/Application Support/BabyKeyboardLock/RemoteFlashcardAssets/` (base64-name files), downloaded on demand with in-flight dedup and a `flashcardAssetCacheDidUpdate` notification on arrival (`:66-207`); `file:`/local URIs are used directly. Typing game has its own near-identical resolution (`views/TypingGameView.swift:179-229`, video-first when enabled).

### 8.3 Custom images (user media)
- Model `CustomWordImage {word (actually wordID key), imagePaths[], imageRotations[]}` (`RandomWordList.swift:58-110`), stored in UserDefaults with per-file **security-scoped bookmarks** (`customWordImages`/`customWordImageBookmarks` keys; add/replace/remove/rotate: `:1437-1702`); rotation is 0/90/180/270 per image (`rotateCustomWordImage`, `:1667-1693`). Multiple images per word rotate through a shuffled queue (`nextCustomImageIndex`, `:2174-2188`).
- Editor: `CustomWordImageEditorView` (`ContentView.swift:586-942`) — list, add by word+clarification, NSOpenPanel multi-select (images **and movies**: `panel.allowedContentTypes = [.image, .movie]`, `:826`), preview with rotation controls, quick-add buttons (Mama/Papa/Grandma/…, `:684-723`). Reachable from Settings → Media → "Manage" (`AdvancedSettingsView.swift:489-492`).
- Folder sync: pick a folder (read-only bookmark); files named `word.png` / `word|meaning.jpg` / `word__2.mp4` (numeric suffixes stripped) are auto-imported on launch and via "Sync now" (`syncCustomImagesFromFolder` + name parsing, `RandomWordList.swift:1704-1892`; UI `AdvancedSettingsView.swift:496-536`). Allowed extensions include images and mp4/mov/m4v/webm (`:1830`).
- Baby image: separate single image with its own bookmark (`setBabyImageURL`/`getBabyImageURL`, `RandomWordList.swift:654-712`; UI `AdvancedSettingsView.swift:450-474`).

### 8.4 Video cards and the cat-video demo (current behavior)
- `showVideoCards` (Settings → Media, `AdvancedSettingsView.swift:432`) enables video playback on cards. In **random-word mode** the video does not autoplay: when a card with an available video is on screen, the **next key press activates the video** instead of advancing the word (`shouldActivateVideoOnSecondKeyPress`/`activateVideoForCurrentCard`, `WordDisplayView.swift:321-340`); the card then stays up for max(display duration, video length + 0.8 s) and the video plays once, muted (`LoopingVideoView` with `shouldLoop: false`, `:129-133`, player impl `:454-558`). In the **typing game**, videos loop continuously as the card media (`TypingGameView.swift:131-134`).
- Video sources per word: custom user video (folder-sync/manual, preferVideo selection `RandomWordList.getCustomImageSelection(preferVideo:)`, `:1556-1631`) → bundled `Resources/FlashcardVideos/...` lookup by `<style>_<word>.<ext>` then `<word>.<ext>` across 6 candidate subdirs including `demo` (`FlashcardStyle.swift:98-153`).
- **The only bundled video is the demo cat**: `BabyKeyboardLock/Resources/FlashcardVideos/demo/simple_cat.mp4` (4.0 MB; alongside its source frame `simple_cat_source.png`, 1.8 MB) — the single file with an explicit `PBXBuildFile` resources entry (`project.pbxproj:36,12,234`) on top of the synchronized group. `FlashcardVideos/demo/README.md` documents the intended workflow (generate a 1-2 s loopable clip from the source frame) and the exact test recipe: random-word mode, Show Flashcards ON, style Simple, Show Video Cards ON, Video Demo ON, demo word `cat`; first key press → still card, second key press before timeout → video.
- **Demo mode** (`videoCardDemoMode` + `videoCardDemoWord`, default "cat"; UI appears only when video cards are on: `AdvancedSettingsView.swift:434-439`): forces *every* key press in speakRandomWord/speakAKeyWord to resolve to the demo word — speech override (`demoWordOverride`, `EventEffectHandler.swift:600-611`), display override (`resolvedEnglishWordForDisplay`, `WordDisplayView.swift:342-348`), and style forced to exactly `simple` so the `simple_cat` assets match (`enforceDemoFlashcardStyleIfNeeded` in both `ContentView.swift:327-333` and `AdvancedSettingsView.swift:559-565`; effective-style override `WordDisplayView.swift:34-39`). Net effect when enabled: press any key → "cat" card with the simple-style image; press again → the cat video plays once. On this machine `videoCardDemoMode = 0`, `videoCardDemoWord = cat` (live defaults).

---

## 9. Shared library ("Daria Shared Library")

- Client: `utils/SharedLibraryClient.swift` — GET `<base>/api/shared-library` (path/query of the base URL are discarded, `endpointURL` `:69-85`), optional `?demo=1` (default **on**: `includeDemo: Bool = true`, `:104`), optional `x-access-pin` header (`:109-111`), 20 s timeout. Contract: `SharedLibraryFeed {schemaVersion(=1), generatedAt, source, items[], warning}`; item = `{id, title, createdAt, image?, videos[], music?}`, asset = `{id, kind image|video|music, url, pathname, bytes, createdAt}` (`:3-33`). Unsupported schema version throws (`:124-126`).
- Player window: `views/SharedLibraryView.swift` ("Daria Shared Library", opened from the main window `ContentView.swift:236-245`). Base URL stored in `sharedLibraryBaseURL` (default `http://localhost:3848`, `:44`), PIN is not persisted. Media view: shows the item's image, then after 1.6 s crossfades into its first video (looping, muted), while `music` plays via a separate `AVPlayer` (`SharedLibraryMediaView`, `:184-234`).
- Advancement: click/Next/space; while the keyboard is **locked** and reward mode is off, *any* blocked key advances the feed (`:145-148`). **Reward mode** (`sharedLibraryRewardMode`, toggle `:72-74`): the media is hidden behind a "Complete a word to reveal a creation" screen; a `.learningRewardEarned` notification (correct gamify letter or completed typing word, §3.9) advances and reveals for `wordDisplayDuration` seconds, then hides again (`:149-164`). This is the "Wire shared stories into learning rewards" feature (commit `b0a6015`).
- Networking preconditions in the app: `com.apple.security.network.client` in both entitlement files, and ATS exceptions `NSAllowsLocalNetworking` + insecure-HTTP for `localhost` (`BabyKeyboardLock-Info.plist:11-23`; commit `797f8e0` "Allow shared library network access").
- **The server side is NOT in this repo.** Verified by full sweep of `web/`: there is no `app/api/shared-library` route, no `schemaVersion`, no `x-access-pin` handling, no `?demo=1`, no `/baby` page, and the string `3848` appears nowhere in `web/` (the Next.js dev server runs on the default 3000; `Makefile` `WEB_PORT ?= 3000`). The contract exists only on the Swift side (`SharedLibraryClient.swift:69-126`) and in its unit-test fixture (`BabyKeyboardLockTests/SharedLibraryClientTests.swift:20-49`, first item `"demo-cat"`, asset path `/demo/cat.svg` at `http://localhost:3848`). `CHANGELOG.md` calls the source "the web generator's versioned creation feed" — an external "Daria" web-generator project. **Consequence: the in-app Shared Library window only works when that external service is running locally on 3848; against this repo's own web app it gets connection errors/404.**

---

## 10. Speech (TTS)

- `AVSpeechSynthesizer` singleton per `EventEffectHandler` (`EventEffectHandler.swift:284`). Voice choice per utterance (`createUtterance`, `:505-545`): Personal Voice (macOS 14+, only for primary English, `:512-522`) → exact language-tag voice → base-language voice, preferring identifiers containing "siri" (`preferredVoice`, `:565-567`); missing voice logs a one-shot warning.
- Personal Voice: toggle in Settings → Speech; enabling requests `AVSpeechSynthesizer.requestPersonalVoiceAuthorization` and alerts if unavailable/unsupported (`EventHandler.swift:412-491`).

## 11. Web app (`web/`)

A Next.js 16 App Router project (package name still `my-v0-project` — v0.dev scaffold, `web/package.json:2`), title "Baby Word Flashcards" (`web/app/layout.tsx`). Two generations coexist:

**Live "v2" surface (functional, no auth):**
- `/` renders `FlashcardPlayerV2` (`web/app/page.tsx:1-5`; component `web/components/flashcard-player-v2.tsx`, 803 lines): set/language pickers (en/ru/de), featured-words chips persisted to localStorage, big flashcard, Next/Speak/Mute/AutoSpeak/Generate-Image controls, audio record-and-override panel; **any keypress advances the word** (`flashcard-player-v2.tsx:434-444`) — the web mirror of the baby-keyboard concept.
- `/api/v2/words` (`web/app/api/v2/words/route.ts:12-86`) serves the catalog **read directly from the macOS bundle file** `BabyKeyboardLock/Resources/word_sets.json` via `web/lib/canonical-model.ts` (`:191-206`), whose types (`CanonicalWordEntry` etc., `:6-47`) and `spelling|meaningKey` word-id scheme (`makeWordID`, `:81-85`) intentionally mirror `utils/WordDataModel.swift` — this file-level catalog is the actual macOS↔web interop, not an API.
- `/api/v2/assets/audio/{resolve,upload}`, `/api/v2/assets/image/generate` (Gemini `gemini-2.5-flash-image` via raw fetch, deterministic fallback SVG card when no key), `/api/v2/assets/video/upload` (**no caller in the UI**). Media stored via `web/lib/media-storage.ts` — local `web/public/` or S3 (`AWS_S3_BUCKET` etc.). None of the v2 routes check authentication.

**Legacy "v1" surface (Supabase-backed):**
- `/manage` parent admin (`web/components/admin-dashboard.tsx`) behind Supabase email/password auth (`/auth/login`, `/auth/sign-up`; gate in `web/lib/supabase/middleware.ts:48-55`, wired through `web/proxy.ts` — Next 16's middleware file, not a network proxy). Word CRUD (`/api/words`, `/api/words/[id]` — PATCH only updates `topic_id`), topics, per-user settings, custom images (Supabase Storage bucket `images`), Gemini image generation, custom audio (**stored as base64 data-URLs in the DB column — an acknowledged in-code placeholder**, `web/app/api/custom-audio/route.ts:60-71`).
- Schema: 11 SQL migrations (`web/scripts/001…011`): `words` (word_en/ru/de), `custom_audio`, `custom_images`, `user_settings`, `word_images`, `topics`, `user_word_progress`, RLS policies, one public bucket `images`. Seed word #1 is `cat/кот/Katze` (`002_seed_initial_words.sql:5`).
- Dead/broken web pieces (verified): `web/components/flashcard-player.tsx` (981-line v1 player, imported by nothing), `/auth/error` (unreachable), `scripts/upload-local-images.js` (queries nonexistent `text_en/ru/de` columns), `lint` script (no eslint installed), `ai`/`@ai-sdk/google` deps installed but never imported, `web/public/generated-audio` absent so the presynth audio manifest always resolves empty, and mixed npm+pnpm lockfiles.
- Deploy evidence: none in-repo (no `.vercel`, no project refs); Supabase creds are env-only and no `.env.local` exists on disk (readme references a missing `.env.local.example`).

## 11b. Scripts, tooling, docs

**Deploy chain (Makefile → shell):** `make deploy` = `clean` (`rm -rf build/`) → `archive` (`xcodebuild clean archive -scheme BabyKeyboardLock -configuration Release`, `scripts/archive.sh:7-11`) → `export` (writes `ExportOptions.plist` with `method=mac-application`, `signingStyle=automatic`, then `xcodebuild -exportArchive` into `./build/export`, `scripts/export.sh:10-29`) → `install` (`cp -R ./build/export/BabyKeyboardLock.app /Applications/`, `scripts/install.sh:7`). Because this builds **Release** (sandboxed), the installed app hits §4.3.1. `install.sh:11` still advises the removed `make fix-signature`. No test target, no notarization target exists in the Makefile.

**Python tooling (uv, Python 3.13, `pyproject.toml` name `Baby-Keyboard-Scripts`):**
- `scripts/word_utils.py` + `scripts/list_words.py` — parse word sets **out of the Swift source** `RandomWordList.swift` by regex (`word_utils.py:12,46-50`) — pre-catalog leftovers; the data they scrape no longer lives there (sets now come from the JSON catalog), so their output is historical.
- Catalog pipeline (functional, all read/write `BabyKeyboardLock/Resources/word_sets.json`): `generate_library_words.py` (wordfreq-based new-word candidates), `generate_llm_definitions.py` (claude-3-5-haiku via calmlib, upserts `definitions[]`, dry-run unless `--write`), `catalog_frequencies.py` (zipf `frequency` blocks, missing-only by default), `vocabulary_manager.py` (litellm local/cloud augmentation CLI — meaning-key required for translations/definitions; does not itself touch the catalog file), `prepare_flashcard_assets.py` (scans FlashcardImages → `dev/artifacts/flashcard-assets-manifest.json` + `word_sets.remote_assets.json`; `--write-catalog` rewrites the real catalog with remote asset URIs).
- `scripts/generate_images.py` — bulk style-image generation via calmlib into `Resources/FlashcardImages/<style>/`, 7 style presets, skips existing, interactive confirm.
- Broken Makefile targets: `download-openimages`, `dictionary-showcase`, and the PRD-cited `scripts.catalog_translations` module all point at files that now live only in `scripts/archive/` (moved by commit `97c4c33`).
- CI: `.github/workflows/main.yml` runs Python pytest (ubuntu) only; the macOS build workflow `ci_cd.yml` is fully commented out.

**Docs:** `readme.md` — features, `make deploy`, web/Supabase env setup, the cross-Mac certificate ritual (§4.4); accessibility appears only as an unchecked TODO (`:114`). `CHANGELOG.md` — single `## Unreleased` section describing the shared-library player, word-source modes, video demo mode, id-centric resolution, Settings reorg. `AGENTS.md`/`GEMINI.md`/`WARP.md`/`.cursorrules` are byte-identical generic personal-ecosystem rules (headers differ only); `CLAUDE.md` is the only project-specific agent doc and defines the `dev/notes/actions/` issue-log convention. `responses.txt` — Q&A dump about generate_images defaults (145 words scraped from Swift at that time).

**Dev notes = the intent record:** `dev/notes/actions/` holds 30 issue docs (raw user text first line); `dev/notes/tasks.md` a lettered backlog `a..ad` (+done `ae..ai`, last: "Generate videos based on photos as first frame and play them on a second key press" — the video-cards feature, commit `9ffbb0d`); `dev/notes/artifacts/` PRDs including `2026-04-07…size-reduction-plan.md` (FlashcardImages ≈ 1.2 GB; move corpus to object storage) and `2026-04-08…remote-flashcard-asset-migration.md` (the manifest/upload flow that `prepare_flashcard_assets.py` + `web/scripts/upload-flashcard-assets.js` + `FlashcardAssetStore` implement); `worksession/prd-word-meaning-id-migration.md` (canonical `word_id` as sole runtime identity — ~95% done per `dev/notes/artifacts/02-22-compound-id-audit-fixes.md`, 4 known gaps) and `worksession/word-system-checklist.md` (10 items, all deliberately unchecked, with a 2026-02-25 discussion log recording what actually shipped: 8-language translations with baked-in articles, template definitions for all entries, frequency blocks).

**`scripts/cleanup_archive_clone.sh`** (the pre-existing dirty file): deletes heavy dirs (`.venv`, `web/node_modules`, `web/.next`, `build`, …) from an archive clone; `--include-optional` additionally removes `dev/Resources`, archives, and `dev/personal_certificate.p12`. The uncommitted edit only changes the default archive path.

---

## 12. Localization

`BabyKeyboardLock/Localizable.xcstrings` (v1.1, source `en`): **209 keys; languages en, de, zh-Hans** (de 22 translated, zh-Hans 23 translated, 170 keys have no localization block at all — English-only in practice). Known regions en/Base/zh-Hans/de (`project.pbxproj:205-210`). A `BabyKeyboardLockCN` scheme launches with `language = zh-Hans` (`xcshareddata/xcschemes/BabyKeyboardLockCN.xcscheme:37`) — and note its TestAction has **no Testables block**, so testing under that scheme runs nothing. Crowdin config `crowdin.yml` exists at repo root.

---

## 13. Persistence inventory

- **UserDefaults** (domain `com.fangxing.BabyKeyboardLockDebug` for dev builds — live and populated on this machine): lock/effect/languages (`lockKeyboardOnLaunch`, `selectedLockEffect`, `selectedPrimaryLanguage`, `selectedTranslationLanguage`), throttles/timing (`throttleInterval`, `wordsThrottleInterval`, `confettiFadeTime`, `wordTranslationDelay`, `wordDisplayDuration`), engine/mode (`selectedWordSetType`, `wordSourceMode`, `enabledRandomWordSets`, `featuredTopicSetNames`), gamify (`gamifyRandomWordEnabled`), speech (`usePersonalVoice`), flashcards (`showFlashcards`, `showVideoCards`, `videoCardDemoMode`, `videoCardDemoWord`, `flashcardStyle`, `flashcardImageSize`), baby profile (`babyName`, `babyNameTranslation`, `babyNameProbability`, `babyImagePath`, `babyImageBookmark`), custom media (`customWordImages`, `customWordImageBookmarks`, `customImagesFolderPath`, `customImagesFolderBookmark`), learning (`learningRotationEnabled`, `learningKnownRatio`, `learningKnownViewsThreshold`, `learningFavoriteRatio`, `learningTagRatios`, `learningPoolSize`, `learningPoolKeys`, `learningLastSync`, `featuredWordsBatch`, `featuredWordsUpdatedAt`), typing game (`typingGameResetOnError`, `typingGameLanguages`), shared library (`sharedLibraryBaseURL`, `sharedLibraryRewardMode`), legacy main words (`customWordSets`). Legacy keys `randomWordSets`/`randomWords`/`selectedRandomWordSetIndex` are purged at launch (`RandomWordList.swift:352-356`).
- **Files** under `~/Library/Application Support/BabyKeyboardLock/`: `word_catalog.json` (user catalog overlay; absent on this machine), `learning_state.sqlite` (present, 149 words), `learning.csv` (legacy, orphaned), `RemoteFlashcardAssets/` cache dir (created on demand).

---

## 14. Build system, signing, schemes, CI (verified)

- Xcode 16 project (`objectVersion = 77`), filesystem-synchronized groups — resources (`Resources/**`, `sound_effects/**`, `word_sets.json`) enter the bundle implicitly with folder structure preserved; the only explicit resource is `simple_cat.mp4` (`project.pbxproj:36,12,234`).
- 3 targets: app (product `BabyKeyboardLock Debug.app` in Debug / `BabyKeyboardLock.app` in Release), unit tests (hosted: `TEST_HOST` → the app binary, `project.pbxproj:513,532`; commit `f55cd47` "Repair Baby Keyboard debug test host" fixed the Debug TEST_HOST to the " Debug" product name), UI tests. Unit-test **Debug** config carries a different team `SQ5HJJDHG9` (`project.pbxproj:504`) vs the app's `5XCYR4LUMD`; Release test config has **no team** — signing of the test bundle may fail outside the original machine's cert set.
- Deployment target 15.0 (app/unit tests), 14.0 (UI tests), project default 14.6.
- Dependencies (SPM): ConfettiSwiftUI 1.1.0 (upToNextMajor), Sauce @ branch `master` (rev 9ed4ca4) — unpinned branch dependency.
- Schemes: `BabyKeyboardLock` (test config Debug, auto test plan, both test bundles) and `BabyKeyboardLockCN` (zh-Hans launch language, empty Testables). Archive/Profile use Release.
- CI: `.github/workflows/ci_cd.yml` is entirely commented out (lines 1-21) — no CI runs.
- Entitlements matrix — the load-bearing fact of §4: Debug un-sandboxed (`BabyKeyboardLock.entitlements:5-6` false), Release sandboxed (`BabyKeyboardLockRelease.entitlements:5-6` true) with user-selected-read-only + app-scope bookmarks + network client. Hardened runtime YES both. `dev/notes/actions/1-image-cache.md:6` already flags "re-check release entitlements for bookmarks".

## 15. Tests (what exists, what they actually verify)

- `BabyKeyboardLockTests/BabyKeyboardLockTests.swift:13-15` — one empty Swift-Testing test; asserts nothing.
- `BabyKeyboardLockTests/EventHandlerUnitTests.swift` — 4 tests over `EventHandler` init/toggle/AppStorage/effect-change. Each test first calls `setUp()` manually, which **wipes the host app's entire UserDefaults domain** (`removePersistentDomain(forName: Bundle.main.bundleIdentifier!)`, `:8`) — running these tests destroys the real dev-app settings recorded in §13. They are hosted tests: constructing `EventHandler` hits `requestAccessibilityPermissions()` (`EventHandler.swift:96`) and can trigger a TCC prompt on a fresh machine.
- `BabyKeyboardLockTests/SharedLibraryClientTests.swift` — 3 pure-logic tests: endpoint URL normalization (`http://localhost:3848/api/shared-library?demo=1`), player URL (`/baby`), and contract decoding of an inline JSON fixture whose first item id is `"demo-cat"` (title "Кот танцует") — the test suite is the executable specification of the shared-library contract.
- UI tests: template code; launch + screenshot, no real assertions (`BabyKeyboardLockUITests/*.swift`).

---

## 16. Status classification

**Verified working on this machine (code path complete + live runtime evidence):**
- Menu-bar lifecycle, overlay windows, lock toggle, event tap and blocking (§2-3) — the Debug app was built Mar 21 2026 and its defaults show sustained real use (window frames saved, effect = speakRandomWord, wordSourceMode = poolFeatured, learningLastSync populated, 149-row learning DB).
- Random-word mode incl. learning pool, weighted anti-repeat, baby-name injection, featured words, flashcards (style "simple", size 500, duration 6 s live), ru/es primary/secondary speech.
- Shared-library URL/contract logic (unit-tested: `SharedLibraryClientTests.swift`).

**Present and coherent but unverified at runtime (no way to confirm without launching):**
- Typing game, gamify mode, video cards + cat demo, visual-effect betas, folder sync, remote-asset caching, Personal Voice, reward mode of the shared library, localization (de/zh-Hans), Release archive/export flow.

**Broken or inert (exact defects):**
1. `LaunchAtStartup.setEnabled` ignores its argument — cannot disable launch-at-login (`LaunchAtStartup.swift:10-16`).
2. `learningRotationEnabled` toggle unreachable (only in orphaned `LearningPoolSettingsView`) and never read by selection logic (§7); "auto-mark known" threshold and tag-mix sliders equally unreachable in the current Settings layout.
3. `getRandomWord(useLearningRotation:)` ignores its parameter → the typing game draws learning-pool words despite explicitly requesting not to (`RandomWordList.swift:533`, `TypingGameState.swift:129`).
4. `AccessibilityAuthorization` is dead code that would crash on use (missing "Main" storyboard, `utils/authorization.swift:18`).
5. `scripts/install.sh:11` instructs "run: make fix-signature" — target no longer exists in the live `Makefile` (only `archive/Makefile.legacy:75-78`).
6. Release configuration is sandboxed → a Release build cannot obtain Accessibility or create the event tap (§4.3.1); the shipping path as configured cannot work.
7. `fatalError` on tap-creation failure (`EventHandler.swift:268`) — crash instead of degradation, reachable via the permission-loss/restart path.
8. Unit-test target's Debug team mismatch (`SQ5HJJDHG9`) and Release team absence (§14); CN scheme runs zero tests; CI disabled.
9. `EventHandlerUnitTests` destroy live user settings when run (§15).
10. Mouse is not blocked at all despite the app's premise ("keyboard lock" is accurate; any mouse-blocking notion is intended-only — zero mouse event types in the tap mask, `EventHandler.swift:252-256`).
11. Flashcard styles pastel/clay/chalk/sticker/pixel are selectable but have no bundled assets (§8.1).
12. Dead views/methods: `VoiceSettingsView`, `LanguageSettingsView`, `BabyProfileSettingsView`, `LearningPoolSettingsView`, `showOrCloseAnimationWindow`, `hideMainWindow` (§2, §7).

**Intended-only (documented plans, little or no implementation):**
- The shared-library **server** ("Daria" web generator, `/api/shared-library`, `/baby` player, port 3848) — consumer fully built, producer absent from this repo (§9).
- Remote flashcard assets in production: pipeline + client cache exist, but the shipped catalog has zero asset URIs and the generated manifest uses `https://cdn.example.com` placeholders (§6.1, §8.2) — never uploaded/applied.
- Presynthesized/Personal-Voice audio files (`readme.md:77` command points to an archived script; `web/public/generated-audio` absent; `dev/notes/actions/02-09-personal-voice-audio-generation.md`).
- Onboarding flow, Photos.app integration, 1k–10k word scale-up, permissions-reset command, mouse blocking, notarization — captured in `dev/notes/actions/*` and `readme.md:114-116` TODOs only.
- Word-meaning-id migration final 5%: 4 known gaps listed in `dev/notes/artifacts/02-22-compound-id-audit-fixes.md`; CI strict translation audit from `worksession/prd-word-meaning-id-migration.md:44-47` does not exist.

**In flight right now (uncommitted, parallel session — do not duplicate):** the accessibility-foundation rework (see header): silent trust check at init, prompt-once UX, non-fatal tap lifecycle with `eventTapState`, no terminate-on-revoke, permission status line in the main window, `AccessibilityPermission.swift` helper, `AccessibilityFoundationTests`, `make verify-ax` audit script. It addresses defects 4, 6(partially — audit only), 7 and the §4.3.2 prompt-once blindness.

---

## 17. Reproducible checks for a coding agent

Safe (no side effects):
```sh
# 1. Build Debug (signs Apple Development / automatic; no prompt, no install)
xcodebuild -project BabyKeyboardLock.xcodeproj -scheme BabyKeyboardLock -configuration Debug build

# 2. Inspect what actually got signed/entitled
codesign -d --entitlements - "$HOME/Library/Developer/Xcode/DerivedData/BabyKeyboardLock-"*/Build/Products/Debug/"BabyKeyboardLock Debug.app"

# 3. Run ONLY the pure-logic tests (hosted, but harmless assertions)
xcodebuild test -project BabyKeyboardLock.xcodeproj -scheme BabyKeyboardLock \
  -only-testing:BabyKeyboardLockTests/SharedLibraryClientTests

# 4. Verify catalog integrity without the app
python3 -c "import json; d=json.load(open('BabyKeyboardLock/Resources/word_sets.json')); print(d.get('version'), len(d.get('entries', d.get('words',[]))), [s['name'] for s in d.get('sets', d.get('wordSets',[]))][:5])"
```

Caution required:
- **Do not run `BabyKeyboardLockTests/EventHandlerUnitTests`** unless prepared to lose the live defaults domain `com.fangxing.BabyKeyboardLockDebug` (§15). Back it up first: `defaults export com.fangxing.BabyKeyboardLockDebug /tmp/bkl-defaults.plist`.
- Launching the app (`open "…/BabyKeyboardLock Debug.app"`) will fire the TCC prompt path on a machine without a grant and installs a global event tap once trusted — launch only via `open`/Finder (never the bare executable, §4.3.5), and remember Ctrl+Option+U unlocks.
- TCC ground truth: System Settings → Privacy & Security → Accessibility (the TCC.db is unreadable without Full Disk Access — verified in this session).
- The permission poll terminates the app if trust is revoked while running (`EventHandler.swift:190-195`) — expected behavior, not a crash.

Web app checks:
```sh
cd web && npm install && npm run dev        # Next dev server on :3000 (NOT 3848)
curl -s 'http://localhost:3000/api/v2/words?limit=3' | head -c 600   # catalog served from ../BabyKeyboardLock/Resources/word_sets.json
# /manage requires Supabase env (web/.env.local — currently absent); without it, middleware redirects /manage → /
```
Shared-library contract check (the server is external; to see the macOS client work without it, stub it):
```sh
# The app expects GET http://localhost:3848/api/shared-library[?demo=1] with x-access-pin,
# returning {"schemaVersion":1,"generatedAt":…,"source":…,"items":[{id,title,createdAt,image,videos,music}]}
# Fixture shape: BabyKeyboardLockTests/SharedLibraryClientTests.swift:20-49
```
Accessibility-foundation audit (added by the in-flight workstream): `make verify-ax` — non-destructive; builds for testing, dumps codesign/entitlements, runs the AX-related tests, never touches TCC.

---

## First coding moves

Ordered by dependency and risk (each unblocks or de-risks the ones after it):

1. **Land/review the in-flight accessibility-foundation change first.** It rewrites `EventHandler`, `authorization.swift`, `ContentView`, Info.plist and pbxproj — the exact files everything else touches. Until it is reviewed/committed, any other Swift work will conflict. Verify with `make verify-ax` plus a manual Debug run (`open ".../BabyKeyboardLock Debug.app"`), and confirm the four §16 defects it targets are actually gone (no `fatalError` on tap creation, no terminate-on-revoke, prompt shows on first launch, status line reflects tap state). Low risk, highest leverage.
2. **Decide the Release sandbox question before any distribution work.** As configured, Release cannot ever hold Accessibility (§4.3.1, proven historically by `a1813a3`). Either flip `BabyKeyboardLockRelease.entitlements` to `app-sandbox=false` (keeping the bookmark entitlements is then unnecessary but harmless), or split "App Store-able" ambitions from reality. Everything deploy-related (`make deploy`, notarization, second-Mac installs) depends on this one-line decision. Tiny diff, but it invalidates existing TCC rows for the release bundle id — schedule it with a re-grant step.
3. **Fix the two one-line behavioral bugs that mislead users:** `LaunchAtStartup.setEnabled` ignoring its argument (`LaunchAtStartup.swift:10-16` — call `SMAppService.mainApp.unregister()` on false) and `getRandomWord(useLearningRotation:)` ignoring its parameter (`RandomWordList.swift:533` — honor it, so the typing game stops draining learning-pool counters). Isolated, testable, no dependencies.
4. **Make the tests safe to run.** `EventHandlerUnitTests.setUp` wipes the live defaults domain (§15) — point it at a scratch suite (`UserDefaults(suiteName:)`) so agents can run the full test bundle without destroying real settings. This unblocks routine `xcodebuild test` in every later task. (The in-flight workstream already edits this file — fold in.)
5. **Reconnect or fence the dead settings surface.** Either mount `LearningPoolSettingsView`'s unique controls (rotation toggle, known-views threshold, tag mix) into the Library tab, or delete the four orphaned views and the unread `learningRotationEnabled` flag (§7). Do this before any new settings work so the next feature doesn't build on dead UI. Requires product decision but no technical risk.
6. **Shared library: build or stub the missing server.** The Swift client + tests define contract v1 precisely (§9); nothing serves it. Cheapest unblock: a tiny `/api/shared-library` route (+ `/baby` page) in `web/` on port 3848 or change the default base URL — then the whole Daria feature becomes demonstrable. Depends on nothing above; riskless to prototype behind the existing `?demo=1` flag.
7. **Finish the remote-asset migration or park it explicitly.** Upload the 942-image manifest to real storage (`make s3-bucket-setup` + `web/scripts/upload-flashcard-assets.js`), regenerate the catalog with real URLs via `prepare_flashcard_assets.py --write-catalog`, and only then consider trimming bundled styles. Highest-risk item here (touches the 1.2 GB corpus and app bundle contents) — do last, after tests (move 4) are safe and the catalog identity work is stable.


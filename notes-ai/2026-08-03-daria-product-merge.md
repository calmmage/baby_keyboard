---
type: ai-synthesis (product + architecture)
date: 2026-08-03
author: Claude Fable (grounded repo inspection, no product code modified)
sources:
  - /Users/petrlavrov/work/projects/baby_keyboard (branch dev, HEAD 6be2027)
  - /Users/petrlavrov/work/projects/v0-creative-content-generator (branch main, HEAD d3ce62c; side branches inspected)
  - v0-creative-content-generator/notes-human/ (vision + thinking, read-only)
---

# One Daria Product — Baby Keyboard × Creative Generator merge

## 0. Executive summary

The two repos are already halfway merged and nobody wrote it down. As of July 2026 the
macOS app fetches the web app's shared creation feed (`SharedLibraryClient.swift`),
plays it in a native window (`SharedLibraryView.swift`), and gates it behind learning
rewards (`EventHandler.swift`, notification `.learningRewardEarned`). The web app
serves a versioned feed contract (`/api/shared-library`, `schemaVersion: 1`) and has
its own full-screen baby player (`app/baby/page.tsx`).

The proposal below does not rewrite either side. It:

1. keeps the Swift app as the **reliable blocker + offline learning engine** (its event
   tap, throttles, TTS, SQLite learning store are the most battle-tested code in either
   repo);
2. keeps the Next.js app as the **creation studio + media backend** (providers,
   storage, grouping, PIN, bilingual UX);
3. promotes the existing feed contract into the **sync spine** (v1 → v2, additive);
4. adds a thin **manifest layer** (server-side DB) that gives media durable identity,
   word linkage, favourites, rotations, topics — the things filenames can't carry;
5. splits everything cleanly into a **hand-controlled deterministic core** (Petr edits,
   machines obey) and an **AI suggestion plane** (assistant proposes, Petr approves —
   using the approve-into-pool mechanism the app already has for featured words).

Two real product gaps found during inspection, both fixable without architecture work:
- **Last-frame video is broken on main** and even the side-branch fix only supports
  loop (last = first). Directed clips (distinct first + last frame) exist nowhere.
  Details and exact lines in §8.
- **The app's library connection points at `http://localhost:3848`** by default
  (`SharedLibraryView.swift:44`) — there is no deployed, stable shared-library URL, so
  the merge only works when the dev server happens to run.

---

## 1. Grounded inventory — what actually exists

### 1.1 Baby Keyboard (Swift, `~/work/projects/baby_keyboard`)

**Blocker core** — the part that must never regress:
- CGEvent tap + run-loop source: `BabyKeyboardLock/EventHandler.swift:36-37`; lock
  state `isLocked` at `:67`; tap lifecycle state machine `eventTapState` at `:70`.
- Locking refuses to engage unless the tap is actually blocking-ready:
  `setLocked` at `EventHandler.swift:186-204`, readiness check at `:213`
  (`accessibilityPermissionGranted && eventTapState.isBlockingReady`).
- Per-category throttles: visual-effect vs word throttle chosen at
  `EventHandler.swift:87-88` (`wordsThrottleInterval` vs `throttleInterval`,
  persisted in UserDefaults, `:112-118`).
- Effect registry with categories (none/visual/words/games):
  `BabyKeyboardLock/LockEffect.swift:18-46`.

**Word system** (`BabyKeyboardLock/utils/RandomWordList.swift`, 2209 lines — the
richest single asset in either repo):
- Canonical word identity `spelling|meaningKey` is implemented:
  `WordDataModel.swift:357` (`makeWordID`), `:363` (`splitWordID`); catalog
  normalization at `RandomWordList.swift:363-431`. This is the `word|meaningKey`
  scheme the old backlog item `w` asked for — it exists.
- Data structs: `RandomWord` (id/english/translation/clarification)
  `RandomWordList.swift:5-9`; `RandomWordSet` `:117-120`; `LearningWord`
  (tags/known/favorite/seenCount/lastSeen) `:149-159`; `CustomWordImage` with
  multi-image paths + per-image rotation degrees `:58-62`.
- Two source modes (`WordSourceMode`, `:168-182`): `poolFeatured` (featured words +
  featured topic sets + all sets) vs `legacySets` (enabled sets only) — computed
  `words` at `:248-257`.
- **Selection engine** (this is the deterministic core to preserve verbatim):
  - `getRandomWord` `:533-557` — learning rotation first, then baby-name, then
    weighted general pool.
  - Baby-name probability with an accumulator so the name is *guaranteed eventually*
    (`babyNameRngAccumulator`, `:1985-1994`; default 12.5% at `:216`).
  - Anti-repeat weighting over recent history: weight 0.2→1.0 by distance for recent
    words, 1.2 for unseen (`selectWeightedWord`, `:2006-2047`).
  - Learning mix: favourite ratio → known/unknown ratio → tag ratio → recency-weighted
    pick (`getLearningRandomWord`, `:2049-2092`; ratios at `:2058`, `:2063`; tag pick
    `:2124-2140`).
  - **Spaced repetition, v0**: pick weight `1.0 + min(daysSinceLastSeen, 10.0)`
    (`selectLearningWord`, `:2094-2122`); auto-mark known after N viewings
    (`:2076-2078`, threshold slider-backed, default 20 at `:240`).
  - Learning pool of bounded size with featured-word/topic priority fill
    (`buildLearningPool`, `:1200-1235`; eligibility `:1247-1286`).
- **Persistence**: UserDefaults keys enumerated at `:187-208`; learning state in
  SQLite — `LearningStateStore.swift` (schema at `:144`: `known`, `favorite`,
  `seen_count`, `last_seen`; select `:20`, upsert `:75`).
- **Favourites already exist** as a first-class flag: seed set (mama/papa/grandma/…)
  `RandomWordList.swift:231-235`; `learningFavoriteRatio` default 0.2 `:241`;
  marking favourites when Petr adds a custom image `:1695-1704`.
- **Featured words = the existing approve-into-pool mechanism**: suggestion search
  `featuredWordSuggestions` `:1063`, batch set `setFeaturedWordsBatch` `:996`,
  featured topics `setTopicFeatured` `:291`. This is the exact UX slot where AI
  proposals should land (§6).
- **Custom images**: security-scoped bookmarks per word and per folder (keys
  `:192-196`), folder auto-sync `syncCustomImagesFromFolder` `:1730`, per-image
  rotation `rotateCustomWordImage` `:1667`, rotation queues `:223`.

**Flashcard display + styles**:
- Resolution order in `views/WordDisplayView.swift`: custom image (`:135`) → baby
  image for the baby's name (`:144`) → generated styled flashcard (`:151`); size and
  style pool from `@AppStorage` (`:16-17`).
- Style registry: 12 named styles (crayon/doodle/…/pixel), multi-select pool
  serialization — `utils/FlashcardStyle.swift:4-55`; per-style asset lookup incl.
  **flashcard videos on disk** (`flashcardVideoURL`, `:98-153`) and on-the-fly color
  squares for color words (`:155-199`). Asset cache: `utils/FlashcardAssetStore.swift`.
- Typing game (`TypingGameState.swift`, `views/TypingGameView.swift`) — completion
  flag `isWordComplete` is what feeds rewards.

**Cross-app wiring (July 2026 commits — already in `dev`)**:
- `2cc14ec` added `utils/SharedLibraryClient.swift` (feed decode, schema check `:61`,
  `/api/shared-library` endpoint builder `:69-85`, `/baby` player URL `:87-102`,
  `x-access-pin` header `:110`) + `views/SharedLibraryView.swift` (base URL + PIN
  fields `:44-71`, any-blocked-key advances feed `:145-148`, native image→video
  playback with 1.6 s image phase `:216-227`, music via AVPlayer `:218`).
- `b0a6015` added learning rewards: `.learningRewardEarned` notification posted from
  the event tap on a correct gamified letter or a completed typing word
  (`EventHandler.swift:334-356`); reward mode hides the feed until earned, reveals for
  `wordDisplayDuration` seconds (`SharedLibraryView.swift:99-110, 149-164`).
- `f55cd47` repaired the debug test host; "Allow shared library network access"
  adjusted entitlements.
- `web/` at the repo root is an **older, separate** v0-scaffold Next.js app (own
  `package.json`, S3 SDK, `scripts/upload-flashcard-assets.js`). Treat it as legacy;
  its one interesting idea (bulk flashcard-asset upload) is superseded by the
  generator's storage layer. Candidate for archival, not revival.

### 1.2 Daria Creative Generator (Next.js, `~/work/projects/v0-creative-content-generator`)

**Create flow** (`app/page.tsx`, client-side source of truth): language RU-default,
PIN check, mode quick/story, provider settings + generation toggles, video settings,
per-medium results with progress, story chapters, history dialog, group id — state
enumerated at `app/page.tsx:36-66`.

**Story mode**: `app/api/story/route.ts` + `lib/prompts.ts`. The system prompt locks
a single named character with 1-2 stable visual traits and a single setting, then
**restates both inside every scene's `videoPrompt`** for cross-clip identity
(`lib/prompts.ts:1-16`, esp. `:12`); scene texts in the child's language, media
prompts kept English (`:18-27`). Continuation prompts exist (`:29-50`). This
restated-identity trick is the seed of the Character entity in §7.

**Image generation**: providers openai/google/stability (`lib/types.ts:84-88`);
8 style presets appended to prompts — core/drawing/clay/paper/wood/ink/studio/felt
(`lib/types.ts:90-99`). (An older 3-preset registry lingers at
`lib/prompts.ts:52-59` — cartoon/storybook/playful — de-facto legacy; unify in §9.)

**Video generation** (`app/api/generate/video/route.ts`) — the load-bearing facts:
- Request fields include `useAsFirstFrame`, `useAsLastFrame` (`route.ts:29`).
- Cyrillic prompts auto-translated to English before dispatch
  (`maybeTranslateVideoPrompt`, `route.ts:98-126`).
- **Veo (main)**: only `requestBody.image` (first frame) is set (`route.ts:149-151`);
  `useAsLastFrame` never reaches Veo on main.
- **Higgsfield**: parameter arrives as `_useAsLastFrame` and is discarded
  (`route.ts:203`); first-frame image is *required* (`route.ts:211-213`); payload is
  `{image_url, prompt, duration}` only (`route.ts:217-221`); includes a full
  data-URL/private-proxy → Higgsfield CDN upload path (`route.ts:312-394`) worth
  keeping.
- **Sora**: `input_reference` first frame only (`route.ts:414-416`); no last-frame
  parameter exists in the API.
- **Side branch fix `d958d46`** ("Daria feedback 06, 03", on
  `fix/daria-feedback-bugs` / `feat/library-restructure`, **not on main**): sets
  `requestBody.config.lastFrame` for Veo — but deliberately pins the *same* image
  ("pin the same image as the closing frame so loop-mode clips return to their
  starting image"). The client sends a last frame **only when mode === "loop" and it
  is always the same `imageUrl`** (`app/page.tsx:260-261`, `:292-293`);
  `VideoSettings.useImageAsLastFrame` is literally commented "For loop animation"
  (`lib/types.ts:26`). → Directed first→last clips: not implemented anywhere. §8.

**Music**: suno/elevenlabs (`lib/types.ts:107-110`), Suno callback route exists.

**Media identity & grouping** (`lib/creation-identity.ts` — the best-designed module
in the web repo, reuse as-is):
- Path scheme `creations/{type}/{groupId}__{type}-{timestampMs}-{hash16}.{ext}`;
  groupId is "the sole durable join key across image/video/music" (docblock `:1-15`).
- Content hash: sha256 first 16 hex chars computed at upload
  (`lib/media-storage.ts:18`); private blob + proxy URL (`:26-31`); data-URL fallback
  without blob token (`:34`).
- Parsing tolerates legacy names (`parseCreationPathname`, `:115-159`); grouping
  (`groupLibraryItems`, `:210-242`); playable filter + deterministic newest-first
  rotation order (`:245-259`).
- **Reconciliation planner** for orphaned media: adopt-group and mint-group proposals
  within a ±15-min window, dry-run, deterministic (`planReconciliation`, `:273-408`);
  manual mapping UI at `app/manual/page.tsx` (the tool the components-overview note
  asked for — it exists).

**Library & players**:
- `app/library/page.tsx` (1336 lines): picker gallery + in-library baby mode; after
  `d958d46`, video triggers on key press, plays once, reverts to image (commit
  message; branch-only).
- `app/baby/page.tsx`: standalone full-screen player — any key/tap advances
  (`:49-61`), Escape exits to library (`:52-54`), image shows 1.6 s then video
  (`:42-47`), music loops (`:113`). Matches the viewer-library vision note.
- Shared feed: `app/api/shared-library/route.ts` — paginates all blobs (`:20-38`),
  limit clamp (`:14-18`), 15 s private cache (`:69`), demo fallback feed whose first
  card is, fittingly, "Кот танцует" (`lib/shared-library.ts:132`).

**Cross-cutting to preserve**: PIN auth via header/cookie (`lib/auth.ts`), bilingual
copy (`lib/translations.ts`), three-level errors — kid-friendly / raw / AI adult
explanation (`lib/error-handler.ts`), profanity guard (`lib/profanity.ts`), provider
env canon (`scripts/setup_wizard.py`), local browser cache (`lib/browser-storage.ts`).

**In flight on branches** (mine, don't rewrite):
- `worktree-creation-builder` `d119018`: guided builder — 82-animal grid + 3
  LLM-generated scenarios via `gpt-4.1-nano` (`components/builder-input.tsx`,
  `app/api/builder/options/route.ts`, `BUILDER_ANIMALS` in `lib/prompts.ts`). This is
  the creation-builder vision note, half-built.
- `feat/library-restructure` `1f4eb1f`: create/library archive flow restructure.
- `chore/self-host-infra` `f378a36`: Docker + Postgres + MinIO draft — the natural
  home for the manifest DB in §4.

### 1.3 Essential web UX that the merged product must carry (not link-out)

PIN gate · quick mode · story mode (real generated multi-scene story with stable
character/setting) · guided builder (animal → 3 scenarios) · voice input
(`components/voice-input.tsx`) · provider/style/toggle settings · per-medium progress
with three-level errors · history panel · library picker gallery · baby mode player ·
manual grouping tool · bilingual RU/EN everywhere.

---

## 2. Product shape — one product, three surfaces

**Working name**: *Daria* (the product); surfaces keep their names — **Baby Keyboard**
(macOS app) and **Daria Studio** (website). One shared library, one word catalog, one
learner profile.

- **macOS app** (real windowed app; it already has Settings, Advanced Settings, editor
  windows, and the SharedLibrary window — `views/ContentView.swift`,
  `AdvancedSettingsView.swift`, `SharedLibraryView.swift`):
  - owns: keyboard blocking, key-press effects, TTS, offline flashcards, learning
    state capture, learning rewards, native library player.
  - hosts the creation studio as an embedded authenticated web surface (WKWebView
    window pointed at the deployed Studio, PIN pre-injected via the existing
    `x-access-pin` convention) **plus** a native quick-create path later. Rationale:
    the studio is 3k+ lines of provider UX that would be a rewrite in Swift; embedding
    the real thing *is* representing the real UX. The player, rewards, and curation
    stay native.
- **Website** (the Next.js app, deployed at a stable URL):
  - owns: generation, media storage, the manifest DB, shared feed, manual grouping,
    admin/debug, remote access from any device (grandparents' machine — the PIN
    whitelist already exists for exactly this).
  - carries a curation UI (word pools, rotations, topics) writing to the same
    manifest DB the app syncs from.
- **Server = source of truth for media + catalog + rotations; app = source of truth
  for interaction events** (presses, seen counts, know/don't-know). Both sides keep
  working offline/apart; sync is eventual (§4.3).

---

## 3. Deterministic core vs AI plane — the governing split

**Deterministic core** (hand-controlled; AI never writes here directly):
- word catalog (`spelling|meaningKey` ids), word sets, enabled/featured topics;
- rotations and their weights/ratios/throttles (all the sliders that exist today:
  `learningKnownRatio`, `learningFavoriteRatio`, tag ratios, pool size, baby-name
  probability, word throttle, display duration);
- favourites / signature rotation membership and order (§7);
- media↔word pinning (custom images, group→word links);
- the SR scheduler state (seen/known/due — machine-updated by *rules*, not by AI).

**AI suggestion plane** (assistant proposes; nothing takes effect until approved):
- new-word proposals, topic-of-week packs, style suggestions, generated media,
  story/character episodes.
- **Approval mechanism already exists and should be reused, not reinvented**: AI
  output lands as a *featured-words batch / featured topic* proposal
  (`setFeaturedWordsBatch` `RandomWordList.swift:996`, `setTopicFeatured` `:291`) or
  as library items in a "proposed" state in the manifest. Petr's approve action is
  what moves them into the core. One inbox, everything auditable, everything
  reversible.

This split maps 1:1 onto sync: the core is small structured data (JSON/DB rows) that
Petr edits on either surface; the AI plane is append-only proposals + generated blobs.

---

## 4. Shared data model, identity, and sync

### 4.1 Entities (manifest DB on the server; Postgres per `chore/self-host-infra`, or
a single JSON manifest blob as the v0 stopgap)

- **WordEntry** — id `spelling|meaningKey` (exact scheme from
  `WordDataModel.swift:357`); translations `[{language, text}]`
  (`WordDataModel.swift:33`), tags, category (`WordDataModel.swift:14-26`),
  difficulty band, `ageIntroMonths` (for the assistant).
- **LearnerProfile** — Daria: birth date; per-language vocab state mirrors the
  existing SQLite columns (`known`, `favorite`, `seen_count`, `last_seen` —
  `LearningStateStore.swift:144`) plus SR fields `box`, `dueAt` (§6.2).
- **MediaAsset** — identity = content hash (the sha256-16 already stamped into every
  filename, `lib/media-storage.ts:18`); fields: kind, pathname, style id, provenance
  (`generated` | `custom-upload` | `photo`), provider, prompt used.
- **CreationGroup** — id = existing `groupId` (unchanged, stays in filenames for
  backward compat); manifest adds what filenames can't hold: `title`, optional
  `wordRef` (WordEntry id), `characterTags` (e.g. `char:kotik`), `topicRefs`,
  `favorite`, `signatureRank`, `state` (`proposed`/`approved`/`archived`). The
  reconciliation planner (`creation-identity.ts:273-408`) and manual tool keep
  repairing filename-level grouping; the manifest references pathnames + hashes so
  renames don't break identity.
- **Rotation** — named, typed: `learning` (the existing engine), `signature` (§7),
  `topic`. Config = member refs (word or group), weights, and policy
  (`uniform` | `spaced-rep` | `ordered-interleave`).
- **Topic / TopicOfWeek** — Topic = word set + optional media set + optional style;
  TopicOfWeek = `{topicId, weekStart, boostWeight}` schedule rows. (Featured topics
  in the app — `featuredTopicSetNames`, `RandomWordList.swift:213` — become the
  client-side projection of this.)
- **Character** — §7: id, names per language, canonical visual description (the
  string that gets restated into every prompt, exactly like story mode's `character`
  field, `lib/prompts.ts:8-12`), linked groups, home style.
- **Proposal** — `{kind: word-batch | topic-pack | media | style, payload, status:
  pending/approved/rejected, createdBy: assistant}`.

### 4.2 Feed contract v1 → v2 (additive, no breakage)

Current v1: `{schemaVersion, generatedAt, source, items[{id,title,createdAt,image,
videos[],music}], rotationOrder}` (`lib/shared-library.ts:29-37`), strictly checked by
the app (`SharedLibraryClient.swift:61,124-126`). v2 adds optional fields:
- per item: `wordRef`, `characterTags`, `favorite`, `signatureRank`, `topicRefs`;
- top level: `rotations`, `topicsOfWeek`, `catalogVersion`, `styleRegistry`.
Keep `schemaVersion: 1` semantics for old clients by serving v1 shape at the same
endpoint unless `?v=2` (or bump and ship both — the Swift check is one constant,
`SharedLibraryClient.swift:61`).

### 4.3 Sync boundaries & offline behavior

- **App → server** (when online): interaction log (word shown, key events aggregated,
  know/don't-know marks, reward unlocks) + local curation edits (custom-image
  pinning, set edits) as ordinary mutations. Conflict rule: **Petr's newest edit wins
  per field; interaction counters merge additively.**
- **Server → app**: catalog + rotations + topics + feed. App caches: feed JSON +
  media files to Application Support with an LRU cap (today `AsyncImage`/`AVPlayer`
  stream from URLs with no disk cache — `SharedLibraryView.swift:196,218` — this is
  the one new offline requirement).
- **Offline app** = fully functional: blocker, effects, TTS, flashcards (bundled +
  cached generated assets via `FlashcardAssetStore`), learning engine (SQLite +
  UserDefaults), plus *cached* shared-library playback. Only creation requires
  network.
- **Offline web**: not a goal beyond the existing browser cache
  (`lib/browser-storage.ts`); the web surface is by definition connected.
- **Secrets/auth**: server keeps provider keys (already true); app holds only the
  PIN, sent as `x-access-pin` (`SharedLibraryClient.swift:110` — already true).

---

## 5. Hand-controlled pools & rotations UX

Petr's controls, consolidated (everything listed exists today in the app; the change
is making them server-backed and mirrored on web, not redesigning them):

- **Pools**: word sets with enable toggles (`toggleSet`,
  `RandomWordList.swift:318`), set editor (`views/RandomWordEditorView.swift`),
  learning-word table editor with known/favorite/tags
  (`views/LearningWordEditorView.swift`), custom image folder sync
  (`RandomWordList.swift:1730`), featured words with suggestion search (`:1063`).
- **Rotation dials**: pool size, known ratio, favourite ratio, tag ratios, known-
  after-N-views threshold (`:238-243`), baby-name probability (`:216`), word
  throttle + display duration (ContentView settings).
- **New, on web (Phase 4)**: the same controls as forms over the manifest, plus a
  visible **pool preview table** (word, translation, known, favourite, seen count,
  tags) — old backlog item `k`, still the single most requested visibility feature;
  the data for it already comes out of `getLearningWordList()`
  (`RandomWordList.swift:968`).
- **Rotation editor**: create/rename rotations, drag members, set weights; assign a
  rotation to a surface (flashcards, baby player, reward reveals). Deterministic
  preview: "next 20 picks" simulation so Petr can *see* what a weight change does
  before a toddler does.

---

## 6. The AI assistant (age- and vocabulary-aware)

### 6.1 What it knows
- Daria's age in months (LearnerProfile DOB).
- Per-language vocabulary state: the full learning table export (already available
  locally via `getLearningWordList()` / SQLite; synced up in Phase 5) — known words,
  seen counts, favourites, per-language translations.
- The word catalog with difficulty/frequency (extend generation scripts in
  `scripts/`; old backlog items `f`, `j` had exactly this ambition — nltk-scale pool
  with progressive difficulty).
- The style registry, characters, and topic history.

### 6.2 What it does (all through the Proposal inbox, §3)
- **Optimal new words**: propose N words just above current vocabulary — frequency-
  ranked, age-banded, per language, excluding known/failed-recently; delivered as a
  featured-words batch (existing merge path `setFeaturedWordsBatch`,
  `RandomWordList.swift:996`).
- **Spaced repetition upgrade**: keep the current engine as the fallback (it already
  does recency weighting `:2094-2122` and seen-threshold promotion `:2076-2078`);
  add Leitner-style `box` + `dueAt` columns to `LearningStateStore` and prefer due
  words inside `getLearningRandomWord`'s unknown branch. Explicit know/don't-know
  signals come from: parent marks (existing editor), typing-game success
  (`TypingGameState.isWordComplete`, already wired at `EventHandler.swift:334-356`),
  and a new web swipe-review page (the vision note's "swipe left/right for know /
  don't know").
- **Topics of the week**: assistant drafts a topic pack (12-20 words + a style + a
  cover generation batch); on approval it becomes a Topic + TopicOfWeek row; the app
  projects it into `featuredTopicSetNames` so `buildLearningPool`'s existing priority
  merge (`RandomWordList.swift:1208-1233`) boosts it for the week. No engine change
  needed for the boost — it's already there.
- **Media enrichment**: propose generations for words lacking images in the active
  styles (gap query over MediaAsset × WordEntry).

---

## 7. Favourites / signature rotation, and Kotik the cat

### 7.1 Signature rotation (independent of learning)
A hand-ordered list of *anything* — words, images, videos, whole creation groups —
that interleaves into any active surface at a configured share. Implementation reuses
two proven mechanics:
- the **accumulator-guarantee** pattern from baby-name selection
  (`RandomWordList.swift:1985-1994`) so signature items are guaranteed to surface
  regularly rather than merely probable;
- the **favourite ratio** slot in the learning mix (`:2058`) generalized: signature
  share is checked before favourite share.
Members ranked by `signatureRank` in the manifest; the app and both web players read
the same rotation from feed v2. Learning rotation and signature rotation never share
state — a word can be in both, but signature order is purely Petr's.

### 7.2 The cat video → a recurring character
Treat the favourite cat video not as one blob but as **Character "Kotik"**:
- Character row: canonical visual description (one sentence with 1-2 stable traits —
  exactly the identity-stability trick story mode already uses,
  `lib/prompts.ts:8-12`), RU/EN names, home style.
- The original cat video becomes the founding CreationGroup tagged `char:kotik`,
  `favorite`, `signatureRank: 1` (uploaded/ingested via the existing storage path;
  if it was never in blob storage, the manual tool + reconciliation flow already
  handle adopting external files' grouping).
- **New episodes** are generated on demand: builder or story mode seeded with the
  Kotik character description; directed first→last clips (§8) let episodes *end* on
  a canonical Kotik pose so the character stays recognizable and clips chain.
- Kotik appears across surfaces: signature rotation in players, an occasional
  flashcard guest (a word card where Kotik demonstrates the word), reward-mode
  reveals ("complete a word to see what Kotik did today"), and — the meme part — a
  dedicated key easter egg in the blocker (a specific key always summons Kotik;
  trivial to add next to the baby-name mechanic).
- Fitting precedent already in the repo: the demo feed's first card is "Кот танцует"
  (`lib/shared-library.ts:132`).

---

## 8. Image-to-video with first AND last frame — directed clips

**Current reality (verified):** main ignores `useAsLastFrame` for every provider
(Veo: `route.ts:149-151`; Higgsfield: `_useAsLastFrame` discarded, `route.ts:203`;
Sora: no such API). The side-branch fix `d958d46` adds Veo `config.lastFrame` but
intentionally passes the *same* image (loop). The client can only ever send
`lastFrame = firstFrame` and only in loop mode (`app/page.tsx:260-261, 292-293`;
`lib/types.ts:26`). So today "last frame" ≡ "loop", and on main it's a silent no-op.

**Design: replace the boolean pair with an explicit clip-shape enum** in
`VideoSettings` (`lib/types.ts:23-28`):

```
clipShape: "free" | "loop" | "directed"
firstFrame?: { assetRef }          // default: the generated image
lastFrame?:  { assetRef }          // required iff directed; forced = firstFrame iff loop
```

- `free` — first frame only (today's behavior).
- `loop` — lastFrame := firstFrame server-side (merge `d958d46` to main as-is).
- `directed` — distinct last frame, passed through to the provider:
  - **Veo**: same `config.lastFrame` field, different image — the SDK call already
    exists in the `d958d46` diff; the only change is *which* image is encoded.
  - **Higgsfield**: per-model capability; extend `lib/higgsfield-models.ts` with a
    `supportsEndFrame` flag and send the model's end-image field where supported,
    reusing the existing upload path (`route.ts:359-394`) for the second image.
  - **Sora**: no end-frame parameter → hide `directed` for Sora, the exact pattern
    `d958d46` already used ("last-frame toggle shown only for Veo").
- Route change: accept `lastFrameUrl` distinct from `imageUrl`
  (`route.ts:29`), thread it to Veo/Higgsfield builders. Guard: if `directed` is
  requested and the provider can't honor it, **fail loudly with the three-level
  error**, never silently drop the last frame — silent dropping is precisely the
  current bug class.

**Where directed clips pay off**:
1. **Story scene chaining**: scene N's last frame = scene N+1's first frame — real
   visual continuity on top of the prompt-restating trick; generate the 3-4 keyframe
   images first (cheap), then N directed clips between consecutive keyframes.
2. **Word morphs**: flashcard image of word A → image of word B ("cat" → "sleeping
   cat"; color → object of that color).
3. **Kotik episodes** ending on his canonical pose (§7.2).

---

## 9. Image styles — unified registry + curated futuristic set

Today there are three disjoint style systems: the app's 12 offline `FlashcardStyle`s
(`FlashcardStyle.swift:4-17`) with per-style asset folders and even per-style videos
(`:98-153`); the web's 8 `IMAGE_STYLES` prompt fragments (`lib/types.ts:90-99`); and
the legacy 3-preset `IMAGE_STYLE_PRESETS` (`lib/prompts.ts:52-56`).

**Unify into one StyleRegistry** (manifest table, served in feed v2):
`{id, title, promptFragment, referenceImageAssets[], source: builtin|curated,
enabledFor: {flashcards, studio}, offlineAssetDir?}`.
- Existing 12 + 8 become `builtin` rows (ids preserved so `@AppStorage
  "flashcardStyle"` pools and blob filenames stay valid).
- The app keeps its multi-select style pool UX (`FlashcardStyle.pool`,
  `FlashcardStyle.swift:25-50`) but reads the roster from the synced registry.
- **Curated futuristic set from Petr's Instagram likes** (future, explicitly staged):
  1. export liked posts (manual export or scraper — outside this product's code);
  2. hand-pick 10-30 exemplars into `referenceImageAssets`;
  3. derive 3-6 style entries: an LLM+vision pass drafts `promptFragment`s from the
     exemplars, Petr edits and approves (Proposal inbox again);
  4. for providers with image-reference/style-reference support, attach exemplar
     images directly; otherwise prompt-fragment only;
  5. batch pre-generate flashcard assets in the new styles for offline app use
     (`FlashcardAssetStore` layout; the old `web/scripts/upload-flashcard-assets.js`
     idea, done properly through the storage layer).

---

## 10. Staged implementation plan

Each phase is independently shippable, ordered by (value ÷ risk), and scoped so a
coding agent can execute it against named files without touching the blocker core.
The Swift selection engine and event tap are **do-not-rewrite** zones; all phases
extend around them.

**Phase 0 — Consolidate what exists (no new features)**
- Merge `d958d46` (auto-loop off + Veo loop last-frame) and `1f4eb1f`
  (library restructure) into `main`; land `worktree-creation-builder` behind a UI
  toggle. Files: `app/api/generate/video/route.ts`, `app/page.tsx`,
  `app/library/page.tsx`, `components/builder-input.tsx`.
- Deploy the web app to a stable URL (Vercel now; `chore/self-host-infra` later);
  change the app default `sharedLibraryBaseURL` (`SharedLibraryView.swift:44`) and
  document PIN setup.
- Decide fate of `baby_keyboard/web/` (recommend: archive per deprecation protocol).
- Exit criteria: Daria feedback fixes live; app plays the deployed feed on a machine
  with no dev server.

**Phase 1 — Directed video (§8)**
- `lib/types.ts`: `clipShape` enum replacing the boolean pair (keep booleans as
  deprecated aliases for one release); `components/video-settings.tsx` picker;
  `app/api/generate/video/route.ts` `lastFrameUrl` threading;
  `lib/higgsfield-models.ts` capability flags; loud unsupported-provider errors.
- Story-mode keyframe chaining as an opt-in toggle in story generation.

**Phase 2 — Manifest + feed v2 (§4)**
- Server manifest store (start: single JSON blob in Vercel Blob + optimistic lock;
  target: Postgres from `chore/self-host-infra`). CRUD routes under `app/api/library/`.
- Feed v2 additive fields; `SharedLibraryClient.swift` reads v2 (bump
  `supportedSchemaVersion`, keep v1 fallback).
- Migrate grouping truth: reconciliation proposals (`creation-identity.ts:273-408`)
  and the manual tool write manifest rows, not just renames.

**Phase 3 — Signature rotation + Kotik (§7)**
- Manifest: `favorite`, `signatureRank`, `characterTags`; Character table with Kotik
  seeded; ingest the original cat video as a group.
- Players: interleave signature items via accumulator pattern — `app/baby/page.tsx`,
  `app/library/page.tsx` baby mode, `SharedLibraryView.swift` (advance logic
  `:37-40` picks from rotation instead of pure `(i+1) % n`).
- First generated Kotik episode via builder + directed clips.

**Phase 4 — Curation on web, rotations everywhere (§5)**
- Web pages: pool table preview, set editor, rotation editor with next-20 simulation,
  topic editor. All writes to manifest; app projects rotations/topics into its
  existing knobs (`featuredTopicSetNames`, ratios) on sync.
- App gains feed/media disk cache (offline playback).

**Phase 5 — Assistant + proposals (§6)**
- App uploads learning-state export (one new endpoint + a Swift sync task around
  `LearningStateStore`); LearnerProfile with DOB.
- Assistant endpoints (server-side, Claude API): new-word batches, topic-of-week
  packs → Proposal inbox UI (web) → approval writes featured-word batches / topics.
- Embedded Studio window in the app (WKWebView + PIN injection) so creation is
  reachable in-app without a browser.

**Phase 6 — SR upgrade + review surfaces (§6.2)**
- `LearningStateStore` migration: `box`, `due_at` columns; due-first preference in
  the unknown branch of `getLearningRandomWord` (surgical change at
  `RandomWordList.swift:2063-2068`); web swipe-review page feeding know/don't-know.

**Phase 7 — Style curation pipeline (§9)**
- StyleRegistry in manifest + feed; app style pool reads registry; Instagram-likes
  ingestion + curated futuristic styles; batch pre-generation for offline flashcards.

---

## 11. Open questions for Petr

1. **Deployment target now**: keep Vercel (blob + PIN already work) or accelerate
   `chore/self-host-infra` (Postgres/MinIO) before Phase 2? The manifest design works
   on either; Postgres makes Phases 4-6 nicer.
2. **The original cat video** — where does the file live today? (It's referenced in
   the product requirement but not present in either repo/storage; Phase 3 needs the
   actual bytes.)
3. **Embedded studio vs native create**: is WKWebView-hosted Studio acceptable as the
   in-app creation surface long-term, or should a native quick-create (builder-only)
   be prioritized after Phase 5?
4. **Contract bump style**: serve v2 at `?v=2` alongside v1, or hard-bump
   `schemaVersion` and update the app in lockstep (you control both clients)?
5. **`baby_keyboard/web/`**: confirm archival.

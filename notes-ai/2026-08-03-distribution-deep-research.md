# Distributing Baby Keyboard / "Daria" — deep research report

**Date:** 2026-08-03
**Method:** `/deep-research` dynamic workflow (106 agents: 5 research angles → 24 sources fetched → 108 claims extracted → adversarial 3-vote verification → synthesis). A transient network outage killed 32 verifier agents, so some claims are marked **[cited, unverified]** — each still carries a direct quote from its primary source, but did not get the 3-0 adversarial confirmation the **[verified 3-0]** claims did. Nothing was refuted. Repo grounding is against the actual working tree (read-only; no app code was modified).

**Repo facts this report is grounded in:**
- Bundle id `com.fangxing.BabyKeyboardLock`; keyboard interception via a **blocking CGEventTap** (`.defaultTap`, `EventHandler.swift:318-321`) gated by `AXIsProcessTrusted` checks (`utils/AccessibilityPermission.swift:93-97`, `utils/authorization.swift`).
- Debug entitlements: `app-sandbox = false`. Release entitlements (`BabyKeyboardLockRelease.entitlements`): `app-sandbox = true`, `network.client`, `automation.apple-events`, `files.user-selected.read-only`, `files.bookmarks.app-scope`.
- Currently signed with an **Apple Development** identity only. Next.js web app in `web/`.

---

## 0. Decision summary (TL;DR)

1. **Ship direct, soon — but resolve the Release sandbox first.** Developer ID + hardened runtime + notarized DMG is the right track because direct distribution lets the blocker ship without App Sandbox. The repo currently enables App Sandbox in Release, while the core `.defaultTap` actively consumes events; that exact combination is not yet verified and is likely incompatible. Do not call the release build distributable until a Developer ID build with the intended entitlements passes a real blocking test. Sparkle 2 remains available for updates in either sandboxed or unsandboxed direct builds.
2. **Treat the Mac App Store as "probably not, for the core lock."** The strongest evidence found (Apple DTS, on the record) says event-tap-based *modification* of events is fundamentally incompatible with App Store sandboxing. Listen-only taps are fine under Input Monitoring; *blocking* taps are the problem, and blocking is Baby Keyboard's entire point. A MAS build would likely need a redesigned, non-blocking mode — and would then also inherit the heavy Kids Category compliance regime.
3. **Switch signing identity once, early, and never mix identities again.** TCC (Accessibility) grants are keyed to the code signature's designated requirement; moving from Apple Development → Developer ID will invalidate existing grants once, and mixing ad-hoc/dev/Developer ID builds of the same bundle id is documented (by Apple DTS) to corrupt TCC state over time.
4. **Media pipeline:** originals in Cloudflare R2 (zero egress), image variants generated on-the-fly at the edge, video via Cloudflare Stream (managed encode + ABR) — no self-hosted transcoding or pre-generated thumbnails needed. Content-addressed immutable IDs + a small manifest API shared by web and native.
5. **First+last-frame video generation is real and commoditized:** Veo, Kling, and Seedance honor a pinned `last_frame` (Vercel AI Gateway exposes this uniformly); Seedance even returns the final frame for chaining clips. Runway/Luma also offer keyframe conditioning via aggregators. Generated MP4s flow into Stream via a simple ingest step.

---

## 1. Direct (Developer ID + notarized) vs Mac App Store

| | Direct distribution | Mac App Store |
|---|---|---|
| Core keyboard blocking (`.defaultTap`) | ✅ Works today (Accessibility TCC) | ⚠️ Very likely disallowed — see §4 |
| App Sandbox | Optional (release entitlements already enable it) | Mandatory |
| Review | None (notarization is an automated malware scan, *not* App Review) **[cited, unverified]** | Full App Review + Kids Category rules if child-targeted |
| Signing | Developer ID Application cert | Apple Distribution cert; Apple re-signs your app **[verified via forum, Apple DTS]** |
| Notarization | Required for all software built after 2019-06-01 on macOS 10.15+ **[cited, unverified — Apple docs]** | Not required (App Store submission includes equivalent checks) **[cited, unverified — Apple docs]** |
| Updates | Sparkle 2 (sandbox-compatible) **[verified 3-0]** | App Store handles it |
| Payments | Yours (Paddle/Stripe/Gumroad/free) | Apple IAP; Kids Category forbids purchase links outside a parental gate **[verified 3-0]** |
| Cost | Apple Developer Program, US$99/yr ([developer.apple.com/programs](https://developer.apple.com/programs/)) — *standard knowledge, not re-verified this session* | Same $99/yr + 15–30% commission |
| Timeline | Days–weeks of build/release engineering | Unknown; gated on §4 + Kids compliance |

**Recommendation:** direct distribution is the primary track. It is what Apple DTS itself recommends for this class of app: *"If this functionality is critical to your product, I recommend that you distribute it independently using Developer ID."* — Apple DTS (Quinn "The Eskimo!"), [developer.apple.com/forums/thread/664959](https://developer.apple.com/forums/thread/664959).

---

## 2. The direct-distribution mechanics (what actually has to change in the build)

### Signing identity
- Notarization **requires a Developer ID Application certificate**; the repo's current "Apple Development" identity is explicitly disallowed for distribution: *"Use a 'Developer ID' application … certificate for your code-signing signature. (Don't use a Mac Distribution, ad hoc, Apple Developer, or local development certificate.)"* **[cited, unverified]** — [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- Enable **Hardened Runtime**, sign with a **secure timestamp**, and ensure `com.apple.security.get-task-allow` is **not** true in the release build. **[cited, unverified — same Apple doc]**

### Notarization workflow
- `xcrun notarytool submit` (Xcode 13+; `altool` was cut off 2023-11-01). Credentials via an app-specific password stored with `notarytool store-credentials` (keychain profile, keeps secrets out of scripts). **[cited, unverified]** — [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- The notary service does **not** accept a bare `.app`: submit a ZIP, UDIF DMG, or signed flat pkg; nested containers are notarized level-by-level. **Staple** the ticket (`stapler`) to the DMG/pkg so Gatekeeper passes offline; you cannot staple a ZIP. **[cited, unverified — same doc]**
- Turnaround: most submissions < 5 min, 98% < 15 min; limit 75/day. **[cited, unverified — same doc]**
- Verify with `spctl -a -t exec -vv`. Avoid `codesign --deep` — it can corrupt embedded XPC service signatures (sign Sparkle's XPC services individually, inside-out). — [steipete.me: Code Signing and Notarization](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) *(blog, corroborates Sparkle docs)*

### Updates: Sparkle 2 — fully compatible with the current release entitlements **[verified 3-0]**
- Sparkle 2 explicitly supports **sandboxed** apps (Sparkle 1 does not). Its sandboxing guide's XPC-service setup applies directly to `BabyKeyboardLockRelease.entitlements` (`app-sandbox=true`). — [sparkle-project.org/documentation/sandboxing](https://sparkle-project.org/documentation/sandboxing/)
- Because the release entitlements already include `com.apple.security.network.client`, **only the Installer XPC service is needed; do not enable the Downloader service** (Sparkle docs say exactly this; the Downloader also drags in the deprecated WebView for release notes). **[verified 3-0]**
- Required app changes when adopting: add `com.apple.security.temporary-exception.mach-lookup.global-name` entries `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and `-spki` to the release entitlements, set `SUEnableInstallerLauncherService = YES` / `SUEnableDownloaderService = NO` in Info.plist, generate the EdDSA key (`generate_appcast`, key lands in login Keychain), and bump `CFBundleVersion` every release (Sparkle compares build numbers, not version strings). **[cited, unverified — Sparkle docs + steipete blog]**
- Sparkle's own recommended pipeline is Developer ID + notarization (its docs never mention the App Store at all — a verifier grepped the page: zero hits), and it can install updates from **DMG, zip, tarballs, Apple Archives, or pkg** — so one artifact format serves both first install and updates. **[verified 3-0]** — [sparkle-project.org/documentation](https://sparkle-project.org/documentation/)

---

## 3. Accessibility / TCC: requesting it reliably, and what breaks it

### Requesting the permission
- The app's existing flow is the officially documented one: `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt = true` returns trust status and triggers the system prompt on startup. **The prompt is asynchronous and does not change the same-call return value** — the app must re-check (poll or relaunch) after the user grants trust. **[verified 3-0]** — [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions); repo already does this at `AccessibilityPermission.swift:93-97`.
- macOS shows the dialog only until the user responds; after a denial the user must enable it manually in System Settings (`tccutil reset Accessibility com.fangxing.BabyKeyboardLock` re-enables prompting for testing). **[verified as part of the 3-0 finding]**
- Per Apple DTS: an app using **only** a CGEventTap should use `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` (Input Monitoring); Accessibility is needed only for other AX APIs. **But** a *blocking* tap (`.defaultTap`, key up/down) is gated on Accessibility-or-root per the API contract, matching the repo's checks: *"Event taps receive key up and key down events if one of the following conditions is true: the current process is running as the root user; access for assistive devices is enabled."* **[cited, unverified]** — [CGEventTapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)?language=objc), [thread/744440](https://developer.apple.com/forums/thread/744440)
- Failure is **silent**: unpermitted event types are cleared from the mask, and an empty mask makes `CGEventTapCreate` return NULL — no error surfaces. **[cited, unverified — same API doc]**
- **Revocation is ugly:** if the user revokes Accessibility while a tap is live, the callback gets no error — the app periodically receives `kCGEventTapDisabledByTimeout` and key responsiveness degrades. There is no revocation notification API (Apple feedback FB13533901); poll `AXIsProcessTrusted` or register a probe tap. — [thread/744440](https://developer.apple.com/forums/thread/744440) *(forum, incl. Apple DTS reply)*

### What breaks the grant (this is the part that bites during the identity switch)
- macOS keys TCC identity to the code signature's **designated requirement (DR)**. Ad-hoc signed code has no stable DR, so every rebuild looks like a different app and grants don't persist. Apple DTS: *"sign your code with a stable signing identity … Doing this will radically cut down on the amount of TCC thrash."* Reference: [TN3127 Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements). — [thread/795739](https://developer.apple.com/forums/thread/795739), [thread/730043](https://developer.apple.com/forums/thread/730043) *(both forum, Apple DTS replies)*
- **Mixing ad-hoc and Developer ID builds of the same bundle id on one machine makes TCC "get confused over time"** and treat granted permissions (`kTCCServiceAccessibility`, `kTCCServiceScreenCapture`) as not granted. — [thread/730043](https://developer.apple.com/forums/thread/730043)
- Grants are keyed by bundle id in TCC.db, and empirically a stable Developer ID signature is enough for rebuilds to be recognized as the same app. `tccutil` can only *reset*, never grant; the system TCC.db is SIP-protected. — [jano.dev on Accessibility permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) *(blog)*, [thread/730043](https://developer.apple.com/forums/thread/730043)
- **Practical consequences for this repo:**
  - The switch Apple Development → Developer ID changes the DR ⇒ existing testers re-grant Accessibility **once**. (Exact behavior across this specific transition failed verification — treat as expected-but-unconfirmed; see §8 unknowns.)
  - Keep the separate `com.fangxing.BabyKeyboardLockDebug` bundle id for dev builds (the repo already has one — good), so dev builds never pollute the release identity's TCC record.
  - App *path* changes matter less than signature: TCC matches on DR + bundle id, not install path, per the DR model above — but don't run two differently-signed copies side by side.

---

## 4. Can the core keyboard lock ship in the Mac App Store? — the evidence

This is the decision-critical question, and the honest answer is **"almost certainly not for a blocking tap, and Apple will not confirm it in writing."**

**Against (strongest evidence):**
- Apple DTS (Quinn), on the record: *"The App Store requires that all apps be sandboxed and modifying user events completely undermines that goal; if you can inject user events you could easily bypass the sandbox."* Recommendation: Developer ID direct distribution. Helper apps/kexts with user consent do **not** create a workaround (asked and answered: no; community answer: "Not a chance."). — [thread/664959](https://developer.apple.com/forums/thread/664959) *(2020, forum, Apple DTS)*
- Apple DTS (2025): *"In general, App Sandbox blocks use of the Accessibility APIs."* `AXUIElementCreateApplication` from a sandboxed app: "No." — [thread/789896](https://developer.apple.com/forums/thread/789896)
- `NSEvent.addGlobalMonitorForEvents` demonstrably stops working in the sandboxed App Store build of an app that worked in Xcode. — same thread.

**Nuances / partial counter-evidence:**
- **Listen-only** CGEventTaps *do* work sandboxed — under **Input Monitoring**, not Accessibility: *"sandboxed apps can monitor events. My go-to API for that is CGEventTap."* (Apple DTS). Posting synthetic events also works sandboxed under a separate PostEvent privilege (`CGRequestPostEventAccess`). — [thread/789896](https://developer.apple.com/forums/thread/789896)
- A developer attests to having two Mac App Store apps that request and use Accessibility permission — sandboxing does not *categorically* prohibit the permission, only most of the APIs behind it. — [thread/756130](https://developer.apple.com/forums/thread/756130) *(2024, forum, non-Apple)*
- One 2020 report of a sandboxed app whose event tap still received events system-wide — with the poster themselves noting sandbox behavior seems to have changed across macOS versions; the thread got zero authoritative replies. — [thread/668975](https://developer.apple.com/forums/thread/668975)
- When asked point-blank in 2025 whether Accessibility/Input Monitoring/event generation are allowed for App Store apps, Apple's App Review account gave no technical answer and redirected to a private App Review appointment. — [thread/780722](https://developer.apple.com/forums/thread/780722)

**Reading of the evidence:** Baby Keyboard's lock is an **active filter** (`.defaultTap`) that *consumes* key events — squarely the "modifying user events" case Quinn calls fundamentally incompatible, not the listen-only case that's fine. No confirmed evidence contradicts this. The MAS track is therefore: (a) probably impossible for the current core feature; (b) resolvable only by either an App Review appointment (Meet with Apple, bi-weekly) or a redesigned non-blocking MAS variant (e.g., a fullscreen "toy" mode that swallows focus rather than tapping events — a product change, out of scope here).

---

## 5. Kids-app compliance (App Store track, but informs the direct build too)

All of the following were **verified 3-0 against the live App Review Guidelines on 2026-08-03** — [developer.apple.com/app-store/review/guidelines](https://developer.apple.com/app-store/review/guidelines/) (Guidelines 1.3 and 5.1.4) and [App privacy details](https://developer.apple.com/app-store/app-privacy-details/):

- **Kids Category (1.3):** no links out of the app, no purchasing opportunities, no "other distractions to kids" unless in a designated area **behind a parental gate**. No sending PII or device info to third parties. No third-party analytics or ads, with two narrow exceptions: analytics that collect no IDFA/identifiable-child/location/device data, and contextual ads from providers with publicly documented kids policies including human creative review.
- **5.1.4:** COPPA/GDPR compliance required; birthdate/parental-contact collection only for statutory compliance; privacy policy mandatory; and Apple explicitly says **the parental gate is generally *not* the same as parental consent** under COPPA/GDPR.
- **Privacy nutrition labels** are required before any submission and must cover every integrated third-party SDK, not just first-party collection; even a zero-collection app must declare "Data Not Collected."
- Once users expect Kids Category behavior, the app must keep meeting those rules in updates even if the category is deselected; and apps *outside* the Kids Category may not use kid-targeted terms ("For Kids", "For Children") in name/subtitle/icon/screenshots/description — which constrains how a non-Kids MAS listing could even be marketed.
- **2026 age-verification laws** (secondary source — [Loeb & Loeb summary](https://www.loeb.com/en/insights/publications/2025/12/app-store-age-verification-laws-trigger-new-federal-and-state-childrens-privacy-requirements)): Texas (2026-01-01), Utah (2026-05-07), Louisiana (2026-07-01) app-store accountability acts, California AB 1043 (2027-01-01). Developers must declare an age range (misleading declarations are developer-attributable violations); platform age-signal APIs give safe harbor but the age data must be siloed; **receiving an under-13 age signal creates COPPA "actual knowledge"** and triggers verifiable-parental-consent obligations for any data collection.

**Implications for this app specifically:**
- The safest posture (either track) is **"Data Not Collected"**: no analytics SDK, no accounts, no server-side logging of anything child-derived. The current app is close to this already.
- Any AI-generation feature that sends typed words/images off-device is a data flow that must appear in the privacy label and survive COPPA scrutiny. Run generation **parent-side/asynchronously** (parent curates packs; the child-facing runtime only ever reads from the local cache/CDN), so the child session itself transmits nothing. *(design guidance, not a verified claim)*
- AI-generated *content* shown to kids has no explicit guideline of its own in the verified excerpts, but review risk is real: expect App Review to probe age-appropriateness controls and human curation. **[unknown — flagged in §8]**

---

## 6. Shared media architecture (web `web/` + native app)

Verified vendor facts **[verified 3-0 unless noted]**, from [Cloudflare media-streaming use case](https://developers.cloudflare.com/use-cases/media-streaming), [Stream docs](https://developers.cloudflare.com/stream/), [image transformation docs](https://developers.cloudflare.com/images/transform-images/), and the [R2+Images reference architecture](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/):

- **Cloudflare Stream** handles upload, encoding, and adaptive-bitrate delivery end-to-end (H.264 ABR, 360p–1080p) — no self-managed transcoding. Caveats: output effectively capped at 1080p H.264; per-minute storage/delivery pricing (non-issues for short baby clips).
- **Cloudflare Images / transformations** resize and optimize **on-the-fly at the edge, cache-first** (`/cdn-cgi/image/width=…,quality=…/<origin-path>` URL syntax); named variants (≤100) are also rendered at delivery time. So: store **only originals**; never pre-generate or lifecycle-manage thumbnails. Transformations must be enabled per zone/domain; each unique source+parameter combo bills once per month.
- **R2** has **zero egress fees** (the decisive cost lever vs S3+CloudFront for a media-heavy free app) and 300+ edge locations for cache; Stream and R2 work without a custom domain, Images requires one.

**Recommended design** *(design guidance grounded in the above, not itself adversarially verified)*:

- **Canonical metadata object** (one JSON document per media asset, served from a small manifest API or static JSON in R2):
  `{ id, kind: image|video|audio, sha256, bytes, mime, width/height/duration, source: generated|user|builtin, model+prompt provenance (for generated), word/set bindings, locale, created_at, safety: curated_by }`
- **Immutable, content-addressed IDs:** object key = `sha256` of the bytes (or `<sha256>.<ext>`). Any edit ⇒ new object, new id; metadata references ids, never paths. This makes CDN caching infinite-TTL (`Cache-Control: immutable`), makes client caches trivially correct, and gives you checksums for free — the id *is* the checksum, verifiable after download.
- **Variants:** never stored — derived at request time via `/cdn-cgi/image/...` for images; Stream serves ABR renditions itself and provides thumbnails per its docs.
- **Native (macOS) cache:** a custom disk cache keyed by content hash under `Library/Caches/<bundle-id>/media/` (inside the sandbox container in the release build) — *not* bare `URLCache`, because you want durable offline packs, integrity checks (re-hash on read), and your own eviction. Two tiers: **pinned** (favourites/packs — never auto-evicted, user-visible size) and **opportunistic** (LRU, byte-capped, evict on pressure; `Caches/` is system-purgeable, so pinned packs that must survive belong in `Application Support/` instead).
- **Prefetch:** when a word set is enabled, background-fetch its manifest + pinned assets on Wi-Fi/power; child-session playback then never waits on the network.
- **Offline / no-internet fallback:** resolution order stays what `WordDisplayView` already does (custom image → baby image → generated), extended to: pinned cache → opportunistic cache → bundled fallback asset → text-only card. The child experience must be fully functional with zero network; the network only ever *enriches*.
- **Web app** consumes the same manifest API + CDN URLs; identical ids mean web and native share cache semantics and provenance.

---

## 7. Video generation with first AND last frame preserved

Verified-source facts (verifiers for this angle partially errored; quotes are from the fetched pages):

- **[Vercel AI Gateway image-to-video docs](https://vercel.com/docs/ai-gateway/modalities/video-generation/image-to-video)** (primary, updated 2026-06-30): a provider-agnostic `frameImages` API where entries tagged `first_frame` and `last_frame` produce a transition between two pinned frames. **Veo (e.g. `google/veo-3.1-generate-001`), KlingAI (`kling-v2.6-i2v`), and Seedance honor `last_frame`; Grok Imagine Video and Wan ignore it** (with a warning) — first+last pinning is model-dependent, so gate model choice on this. Veo: 4/6/8s, 720p/1080p. Kling: first+last mode is mutually exclusive with motion-brush/camera-control; inputs jpg/png ≤10MB, ≥300px, AR 1:2.5–2.5:1.
- **Seedance** offers `returnLastFrame` — returns the final frame of the generated clip specifically to **chain consecutive videos** (clip N's returned last frame becomes clip N+1's `first_frame`). This is the primitive for both long sequences and seamless loops (set the whole chain's final `last_frame` = the very first frame to close the loop).
- Output arrives as raw MP4 bytes; generation takes minutes (poll timeout ≥10 min recommended) ⇒ an async ingest step pushes results into the media pipeline rather than serving from the generation API.
- **[WaveSpeed](https://wavespeed.ai/landing/models/first-last-frame-video-models)** (vendor marketing — weakest source tier here): aggregates first/last-frame models incl. **Kling and Luma**; transitions up to 10s, generation <20s, pay-per-generation REST API with webhooks. Treat capability claims as directional until tested.

**Pipeline fit** *(design guidance)*: parent triggers generation (see §5 — keep it out of the child session) → worker calls gateway with `first_frame`/`last_frame` pulled from existing flashcard images → poll/webhook → validate + hash the MP4 → upload to Cloudflare Stream → write canonical metadata (incl. model, prompt, frame ids as provenance) → clients discover it via the manifest like any other asset. Because the first/last frames are existing canonical images, chained clips are stitchable by construction.

**Open (failed verification, needs a small paid spike):** current per-clip pricing and real quality of Veo vs Kling vs Seedance vs Luma for toddler-friendly content; whether "honors last_frame" means pixel-exact or approximate reproduction (docs say "transitions toward" — likely approximate; if pixel-exactness matters for looping, plan to hard-cut to the canonical still at clip boundaries).

---

## 8. Phased roadmap

### Phase 1 — "Distributable soon" (direct; ~days of work, all steps documented)
1. Enroll in the Apple Developer Program if not already ($99/yr) and create a **Developer ID Application** certificate.
2. Release build: test the core lock with the intended Developer ID identity and **disable App Sandbox if the `.defaultTap` cannot consume events** (the evidence in §4 makes failure the expected result). Enable **Hardened Runtime**, strip `get-task-allow`, and sign with secure timestamp. Sparkle support does not prove the blocker itself is sandbox-compatible.
3. Notarize: `xcrun notarytool submit` on a UDIF DMG → `stapler staple` → `spctl -a -t exec -vv` sanity check. Script it (≤75/day limit is irrelevant at this cadence).
4. First-run UX: keep the `AXIsProcessTrustedWithOptions(prompt)` flow, add post-grant re-check polling and a "revoked mid-session" handler (watch for `tapDisabledByTimeout`, drop the lock UI gracefully).
5. Expect one-time Accessibility re-grants for anyone who ran dev builds (identity change). Keep the `…Debug` bundle id for all local builds from now on; never ad-hoc sign.
6. Add **Sparkle 2**: Installer XPC service only, mach-lookup exceptions `-spks`/`-spki`, EdDSA key, appcast on any static host (R2 works), `CFBundleVersion` bump per release.
7. Distribute the stapled DMG from the web app.

### Phase 2 — Media platform (parallel track)
R2 + Images + Stream setup; manifest API; content-hash cache in the app with pinned packs; prefetch-on-enable; offline fallback chain. Then the first+last-frame generation worker (§7) feeding it.

### Phase 3 — "App Store if compatible" (gated, don't build ahead of the gate)
1. Book a **Meet with Apple App Review appointment** (bi-weekly; this is Apple's own suggested channel per thread/780722) and ask the blocking-tap question explicitly. This is the cheapest way to resolve the §4 unknown.
2. In parallel, empirically test: MAS-provisioned sandboxed build — does the Accessibility prompt even appear, and does a `.defaultTap` receive/consume keydown? (One verifier flagged the prompt may not appear at all for sandboxed apps.)
3. Only if both pass: Kids Category compliance work (parental gate for all settings/links, "Data Not Collected" label, privacy policy, declared age range under the 2026 state laws, no third-party SDKs).
4. If they fail (expected): either skip MAS, or scope a non-blocking MAS variant as a separate product decision.

### Explicit unknowns (nothing found refutes the plan, but these were not confirmed)
- **Blocking `.defaultTap` under the MAS sandbox** — the central gate for Phase 3; strong negative signal (Apple DTS 2020) but no current written ruling. Test + App Review appointment.
- **TCC behavior across the exact Apple Development → Developer ID transition** (do testers re-grant once, or does stale state linger requiring `tccutil reset`?) — all three verifier votes errored; forum evidence says stable-identity-going-forward fixes it, but budget one debugging session.
- **Whether the Accessibility prompt appears for a sandboxed release build** — plan the guided open-System-Settings fallback regardless.
- **Video-gen pricing/quality and last-frame exactness** — needs a small paid spike (§7).
- The eleven **[cited, unverified]** claims above (notarization mechanics, CGEventTap API contract, Sparkle XPC internals) are standard, widely documented behavior quoted from current primary docs, but carry presumptive weight only — the verification stage lost them to a network outage, not to refutation.

---

## Appendix: sources

**Apple primary:** [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) · [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) · [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) · [CGEventTapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)?language=objc) · [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (1.3, 5.1.4; quotes verified live 2026-08-03) · [App privacy details](https://developer.apple.com/app-store/app-privacy-details/) · [TN3127 Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)

**Apple Developer Forums (several with Apple DTS replies):** [664959](https://developer.apple.com/forums/thread/664959) (event modification vs App Store — DTS) · [789896](https://developer.apple.com/forums/thread/789896) (sandbox vs AX APIs; listen-only taps OK — DTS) · [756130](https://developer.apple.com/forums/thread/756130) (MAS apps using Accessibility exist) · [780722](https://developer.apple.com/forums/thread/780722) (App Review declines to answer publicly) · [668975](https://developer.apple.com/forums/thread/668975) (sandboxed tap anecdote, unanswered) · [730043](https://developer.apple.com/forums/thread/730043) (TCC DR, identity mixing — DTS) · [795739](https://developer.apple.com/forums/thread/795739) (stable signing identity — DTS) · [744440](https://developer.apple.com/forums/thread/744440) (revocation behavior, CGRequestListenEventAccess — DTS)

**Sparkle primary:** [Documentation](https://sparkle-project.org/documentation/) · [Sandboxing guide](https://sparkle-project.org/documentation/sandboxing/)

**Cloudflare primary:** [Media streaming use case](https://developers.cloudflare.com/use-cases/media-streaming) · [Stream](https://developers.cloudflare.com/stream/) · [Transform images](https://developers.cloudflare.com/images/transform-images/) · [R2 + Images reference architecture](https://developers.cloudflare.com/reference-architecture/diagrams/content-delivery/optimizing-image-delivery-with-cloudflare-image-resizing-and-r2/)

**Vendor/secondary/blog:** [Vercel AI Gateway image-to-video](https://vercel.com/docs/ai-gateway/modalities/video-generation/image-to-video) · [WaveSpeed first/last-frame models](https://wavespeed.ai/landing/models/first-last-frame-video-models) (marketing) · [Loeb & Loeb on 2026 app-store age laws](https://www.loeb.com/en/insights/publications/2025/12/app-store-age-verification-laws-trigger-new-federal-and-state-childrens-privacy-requirements) · [steipete.me on signing/notarization/Sparkle](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) · [jano.dev on Accessibility permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)

**Verification legend:** **[verified 3-0]** = survived a 3-vote adversarial refutation panel. **[cited, unverified]** = direct quote captured from the named source, but the verifier panel errored (network outage), so treat as presumptively true. Forum threads are attributed to Apple DTS where the workflow captured that attribution. Zero claims were refuted.

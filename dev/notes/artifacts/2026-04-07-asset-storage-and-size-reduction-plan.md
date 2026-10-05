# BabyKeyboard Asset Storage And Size Reduction Plan

Date: 2026-04-07

## Current state

- `BabyKeyboardLock/Resources/FlashcardImages` is about `1.2G` in the canonical repo.
- The app currently loads bundled media directly from the app bundle.
- The vocabulary model already supports asset URIs via `WordDataAsset.uri`.
- The web side already has object-storage support and can target S3-compatible storage.

## Recommendation

Use a hybrid storage model:

- Keep code and metadata in git.
- Move the full image corpus out of the repo into object storage.
- Keep high-quality masters outside the app bundle.
- Serve delivery variants from object storage.
- Cache downloaded images locally in the mac app.
- Bundle only a small offline fallback pack in the app.

## Why

- Normal git is the wrong place for a `1.2G` image corpus that will keep growing.
- The app repo and machine migration both become expensive when bundled media dominates the checkout.
- The current data model already has the right seam for remote assets.
- The web stack already knows how to upload to local or S3-backed media storage.

## Storage design

### In git

- app source code
- web source code
- `word_sets.json` or equivalent catalog metadata
- a small fallback media pack for offline use

### In object storage

- original image masters
- app/web delivery variants
- optional generated videos or future audio assets

### Not in git

- `dev/output`
- `dev/Resources`
- `.venv`
- `web/node_modules`
- `web/.next`
- `.specstory`
- local IDE/editor state
- release artifacts like `.dmg`
- secrets

## Asset layout

Suggested layout:

- `masters/images/{word_id}/{style}.png`
- `delivery/images/{word_id}/{style}/1024.png`
- `delivery/images/{word_id}/{style}/768.webp`
- `delivery/images/{word_id}/{style}/512.webp`

For metadata, keep asset records on each word entry using `WordDataAsset`:

- `kind`: `image`
- `uri`: public URL or stable object key
- `language`: optional
- `rotationDegrees`: optional

## App loading order

The mac app should resolve media in this order:

1. user-provided custom local image
2. locally cached downloaded asset
3. bundled fallback asset
4. remote asset from catalog

This preserves offline behavior while removing the requirement to ship the whole corpus inside the app bundle.

## Quality strategy

Keep quality, but separate archival quality from shipped quality.

- Keep original `1024x1024` PNGs as masters.
- Generate smaller delivery variants for app/web use.
- Test `768px` and `512px` WebP variants against current app display size.
- Keep a visually lossless default rather than forcing every shipped asset to be an original master.

## Migration steps

### Phase 1: metadata

- Extend the vocabulary catalog so each word/style can point to remote assets.
- Keep the metadata file in git.

### Phase 2: uploader

- Build or adapt an uploader that scans bundled flashcard images and uploads them to object storage.
- Do not store image blobs directly in the database.
- Store URLs or object keys in metadata.

### Phase 3: app cache

- Add an `Application Support` image cache for downloaded assets.
- Prefer local cached files once downloaded.

### Phase 4: bundle reduction

- Keep only a small fallback set bundled in the app.
- Remove the full image corpus from the app bundle once the remote/cache path is stable.

### Phase 5: history cleanup

- If desired later, shrink repository history with `git filter-repo` after deciding on the final storage layout.
- Git LFS can help for future large tracked binaries, but it does not by itself shrink existing history.

## Near-term cleanup targets

Safe local cleanup targets for archive clones:

- `.venv`
- `web/node_modules`
- `web/.next`
- `dev/output`
- `.specstory`
- `.idea`
- `.claude`
- `.uv-cache`
- `build`

Possible later cleanup targets after review:

- `dev/Resources`
- `archives/*.dmg`

## Decision

Preferred path:

- object storage + local app cache + small bundled fallback pack

Avoid:

- keeping the full image corpus in normal git
- storing binary image blobs inside the database

Go on. Anything else? Also, i don't care about the archive that much.

Rewriting git history - maybe not.

Everything else - definitely yes.

For larger work - write detailed prds
---
## Objective

Move the flashcard image migration forward without rewriting git history.

The immediate goal is to replace the current "images as bundled repo payload" approach with a deterministic remote-asset workflow:

- scan bundled flashcard images
- produce an upload manifest with stable object keys and public URLs
- populate catalog `assets` entries using `WordDataAsset.uri`
- upload media to object storage or a local-public folder
- keep the mac app using bundle fallback until metadata is populated and remote cache paths are stable

## Current Context

### Repo state

- `BabyKeyboardLock/Resources/FlashcardImages` is still the dominant app payload at roughly `1.2G`.
- `word_sets.json` currently contains `assets: []` for entries.
- the app now has a first-pass shared remote/cache resolver via `FlashcardAssetStore`
- the existing uploader at `web/scripts/upload-local-images.js` stores base64 blobs in `word_images`; that is not the desired long-term architecture

### Code seams already available

- `WordDataAsset.uri` already exists in the canonical word model.
- the web stack already supports object storage through `web/lib/media-storage.ts`.
- the mac app now supports cache-first remote image resolution with bundled fallback.

## Non-goals

- rewriting git history
- deleting bundled images from the canonical repo immediately
- full production rollout of all remote assets in one step
- replacing all video/audio asset flows in this PRD

## Proposed Solution

Implement a two-step migration pipeline.

### Step 1: prepare manifest and updated catalog

Create a Python script that:

- scans `BabyKeyboardLock/Resources/FlashcardImages`
- validates file naming and style folders
- emits a JSON upload manifest with:
  - local file path
  - style
  - inferred english spelling
  - object key
  - public URL
  - file size
- loads `word_sets.json`
- attaches image `assets` to matching entries using public URLs
- writes a preview catalog file or updates the catalog in place when explicitly requested

This script should preserve existing non-image assets and replace only auto-generated remote image assets for the matched spelling.

### Step 2: upload assets to storage

Create a Node uploader that:

- reads the generated manifest
- uploads files either to:
  - an S3-compatible bucket, or
  - `web/public/` for local/dev use
- uses stable object keys from the manifest
- prints a clear success/failure summary
- does not write blobs into the database

## Data Model Decisions

### Asset shape

For now, each image asset record should look like:

```json
{
  "kind": "image",
  "language": "en",
  "uri": "https://cdn.example.com/flashcard-images/crayon/crayon_apple.png"
}
```

### Entry matching

Bundled images are keyed by spelling, not by meaning key. Because of that:

- match images by normalized english spelling
- apply the same style image set to every catalog entry sharing that spelling

This is acceptable for the migration because the current bundled resource layout also does not distinguish meanings.

### Object key format

Use stable, human-readable keys:

- `flashcard-images/{style}/{filename}`

Example:

- `flashcard-images/crayon/crayon_apple.png`

## CLI Design

### Python preparation script

Example usage:

```bash
uv run python -m scripts.prepare_flashcard_assets \
  --base-url https://cdn.example.com \
  --manifest-out dev/artifacts/flashcard-assets-manifest.json \
  --catalog-out dev/artifacts/word_sets.remote_assets.json
```

Optional in-place write:

```bash
uv run python -m scripts.prepare_flashcard_assets \
  --base-url https://cdn.example.com \
  --write-catalog
```

### Node uploader

Example usage:

```bash
cd web
node scripts/upload-flashcard-assets.js \
  --manifest ../dev/artifacts/flashcard-assets-manifest.json
```

Provider modes:

- `MEDIA_STORAGE_PROVIDER=local`
- `MEDIA_STORAGE_PROVIDER=s3`

## Rollout Plan

### Phase 1

- prepare manifest
- upload a subset to local/public or a test bucket
- generate a preview catalog with populated asset URLs
- verify the mac app loads remote assets after cache download

### Phase 2

- upload full corpus
- populate canonical catalog assets
- verify cache hydration and bundle fallback behavior

### Phase 3

- reduce bundled fallback set
- stop shipping the full image corpus in the app bundle

## Risks

### Ambiguous spellings

Multiple meanings of the same spelling will share the same image assets. This matches current bundled behavior but may need refinement later if image selection becomes meaning-specific.

### Partial metadata rollout

If only some words receive `assets`, the app must keep working with bundled images. The current bundle fallback path covers that.

### Storage drift

If uploaded object keys diverge from manifest object keys, catalog URLs will break. Stable key generation is required.

## Deliverables for this work item

1. detailed PRD on disk
2. Python script to prepare upload manifest and catalog asset metadata
3. storage-backed uploader script that avoids DB blob storage
4. minimal docs or script command entries so the flow is discoverable

## Follow-up work after this PRD

1. enrich `WordDataAsset` with explicit style metadata if desired
2. replace legacy `word_images` dependency in web views with catalog-driven assets
3. add image compression/variant generation pipeline
4. eventually remove most bundled images from the app

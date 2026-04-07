Right now we have all our words defined in code, right? 
Should we like.. store it some other way?

What are our options in a swift app?

I mean at least it should be a json / csv, and a loader module?

Also, do we have a data model in code? 

here's a few thoughts

0) We need to transition from (word) to (word + meaning) identifier
That would allow us to do a better mapping word <-> translation
And word <-> image 

We should also support phrases, i guess (pairs of words) when there's no single-word translation
e.g. just allow and support the 'word' to contain space character

1) Words + Annotations
I want our data model to support a few annotation types
- first is part of speech 
(And again that's going to have to be word+meaning -> annotation, because fly - verb + fly - animal + fly - part of clothing)
- second is 'category' - as in special category within our app that serves general word pool control function (namely, there's 'actions' which Daria performs, objects, which she names or imitates, and close relatives which she names and which we usually attach an image for)
- maybe some other, but i'm not sure

2) Words + translations
We need some good way of maintaining a mapping of word with its translations
I've had issues with orange - fruit / color and wave - action / object
I think actually a proper word-meaning identifier solves this issue.
So we'll now have word-id (preferably keep the current approach where it's (word-spelling_meaning-keyword)

3) Words + Images
Same thing. Had issues with wave <-> action or object

4) Words + Definitions
i am preparing scripts for supporting providing definitions for words

---
So, overall i think this is all I want for now. 
How to place it and store it. - single table or multiple, i don't really care.

---
Can we use supabase for this?
And have a local mirror cache? (also for local images uploads)

---
Ah, and also, I have one more feature in the workings - custom audios / pre-created audios. So, let's make it so data models supports audios in each language as well

prd: unify word dataset + meaning ids + annotations + translations + assets (images/audio) + definitions
users: app users; maintainers/tools/scripts
success: stable word id (word|meaning) across UI, images, translations, learning rotation, definitions; dataset not hardcoded in Swift

repo current state
- hardcoded default word sets: `BabyKeyboardLock/utils/RandomWordList.swift` -> `createDefaultWordSets()`
- current word id: `wordKey(word:clarification:)` => `"word|clarification"` (already used for learning + custom images)
- current models: `RandomWord`, `RandomWordSet`, `LearningWord`, `CustomWordImage`, `CustomWordPair`, `CustomWordSet`
- learning csv: `BabyKeyboardLock/utils/RandomWordList.swift` -> `learning.csv` in Application Support

options in a swift/mac app
- bundle JSON/CSV + loader: easiest to maintain, versioned with app
- user JSON/CSV in Application Support: editable, migratable, offline
- local DB: SwiftData/CoreData or SQLite (GRDB) for fast queries + caching
- remote sync: CloudKit/iCloud or Supabase (metadata in DB, binaries in Storage) + local mirror cache

proposal (incremental)
- formalize meaning id: rename `clarification` to `meaningKey` (keep string form `word|meaningKey`), allow spaces in `word`
- move default word sets into `Resources/*.json` and load via a small `WordRepository` module
- extend schema: pos/category/tags, translations by language, definitions, image refs, audio refs
- keep user overrides in Application Support; merge over bundle defaults at runtime

supabase note
- feasible, but client-side keys + RLS/auth; still need local cache for offline; use Supabase Storage for images/audio, DB for metadata

plan/tests
- prototype: json loader + migrate from UserDefaults saved sets
- add a minimal validator script (python) for schema sanity
- manual test: random word mode still works; images/audio map by `word|meaningKey`

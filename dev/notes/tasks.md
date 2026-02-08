---
calmmage_id: nn0vXJFT
---
- a
    - `key: 48f24568`
    - Finish scripts.word_dictionary_showcase to generate a rich progressive dictionary and add definition mode
- b
    - `key: 09461e23`
    - Make the settings window open in the top right corner instead of middle of the screen
    - Make the window with words closeable and moveable (hotkey? How to drag it?)
- c
    - `key: f0750a6c`
    - `cue: Can't see which words are actually selected`
    - Make sure we can (pre)view the current pool of words in the selection
    - Bonus: make it a table that showcases
        - status in learning (num viewings, known or not)
        - category in database - e.g. activity / relative / item / ...
- d
    - `key: 45ed1f4f`
    - Add multi-image support to photos
- e
    - `key: f260c606`
    - `cue: There's too many buttons now, including 'no images' and 'random' - we could instead allow customizing enabling each style separately`
    - Rework 'images' to bool flags enable / disable
- f
    - `key: 4acf1c5b`
    - `cue: I'm tired of manually deleting and re-adding the app in privacy settings`
    - Add permissions reset command
    - Add a command to quickly re-set permissions (with sudo) of the app after deploy (delete and re-add)
- g
    - `key: e271e2ab`
    - `cue: I have to re-load photos every time I relaunch the app, and it is annoying`
    - Debug and fix photo loading issue
    - Add custom photos config
    - Add a text yaml config of local photos - to avoid re-adding them constantly. Re-load on start
- h
    - `key: eca3009a`
    Find a way to publish and distribute images other than git - upload to storage, download on first launch
- i
    - `key: 8bd1d2ea`
    Fix issues with words meanings and image discrepancies - Orange - color and fruit, drink - verb and noun
- j
    - `key: 441b4ef3`
    - `cue: My PC turns into a heater when I run my app..`
    - Generate audio samples with TTS and cache on disk to prevent running heavy AI model every time instead of just playing the sound
    - Add 'refresh cache' button in Settings
- k
    - `key: 78983d50`
    Test the flashcard display for game mode
- l
    - `key: 8938ae62`
    Improve game mode - remove per-letter sound, Allow all words simultaneousl
- m
    - `key: 81e9cb8c`
    - Initial request: I've ran make images-main - first step - but where are the files?
    - Latest: what? do uv add..
- n
    - `key: 4abc703d`
    - `cue: Couldn't get a specific word - mama - to appear at all`
    - Rework random into pseudo-random that balances probabilities into a more even shuffle
- o
    - `key: ddd1a65b`
    Publish calmlib, install and download quick draw images
- p
    - `key: 490a0894`
      Load images from user folder instead of including resources in the package. Bonus: Auto-generate words for images and use that set in text
- q
    - `key: 8e21dce0`
    - Gamify keyboard locker somehow
    - Idea 1: Add a new mode, where the baby has to type the word correctly for it to appear on the screen and be
      pronounced
    - When baby types the letters correctly - make them appear on screen (e.g. if she types 'M' - show 'M', then add
      'A' etc.). Allow any words from selected word sets.
      Some nice animation when the word is completed correctly
    - Add a setting checkbox "reset on error".
- r
    - `key: 20234a42`
    - Make it a website
- s
    - `key: 8d4d24da`
    - `cue: I tried to deploy on Anna's macbook using make deploy, and it failed saying it can't export archive because it misses the certificate. The main question is do i create a new one or copy this one?`
    - Figure out how to deploy on another machine - missing certificate
    Build description signature: c6f264918b4db5acd581c2181fb6fac3
    Build description path: /Users/annalav/Library/Developer/Xcode/DerivedData/BabyKeyboardLock-bgubpirqszsziihdvtozqvgxmqja/Build/Intermediates.noindex/ArchiveIntermediates/BabyKeyboardLock/IntermediateBuildFilesPath/XCBuildData/c6f264918b4db5acd581c2181fb6fac3.xcbuilddata
    /Users/annalav/Documents/GitHub/baby_keyboard/BabyKeyboardLock.xcodeproj: error: No signing certificate "Mac Development" found: No "Mac Development" signing certificate matching team ID "5XCYR4LUMD" with a private key was found. (in target 'BabyKeyboardLock' from project 'BabyKeyboardLock')
    a
## Done
- [x] t
    - `key: c0e2f3af`
    generate images with nano-banana using script
- [x] u
    - `key: b394d43b`
    - Use simple color images if the word selected is a color
- [x] v
    - `key: 8884e924`
    - `cue: The settings don't fit the screen on Anna's monitor, and can't be scrolled. Also, I'm adding new settings`
    - How do I rework settings menu to contain less items
    - Move additional settings to a separate window
- [x] w
    - `key: bd515a4e`
    - Simplify our window resize logic as much as possible because it's causing issues
    - Allow macOS to handle window sizes, scrolling and positions automatically
    - Experiment in a separate branch
    - I've made updates in task 8edc4e86 - about style picker menu - and now the app spams windows resizes and relocations and goes off screen
        "Content height changed to: 121.0"
        "Updating window to height: 693.0"
        "Updating window to height: 281.0"
        "Content height changed to: 533.0"
        "Content height changed to: 121.0"
        "Updating window to height: 693.0"
        "Updating window to height: 281.0"
        "Content height changed to: 533.0"
- [x] x
    - `key: 8edc4e86`
    - Rework style selector to be multi-line to fit on screen better

Let's make a prd + task to design a onboarding user flow on first launch, guide through setup / like nice ui guiding through questions and stuff, showcase basic items and functionality (but with option to skip

prd: first-launch onboarding flow with guided setup and optional skip
users: first-time app users; family members setting up on a new Mac
success: first launch guides through key setup and basic features in under 2 minutes, with skip and resume paths
non-goals: replacing all settings screens

scope
- detect first launch with persistent flag
- show onboarding window before regular settings flow
- steps:
- welcome + skip
- accessibility permission check
- pick base word mode and language
- optional baby name/image setup
- optional custom images folder selection
- quick showcase of lock/unlock + random word mode
- finish and enter main app

interaction design
- wizard-style card stack with progress indicator
- one primary action + secondary skip/back actions
- keep technical text minimal; show concrete examples
- include "Skip for now" on each step
- include "Open onboarding again" in settings

implementation plan
- new view: `OnboardingFlowView` with local step state
- new storage flags:
- `hasCompletedOnboarding`
- `lastOnboardingVersion`
- wire launch gate in app startup (`BabyKeyboardLockApp` / `ContentView` entry point)
- reuse existing actions:
- accessibility request
- baby image picker
- custom images folder picker/sync
- language/effect selectors

acceptance criteria
- clean first-run flow with skip works end-to-end
- no regression for existing users (onboarding auto-skipped when already completed)
- onboarding can be reopened manually from settings

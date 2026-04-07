This seems complicated - word pool mechanics etc. Unclear. Also, when i move sliders from 25/25/25/25 - other sliders don't change - feels crazy to interact with and unclear what that means

prd: rework learning-pool mix controls to be understandable while preserving mixed-word selection behavior
users: app users tuning learning rotation
success: users can predict what slider changes do; no ambiguous percentages; pool composition remains configurable
non-goals: removing known/favorite/tag mixing capabilities

problem
- current sliders are independent, so users assume percentages should rebalance but they do not
- "mix" semantics are unclear: probability vs quota vs preference

proposal
- introduce explicit modes:
- `Simple` mode:
- one "Focus" control with presets: balanced / mostly new / mostly known / favorites boost
- one optional tag selector (single dominant tag or balanced tags)
- `Advanced` mode:
- normalized weights model (weights auto-rebalance to 100%)
- if one slider increases, others decrease proportionally
- show live normalized percentages + short text explanation
- add "Reset to balanced" action

model semantics
- treat all mix controls as weights (not direct probabilities)
- normalize on every change
- persist raw weights and normalized display
- use normalized weights for pool sampling

ui details
- rename labels from `mix` to `weight`
- add inline helper text:
- "Weights define relative chance; values auto-balance to 100%."
- add preview chips for resulting composition (known/unknown/favorite + top tags)

acceptance criteria
- sliders always sum to 100% in advanced mode
- simple mode can be used without understanding weight math
- sampling behavior remains equivalent in capability to current implementation

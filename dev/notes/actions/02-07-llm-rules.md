I want to write down the rules i described above somewhere.
For now, in LLM_RULES.md
But also more broadly for other repos as well..

prd: capture agent workflow rules in-repo and make them portable to other repos
users: ai agents, maintainers
success: LLM_RULES.md contains the rules; easy to copy to other repos
non-goals: implement automation or tooling

repo notes
- existing docs: `LLM_RULES.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `WARP.md`

proposal
- keep canonical rules in `LLM_RULES.md`
- when asked on other repos, copy the same block into their `LLM_RULES.md`

plan/tests
- add rules block to `LLM_RULES.md` (done in this change)
- no tests

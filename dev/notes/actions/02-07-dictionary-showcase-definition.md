Finish scripts.word_dictionary_showcase to generate a rich progressive dictionary and add definition mode

prd: finish the showcase script and add definition mode output
users: maintainers, dataset reviewers
success: script runs end-to-end; definition mode produces expected output
non-goals: UI integration in app

repo notes
- task key: 48f24568 (`dev/notes/tasks.md`)
- script: `scripts/word_dictionary_showcase.py`
- deps: `pyproject.toml`

proposal
- complete missing TODOs in `word_dictionary_showcase.py`
- add definition mode flag/output format
- ensure it runs via `uv run python -m scripts.word_dictionary_showcase`

plan/tests
- run a small sample with `--limit`
- verify output in table format

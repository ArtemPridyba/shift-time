# Boris's folder — rules for Claude

Boris, the web designer of the team, uses `boris/` to study the market, collect ideas and prepare proposals. The folder is separate from the game, the plan and the rules of the project; nothing here is a team decision. Boris's friend keeps working by `docs/roadmap.md` at the same time, so the two lines of work must not touch each other.

## When this file applies

A session works for Boris when its first message says so or names `boris/`. Such a session follows this file instead of «How every session works» in the root `CLAUDE.md`. The rest of the root file still applies: talk in Russian, «Spend few tokens», git rules.

## Rules

- Write only inside `boris/`. Never edit, move or delete anything outside it: not `game/`, `docs/`, `.github/`, `.claude/`, not the root `CLAUDE.md`. If a task seems to need a change outside, tell Boris; the team makes it in a roadmap session.
- Read the friend's files only when the task needs them, and only the lines you need (`grep -n` first).
- Findings and proposals go into files here; decisions are the team's. Mark what is checked (with a source) and what is a guess.
- Start: read «Сейчас» in `boris/README.md` and only the files the task needs. If a pull request that changes only `boris/` is open, tell Boris and offer to merge it before new work.
- Godot tests are not needed when only `boris/` changes: CI runs them on the pull request.
- End: update «Сейчас» in `boris/README.md` (what is done, what is next, the first message of the next session with model and effort), commit, push and open a pull request into the default branch that changes only `boris/`, with the title and description in Russian.

## The repository is public

Git keeps deleted files in history, and anyone can read them, other jam teams too. Never write personal data, money, contracts or anything the team would not show to strangers.

## Cost

- Bulk reading (web pages, lists of games, long logs) goes to the `reader` helper (Haiku) in batches that keep its context under 100 000 tokens; the session keeps only its summaries.
- Default: Sonnet with medium effort. Inventing concepts from a ready digest: Opus with high effort, in a short separate session. Never max effort unless Boris asks.

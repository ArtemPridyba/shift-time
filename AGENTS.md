# Shift Time — rules for Antigravity and other agents

Antigravity, Gemini CLI and other agents read this file; Claude Code reads `CLAUDE.md`. Both describe one project. `CLAUDE.md` holds the full rules: before changing code, read its sections «What this is», «Decisions so far», «Rules for changes», «Design rules the code must respect» and «Commands». If this file and `CLAUDE.md` disagree, `CLAUDE.md` wins: tell the user.

## The project in five lines

- A 2D side-view puzzle-platformer in Godot 4.7.2 (GDScript, static types, Compatibility renderer) for Game Off 2026; we submit on 30 November.
- The player always moves forward in time; holding Shift reverses the world. Releasing Shift replays the recorded future (rule «A»); only interference changes the past.
- 10 levels, floor 7. The web build on itch.io is required; Windows is secondary.
- The game is sold after the jam: every asset must allow commercial use and gets a line in `docs/art/log.md`.
- Two people with equal say. Open questions go to `docs/decisions.md`.

## Which tasks are yours

Task cards in `docs/roadmap.md` carry a label (`**Модель:**`):

- **А** — yours: objects and levels by an existing pattern, build, menu, sound and art in the game.
- **А−** — yours: documents, level cards, data.
- **О** — the time core and the hardest levels: only if you run Opus in Antigravity; otherwise tell the user it belongs to Claude Code.
- **О+, Г, Л** — not yours (Claude Code with xhigh effort, the Gemini app, people).

Labels don't depend on your plan. Without Gemini 4 Argon (Google AI Plus), take А on the model you have: Claude Sonnet for code, Gemini Flash for documents and short tasks, Claude Opus only after Sonnet failed in one chat (D46). A task not done in one chat goes to О; add the model, the task and what went wrong to D45 in `docs/decisions.md`.

Never change the time core (`game/core/timeline.gd`, `temporal_recorder.gd`, the time world, branches, the prelude) unless your task card says so.

## How a task goes

1. Run `git checkout main`, then `git pull`. Read the «Сейчас» section of `docs/progress.md`.
2. Take the task the user names, or the next one in «Дальше» with your label that nobody has in «Кто что делает». «Дальше» says whose task it is: if you don't know who the user is, ask. Tell the user which one you took.
3. Read only that task's section of `docs/roadmap.md` (search for its heading, for example `### 2.1`) and the files it lists. Create a branch `ag/<task>-<short-name>`, for example `ag/2-1-buttons`.
4. Write a plan in 3–5 lines. If the task changes what the player sees or the rules of time, also say what the player will see and what you need to ask, then wait for «ок».
5. Work in small steps. After each step run both tests: on Windows `.\run_tests.bat nopause` (it imports the project first, so a fresh clone works); elsewhere the commands from «Commands» in `CLAUDE.md`. Green is `N tests, 0 failed` and `UI smoke test: 0 failed`.
6. End: tests green; one line in «Сейчас» of `docs/progress.md` and your row removed from «Кто что делает»; a journal row in `docs/history.md` with the price column «Antigravity, <model>, <share of the limit>» (ask the user for the share); new decisions with their reason in `docs/history.md`; commit in English, push the branch, open a pull request into `main` with `gh pr create`, a Russian title and description: what changed and how to check it. Without `gh`, give the user the link that `git push` printed and the ready title and description to paste. Never merge: people do. End with the link and the ready first message for the next chat, as in step 5 of `.agents/workflows/finish.md`.
7. Not finished: write a handoff into «Сейчас» (what is done, what is left, which files) and still end with step 6.

The workflows `/start` and `/finish` in `.agents/workflows/` run steps 1–4 and step 6. If they don't show up after `/`, the user asks you to follow `.agents/workflows/start.md` or `finish.md`: read that file and do its steps.

## Rules that are easy to break

- Run each terminal command on its own, from the repository root: no `cd`, no `;`, `&&` or `$(...)`. Antigravity's permission rules match a command by its start, so a compound command matches none and stops for approval.
- Rules go in `game/core/`, objects in `game/objects/`, presentation in `game/ui/`, numbers in `game/data/` (never hardcoded). A new JSON field needs a data check in the tests.
- Every level has a solution test (`game/tests/solutions/level_NN.json`) written from its card in `docs/levels/`.
- Nothing that fails in the browser build: native threads, GDExtension, `OS.execute`, desktop file dialogs, absolute paths.
- No keys or passwords in the repository: it is public.
- Godot 4 syntax only. Commit `*.uid` files; never commit `.godot/`.
- Two people never edit one level scene at once: check «Кто что делает».
- Ideas outside the task go to «Идеи на потом» in `docs/roadmap.md`, not into the code.

## Shared skills

- A long dictated message (voice input): first follow `.claude/skills/golos/SKILL.md` and its glossary.
- Several different jobs in one message: sort them by `.claude/skills/razbor/SKILL.md`.

## Language

Talk to the team in Russian, in plain words. Code, comments, commit messages and game texts are in English.

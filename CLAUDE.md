# Shift Time — notes for Claude

## What this is

Shift Time (the name was chosen on 3.11.2026) is a 2D puzzle-platformer made in Godot. The player always moves forward in time; holding Shift reverses the time of the surrounding world (doors, platforms, water, crates), and the player can act in both directions, which creates a new branch of history. Scope: the first chapter, 5–8 levels (target 7), deadline 4 weeks.

- Full concept, the source of truth for rules and scope: `docs/concept.md` (Russian).
- Plan: `docs/roadmap.md` (Russian): weeks, gates, tasks sized for one session with done criteria, the cut list.
- Where we are: `docs/progress.md` (Russian): the next task for each track, handoffs, the queue, what waits for people, known issues.
- History: `docs/history.md` (Russian): decisions with reasons, and the journal of sessions with their price. Not read at the start: search it when a past decision matters.
- For people: `docs/how-we-work.md` (Russian): first messages, which model and effort to pick, how to give feedback. Not read at the start: at the end of a session take the next first message and the model and effort from it.
- Setting and visual language: `docs/setting.md` (Russian): the worn-future setting, silhouettes, palette, how time reads in the picture, the neural-network art pipeline. Read it only for tasks that touch art, UI or level looks.
- Architecture: `docs/architecture.md` (Russian): the time model (replay instead of re-simulation, branch, prelude), folders, components, data, input, tests, CI, open questions for the Core plan. Read it before any Core task.
- Art pipeline: `docs/art-pipeline.md` (Russian): sizes, layers, object and character specs, prompts for the neural network, asset list, file names. Read it before an art task.
- Level cards: `docs/levels/NN.md` (Russian, template in `docs/levels/_template.md`): the effect the player sees first, the cause, the solution step by step. A level's solution test is written from its card.

## Decisions so far

- Engine: Godot 4.7.2-stable (the same build as Crown), GDScript with static types, Compatibility renderer, 2D. Pin the version in CI together with the SHA-512 sums, like the Crown project did.
- Platform: PC first (Shift is the main key). A Windows build from GitHub Actions on every merge into `main`.
- The core is not a general physics rewinder. Objects are controlled and recorded: fixed step, interpolation, short history (see «Design rules»).

## Current stage

Week 1 of 4: the prototype of time. Stages and gates are in `docs/roadmap.md`.

## How every session works

The team is two people who build the game through Claude, in two tracks: **Core** (code of time, history, branches, interactions) and **Content** (levels, art, sound, playtests). Every session is one task from `docs/roadmap.md` and ends with its pull request. Every step re-reads the whole conversation, so each step of a long session costs more: keep sessions short and see «Spend few tokens» below.

1. Start: read `docs/progress.md` and, from `docs/roadmap.md`, only the section of your task (find it with `grep -n '^### 1.3' docs/roadmap.md`). This file is already loaded: don't read it again. Check GitHub for open pull requests from earlier sessions: if one is open, tell the user and offer to merge it, then pull the default branch into your branch before new work. If the latest Tests run on the default branch is red, tell the user and fix it first.
2. Take the task the user names, or the next task of the user's track from `docs/progress.md`. Before coding, state a plan in 3–5 lines. When the task changes what the player sees or the rules of time, the plan also says what the player will see, which decisions you will make yourself and what you need to ask; then wait for the user's «ок». Technical tasks (tests, build, CI) go ahead at once.
3. Work in small steps and run both test commands after each one.
4. End (the user says «заканчиваем», or the task is done): both tests green; your line in your track's «Сейчас» in `docs/progress.md`; a journal row and new decisions with their reason in `docs/history.md`, with «запишет следующий чат» in the row's price; the done criteria of the chapter (`docs/roadmap.md`, «Критерии готовности») that this task closed are ticked; commit, push and open a pull request into the default branch, with its title and description in Russian: what changed and how to check it. Then wait for the pull request's Tests check; if it is red, read the failed step's log and fix it. Before any later push, check that the pull request is still open.
5. Once the check is green, the session is done. The last message says what changed and how to check it, offers two or three tasks from the queue for this user and says in one line what is left for the other person, then gives the first message of the next session from `docs/how-we-work.md`, with the model and effort. Don't offer to watch the pull request.
6. If the task is not finished, write a handoff into your track's «Сейчас» (what is done, what is left, which files), keep the tests green and still end with step 4.
7. New ideas outside the task go to «Идеи на потом» in `docs/roadmap.md`, not into the code. When the week is short on time, cut by the cut list in `docs/roadmap.md`, in its order, and write the cut into `docs/history.md`.
8. Two people work at once: take only tasks whose «Файлы» don't meet those of a task in progress (see the queue in `docs/progress.md`). Each track has its own «Сейчас» section, so the two never edit the same lines.
9. Talk to the team in Russian, in plain words. Code, comments, commit messages and game texts are in English.

## Spend few tokens

Everything a step reads stays in the conversation and is read again by every later step.

- Read only what the step needs: `grep -n` first, then the lines around the match. Don't print whole long files, and don't re-read a file you just wrote or edited.
- Check with the short command from «Commands»: it prints only failures and the totals.
- Ask GitHub only for the fields you need. Don't open old pull requests to copy their style: the format is above.
- Compare with `origin/main` after `git fetch`, never with a stale local `main`.
- Make independent calls in one step, such as several reads at once.
- When a message brings several different jobs, sort them first: small ones here, big mechanical ones to a helper subagent on Sonnet, long output to a reader subagent on Haiku, hard code on Opus. Subagents start from nothing, so never hand them small things. No agent teams unless the user asks.
- When the user asks «запиши цену прошлых чатов», take each past session's cost and used tokens and fill the price column of the journal in `docs/history.md`, as `$18 · 527 тыс.`.

## Layout

- `game/` — the Godot project (`game/project.godot`).
- `game/autoload/` — singleton nodes (`time_manager.gd`, `game_data.gd`): anything that must be a `Node` and global lives here, not in `core/`.
- `game/core/` — rules in plain GDScript (`RefCounted`, no nodes, no UI): history, recorder, branches, time direction logic. Must stay testable headless.
- `game/objects/` — temporal objects as scenes plus scripts: door, platform, crate, water, button, lever, valve. One scene per object.
- `game/levels/` — one scene per level, `level_01.tscn` … `level_07.tscn`. Two people never edit one level at once.
- `game/ui/` — HUD, menus, time-direction indicator. Presentation only.
- `game/data/` — numbers and settings as JSON (recording step, history length, level list, texts). The team edits these without code.
- `game/tests/` — headless tests: `test_runner.gd`, rule tests, determinism test, level solution tests (`solutions/`), UI smoke test.
- `docs/` — concept, roadmap, progress, history, how-we-work, level cards.
- `.github/workflows/tests.yml` — runs both test commands on every push; `.github/workflows/build.yml` — after every merge into `main`: tests, then the Windows build as a release artifact.

## Commands

Run from the repository root (`godot` = the Godot 4.7 binary):

- After a fresh clone, and after adding a script with a new `class_name`: `godot --headless --path game --import`
- Rule tests: `godot --headless --path game --script res://tests/test_runner.gd`
- UI smoke test: `godot --headless --path game --script res://tests/ui_smoke_test.gd`
- Both tests with short output, the usual check in a session: `godot --headless --path game --script res://tests/test_runner.gd 2>&1 | grep -E 'FAIL|SCRIPT ERROR|tests,'; godot --headless --path game --script res://tests/ui_smoke_test.gd 2>&1 | grep -E 'FAIL|SCRIPT ERROR|failed'`. Green is `N tests, 0 failed` and `UI smoke test: 0 failed`.
- Play: open `game/project.godot` in the Godot editor and press F5.

Both test commands exit with code 0 on success. A script error fails the test it happens in; `push_error` only prints. These commands and the tests are written in task 1.1; until then they don't exist.

No `godot` on PATH (a fresh cloud container): download the Linux build from GitHub releases, `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`, unzip it and use the `Godot_v4.7.2-stable_linux.x86_64` binary inside. The downloads.godotengine.org mirror may be blocked by the cloud proxy. The SHA-512 of the zip is in `docs/architecture.md`, section 9.

## Rules for changes

- Run both test commands after every change. Add a test for every new rule.
- Rules go in `core/`, objects in `objects/`, presentation in `ui/`, numbers in `data/`. Never hardcode numbers that a designer will tune.
- When you add a JSON field or file, extend the data check so broken data shows up in the tests.
- JSON numbers load as floats: convert with `int()` where an integer is needed.
- Every level has a solution test: a recorded sequence of inputs (`game/tests/solutions/level_NN.json`) that the headless runner plays and that must reach the exit. A change to the time rules that breaks a solution fails the tests; fix the rules or, with the team's «ок», the level.
- A determinism test records N frames, rewinds them and compares the states. A pure refactor must leave it as it is.
- Godot 4 syntax only. No Godot 3 APIs.
- Commit `*.uid` files that Godot creates next to scripts. Never commit `.godot/`.
- Small steps: one feature per commit.
- A part never keeps a reference to the game or the level; it gets them as an argument (two `RefCounted` that hold each other are never freed). `core/` never refers to `ui/` and never extends `Node`.
- Two people, two tracks: Core owns `core/`, `objects/`, `tests/` of rules; Content owns `levels/`, `ui/` visuals, `art/`, `audio/`, level cards and solution files. Touching the other track's files is fine in a task that says so in its «Файлы».

## Design rules the code must respect

- The player's time `t` always grows. World time `τ` grows in normal mode and decreases while Shift is held: `dτ/dt = +1 or −1`. Shift never moves the player back and never cancels the player's own actions.
- `TimeManager` (autoload) holds the direction, +1 or −1, and tells temporal objects. The player does not subscribe to it as a temporal object.
- Temporal objects record their state in a frame of the room's history. Start value: a frame on every physics tick (60 per second), fallback every 4th tick with interpolation; the history is bounded (start value 20 seconds per room), all numbers in `data/time.json`. Reverse motion is continuous, never a teleport.
- Replay, not re-simulation: while the cursor is left of the head of the history, objects only restore recorded frames; they simulate only at the head. A player action left of the head writes the new state into the frame at the cursor and cuts everything to its right (a branch). The player is never recorded. While Shift is held and the cursor is at frame 0, the world stands still. Details: `docs/architecture.md`.
- A level may have a prelude: the room is run without the player for `prelude_seconds` and recorded, so levels that start from an effect have a past to rewind. Scripted events are data, never random.
- Every window in which the player must act is at least 3 seconds and visible; where possible the solution works from the world pinned at frame 0.
- Do not try to reverse arbitrary Godot physics. Objects are controlled and recorded; water is a level value plus particles, not fluid simulation.
- An action of the player during reverse mode creates a new branch: the old future of the changed object, and for the MVP of the whole room, is cut and recording continues from the new state (`BranchManager`).
- The direction of time must read from motion, particles, mechanism animation and sound, never from color alone.
- The player has an action in both modes: pressing buttons, using levers, carrying crates, only through special points of interaction, not by pushing (see `docs/history.md` for the decision).
- Each level introduces one new rule and checks it in a new situation. At least two levels start from a visible effect whose cause the player must find, and no solution may depend on guessing a timing.
- Postponed beyond this month: full physics inversion of all rigidbodies, fluid and gas simulation, several independent time fields, switching freely between all alternative histories, story, cutscenes, voice and a dialog system.

## Visual rules

Details and reasons are in `docs/setting.md`. Read it before a task that touches art, UI or how a level looks.

- Setting: a worn future in the spirit of Portal and Half-Life, with rust, metal and tired spaces and working new technology among them. Take the mood, never recognisable parts of those games (no orange portals, no Aperture panels).
- Style: side view, silhouettes and flat geometric shapes, minimal detail. Wear is shown by shape (chips, holes, bent beams, streaks), thin overlays and particles, not by detailed textures. The background is always quieter than platforms, doors and interaction points.
- One accent: the cold cyan (start value `#7FE8FF`) belongs only to special mechanisms and objects tied to time, the wrist device and its indicator. Ordinary things in the world also rewind but get no glow. Nothing else uses it.
- The player wears a device on the wrist; the time-direction indicator lives on it.
- Time reads in the picture, not by color alone: particles, light pulses and the wrist device run the other way in reverse mode. «Worn ↔ clean» fading on temporal objects is optional polish and the first visual cut.
- Neural-network art goes only on backdrops, decor, wear overlays and concept frames, after an approved style sheet. Level geometry and collision come from the blockout in Godot, never from an image. Temporal objects, interaction points and the wrist device are made by hand (vector, shaders, animation) so their states play forward and back without jumps.

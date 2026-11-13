# Shift Time — notes for Claude

## What this is

Shift Time is a 2D side-view puzzle-platformer in Godot for **Game Off 2026** (theme SHIFT). The player always moves forward in time; holding Shift reverses the time of the surrounding world (doors, platforms, water, fire, lamps, crates), and the player can act in both directions, which creates a new branch of history.

- **Goal:** win Game Off 2026. Deadline 1 December 2026, 21:37 UTC (13:37 PST); we submit on 30 November.
- **Result:** an itch.io page where the game runs in the browser. The web build is required, Windows is secondary.
- **Scope:** the first chapter, 10 levels, floor 7 when cutting. Each level introduces one mechanic: mechanisms, water, fire, light and darkness, reverse items, cause and effect, interference with the past.
- **After the jam the game is sold:** every asset must allow commercial use.

Documents are in Russian. Read only what the task needs:

- `docs/progress.md` — where we are, who is on what, what is next. The session-start hook prints its «Сейчас».
- `docs/roadmap.md` — weeks, gates, task cards with labels, cut list. Read only your task's section: `grep -n '^### 2.3' docs/roadmap.md`.
- `docs/concept.md` — rules of the game and scope, the source of truth.
- `docs/architecture.md` — time model, folders, components, data, tests, CI. Read it before any task that changes the time rules, the code structure or the tests.
- `docs/levels/NN.md` — level cards; a level's solution test is written from its card.
- `docs/decisions.md` — the shared register of open questions and answers.
- `docs/history.md` — decisions with reasons and the session journal. Search it, don't read it whole.
- `docs/how-we-work.md` — for people: tools, labels, first messages, Antigravity setup.
- `docs/style.md`, `docs/setting.md`, `docs/art-pipeline.md`, `docs/ai-tools.md` — style test, setting, art specs, AI tools for art and sound. Only for art, UI, sound or level-look tasks.
- `docs/research/` — market scan, mechanics of similar games, after-jam ideas. Background, not rules.

## Decisions so far

- Engine: Godot 4.7.2-stable, GDScript with static types, Compatibility renderer, 2D. CI pins the version with its SHA-512 in `.github/actions/install-godot/`.
- Platform: the web build on itch.io is required; Windows is secondary.
- Rule «A»: releasing Shift erases nothing — the world replays the recorded future. Only interference changes the past.
- Rooms fit one screen (16:9).
- Three kinds of objects: recorded (door, platform, water, wood zones, lamp, gear, lever, crate), live (the player and reverse items, never recorded), decoration (puddles, splashes, sparks: inverted animations, no effect on anything).
- The core is not a general physics rewinder: objects are controlled and recorded, fixed step, interpolation, short history.
- Art: AI draws the look of everything after an approved style sheet; motion and states are code (shaders, particles, cutout rigs), so everything plays backwards without jumps. The style is being chosen (`docs/style.md`).
- Two people with equal say. Open questions go to `docs/decisions.md`; either person answers; the answer becomes a decision with its reason in `docs/history.md`; a wrong decision is undone by a new one, never erased.

## Current stage

Week 1 of 4 ends on 9 November with task 1.4. Week 2: 10–16 Nov, week 3: 17–23 Nov, week 4: 24–30 Nov. Gates are in `docs/roadmap.md`.

## Who does what

Every task card has a label (`**Модель:**`). Claude Code limits are short: on Opus it takes only О and О+, on Sonnet also А (D46). Everything else goes to Antigravity or the Gemini app. A regular Claude chat sees no repository and runs nothing: it only helps next to Antigravity (template in `docs/how-we-work.md`).

| Label | Who | Where |
| --- | --- | --- |
| О | Opus, effort high | Claude Code, or Opus in Antigravity |
| О+ | Opus, effort xhigh | Claude Code |
| А | Gemini 4 Argon; without it (Google AI Plus) Claude Sonnet 4.6 for code, Gemini 3.8 Flash for short tasks; Sonnet in Claude Code | Antigravity or Claude Code |
| А− | Gemini: documents, cards, data | Antigravity or the Gemini app |
| Г | Gemini app: images, video, music, second opinion, playtest videos | the Gemini app |
| Л | people | — |

Antigravity and other agents follow `AGENTS.md`, which points back to this file.

## How every session works

1. **Start.** The hook has printed «Сейчас» of `docs/progress.md`; if not, read that section. Compare your model with the task's label (Sonnet matches А, see «Who does what»): if it doesn't match, say so, give the first message for the right tool from `docs/how-we-work.md` and wait. Read only your task's section of `docs/roadmap.md`. Check GitHub for open pull requests from earlier sessions: if one is open, tell the user and offer to merge it, then pull the default branch into your branch. If the latest Tests run on the default branch is red, tell the user and fix it first.
2. **Take a task:** the one the user names, or the next one in «Дальше» that nobody has in «Кто что делает». A long dictated message goes through the `golos` skill first. Before coding, state a plan in 3–5 lines. When the task changes what the player sees or the rules of time, the plan also says what the player will see, which decisions you will make yourself and what you need to ask; then wait for «ок». Technical tasks (tests, build, CI) go ahead at once.
3. Work in small steps and run both test commands after each one.
4. **End** (the user says «заканчиваем», or the task is done): both tests green; your line in «Сейчас» of `docs/progress.md`, and your row removed from «Кто что делает»; a journal row and new decisions with their reason in `docs/history.md`, with «запишет следующий чат» in the row's price; the done criteria of the chapter that this task closed are ticked in `docs/roadmap.md`; commit, push and open a pull request into the default branch with its title and description in Russian: what changed and how to check it. Wait for the Tests check; if it is red, read the failed step's log and fix it. Before any later push, check that the pull request is still open: commits pushed after a merge never reach `main`; if it was merged, move the new commits onto the fresh default branch and open a new pull request.
5. Once the check is green, the session is done. The last message says what changed and how to check it, then gives the first message of the next session with its tool, model and effort (`docs/how-we-work.md`). Don't offer to watch the pull request: every event wakes the whole conversation.
6. If the task is not finished, write a handoff into «Сейчас» (what is done, what is left, which files), keep the tests green and still end with step 4.
7. Ideas outside the task go to «Идеи на потом» in `docs/roadmap.md`; questions the team must answer go to `docs/decisions.md`. When a week is short on time, cut by the cut list in its order and write the cut into `docs/history.md`.
8. When a week's gate is passed, update «Current stage» above and detail the next week in `docs/roadmap.md`.
9. Talk to the team in Russian, in plain words. Code, comments, commit messages and game texts are in English.

## Spend few tokens

Everything a step reads stays in the conversation and is read again by every later step.

- Read only what the step needs: `grep -n` first, then the lines around the match. Don't print whole long files and don't re-read a file you just wrote or edited.
- Check with the short command from «Commands»: it prints only failures and totals.
- Ask GitHub only for the fields you need. Compare with `origin/main` after `git fetch`, never with a stale local `main`.
- Make independent calls in one step.
- Several different jobs in one message: sort them with the `razbor` skill first. Long output (a CI log, many screenshots) goes to the `reader` subagent, big mechanical work to `helper`. Subagents start from nothing: never hand them small things.
- Effort: high by default, xhigh only for code across many files, never max.
- Long reading that the session doesn't need word for word (videos, long documents, a second opinion) goes to Gemini; the user brings back the answer.
- More than about 40 steps means the task is too big: write a handoff and end.
- «Запиши цену прошлых чатов»: fill the price column of the journal in `docs/history.md` as `$18 · 527 тыс.`.

## Layout

- `game/` — the Godot project (`game/project.godot`).
- `game/autoload/` — singletons (`time_manager.gd`, …): anything that must be a `Node` and global lives here, not in `core/`.
- `game/core/` — rules in plain GDScript (`RefCounted`, no nodes, no UI): timeline, recorder, time world, live sources, time-direction logic. Must stay testable headless.
- `game/objects/` — temporal objects as scenes plus scripts, one scene per object: door, platform, crate, water, button, lever, valve, gear, wood zone, lamp, reverse items (flamethrower, trampoline).
- `game/levels/` — one scene per level, `level_01.tscn` … `level_10.tscn`. Two people never edit one level at once.
- `game/ui/` — HUD, menus, time-direction indicator. Presentation only.
- `game/data/` — numbers and settings as JSON (recording step, history length, burn time, player, level list, texts). The team edits these without code.
- `game/assets/` — images and sounds; every file has a line in `docs/art/log.md`.
- `game/art/` — block sets for levels (`art/blocks`, made by `tools/make_grey_blocks.py`); `game/audio/` — the place for the two time sounds (`time_sound.gd`, paths in `data/time_hud.json`).
- `game/tests/` — headless tests: `test_runner.gd`, rule tests, determinism test, level solution tests (`solutions/`), UI smoke test.
- `docs/` — the documents above; `docs/art/` — concept frames, the style sheet, the asset log `docs/art/log.md`.
- `tools/` — scripts outside the game: blockout, concept frames; art and audio scripts later.
- `.github/workflows/tests.yml` — both test commands on every push; `build.yml` (tasks 2.0 and 4.5) — after every merge into `main`: tests, then the web build and the Windows build.
- `.claude/` — skills `razbor` (sorts jobs by cost) and `golos` (dictated messages), subagents `helper` (Sonnet) and `reader` (Haiku), the session-start hook. `AGENTS.md` and `.agents/workflows/` — the same rules for Antigravity.

## Commands

Run from the repository root (`godot` = the Godot 4.7.2 binary):

- After a fresh clone, and after adding a script with a new `class_name`: `godot --headless --path game --import`
- Rule tests: `godot --headless --path game --script res://tests/test_runner.gd`
- UI smoke test: `godot --headless --path game --script res://tests/ui_smoke_test.gd`
- Both tests with short output, the usual check in a session: `godot --headless --path game --script res://tests/test_runner.gd 2>&1 | grep -E 'FAIL|SCRIPT ERROR|tests,'; godot --headless --path game --script res://tests/ui_smoke_test.gd 2>&1 | grep -E 'FAIL|SCRIPT ERROR|failed'`. Green is `N tests, 0 failed` and `UI smoke test: 0 failed`.
- Web export (preset `Web` in `game/export_presets.cfg`, single-threaded Compatibility build into `build/web/index.html`): `mkdir -p build/web && godot --headless --path game --export-release "Web" ../build/web/index.html && (cd build/web && zip -r ../shift-time-web.zip .)`
- Play: open `game/project.godot` in the Godot editor and press F5. On Windows `run_tests.bat` imports the project and runs both tests; an agent runs `.\run_tests.bat nopause`, because `pause` would wait for a key.

Both test commands exit with code 0 on success. A script error fails the test it happens in; `push_error` only prints.

In a cloud session the hook puts Godot on PATH and imports the project. Without the hook: download `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` (the downloads.godotengine.org mirror may be blocked), check its SHA-512 from `.github/actions/install-godot/action.yml`, unzip it and use the binary inside.

## Rules for changes

- Run both test commands after every change. Add a test for every new rule.
- Rules go in `core/`, objects in `objects/`, presentation in `ui/`, numbers in `data/`. Never hardcode numbers that a designer will tune.
- When you add a JSON field or file, extend the data check so broken data shows up in the tests.
- JSON numbers load as floats: convert with `int()` where an integer is needed.
- Every level has a solution test: a recorded sequence of inputs (`game/tests/solutions/level_NN.json`) that the headless runner plays and that must reach the exit. A change to the time rules that breaks a solution fails the tests; fix the rules or, with the team's «ок», the level.
- A determinism test records N frames, rewinds them and compares the states. A pure refactor must leave it as it is.
- Don't break the web export: nothing that fails in the browser build (native threads, GDExtension, `OS.execute`, desktop file dialogs, absolute file paths).
- The repository is public: never keys or passwords in it; CI keys live only in GitHub Secrets. Every AI-made or third-party file gets a line in `docs/art/log.md` (service, prompt or source, license); third-party files also go to `CREDITS`. Only sources that allow commercial use.
- Godot 4 syntax only. No Godot 3 APIs.
- Commit `*.uid` files that Godot creates next to scripts. Never commit `.godot/`.
- Small steps: one feature per commit.
- A part never keeps a reference to the game or the level; it gets them as an argument (two `RefCounted` that hold each other are never freed). `core/` never refers to `ui/` and never extends `Node`.

## Design rules the code must respect

- The player's time `t` always grows. World time `τ` grows in normal mode and decreases while Shift is held: `dτ/dt = +1 or −1`. Shift never moves the player back and never cancels the player's own actions.
- `TimeManager` (autoload) holds the direction, +1 or −1, and tells temporal objects. The player does not subscribe to it as a temporal object.
- Recorded objects write their state into a frame of the room's history on every physics tick (60 per second; fallback every 4th tick with interpolation). The history is bounded (start value 20 seconds per room); all numbers are in `data/time.json`. Reverse motion is continuous, never a teleport.
- Replay, not re-simulation: while the cursor is left of the head, recorded objects only restore frames; they simulate only at the head. Releasing Shift without interference replays the recorded future (rule «A»). While Shift is held and the cursor is at frame 0, the world stands still.
- Interference: an action of the player or of a live source on a recorded object left of the head writes the new state into the frame at the cursor and cuts everything to its right — a branch, for the MVP of the whole room (`Timeline.branch()` through `TimeWorld.player_action` / `TimeWorld.live_action`; there is no separate BranchManager class). At the head it is ordinary recording. Details: `docs/architecture.md`, sections 2 and 2.5.
- Live sources (the player and reverse items) are never recorded and act by the current direction of time. A live source affects a recorded object once per contact.
- Reverse items keep no history: inverted animations, reversed behaviour; in some levels their behaviour is baked into the prelude as scripted events. They are a flag on an object, not a second time field: world time is one per room.
- The world moves the player: a platform replaying backwards carries the player, a crate flying back pushes the player. Nothing crushes the player: if the next frame would, the world waits on that tick until the player moves away. What the player holds stays with the player while the world rewinds.
- Fire works by zones: a wood zone is whole → burning → burnt; burning lasts at least 3 seconds (`burn_seconds` in data). Standing in fire kills the player after 3 seconds and the room resets. No free-spreading fire. Water and the reverse flamethrower in normal time put fire out; with Shift held the reverse flamethrower sets wood burning, and burning ends in «burnt» only in normal time.
- Water is a flow from its source (valve, gear); it does not hurt the player, it blocks the way: the player sinks to the bottom, walks slower and cannot jump out; rising water lifts the player to its surface. A floating platform follows the water level and carries the player. Puddles and splashes are decoration.
- Darkness: dark rooms show only what is lit. A broken lamp reassembles under Shift and shines while Shift is held (rule «A»); keeping the light needs interference.
- A level may have a prelude: the room is run without the player for `prelude_seconds` and recorded, so levels that start from an effect have a past to rewind. Scripted events are data, never random.
- Every window in which the player must act is at least 3 seconds and visible; where possible the solution works from the world pinned at frame 0. No solution depends on guessing a timing.
- The player acts only through interaction points (buttons, levers, valves, crate grabs), never by pushing.
- The direction of time reads from motion, particles, mechanism animation and sound, never from color alone.
- Each level introduces one new rule and checks it in a new situation. At least two levels start from a visible effect whose cause the player must find.
- Do not try to reverse arbitrary Godot physics. Water is a level value plus particles, not fluid simulation.
- Postponed beyond the jam: full physics inversion of all rigidbodies, fluid and gas simulation, several independent time fields, free-spreading fire, switching freely between alternative histories, story, cutscenes, voice and a dialog system.

## Visual rules

Details: `docs/style.md` (the style test), `docs/setting.md`, `docs/art-pipeline.md`, `docs/ai-tools.md`.

- The style is chosen on 11 November among three options: cardboard diorama, rotoscope, rusty silhouette. Until then levels stay grey blockout.
- Setting: a worn future in the spirit of Portal and Half-Life — rust, metal, tired spaces and working new technology among them. Take the mood, never recognisable parts (no orange portals, no Aperture panels). Earlier picture decisions (torn ceiling, rust streaks, the scarf, one cyan accent) carry over where the chosen style allows.
- One accent: the cold cyan (start value `#7FE8FF`) belongs only to mechanisms and objects tied to time and to the wrist device with its indicator.
- The player wears a device on the wrist; the time-direction indicator lives on it.
- Time reads in the picture by motion: particles, light pulses and the wrist device run the other way in reverse mode.
- Special items glow only where there is light. Reverse items and decoration play inverted animations. Fire danger reads by shape and particles before contact, not by one color.
- Level geometry and collision come from the blockout in Godot, never from an image. AI art goes in only after the approved style sheet.

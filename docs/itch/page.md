# Shift Time — itch.io page (draft)

Draft of the page text for task И1 (27.11.2026). English, as it goes on itch. Pictures: `gif/` and `shots/` next to this file; how to remake them — [README.md](README.md). The team edits the text freely; the facts (keys, tools, AI) are checked against the repository on 27.11.

---

## Short description (the one line under the title)

Hold Shift and the world runs backwards. You don't.

## Page text

**Shift Time** is a short puzzle-platformer about a night shift in an old brick factory, made in four weeks for GitHub Game Off 2026 (theme: *SHIFT*).

Hold **Shift** and time in the room around you runs backwards: doors close the way they opened, platforms slide back along their rails, water drains into its pipes, fire un-burns. You keep moving forward. Everything you do while the world rewinds becomes part of its past — and when you let go, the world plays out the new history you wrote.

Each room is one puzzle. Most of them start from an effect — a jammed door, a flooded pit, a crane stuck halfway — and you go back to find the cause.

- 5 hand-made rooms, each teaching one rule of time
- No timing tricks: every window to act lasts at least three seconds, and the world can be held at its first frame
- Rewinding is continuous — no jumps, no checkpoints, just the world playing in reverse
- Runs in the browser

### Controls

| Action | Keys |
|---|---|
| Move | A / D or ← / → |
| Jump | Space, W or ↑ |
| Reverse the world's time (hold) | Shift or Q |
| Use a lever, button or valve | E |
| Restart the room | R |
| Look at the whole room (hold) | Tab |
| Zoom | mouse wheel, + / − |
| Pause | Esc |

Click the game once to give it the keyboard. Best in a desktop browser with a keyboard; there are no touch controls.

### Made with

- **Godot 4.7** (MIT), GDScript, Compatibility renderer, single-threaded web build
- Code, level building scripts, tests and tools: written by the two of us together with AI coding assistants (Claude Code, Gemini in Antigravity); every level has an automated solution test that replays its inputs
- The whole project is open: <https://github.com/ArtemPridyba/shift-time>

### About AI

We want to be plain about where AI was used.

- **Pictures.** The look of the factory (back walls, the brick kit, lamps, platforms, the backdrop of the first room) and the heroine's body parts were generated with the Gemini app from our own prompts and our own game screenshots, then cut, keyed and fitted into the game by our scripts. Every such file is listed with its prompt in [`docs/art/log.md`](https://github.com/ArtemPridyba/shift-time/blob/main/docs/art/log.md).
- **Motion.** All movement — the heroine's walk, doors, gears, water, fire, light — is code (cutout rig, shaders, particles), so that everything can play backwards.
- **Code.** Written with AI coding assistants, reviewed and play-tested by us; the design, the levels and every decision are ours (the decision log is in the repository).
- **Sound.** *(fill in from the sound session's rows in `docs/art/log.md`)*
- No third-party art or sound packs.

### Credits

Artemiy Pridyba and Borys Shapovalov. Thanks to Godot Engine and its contributors. Full list: [`CREDITS`](https://github.com/ArtemPridyba/shift-time/blob/main/CREDITS).

---

## AI disclosure for the jam form (short)

Shift Time uses generative AI. Pictures: the factory backgrounds, the brick and machine kit, platforms and the heroine's body parts were generated with Google's Gemini app from our prompts and our own screenshots, then cut and assembled by our scripts; all motion is code. Code: written by the two of us with AI coding assistants (Claude Code, Gemini in Antigravity), and reviewed, tested and play-tested by us. Game design, levels and decisions are ours. Sound: *(fill in after the sound session)*. Every generated file and its prompt are listed in docs/art/log.md of the public repository.

---

## itch.io settings (for the person who uploads)

- Kind of project: **HTML**; upload `shift-time-web.zip` (the `build.yml` artifact `shift-time-web` of the latest `main`, or the command «Web export» in `CLAUDE.md`), tick «This file will be played in the browser».
- Viewport **1280 × 720**, tick «Fullscreen button»; «Mobile friendly» off (no touch controls).
- «SharedArrayBuffer support» — **off**: the build is single-threaded (check of task 2.0, 10.11).
- Genre: Puzzle; tags: puzzle-platformer, time-manipulation, 2D, godot, game-off-2026, short.
- Cover 630 × 500 (and 315 × 250): to be made (Г); the first frame of the GIF or a shot of level 01 under Shift will do until then.
- Before the jam build: `"unlock_in_order": true` in `game/data/menu.json` (card И3, D167).

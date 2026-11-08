---
name: razbor
description: Sorts a session's several subtasks by cost before any work starts. For each one it decides who does it — this session at once, the `helper` subagent on Sonnet or Opus, the `reader` subagent on Haiku, or Opus in this session or a new one — and with which effort. It shows the team the table and waits for «ок». Use when one message brings two or more different jobs, such as renaming documents, editing a table and writing new code.
when_to_use: The user lists several different jobs in one message, writes «разбор» or /razbor, or a task turns out to hold parts of very different difficulty.
argument-hint: "[подзадачи]"
---

# Razbor: sort the subtasks before doing them

Tasks in `docs/roadmap.md` carry a label: О and О+ stay in Claude Code, А and А− go to Antigravity, Г to the Gemini app, Л to people. Claude Code limits are short, so everything that doesn't need it goes out.

Every step re-reads the whole session, and a subagent starts from nothing: its own instructions plus every file it reads again. A subagent pays off only for a big, self-contained piece of work whose long output this session doesn't need. Small things are cheaper here, and hard things belong on Opus.

## 1. Split

List the subtasks of the message (and of `$ARGUMENTS`, if given), one line each, in the order they depend on each other.

## 2. Sort each one into a basket

| Basket | What goes there | Who | Model and effort |
| --- | --- | --- | --- |
| Here | Small and quick: a rename, a few lines of text, a row in a table, a question about the code. Up to about five steps. | This session, at once | The session's own |
| Helper | Big and mechanical, with a clear check of done: numbers from level cards into `game/data` JSON, the same edit across many files, a long document to rewrite, tests that follow an existing pattern. | `helper` | Sonnet, medium for text and data; Sonnet, high when tests or `Content.validate()` must pass; never max |
| Helper on Opus | Code that follows a plan the team has approved, in a few files, with tests to show it works. | `helper` | Opus, medium |
| Reader | Long output to read and boil down: a failed CI log, many screenshots to compare, a search across the whole project. | `reader` | Haiku, low; medium when it must compare or judge |
| Opus | A new rule or system, code across several layers, a bug without a clear cause, anything where the team's plan and «ок» matter. | This session if it runs on Opus, otherwise a new session | Opus, high; xhigh for code across many files, a stage plan, a stubborn bug or architecture; never max |
| Antigravity | A task labelled А or А−, or anything else that doesn't need Claude Code: objects and levels by an existing pattern, build, menu, sound and art in the game, documents. | A new session in Antigravity | Gemini 4 Argon; Claude Sonnet in Antigravity as a fallback |

- In doubt between Here and Helper, choose Here: the start of a subagent alone costs more than a few steps.
- A subtask that changes what the player sees or the rules of time goes to a subagent only after the team has said «ок» to its plan.
- Subagents can't ask the team anything. Whatever needs a decision stays in this session.
- Two subagents that touch the same files run one after the other, never at once.

## 3. Show the table and wait

Show the team a table in Russian, for example:

| Подзадача | Кто | Модель и усилия | Почему |
| --- | --- | --- | --- |
| Переименовать документы | этот чат, сразу | — | два шага |
| Перенести числа карточек уровней в `levels.json` | помощник helper | Sonnet, high | большая однообразная работа, проверка тестами |
| Запись и история | этот чат | Opus, high | новая система: сначала план и «ок» |
| Меню и настройки | новый чат в Antigravity | Gemini 4 Argon | метка А: Claude Code не нужен |

If an Opus subtask doesn't fit this session, because it doesn't run on Opus or is already long, say so and give a ready first message for a new session from `docs/how-we-work.md`. For an Antigravity subtask, give its first message from the same file. Then wait for «ок» or changes.

## 4. Do it

- **Here:** now, in the order of the table.
- **Helper or reader:** start the subagent with `model` and `effort` from the table. It hasn't seen this session, so the prompt carries everything it needs: the goal, the files, the decisions already made with the team, the check of done (for code and data, the short test command from CLAUDE.md is green) and what to send back — at most ten lines: what changed, which files, the result of the check, anything it couldn't do.
- **Opus:** here, or end the session with the first message for the new one.

## 5. Check

After each subagent, look at `git diff --stat` and run the short test command yourself. Fix a small miss here. A big miss goes back to the subagent once, with what was wrong; after that, take the subtask over. Commit each finished subtask on its own.

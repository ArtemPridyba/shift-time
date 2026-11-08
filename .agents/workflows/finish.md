---
description: Finish a Shift Time task — tests, progress, history, pull request
---

1. Run both tests (`run_tests.bat` on Windows, or the commands from «Commands» in `CLAUDE.md`). Both must be green.
2. In `docs/progress.md`, «Сейчас»: one line on what is done, and remove your row from «Кто что делает». Not finished: write a handoff instead (what is done, what is left, which files).
3. In `docs/history.md`: a journal row with the price «Antigravity, <model>», and each new decision with its reason.
4. Commit in English, push the branch, open a pull request into `main` with a Russian title and description: what changed and how to check it.
5. Give the user the link to the pull request and the next task from «Дальше».

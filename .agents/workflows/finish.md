---
description: Finish a Shift Time task — tests, progress, history, pull request
---

1. Run both tests (`.\run_tests.bat nopause` on Windows, or the commands from «Commands» in `CLAUDE.md`). Both must be green.
2. In `docs/progress.md`, «Сейчас»: one line on what is done, and remove your row from «Кто что делает». Not finished: write a handoff instead (what is done, what is left, which files).
3. In `docs/history.md`: a journal row with the price «Antigravity, <model>, <share of the limit>» (ask the user for the share), and each new decision with its reason.
4. Commit in English, push the branch, open a pull request into `main` with `gh pr create` and a Russian title and description: what changed and how to check it. Without `gh`: give the user the link from the `git push` output and the ready title and description to paste. Never merge.
5. End with the link to the pull request and the first message for the next chat, ready to copy as is. Take this user's next task in «Дальше» (none left — the other person's next one); skip a task that waits for an unfinished one. Pick the tool, the model and the thinking level by its label from «Метки задач» in `docs/how-we-work.md`. For the labels А and А− write in Russian:

   ```text
   Следующий чат: задача <номер> «<название>». Antigravity, <модель>, <уровень>.
   Новый чат внутри проекта Shift Time, вставь:
   /start <номер>
   Если /start нет в списке после «/»:
   Это проект Shift Time. Работай по AGENTS.md и .agents/workflows/start.md. Задача <номер>. Напиши план и жди моего «ок».
   ```

   For the labels О and О+:

   ```text
   Следующий чат: задача <номер> «<название>». Claude Code, Opus, усилия <high, xhigh или medium из карточки>.
   Вставь:
   Это проект Shift Time. Возьми задачу <номер> из «Дальше». Напиши план: что увидит игрок, что решишь сам, вопросы. Жди моего «ок».
   ```

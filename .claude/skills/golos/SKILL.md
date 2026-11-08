---
name: golos
description: Turns a long dictated (voice-to-text) message into a clean task before any work. It fixes misheard words by its glossary, restates the message as a goal, numbered jobs with done criteria, decisions already made and open questions, checks that nothing was lost or added, and waits for «ок» only when a decision or an ambiguity is involved. Use when a message looks dictated — long, run-on, with fillers like «что ещё», «вот», «короче», «получается», «ну», repeated phrases, odd words — or the user writes «голос» or /golos.
when_to_use: A long message that reads like speech-to-text, a message with words that don't fit the project (likely misheard), or «голос» / /golos.
argument-hint: "[текст диктовки]"
---

# Golos: dictated message → clean task

Speech-to-text loses punctuation, splits thoughts and garbles names. A task built on a misread message wastes a whole session, so restate first.

## 1. Clean

- Drop fillers, false starts and repeats; keep every request, constraint, decision, answer and question.
- Fix misheard words with `glossary.md` next to this file. A word that looks like a product or a term but is not in the glossary: put it in quotes under «Неясно» with your best guess — never replace it silently.
- Answers to earlier numbered questions («первый вопрос — …», «одиннадцатый — да, всему») map to those numbers.

## 2. Restate, in Russian

- **Цель:** one sentence.
- **Задачи:** numbered, in the order they depend on each other; each ends with «готово, когда …».
- **Решения из сообщения:** what the user decided or answered.
- **Неясно:** only what blocks the work, each with your default.

## 3. Check

- Walk the original sentence by sentence: each one maps to a task, a decision, a question, or is filler. Add nothing of your own.
- Anything dropped or merged: say so in one line.

## 4. Go or wait

- Wait for «ок» when the restatement holds a team decision, a change of the time rules or of what the player sees, or anything under «Неясно».
- Otherwise show the restatement in 3–5 lines and go on.
- Several different jobs: hand the task list to `razbor`.
- A misheard word you resolved: add a row to `glossary.md` in the same pull request.

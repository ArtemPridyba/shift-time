# Концепт-кадры

Скрипт строит два кадра одной комнаты в стиле Shift Time: обычное время и обратное. Это векторная основа для нейросети и образец для листа стиля, описанного в [docs/art-pipeline.md](../../docs/art-pipeline.md).

- `make_concept.py <папка>` — пишет `01_normal.svg` и `02_reverse.svg`. Зависимостей нет, только стандартная библиотека Python 3.
- `render.py <масштаб> <svg...>` — рисует PNG рядом с SVG через Playwright (Chromium). Масштаб 1 даёт 1920×1080, масштаб 2 — 3840×2160.

Из корня репозитория:

```
python3 tools/concept/make_concept.py docs/art/concept
python3 tools/concept/render.py 1 docs/art/concept/01_normal.svg docs/art/concept/02_reverse.svg
```

Готовые кадры лежат в [docs/art/concept/](../../docs/art/concept/). Цвета, формы и размеры в скрипте — это стартовые значения из [docs/setting.md](../../docs/setting.md): палитра в начале файла, персонаж в блоке «# 6. the player».

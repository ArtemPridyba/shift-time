# Gemini по уровням 02–07: фон комнаты и предметы (27.11.2026)

Образец — уровень 01: одна картинка Gemini на всю комнату (D131, D138, [gemini/raw/f1_room_v1.jpg](gemini/raw/f1_room_v1.jpg)), всё, что движется или чем пользуется героиня, — отдельные детали на зелёном поверх (Н-1…Н-14 в [gemini-kit.md](gemini-kit.md), режет `tools/cut_kit.py`). Здесь — то же для остальных уровней. Решения: D199 (как рисуем), D200 (в каком порядке).

## 0. Порядок для Бориса — одна страница

**Что нужно:** приложение Gemini (режим картинок, высокое качество, как для героини) и репозиторий на GitHub (файлы качать кнопкой «Download raw file»). Один уровень — один новый чат Gemini, все шаги уровня — в нём, чтобы стиль не уплыл.

1. **Схема.** Открыть раздел уровня ниже. Скачать из `docs/art/gemini/` его схему с номерами `levelNN_scheme.png` (уровень на один экран) или `levelNN_partK_scheme.png` (широкий уровень — по частям, у каждой части свой чат-шаг).
2. **Фон, запрос Ф.** Новый чат Gemini → приложить **только** схему → скопировать текст запроса «Ф-NN» из раздела уровня → отправить. Вторую картинку в этом сообщении не прикладывать: Gemini берёт расстановку у той, что красивее (урок Ф-1).
3. **Вид, запрос «стиль».** Если по местам, но беднее уровня 01 — в том же чате приложить `docs/art/gemini/raw/f1_room_v1.jpg` (фон уровня 01) и отправить запрос «стиль» (раздел 1).
4. **Размер.** Проверить размер файла: ширина не меньше 3840 px. Меньше — в том же чате запрос «4K» (раздел 1).
5. **Тёмная версия, запрос «Ф-т».** В том же чате, к готовой картинке — запрос «Ф-т» (раздел 1): та же комната, лампы погашены.
6. **Куда положить.** На GitHub: `docs/art/gemini/raw/` → Add file → Upload files, имена: `g03_room_v1.jpg` и `g03_room_dark_v1.jpg` (уровень 03, попытка 1; часть 2 широкого уровня — `g02_room_p2_v1.jpg`). Новая попытка — `v2`, старое не удалять. Проще — прислать обе картинки в чат Claude Code: он положит сам.
7. **Проверка.** Команда (или фраза «проверь фон 03» в чате Claude Code):
   `python3 tools/gemini_scheme.py level_03 --check docs/art/gemini/raw/g03_room_v1.jpg` (часть широкого уровня: в конце `--part 2`) → `build/backdrop/level_03_part1_check.jpg`. Годится, когда верх полов лежит на голубых линиях с точностью до полклетки, в оранжевых рамках нет ничего, кроме стены, проёмы — в пурпурных рамках, конусы света — под жёлтыми точками. Не годится — тот же запрос с поправкой «move the floor at … down by one cell» (раздел 1, «Если не то»).
8. **В игру.** Новый чат Claude Code (метка О): «Вставь фон уровня 03 из `docs/art/gemini/raw/g03_room_v1.jpg` и `_dark_v1.jpg`, как D131/D141 у уровня 01». Он скопирует картинки в `game/assets/art/backdrop/`, впишет `world.backdrop` уровня в `levels.json` (прямоугольник — из раздела уровня), строку в [log.md](log.md).
9. **Посмотреть в игре.** F5 → уровень 03 (или `tools/shots.sh level_03` — лист кадров). Смотреть: ноги героини на нарисованном полу, ничего не нарисовано дважды (картинка и код), конусы под лампами, Tab — вся комната.
10. **Предметы.** Когда фон утверждён — в том же чате Gemini запросы «П-NN-x» по одному. Приложить: утверждённый фон этого уровня (стиль) и снимок экрана из игры (F5, PrtSc), где этот предмет стоит. Положить как `p03_detector_v1.png` в `raw/`; вставит чат Claude Code: «вставь деталь П-03-д из `raw/p03_detector_v1.png`» (строка в `PIECES` `tools/cut_kit.py`, вид в `look.json`, строка в `log.md`). Посмотреть — F5.

**Порядок уровней (D200):** 03 → 06 и 07 (когда их PR влиты: сначала схема, раздел 3) → 05 (после сессии 2) → 02 и 04 — только если остаются в игре рядом с 06 и 07.

## 1. Общие запросы

**Схема.** Строит `tools/gemini_scheme.py` из данных уровня (тайлы и узлы сцены, `ceiling` и лампы в `levels.json`), поэтому совпадает с игрой. После перестройки уровня — `python3 tools/gemini_scheme.py level_NN` (номера предметов — в `ITEMS` скрипта, сверить с карточкой). Цвета: тёмно-коричневое — зал, темнее сверху — крыша, серое — кладка, голубая линия — верх пола, зелёная — спуск или ступени, пурпурное — пустой проём, оранжевая рамка — здесь игра рисует движущееся или предмет (на картинке только стена), синяя рамка — вода (игра рисует воду, на картинке сухой бассейн), жёлтая точка на нити — лампа, белый кружок — номер из списка запроса. Схема без номеров (`levelNN_clean.png`, `levelNN_partK_clean.png`) — запасная, если Gemini перерисует кружки с цифрами.

**Размер (D199).** Картинка — 16:9, не меньше двух пикселей картинки на пиксель комнаты (камера ×1,5, иначе фон мылит; детали набора режутся так же, `TEXEL = 2`). Для комнаты в 17 клеток высотой это 3840×2160. Gemini дал меньше — запрос «4K»; не помогло — Claude Code растянет кодом, это хуже, но лучше, чем 2000 px у уровня 01.

**Запрос «стиль»** (в том же чате, приложить `raw/f1_room_v1.jpg`):

```text
Make the painting style, materials and light like this second image, the first room of the same game, but do not move or resize anything in the first one. Keep every floor, wall, doorway and empty place exactly where it is.
```

**Запрос «4K»:**

```text
Give me this exact image again at 3840x2160 pixels. Change nothing: same layout, same details, same light.
```

**Запрос «Ф-т»** (тёмная версия, к утверждённой картинке):

```text
The same image, exactly the same, but every lamp is off: no light cones, no glow, the whole hall in deep darkness, details still faintly visible. Change nothing else.
```

**Если не то** — фразы для поправки в том же чате:
- сдвинул пол — «Keep the layout of the scheme: the floor at number N must be exactly on the cyan line, move it down/up by one cell»;
- нарисовал вещь в оранжевой рамке — «Remove the [platform/door/machine] at number N: there is only the back wall, the game draws it»;
- оставил кружки, цифры, линии — приложить `levelNN_clean.png` вместо схемы с номерами и повторить запрос Ф;
- нарисовал лампы — «Paint no lamps, only their warm light cones»;
- светится что-то кроме конусов или есть бирюзовый, фиолетовый — «Nothing glows except the lamp cones; no cyan, purple or magenta anywhere».

**Начало каждого запроса Ф** (уже вставлено в тексты уровней ниже, здесь — для справки):

```text
Repaint the attached scheme as a finished 2D game background for my side-view puzzle-platformer, 16:9, 3840x2160. Strict side view like the cross-section of a building, no perspective. The scheme is an exact layout: keep every shape in the same place and the same size. Grey is solid masonry: dark red brick walls and riveted steel floor plates on brick plinths with rust streaks. The cyan lines are the top faces of floors: the walking surface must be exactly on them, with a thin strip of the top face visible. Green lines are slopes or flights of worn brick steps: exactly along them. The dark brown area is the inside of a night factory hall: sooty red brick back wall, tall arched windows with broken panes, black cast-iron columns, iron trusses and hanging cables under the roof; the darker band at the top is the roof. Magenta rectangles are empty dark doorways in a flat steel frame, no door leaf. Orange outlines are where the game draws moving things: paint only the back wall there, nothing standing in front of it. Blue outlines are water basins: paint them dry and empty, concrete with dark wet stains and rust; the game draws the water. Small yellow dots on thin lines are lamp bulbs: paint no lamp, only a soft warm cone of light from each dot down the wall and floor, with dust in it, and deep shadows between the cones. Nothing else glows; no cyan, purple or magenta anywhere. The white circles with numbers are notes for you, listed below: leave no circles, numbers, text, lines or coloured marks in the picture. No people.
```

**Начало каждого запроса П** (детали; вставлено в тексты ниже):

```text
Same game, same style as the room you painted. Separate pieces on one 16:9 sheet, 3840x2160, flat pure green #00FF00 background with wide empty green gaps between pieces, no green inside a piece. Strict side view, flat even neutral light like a material swatch: no cast shadow, no light source, no glow, no vignette. Parts the game moves are drawn separately, each alone. Everything the player presses, carries or rides is worn signal-yellow paint over steel with scratches and rust at the edges; the rest is black cast iron, rusty steel, red brick, concrete. No cyan, purple or magenta; nothing glows. No text, letters, numbers or logos. Sizes are in cells: one cell is 64 game pixels; the heroine is 1.4 cells tall.
```

**Что уже есть в наборе — не рисовать заново:** гермодверь выхода и маяк (Н-6), лампы и провод (Н-8), заслонка с колесом (Н-5), лифт на зубчатой колонне и платформа на цепи (Н-14), кнопка, рычаг, ящик (Н-12), трубы и колена (Н-4, Н-9). Код ставит их сам; новый вид нужен, только если Борис скажет, что не подходит.

## 2. Уровни

### Уровень 03 «Нить» — один экран, 30×17 клеток

- **Схема:** [gemini/level03_scheme.png](gemini/level03_scheme.png), запасная [gemini/level03_clean.png](gemini/level03_clean.png). Уровень ещё меняется (сессия «03 v3»): перед запросом пересобрать схему (раздел 1).
- **Картинка:** одна, 3840×2160; в игре — `rect` `[0, 0, 30.22, 17]` (на 0,2 клетки шире комнаты справа).
- **Номера:** 1 вход; 2 лебёдка (барабан, цепь) — код; 3 трап — код; 4 яма, открыта вниз; 5 лифт — код (Н-14); 6 стальная антресоль — нарисовать; 7 горелка с факелом — код; 8 пожарный датчик и труба разбрызгивателей — код; 9 кнехт нити — код; 10 клеть в шахте — код; 11 выход на галерее.

**Запрос Ф-03** (приложить `level03_scheme.png`):

```text
Repaint the attached scheme as a finished 2D game background for my side-view puzzle-platformer, 16:9, 3840x2160. Strict side view like the cross-section of a building, no perspective. The scheme is an exact layout: keep every shape in the same place and the same size. Grey is solid masonry: dark red brick walls and riveted steel floor plates on brick plinths with rust streaks. The cyan lines are the top faces of floors: the walking surface must be exactly on them, with a thin strip of the top face visible. Green lines are slopes or flights of worn brick steps: exactly along them. The dark brown area is the inside of a night factory hall: sooty red brick back wall, tall arched windows with broken panes, black cast-iron columns, iron trusses and hanging cables under the roof; the darker band at the top is the roof. Magenta rectangles are empty dark doorways in a flat steel frame, no door leaf. Orange outlines are where the game draws moving things: paint only the back wall there, nothing standing in front of it. Blue outlines are water basins: paint them dry and empty, concrete with dark wet stains and rust; the game draws the water. Small yellow dots on thin lines are lamp bulbs: paint no lamp, only a soft warm cone of light from each dot down the wall and floor, with dust in it, and deep shadows between the cones. Nothing else glows; no cyan, purple or magenta anywhere. The white circles with numbers are notes for you, listed below: leave no circles, numbers, text, lines or coloured marks in the picture. No people.
This room: a tall workshop with a pit and a steel mezzanine.
1: the entrance, an empty doorway in the left wall.
2: here the game draws a winch drum; paint only a heavy iron bracket bolted to the wall behind it.
3: the game draws a steel bridge board that lies across the pit or stands upright; paint only the back wall.
4: a deep pit open to the bottom: dark brick shaft walls going down into blackness, no floor visible.
5: the game draws a lift; paint only the back wall.
6: a thin riveted steel mezzanine deck on the cyan line at 6, with a simple railing at its back edge and thin iron posts down to the lower floor in the background; the lower floor runs under it.
7, 8, 9: the game draws a gas burner, a fire detector with a sprinkler pipe and a bollard; paint only the back wall.
10: a narrow lift shaft: two dark iron guide rails on the back wall from the bottom to the top of the outline, nothing in front.
11: the exit doorway on the high gallery at the right.
```

**Детали 03** (каждая — отдельным сообщением, начало — «Начало запроса П» из раздела 1, ниже — только своё):

- **П-03-а. Лебёдка и блок** (2; блок на нити над ямой — 11,3; 2,6). Код: `objects/winch_ramp.gd`. Барабан ~1,2 клетки, крутится — отдельно.
  ```text
  Request P-03-a: a wall winch. (1) a heavy iron bracket with a gearbox, about 1.6 by 1.6 cells; (2) separately, its drum with a wound chain, seen from the side as a perfect circle, 1.2 cells across (the game turns it); (3) separately, a pulley block, a perfect grooved circle 0.6 cells across, with its hanger.
  ```
- **П-03-б. Трап** (3). Код: `objects/winch_ramp.gd`, длина 373 px (5,8 клетки). Героиня по нему ходит — жёлтая кромка (D65).
  ```text
  Request P-03-b: a hinged steel bridge board, 5.8 cells long and 0.3 cells thick, lying flat: riveted steel plate with a worn signal-yellow edge along its top, a heavy hinge at the left end, a ring for the chain at the right end.
  ```
- **П-03-в. Горелка и факел** (7). Код: `objects/torch.gd`. Пламя — код (частицы), не рисовать.
  ```text
  Request P-03-c: (1) a gas burner on a cast-iron stand, about 0.9 cells wide and 1.5 cells tall, with a small valve and a gas pipe going down, a holder hook for a torch, no flame; (2) separately, a hand torch: a short worn signal-yellow steel handle with a black wrapped head, 0.8 cells long, no flame.
  ```
- **П-03-г. Пожарный датчик и разбрызгиватели** (8). Код: `objects/sprinkler.gd`; зону обзора, мигание лампы и дождь рисует код.
  ```text
  Request P-03-d: (1) a fire detector: a red steel box 0.7 cells wide with a round lamp lens (unlit, dark glass) and a small sensor grille, mounted on a bracket; (2) a straight water pipe 3.5 cells long that runs under the ceiling with four sprinkler heads hanging from it, drawn so it can be cut at any length; (3) separately, one sprinkler head, larger.
  ```
- **П-03-д. Кнехт и клеть** (9, 10). Код: `objects/counterweight_cage.gd`, `objects/fire_rope.gd`. Нить — код. Клеть — героиня в ней едет: жёлтая.
  ```text
  Request P-03-e: (1) a short iron mooring bollard, 0.6 cells, bolted to a steel deck; (2) a lift cage 2 cells wide and 1.8 cells tall: a worn signal-yellow steel frame with mesh sides and an open front, a flat floor, a hanger on top for a rope; (3) separately, a big pulley, a perfect grooved circle 0.8 cells across.
  ```

### Уровень 02 «Поток» — широкий, 70×17 клеток, три части

Возможно, заменит его 06 «новый 02 на один экран» — тогда этот раздел не нужен (D200).

- **Схема:** вся комната [gemini/level02_scheme.png](gemini/level02_scheme.png); части [part1](gemini/level02_part1_scheme.png), [part2](gemini/level02_part2_scheme.png), [part3](gemini/level02_part3_scheme.png) (без номеров — `_clean`). Части перекрываются на 10 клеток.
- **Картинки:** три по 3840×2160; `rect` — `[0, 0, 30.22, 17]`, `[19.89, 0, 30.22, 17]`, `[39.78, 0, 30.22, 17]`. Игра пока кладёт на уровень одну картинку — несколько частей потребуют кода (D199).
- **Номера:** 1 вход; 2 кнопка 1 — набор (Н-12); 3 бассейн 1; 4 поплавок 1 — код; 5 шлюз — код; 6 бассейн 2; 7 штурвал вентиля на дне — код; 8 поплавок 2 — код; 9 труба с фланцем — код; 10 приямок; 11 дверь приямка — код; 12 кнопка 2 — набор; 13, 16 заслонки тоннеля — код; 14 насосная — код; 15 тоннель (вода); 17 выход.

**Запрос Ф-02, часть K** (приложить `level02_partK_scheme.png`; для частей 2 и 3 вторым — утверждённую предыдущую часть): «Начало запроса Ф» из раздела 1, затем:

```text
This room: a pump hall with water basins, one long hall painted in three parts. This picture is part K of 3. (For parts 2 and 3:) The second attached image is the part to the left of it, already approved: the left third of the new picture shows the same place as the right third of that one, so make the walls, windows, columns and light continue it seamlessly; use it only for this.
1: the entrance, an empty doorway in the left wall.
3, 6, 10: concrete water basins with steel edges, dry, wet stains on their walls, a tide line, rust.
4, 5, 7, 8, 9, 11, 13, 16: the game draws floats, a sluice gate, a valve wheel, a pipe and gates; paint only the back wall or the basin wall there.
12, 2: the game draws buttons; paint the floor as it is.
14: the game draws a pump room on the slab: paint only a dirty tiled back wall with cable trays.
15: a low flooded tunnel under a rock-and-concrete slab, its slopes going down and up along the green lines, dark wet walls.
17: the exit doorway at the right.
```

**Детали 02:**

- **П-02-а. Поплавки** (4, 8). Код: `objects/water_float.gd`; ширина 3 клетки. Героиня на них стоит — жёлтые.
  ```text
  Request P-02-a: a floating pontoon 3 cells long and 0.5 cells tall: a riveted steel box with a worn signal-yellow deck and rubber fenders at its ends, seen from the side, its lower part dark with water.
  ```
- **П-02-б. Шлюз, дверь приямка, заслонки** (5, 11, 13, 16). Код: `objects/door.gd`, `objects/water_gate.gd`. Шлюз 0,5×1, дверь приямка 1×2, заслонки 1×2 клетки.
  ```text
  Request P-02-b: three sliding steel gates, each a separate piece: (1) a small sluice plate 0.5 by 1 cell with a rubber seal; (2) a door 1 by 2 cells of riveted steel with a wheel lock, worn; (3) a heavy flood gate 1 by 2 cells with vertical ribs that slides into the floor, rusty, a seal along its top edge.
  ```
- **П-02-в. Штурвал и труба** (7, 9). Код: `objects/burst_pipe.gd`, вентиль — `objects/pipe_plug.gd`. Штурвал героиня носит — жёлтый.
  ```text
  Request P-02-c: (1) a valve wheel with four spokes and a short stem, worn signal-yellow, a perfect circle 0.8 cells across seen straight on; (2) a thick riveted water pipe that can be cut at any length, a 90-degree elbow, and an open pipe flange with bolt holes; (3) a round pressure gauge 0.5 cells across with a red zone on the dial and, separately, its needle.
  ```
- **П-02-г. Насосная** (14). Код: `objects/pump_room.gd`, `objects/fault_fx.gd`. Искры, дым, мигание ламп — код.
  ```text
  Request P-02-d: a pump room set, separate pieces: (1) a wall control panel 1 by 1.5 cells with a green and a red lamp, both unlit, a big switch and gauges; (2) an electric motor 2 cells long on a base, its cooling fan separately as a perfect circle 0.8 cells across (the game spins it); (3) a centrifugal pump 1.5 cells with pipe flanges; (4) a fat cable that can be cut at any length.
  ```

### Уровень 04 «Плиты» — широкий, 60×17 клеток, три части

Возможно, заменит его 07 «новый 04 на один экран» (D200). В уровне ещё нет `world` (ламп, кладки «Ночного цеха»): на схеме нет жёлтых точек. Фон рисовать только после того, как уровень соберут в «Ночном цехе» с лампами.

- **Схема:** [gemini/level04_scheme.png](gemini/level04_scheme.png); части `level04_part1…3_scheme.png`; `rect` — `[0, 0, 30.22, 17]`, `[14.89, 0, 30.22, 17]`, `[29.78, 0, 30.22, 17]`.
- **Номера:** 1 вход; 2, 4 плиты A и B — код; 3, 5 заслонки A и B — набор (Н-5); 6, 7 плиты 2 и 1 над стрелками — код; 8 рельсы, стрелки, тупики — код; 9 линия подъёмника — код; 10 вагонетка на горке — код; 11 тоннель и станция; 12 выход.

**Запрос Ф-04, часть K** — как у 02, свои строки:

```text
This room: an ore line in a factory: a low corridor and open walkways above, a deep pit with rail trestles below. This picture is part K of 3. (Continuity line as for level 02.)
1: the entrance, an empty doorway in the left wall.
2, 3, 4, 5, 6, 7: the game draws pressure plates and gates; paint the floor and the wall as they are.
8: the game draws rails on trestles over the pit; paint only the pit: dark brick walls going down into blackness, no floor.
9, 10: the game draws a hoist line and a minecart; paint only the back wall and the dark shaft at 10.
11: a low brick tunnel with a buffer stop at its end, darker than the hall.
12: the exit doorway at the left of the tunnel.
```

**Детали 04:**

- **П-04-а. Плиты** (2, 4, 6, 7). Код: `objects/time_plate.gd`. Плита 3 клетки. Нажимается — жёлтая; стрелку ▼▲ рисует код.
  ```text
  Request P-04-a: a pressure plate set into a floor, 3 cells long: (1) the steel frame in the floor; (2) separately, the plate itself, worn signal-yellow with a ribbed top, 0.25 cells thick (the game moves it down and up); (3) a vertical pull rod with a joint, cut at any length.
  ```
- **П-04-б. Рельсы и стрелки** (8). Код: `objects/rails.gd`, `objects/rail_switch.gd`.
  ```text
  Request P-04-b: a mine rail set, seen exactly from the side: (1) a straight rail on sleepers that can be cut at any length; (2) a riveted iron trestle under the rail, 1 cell wide, 2 cells tall, that can be stacked; (3) a rail switch lever on a small base, worn signal-yellow, its handle separately (the game turns it); (4) a buffer stop at the end of a rail, with a yellow-and-black striped beam.
  ```
- **П-04-в. Вагонетка и подъёмник** (9, 10). Код: `objects/minecart.gd`. На вагонетке — такой же прибор, как у героини: его свет — исключение из D60, решает Борис (карточка 04); здесь прибор без свечения, свет добавит код.
  ```text
  Request P-04-c: (1) a minecart 2.5 cells long and 1.2 cells tall: a riveted steel tub with a worn signal-yellow rim, a small dark time device bolted to its side with an unlit glass dial, no glow; (2) separately, its wheel, a perfect circle 0.5 cells across; (3) a hoist hook on a short chain; (4) a hoist trolley on an overhead beam, its two wheels separately.
  ```

### Уровень 05 «Кран» — широкий, 66×22 клетки, две части

Сессия 2 уровня идёт сейчас (кран ниже, лестница из обломков, противовес, дверь у рельса, D176): **дождаться её PR**, пересобрать схему и сверить номера с карточкой.

- **Схема:** [gemini/level05_scheme.png](gemini/level05_scheme.png); части `level05_part1_scheme.png`, `level05_part2_scheme.png`; `rect` — `[0, 0, 39.11, 22]`, `[26.89, 0, 39.11, 22]`. Комната в 22 клетки высотой: 4K даёт 1,5 пикселя на пиксель комнаты, а не 2 (D199) — комната тёмная (`darkness`), это терпимо.
- **Номера:** 1 вход; 2 три плиты на цепях — код; 3 пеньки в яме; 4 уступ крана на столбе; 5 кран на наклонном рельсе — код; 6 потолок, который рушится в акте 3 — код; 7 падающие куски и стена на цепях — код; 8 противовес и площадка — код; 9 выход.

**Запрос Ф-05, часть K** — как у 02, свои строки:

```text
This room: a collapsing crane hall over a bottomless pit, darker than the others. This picture is part K of 2. (Continuity line as for level 02.)
1: the entrance, an empty doorway in the left wall.
2, 5, 6, 7, 8: the game draws hanging slabs, a crane on its rail, falling ceiling chunks and a counterweight; paint only the back wall, with a ragged hole in the roof above 6.
3: concrete stubs standing in the pit, their tops on the cyan lines, the pit going down into blackness.
4: a brick ledge on a tall brick pillar.
9: the exit doorway on the high ledge at the right.
```

**Детали 05:**

- **П-05-а. Кран и рельс** (5). Код: `objects/collapse.gd`. Кран 3 клетки; героиня в нём едет — жёлтая кромка.
  ```text
  Request P-05-a: (1) an overhead crane carriage 3 cells long: a riveted cab-less platform with a worn signal-yellow deck edge and railing, hung from a trolley; (2) separately, the trolley's two wheels, perfect circles 0.4 cells across; (3) a heavy I-beam rail that can be cut at any length.
  ```
- **П-05-б. Плиты, куски потолка, обломки** (2, 6, 7). Код: `objects/collapse.gd`; ломает и роняет код.
  ```text
  Request P-05-b: (1) three concrete slabs with exposed rebar, 3 to 4 cells long and 0.8 cells thick, each with two lifting eyes for chains; (2) six ceiling chunks of brick and concrete with ragged edges, from 0.6 to 4.6 cells wide; (3) a chain that can be cut at any length; (4) twelve small rubble pieces.
  ```
- **П-05-в. Противовес** (8). Код: `objects/collapse.gd` (`follow`); карточка 05: плиту сделать тяжелее и заметнее.
  ```text
  Request P-05-c: (1) a counterweight: a heavy dark steel billet 2 cells wide with a big hook on top; (2) a lift platform 2 cells wide, worn signal-yellow deck, a hanger for a chain; (3) separately, a pulley block, a perfect grooved circle 0.7 cells across.
  ```

### Уровень 06 «новый 02 на один экран» — заготовка

Схемы в открытых PR на 27.11 нет. Когда PR уровня влит: добавить уровень в `ITEMS` `tools/gemini_scheme.py` (номера — по его карточке `docs/levels/06.md`), `python3 tools/gemini_scheme.py level_06`, дописать сюда номера и запрос Ф-06 по образцу 03 (одна картинка, `rect` печатает скрипт). Детали — брать из 02: поплавки (П-02-а), шлюз и заслонки (П-02-б), штурвал и труба (П-02-в), насосная (П-02-г) — какие останутся в уровне; кнопка — набор.

### Уровень 07 «новый 04 на один экран» — заготовка

Так же, как 06: схема — после PR, `python3 tools/gemini_scheme.py level_07`. Детали — из 04: плиты (П-04-а), рельсы и стрелки (П-04-б), вагонетка и подъёмник (П-04-в); заслонки — набор (Н-5).

## 3. Что делает Claude Code, когда картинка готова

- Проверка: `python3 tools/gemini_scheme.py level_NN --check raw/…jpg [--part K]`.
- Фон на один экран — как у 01 (D141): `world.backdrop` уровня (`lit`, `dark`, `rect`, `cone`, `painted`) в `levels.json`; узлы, чьё неподвижное уже на картинке, — в `painted`.
- Фон из частей — сначала код: `world.backdrop` со списком картинок (каждая со своим `rect`), сжатие текстур для веба (несжатые 4K-картинки: 33 МБ видеопамяти каждая, у 02 их было бы шесть). Пока кода нет — части не вставлять (D199).
- Деталь — строка в `PIECES` `tools/cut_kit.py` (`TEXEL = 2`), путь в `look.json`, строка в `log.md`; объект рисует картинку вместо кода.

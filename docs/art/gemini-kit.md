# Набор «Ночной цех» у Gemini — бриф и запросы (22.11.2026)

Заменяет запросы Н-1…Н-8 из [level01-look.md](level01-look.md) (раздел 4). Борис 22.11: Gemini рисует красиво, но не то, что нужно, — он не знает игру. Короткий запрос без объяснения бесполезен. Поэтому здесь сначала бриф: что за игра, как устроен кадр, как игра режет и складывает детали, какой должен быть свет. Потом эталонный кадр, перерисованный из настоящего снимка игры. Детали рисуются уже по нему, в одном стиле.

## 1. Как работать

1. **Новый чат в приложении Gemini** (режим картинок, «высокий», как для героини). Весь набор делаем в одном чате, чтобы стиль не уплыл.
2. **Первое сообщение — бриф** (раздел 2) и три картинки:
   - [`docs/art/gemini/ref_close.jpg`](gemini/ref_close.jpg) — игра сейчас, так видит игрок (камера ×1,5, D114);
   - [`docs/art/gemini/ref_room.jpg`](gemini/ref_room.jpg) — вся первая комната издалека;
   - [`docs/art/heroine/character_ref.jpg`](heroine/character_ref.jpg) — героиня, это образец кисти;
   - снимки `ref_close` и `ref_room` пересняты 22.11 после уменьшения мира (D112): размеры деталей рядом с героиней — в [scale.md](scale.md);
   - по желанию — снимок экрана макета «Ночной цех» (<https://claude.ai/artifact/4oXXyUdMz88da8hk4ozYFC>), образец настроения.

   В конце брифа Gemini должен пересказать его в пяти строках. Если пересказ мимо — поправить словами до того, как он начнёт рисовать.
3. **Эталонный кадр** — Э-1, потом Э-2 (раздел 3). Переделывать, пока не понравится. Лучший сохранить, он становится образцом для всех деталей.
4. **Детали** — Н-1…Н-12 (раздел 4), одна деталь или один лист на сообщение. К каждому запросу снова прикладывать утверждённый эталонный кадр: в длинном чате Gemini забывает картинки.
5. **Проверка** каждой картинки — раздел 5. Там же фразы, которыми править.
6. **Куда класть.** Картинки как есть, без чистки: в чат Claude Code или в `docs/art/gemini/raw/` с именем по номеру запроса (`e1_close.png`, `n1_brick.png`, `n2a_floor_top.png`). Зелёный фон, бесшовность и подгонку к сетке делает код в Д3, руками чистить не нужно. Строку в [log.md](log.md) допишет чат, который кладёт файл в игру. В игре деталь встаёт одной строкой: путь к картинке в `world.textures` `game/data/look.json` (пусто — заглушка кодом, D107).

Порядок: бриф → Э-1 → Э-2 → для Д3 стена, пол, окно, железо, станки, обломки, пятна (Н-1…Н-4, Н-9…Н-11) → для Д4 заслонка, гермодверь, платформы, лампы и часы, жёлтые вещи (Н-5…Н-8, Н-12).

## 2. Бриф — первое сообщение

```text
I am making a 2D game and I need you as the concept artist and asset painter for its environment. Please read all of this before you draw anything. Attached: (1) a screenshot of the game as it is now, with grey placeholder blocks, at the normal camera distance; (2) the whole first room seen from far; (3) the heroine, already painted by you: this is the painting style to match.

THE GAME. "Shift Time" is a 2D side-view puzzle-platformer that runs in a web browser. A young crane operator walks through an old factory at night. On her forearm is a gauntlet that turns back the time of the world around her: doors, moving platforms, water, lamps. The player walks, jumps and pulls levers; while she holds a key, the world plays backwards around her.

THE CAMERA. Strict side view, like the cross-section of a building or a stage set: we look straight at the back wall of a factory hall. No vanishing point, no 3/4 view, no isometric view. Floors and platforms are horizontal slabs: we see their front face and a thin strip of their top surface, as if the camera were only a little above them (about 10 degrees). Everything stands on a grid: one cell is 64 game pixels; the heroine is 92 pixels tall (about 1.5 cells); a door is 2 cells tall. The camera shows about 20 cells across and 11 cells high, so on a 1920x1080 screen one cell is about 96 pixels and the heroine is about 140 pixels tall. A room is up to three screens wide and the camera follows her.

THE LAYERS, from back to front:
1. The night sky, seen only through the windows (the game draws it).
2. The back wall of the hall: sooty red brick, tall arched windows with broken panes, black cast-iron columns, roof trusses, a crane beam. It is a backdrop: nobody walks on it.
3. Background machines standing in front of the wall: tanks, hoppers, catwalks, pipes, a conveyor. Darker, lower contrast, less detail. They must never look like something the player could stand on or use.
4. The play layer: floors, ledges, moving platforms, doors, levers, the heroine. Clear shapes, more contrast, edges nearly straight (a pixel or two of wear, never jagged).
5. Grime laid on top: cracks, soot, rust streaks, rubble, broken glass.

HOW THE GAME USES YOUR PICTURES. Every piece is a separate image. The game cuts it out of its background, scales it to the grid and places it; walls and floors repeat side by side as tiles. The game makes all the light: the room is dark, and small warm lamps light only the things the player needs. So every piece must be painted in flat, even, neutral light, like a material swatch: no shadow cast by the object, no light source, no glow, no dark corners or vignette, no fog. Shading only where the form itself turns (a round pipe, a rivet head). Painted-in lighting breaks as soon as the game lights the piece. The background behind an isolated piece is flat pure green #00FF00, perfectly even, so it can be keyed out; holes and empty window panes inside a piece are the same flat green. Never use that green inside a piece.

THE LOOK: "Night factory". An old factory of red brick and black cast iron in a near future between old mechanics and new technology: rust, tired warehouse and laboratory spaces, a few working new machines among them. Serious and atmospheric, not cartoonish, yet every shape reads at a glance. Materials: sooty red-brown brick with grey mortar; near-black cast iron with cold grey worn edges and rivets; grey-ochre concrete; orange-brown rust; tin; old wood; rubber. Everything the player moves or presses (levers, buttons, crates, the edge of a moving platform) is worn signal-yellow paint over steel. The world is warm (yellow things, orange lamps); time is cold purple, and purple belongs only to the heroine's gauntlet: never use purple, magenta or cyan in the environment, and nothing in the environment glows.

THE SCALE. Everything is sized to the heroine, as a real factory would be next to a real woman: a door is a little taller than her, a moving platform is one and a half of her heights wide, a step is up to her waist, a lever reaches her chest, one brick is about half her head wide. Never draw the world giant next to her.

THE BRUSH. Hand-painted digital art in the same style as the attached heroine: painterly but clean, soft texture, medium detail that still reads when the piece is small. No black outlines. Not pixel art, not a photo, not a 3D render.

NEVER: perspective or isometric views; a whole scene when I ask for one piece; several versions when I ask for one (I will ask for versions myself); text, letters, numbers or logos; people or characters (except the heroine when I say so); anything recognisable from existing games or films (nothing from Portal or Half-Life). Hex codes are colour values only; never write them as text in a picture.

Before you draw anything, answer in five short lines: what the camera is, what the layers are, how the game will use the pieces, what the light must be, and which colours are forbidden. Then wait for my first request.
```

## 3. Эталонный кадр

Это картина того, что увидит игрок: здесь свет ламп рисуется, в деталях потом — нет. Кадр утверждает Борис, он становится образцом стиля для деталей и для Д3. Детали не обязаны быть вырезаны из него точь-в-точь.

**Э-1. Крупный план** — приложить `ref_close.jpg`.

```text
Request E-1: the reference frame. Repaint the attached close-view screenshot as the finished game. Keep the camera and the layout exactly: every grey block stays a solid thing of the same size in the same place, and the heroine stays the same size in the same place. In this one picture the game's light is part of the painting, because it shows what the player will see.
What each placeholder is:
- the grey blocks with grid lines along the bottom: the floor, a slab of black cast-iron floor plates on dark brick masonry; her boots stand on the middle of the plates' top strip;
- the column of grey blocks hanging from the top: a brick partition wall coming down from the ceiling;
- the narrow bar under it with a light stripe: a heavy riveted steel shutter that slides down into the floor along a toothed rack between two gears; the dark ring beside it is the hub of its handwheel;
- the dark rectangle with a thin bright outline on the left: the doorway she came in through, a dark opening in the brick wall with a worn steel frame (the bright outline is only a placeholder, not a colour to use);
- the column of grey blocks along the left edge: the side wall of the hall, brick;
- on the right the floor drops in two short steps into a dark pit: the floor broken away, a few fallen bricks on the steps;
- the empty grey: the back wall of the hall behind everything: red brick, one tall arched window with broken panes and a dark night sky behind, a black cast-iron column, a background machine in deep shadow.
Light: the hall is dark, it is night. A warm orange enamel dish lamp hangs above the heroine and another above the shutter; each makes a soft island of light on the floor and the wall behind; between the islands it is dark, but the edge of the floor still reads faintly. Dust floats in the lamp light. No purple anywhere except the small light of her gauntlet. 16:9, 1920x1080.
```

**Э-2. Вся комната** — приложить `ref_room.jpg` и удачный Э-1.

```text
Request E-2: the whole first room. Repaint the attached far view of the room in the same style as the frame you just painted (attached too). Keep the layout exactly.
What each placeholder is:
- the dark rectangle on the left: the doorway she came in through;
- the column of blocks hanging from the top and the bar under it: the brick partition and the steel shutter from the first frame;
- the floor stepping down into a pit: the floor broken away, with fallen bricks on the steps;
- the two thin bars with a light stripe: moving steel platforms with a worn signal-yellow top edge; the lower one rides left and right on a chain, the upper one rides up and down a toothed column;
- the big block on the right: a high concrete ledge;
- the square with the arrow: the exit, a heavy hermetic steel door with rounded corners and a handwheel, set in the back wall, a red beacon lamp above it;
- the empty grey: the back wall: red brick, three or four tall arched windows with a night sky, black cast-iron columns, roof trusses along the top, a crane beam, background machines in deep shadow.
Light: five warm islands of light from hanging lamps: over the doorway, over the shutter, over each platform, over the exit. Everything else dark, the floor edges still faintly readable. 16:9.
```

**Э-2б. Если Gemini переставил уровень** (22.11, первый Э-2 — [gemini/raw/e2_room_v1.jpg](gemini/raw/e2_room_v1.jpg): ступени начались прямо под заслонкой, заслонка в широкой башне, платформы и уступ на других высотах). Для вида это не помеха (D109): детали игра всё равно ставит по своей сетке. Но если нужен кадр, совпадающий с уровнем, — словами расстановку не объяснить, генератор её не держит. Работает другое: дать ему схему, где всё уже стоит на месте, и попросить её **перерисовать**, а не «посмотреть». Схема уровня 01 — [gemini/layout_room.png](gemini/layout_room.png) (цветные зоны с номерами, 16:9). Её строит `tools/layout_guide.py` из данных уровня (карта сборщика, `world` в `levels.json`): после правок уровня — `python3 tools/layout_guide.py level_01 docs/art/gemini/layout_room.png`; номера для другого уровня — в `LABELS` скрипта. В новом сообщении первой картинкой — схема, второй — удачный кадр Gemini как образец вида.

```text
Request E-2b: repaint the first picture, a layout diagram of the room, as the finished game, in the style of the second picture (your painting). The diagram is exact: keep every shape where it is and the same size; change only how things look, never where they are. What the flat colours and numbers mean:
- brown: the back wall of sooty red brick; dark blue arches: tall arched windows with a night sky;
- dark grey: solid ground, black cast-iron floor slabs on dark masonry; the thin light line on top of each slab is its walkable top surface, keep it that thin; the dark bands above and below the room are the roof and the foundations, in darkness;
- 1, black: the doorway she came in through;
- 2, the narrow red column: a brick partition hanging from the ceiling, only as wide as the heroine; the yellow-black bar under it: a heavy steel shutter, as narrow as the bar;
- 3: a flat floor between the shutter and the steps, nothing on it, no stairs here;
- 4: the floor broken away in two short steps down into the pit, a few fallen bricks on them; the steps begin only at the right end of the flat floor 3, under the left end of platform 5, not at the shutter;
- 5 and 6, yellow bars: two thin moving steel platforms with a worn signal-yellow top edge;
- 7: the floor of the pit;
- 8, grey with a red dot: the exit, a heavy hermetic door with rounded corners, a red beacon lamp above it;
- 9, beige: a high concrete ledge;
- orange dots on black lines: enamel lamps hanging on cables, warm light pooling below each;
- purple: the heroine, for scale.
The numbers and the flat colours are notes for you: do not paint them. 16:9.
```

**Правки по месту** (22.11, второй Э-2: Gemini не перерисовал схему, а поправил свою прошлую картинку — ступени остались сразу за заслонкой, заслонка стала плоской полосатой панелью). Уроки:

- Картинку с неверной расстановкой не прикладывать «как образец стиля»: Gemini берёт её за основу и копирует расстановку. Стиль он помнит по чату; если нужен образец — только крупный план (Э-1) или вырезка одной вещи.
- Одна правка — одно сообщение. Мерить по тому, что на картинке («до левого края жёлтой платформы»), а не числами.
- Как должна выглядеть вещь — показать вырезкой из удачной картинки: заслонка из Э-1 — [gemini/ref_shutter.jpg](gemini/ref_shutter.jpg).

Правка 1 — заслонка: приложить последнюю картинку и `ref_shutter.jpg`.

```text
Edit the first picture and keep everything else exactly as it is: replace the striped panel under the brick column with the heavy steel shutter from the second picture: a thick riveted dark-steel slab with bolted plates, a toothed rack along its left side, the handwheel and two gears beside it, worn yellow fittings. Keep its position and its width. No hazard stripes on its face.
```

Правка 2 — пол между заслонкой и ступенями: приложить то, что вышло после правки 1.

```text
Edit this picture and keep everything else exactly as it is. The flat floor where the heroine stands continues to the right, past the shutter, until it reaches the lower yellow platform: the left end of that platform touches the end of this floor at the same height, like a bridge leaving it. Only there, under the left end of the platform, the floor breaks away in a few short, steep steps down to the pit floor. Between the shutter and the platform there are no steps and no rubble, only flat floor.
```

Не выходит за две-три попытки — оставить как есть: для игры кадр нужен как образец вида (D109), детали Н-1…Н-12 важнее.

## 4. Детали

У каждой детали: зачем она игре (по-русски) и запрос. Сохранять картинки как есть, в самом большом размере.

### Н-1. Кирпичная стена

Задняя стена всего цеха — повторяется плиткой на три экрана. Шов на стыке поправит код, но чем ровнее ряды, тем лучше.

```text
Request N-1: brick wall tile. Take the brick wall of the reference frame and paint it as a flat square swatch, 1:1, filling the whole picture edge to edge (no green, no border). Exactly flat front view, flat even light, no shadows, no vignette. The game repeats it across the whole hall, so the left edge must continue the right edge and the top must continue the bottom. Straight, even courses of sooty red-brown bricks in running bond with grey mortar: about 4 bricks across and 10 courses from top to bottom. A few bricks a little darker or lighter, small chips; no brick that stands out; no cracks, stains or soot (those come as separate pieces).
```

**Н-1б.** Тот же запрос, последнее предложение заменить: «Patches of old whitewashed plaster cover parts of the wall and flake off, brick showing through; the plaster is grey-beige and dirty.» Вариант стены, чтобы стена не была однообразной.

### Н-2. Пол, земля, уступ

Твёрдое в игре — блоки по сетке. Код собирает их сам: верхняя грань (на ней стоит героиня), передняя кромка, заливка массы под ней, боковая кромка (край уступа, стенки ямы). Углы код сложит из кромок.

**Толщину грани у Gemini не просить** (22.11, первый эталонный кадр): он рисует пол широкой дорогой в перспективе и не слушает «тоньше» — генераторы плохо держат пропорции. Поэтому верх пола он рисует плоско, строго сверху, как карту, а код сжимает эту картинку в тонкую полоску (16 px в игре) — так и получается лёгкий взгляд сверху. Перспективу Gemini не рисует нигде. Как это работает — картинка [gemini/flat_floor_demo.png](gemini/flat_floor_demo.png): плоская текстура, сжатая полоска, она же в игре под ногами. При сжатии мелкий рисунок (рифление, мелкие царапины) сливается в ровный серый; остаётся только крупное: тёмные швы между плитами, большие пятна ржавчины и потёртости — поэтому просим плиты крупно и контрастно.

```text
Request N-2a: the top surface of the floor, seen from straight above. A square swatch, 1:1, filling the whole picture edge to edge: worn black cast-iron checker floor plates two to four big plates across the picture, bold dark seams between them, big rivets, large rust patches and worn bright patches, strong contrast (fine patterns like small tread or thin scratches disappear when the game squeezes the picture), seen exactly from above like a map or a floor plan: no perspective at all, no horizon, no wall, flat even light. The left edge continues the right edge. The game squeezes this picture into a thin strip under the heroine's feet; that squeeze makes the look from above, so do not draw any perspective yourself.
```

```text
Request N-2b: the front edge of the floor, seen straight from the front. A long horizontal strip, 8:1, filling the whole picture: the riveted iron angle along the front edge of the floor plates, worn and scratched, a few short rust streaks; none of the top surface is visible. Flat even light. The left end continues the right end.
```

```text
Request N-2c: the solid ground under the floor. A square swatch, 1:1, filling the whole picture: old dark masonry of the factory foundation, brick and rough concrete, darker and lower in contrast than the back wall, little detail; it is mass, not a feature. Flat even light; the left edge continues the right edge, the top continues the bottom.
```

```text
Request N-2d: the side edge of a ledge. A tall vertical strip, 1:4. Left of the ledge: flat green. The vertical face of the ledge's edge: a riveted iron angle along the edge, dark masonry to its right down to the right edge of the picture. Flat even light; the top end continues the bottom end.
```

**Н-2e.** Бетонный уступ выхода: запросы N-2a и N-2b ещё раз, в каждом заменить материал: «worn grey-ochre concrete with a steel edge band and chipped corners» вместо чугунных плит.

### Н-3. Окно

Окна на задней стене. Небо и свет за окном рисует игра, поэтому пустые стёкла — зелёные.

```text
Request N-3: a factory window. A tall arched factory window seen from inside the hall, exactly flat front view, flat even light, on flat green, about 1:2. A black cast-iron frame with 3 x 6 panes, a brick arch on top and a stone sill below, a little brick around the arch. Most panes are broken, sharp shards left in the frame; a few panes are whole but dirty, opaque grey-brown. Where a pane is missing, flat green #00FF00: the game draws the night sky there. Only the window, nothing else.
```

### Н-4. Колонна, фермы, балка крана

Чугунный каркас цеха на задней стене. Колонна повторяется вверх, ферма — вбок.

```text
Request N-4: the iron of the hall. Three separate pieces on one sheet with wide empty green gaps, no piece touching another; flat front view, flat even light: (a) a vertical piece of a black cast-iron I-beam column with rivets and bolted plates, cut straight at the top and bottom so it repeats upwards; (b) a horizontal piece of a roof truss, two flanges and a diagonal lattice, cut straight at both ends so it repeats sideways; (c) a crane beam with a small trolley and a hook on a chain hanging from it.
```

### Н-5. Заслонка-преграда

Дверь в середине уровня 01: сама закрывается, опускаясь в пол. Детали двигает код: створка едет, штурвал и шестерни крутятся. Поэтому всё отдельно.

```text
Request N-5: the shutter. Separate pieces on one sheet with wide empty green gaps, flat front view, flat even light: (a) a heavy riveted steel shutter that blocks a passage: a tall narrow thick slab, about 1:4 (width to height), dark steel, worn yellow-and-black hazard stripes along its bottom edge, bolts, two locking bars, a toothed rack along its left side; (b) a handwheel, round with spokes, seen straight on; (c) two gears of different sizes, seen straight on, with clean even teeth (the game spins them); (d) a locking bolt. The shutter slides down into the floor in the game, the wheel and gears turn.
```

### Н-6. Гермодверь выхода и лестница за ней

Выход уровня. Створка отходит и уезжает вправо по рельсу, штурвал крутится. Из проёма — холодный свет лестницы, по нему понятно, куда идти.

```text
Request N-6: the exit door. Separate pieces on one sheet with wide empty green gaps, flat front view, flat even light: (a) the door frame as it sits in a brick wall: a thick riveted steel frame with rounded corners, about 1:1.3 (width to height), the opening inside it flat green; (b) the door leaf that fits that frame: thick dark steel with rounded corners, rivets, a worn hazard stripe at the bottom, a small wired-glass window, a hub in the middle; (c) the handwheel alone, seen straight on; (d) a steel rail with two rollers on which the leaf hangs and rides to the right; (e) a red rotating beacon lamp in a wire cage, switched off.
```

```text
Request N-6b: behind the exit door. The view through the open exit doorway: a narrow concrete staircase going up and away, iron handrails, cold white light falling from the top of the stairs, the lower steps in shadow. Here painted light is welcome: this is a distant scene inside the doorway and the only place in the room where cold light comes from. Fill the whole picture, 1:1.3. No purple or cyan; the light is white, slightly cold.
```

### Н-7. Платформы

Две подвижные платформы уровня 01: одна ездит вбок на цепи, другая — вверх-вниз по зубчатой колонне. В игре платформа — 3 клетки на полклетки (6:1).

```text
Request N-7: moving platforms. Separate pieces on one sheet with wide empty green gaps, flat even light: (a) a moving steel platform, a long flat slab, 6:1, its top surface seen from just a little above as a thin strip, the front face riveted dark steel, a worn signal-yellow edge along the top so the player sees where to land, a small carriage with rollers under its middle; (b) a vertical segment of a toothed column, the rack a platform climbs, cut straight to repeat upwards; (c) a horizontal segment of a heavy chain, cut to repeat sideways.
```

### Н-8. Лампы и часы

Свет ламп и стрелки часов делает игра, поэтому лампы рисуются выключенными, часы — без стрелок.

```text
Request N-8: lamps and the clock. Separate pieces on one sheet with wide empty green gaps, flat front view, flat even light, nothing lit and nothing glowing: (a) an enamel dish lamp on a short cable, dark green-grey enamel outside, white inside, the bulb pale clear glass, switched off; (b) a caged wall lamp with a glass globe, switched off; (c) a big round factory wall clock with a cast-iron rim and a cream face with plain tick marks, no numbers, without hands; (d) the clock's two hands alone, straight, pointing up.
```

### Н-9. Станки фона

Стоят перед задней стеной в темноте. Главное — не выглядеть местом, куда можно прыгнуть: игрок не должен путать их с платформами.

```text
Request N-9: background machines. Separate pieces on one sheet with wide empty green gaps, flat front view, flat even light: a tall riveted tank with a ladder; a hopper on legs; a catwalk segment with railings; a conveyor segment; pipes with flanges and valves (a straight piece, an elbow, a T). Darker and lower in contrast than the play layer, less detail, muted colours: they stand in the dark behind everything the player uses. No flat top that looks like a place to stand: tops are rounded, slanted or covered with pipes. No yellow.
```

### Н-10. Обломки

Лежат на полу поверх: груда кирпича на ступенях ямы, упавшая балка, штукатурка, стекло.

```text
Request N-10: rubble. Separate pieces on one sheet with wide empty green gaps, seen from the side with the same slight view from above, flat even light, no shadow under them (the game adds it): a heap of fallen bricks, wide and low, about 5:1; a fallen steel I-beam, long and thin; a lump of fallen plaster; broken glass shards lying on the floor.
```

### Н-11. Пятна — маски

Сажа, потёки и трещины мягкие по краю — с зелёного фона их чисто не вырезать. Поэтому они рисуются как маски: белое — пятно, чёрное — ничего; цвет даёт игра.

```text
Request N-11: stains as masks. A sheet of separate stains as greyscale masks on a pure black background, wide black gaps between them: pure white means full stain, black means nothing, soft grey edges. No colour at all: the game paints them. Soot rising above a window (wide and soft); rust streaks running down from an edge (vertical, thin and thick, of different lengths); a web of thin wall cracks; a water stain.
```

### Н-12. Жёлтые игровые вещи

Для следующих уровней (в уровне 01 их нет): рычаг, кнопка, ящик. Рычаг и кнопка — из двух частей: код двигает ручку и шляпку.

```text
Request N-12: things the player uses. Separate pieces on one sheet with wide empty green gaps, flat front view, flat even light, worn signal-yellow paint over steel with dark scratches and rust at the bottom: (a) a floor lever: the base box and, drawn separately, the handle (the game rotates it); (b) a floor button: the base and, drawn separately, the round cap (the game presses it); (c) a crate of corrugated steel, about 1:1. Stencil-like marks are fine, but no letters or numbers.
```

## 5. Проверка и правки

Принимать картинку, если: вид строго сбоку без перспективы; свет ровный, без теней и свечения; фон — ровный зелёный без теней и шахматки; одна деталь (или лист деталей, которые не касаются друг друга); кисть и цвета как у эталонного кадра; нет пурпура, циана и надписей.

| Что не так | Что сказать Gemini |
|---|---|
| Перспектива, вид 3/4, наклон | `Too much perspective. Repaint as a perfectly flat front elevation, like a technical drawing: no vanishing point, every vertical line vertical, every horizontal line horizontal.` |
| Нарисован свет, тени, тёмные углы | `Remove all lighting: flat, even, neutral light, no cast shadows, no dark corners, no glow. The game adds the light.` |
| Фон неровный, с тенью или шахматкой | `The background must be one flat colour, pure #00FF00, with nothing on it: no shadow, no gradient, no checkerboard.` |
| Целая сцена вместо детали, несколько вариантов | `Only this one piece, alone, nothing else in the picture. One version only.` |
| Плитка со швом, ряды кривые | `The game repeats this texture side by side. Make the left edge continue the right edge and the top continue the bottom, with straight even courses.` (небольшой шов код поправит) |
| Стиль уплыл: другая кисть, другие цвета | Приложить эталонный кадр снова: `Match the brush, the colours and the level of detail of the attached reference frame exactly.` Не помогает — новый чат с брифом. |
| Детали слиплись | `Leave wide empty green space between the pieces; no piece may touch another.` |
| Пурпур, циан, что-то светится | `No purple, magenta or cyan anywhere, and nothing glows.` |
| Буквы, цифры | `Remove all text, letters and numbers.` |
| Мелко, детали не читаются | `Fewer, bigger details: it must read when it is small on the screen.` |

**Если Gemini не держит пропорции** (пол слишком широкий, заслонка толще, героиня мельче): эталонный кадр задаёт вид — кисть, цвета, свет, материалы, — а не геометрию. Геометрию строит игра по сетке, поэтому кадр с неточными размерами годится. Если всё же хочется поправить кадр, не описывать его заново, а править готовую картинку и мерить по тому, что на ней есть: «толщиной с её ботинок», «вдвое уже двери», а не числами:

```text
Edit this picture and keep everything else exactly as it is: lower the camera to the height of the floor, so the top surface of the floor becomes a thin strip no thicker than the heroine's boots are tall, and she stands on the middle of that strip. Keep the front face of the floor below as it is. The seams between the plates are straight and vertical, with no perspective.
```

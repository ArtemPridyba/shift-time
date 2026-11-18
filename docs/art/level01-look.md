# Вид уровня 01 «Ночной цех» — план

Решения 18.11.2026 (D60, D61, D63–D69; открытые D70–D72 — в [decisions.md](../decisions.md)). Этот документ — как всё делается по шагам, чтобы ничего не упустить. Уровень 01 — образец: по нему одеваются все следующие уровни (D59).

Макеты, нарисованные кодом (приватные ссылки Бориса, доступ открывает он через «Поделиться»):

- восемь первых вариантов: <https://claude.ai/artifact/44pUL9a6bjmPAntLugtSK9>;
- шесть вариантов «Кирпич и чугун»: <https://claude.ai/artifact/LAhRpqX1uqzGZSSTa3K6gt>;
- итог «Ночной цех» (уровень, двери, героини, набор деталей): <https://claude.ai/artifact/4oXXyUdMz88da8hk4ozYFC>.

В макетах всё нарисовано кодом: свет, механизмы, двери и эффекты — образец того, как это должно двигаться; героиня там — заглушка, её рисует Gemini.

## 1. Что решено

- **Вид (D61):** старая фабрика из красного кирпича с чёрным чугуном, ночь. Окна разбиты, за ними тёмное небо. Пожара в уровне 01 нет: тревогу дают толчки, падающая лампа, искрящий провод, маяк и пыль. Пожар у окон (огонь лезет в окна, рушатся балки, дым) — для поздних уровней.
- **Свет (D65):** комната тёмная, свет дают только лампы, и каждая стоит над тем, с чем работает игрок: островки света. Пожар и окна комнату не освещают.
- **Игровые вещи (D65):** всё, что игрок двигает или нажимает (рычаг, кнопка, ящик, кромка платформы), выкрашено облезлой сигнальной жёлтой краской.
- **Время на механизмах (D60, вариант «в»):** механизмы под Shift не светятся. Светится только героиня и её наруч.
- **Как читается откат (D67):** картинка чуть выцветает, от наруча расходится волна, стрелки заводских часов на колонне идут назад, таймер времени мира слева сверху считает вниз (на нуле мир стоит), звук играет задом наперёд (Д8).
- **Двери (D66):**
  - выход — гермодверь в задней стене на уступе: штурвал делает 2,5 оборота, четыре засова уходят внутрь, створка отходит от стены и уезжает вправо по рельсу на роликах; видна толщина двери и тень на стене. За ней лестница вверх и холодный свет сверху, свет выходит из проёма на уступ — понятно, куда идти;
  - преграда посреди пути (дверь, которая сама закрывается в начале уровня) — тяжёлая заслонка в том же стиле: толстая створка с засовами и штурвалом сбоку, опускается в пол по рейке между шестернями, под Shift поднимается.
- **События (D67):** на 6-й секунде слабый толчок; на 14-й сильный — лампа над проходом падает и разбивается, отваливается кусок штукатурки, сыплется пыль; дальше слабые толчки примерно каждые 13 с. Под Shift всё собирается обратно, лампа снова горит — подводка к уровню про темноту. Лампа — уже готовый записанный объект `game/objects/lamp.*` (2.8), события — данные уровня.
- **Героиня (D63):** Крановщица — крупная голова, короткие ноги, простой сильный силуэт; пучок, красная каска висит на спине на ремешке, перчатка-наруч с кабелем к батарее на поясе. Под Shift она светится цветом времени, эффект нарастает: сначала волны по телу, при долгом удержании — эхо-силуэты. Цвет робы (D72) и цвет времени (D70) выбираем по картинкам Gemini. Ноги стоят на середине верхней грани пола.
- **Набор деталей (D64):** всё рисуется отдельными деталями, которые переходят из уровня в уровень. Текстуры плоские, без нарисованных теней и света — свет и тени считает игра. Разруха — отдельные наклейки поверх. Рисует смешанно: материалы и сложные вещи — Gemini, простые движущиеся части — код.
- **Сделанное в Д1 (D68):** палитры, общий материал и витрина Артёма остаются в репозитории как история и запасной вариант; новые задачи на них не опираются. Убрать — отдельной задачей, если начнут мешать.
- **Делёж (D69):** весь вид делает Борис; Артём — звук (Д8), переделка уровня 02 по плейтесту, уровни 03–10 и проверки. Уровень 01 одет к 21.11.

## 2. Как это делается, по шагам

| Шаг | Что | Кто, чем | Когда | Готово, когда |
|---|---|---|---|---|
| 1 | Героиня у Gemini: запросы Г-1, Г-2, Г-3 ниже | Борис, приложение Gemini (Г) | 19.11 | есть лист персонажа в двух цветах робы и двух цветах времени, вид сбоку для куклы, силуэт; выбраны D70 и D72 |
| 2 | Детали набора у Gemini: запросы Н-1…Н-8 | Борис, Gemini (Г) | 19.11 | на каждую деталь из таблицы раздела 3 есть картинка или пометка «код» |
| 3 | Подчистка: убрать фон, подогнать к сетке 64 px, сложить в `game/assets/art/kit/` и `game/assets/art/heroine/`, строка в `docs/art/log.md` на каждый файл | Борис (Л) | 19–20.11 | файлы в репозитории, в журнале у каждого сервис, запрос и лицензия |
| 4 | Д2: частицы времени и механизмы | Claude Code, Opus (О) | 19–20.11 | см. карточку Д2 в roadmap |
| 5 | Д3: мир — набор деталей в уровне, темнота и островки света | Claude Code (О+) | 20.11 | см. Д3 |
| 6 | Д4: объекты уровня 01 — заслонка, гермодверь с лестницей, платформы, рычаг, ящик, часы, таймер, падение лампы | Claude Code (О) | 20–21.11 | см. Д4 |
| 7 | Д5: героиня — кукла из частей и силуэт со светом, выбор D71 | Claude Code (О) | 21.11 | см. Д5 |
| 8 | Д7: вид отката — выцветание, волна, эффект героини, часы | Claude Code (О) | 21.11 | см. Д7 |
| 9 | Проверка уровня 01: снимки `tools/shots.sh`, веб-сборка, человек со стороны | Борис (Л) + Claude Code | 21.11 | снимки вперёд и под Shift, веб-сборка открывается и не тормозит |
| 10 | Уровень 02 по тому же образцу (Д6), звук (Д8), образец для остальных уровней (Д9) | Борис; Артём — Д8 | 22–24.11 | см. Д6, Д8, Д9 |

Порядок важен: шаги 1–3 (картинки) и шаг 4 (код частиц и механизмов) идут параллельно; Д3–Д5 ждут картинок; если картинок нет к 20.11 — включаем план Б (раздел 5) и не ждём.

## 3. Набор деталей

Размеры — в пикселях кадра 1280×720 (в игре клетка 64 px, кадр 1920×1080: умножить на 1,5). «Gemini» — рисует Gemini, «код» — рисуется и двигается кодом, как в макете.

| Группа | Деталь | Размер | Кто |
|---|---|---|---|
| Стены и пол | кирпичная стена, плитка без шва | 128×128 | Gemini |
| | стена с остатками штукатурки | 128×128 | Gemini |
| | пол: чугунная плита, верх и торец | 128×120 | Gemini |
| | уступ: бетонный блок | 140×222 | Gemini |
| Архитектура | окно: арка, рама, остатки стёкол (стёкла прозрачные) | 178×370 | Gemini |
| | колонна-двутавр, сегмент | 44×140 | Gemini |
| | балка крана, фермы потолка | 256×30, 256×66 | Gemini |
| Наклейки разрухи | трещины, сажа над окном, ржавые потёки, осколки стекла | 128×128 и меньше | код |
| | груда кирпича, упавшая балка | 160×34, 200×28 | Gemini |
| Двери | гермодверь с рамой и рельсом; за ней лестница вверх | 206×232 | Gemini + код |
| | штурвал, засов, ролик рельса | 56, 60×12, 24 | код |
| | заслонка-преграда с засовами и штурвалом сбоку | по блокауту двери уровня 01 | Gemini + код |
| Механизмы | платформа с кареткой, зубчатая колонна, шестерни (3 размера), цепь, крюк крана | — | код (крюк — Gemini) |
| Игровые вещи (жёлтые) | рычаг, кнопка, ящик | 50×60, —, 90×92 | Gemini |
| Свет и часы | лампа-тарелка, лампа в решётке, маяк, заводские часы | 64×30, 32×40, 40×26, 70×84 | Gemini; стрелки и свет — код |
| Станки фона | бак, бункер, мостик с перилами, конвейер, трубы и фланцы, маховик | см. макет | Gemini; маховик — код |
| Героиня | части куклы (12) или силуэт | высота ~120 px | Gemini |

Вторая комната в макете («Насосная») собрана из тех же деталей без единой новой — так проверяем, что набор переходит в другие уровни.

## 4. Запросы для Gemini

Общее для всех: в конце каждого запроса — «No text, no logos, nothing recognisable from existing games or films.» Перед загрузкой в репозиторий — строка в `docs/art/log.md` (сервис, запрос, лицензия; только то, что можно продавать после джема).

### Героиня

- **Г-1. Лист персонажа.** Character sheet for a 2D side-view puzzle-platformer, hand-painted digital art matching an old red-brick factory with black cast iron, flat even lighting, plain mid-grey background. A sturdy young woman crane operator, cartoon proportions: big head (about one fifth of her height), short legs, a simple strong silhouette that reads at 120 pixels tall. Dark hair in a bun, a red hard hat hanging on her back by its strap, work boots and gloves, a heavy industrial gauntlet on her right forearm with a dial, two small levers and a cable to a battery pack on her belt. Two versions side by side: faded orange overalls and dark teal overalls; the gauntlet light in cyan (#7FE8FF) and in magenta (#FF4FB8). Calm and determined. Views: side view standing, side view walking in three poses, front view, back view.
- **Г-2. Для куклы из частей.** The same character, side view facing right, neutral standing pose, arms slightly away from the body and legs slightly apart so no part overlaps another, flat even lighting, plain white background, clean edges. Then the same image split into separate parts on one sheet: head with bun, hard hat with strap, torso, upper arm, forearm with gauntlet, hand, thigh, shin, boot, battery pack with cable; each part with a little overlap at the joints.
- **Г-3. Силуэт и свет.** The same character, side view, as a dark silhouette with strong rim light: warm orange rim on the left, cold blue rim on the right, the gauntlet glowing. Second pose: rewinding time — waves of light run from the gauntlet across her body, and translucent echo copies of her trail behind.

### Набор

- **Н-1. Стены и пол.** Seamless tileable texture, 512×512, hand-painted digital art for a 2D side-view game: old sooty red brick wall of a factory, mortar lines, a few darker and lighter bricks, small chips. Flat even lighting, no shadows, no light source, no perspective. Same style, separate images: a wall with remains of grey-green plaster over brick; a cast-iron floor plate with rivets seen with a slight top-down tilt (top face and front edge); a concrete ledge block.
- **Н-2. Окно.** Game asset, isolated on a transparent background, hand-painted, flat even lighting: a tall arched factory window with a cast-iron frame, 3 × 6 panes, most panes broken with sharp shards left in the frame, a brick sill. The glass holes are transparent. Front view, no perspective.
- **Н-3. Гермодверь и заслонка.** Game asset, isolated on a transparent background, hand-painted, flat even lighting: a thick riveted steel hermetic door for a factory, about 1 × 2 proportion, a hazard stripe at the bottom, rust streaks, seen from the front with a slight top-down tilt showing its thick top edge. On the same sheet: a red cast-iron valve wheel with five spokes, a bolt rod, a small rail roller, a heavy steel gate slab with bolts and a small valve wheel on its side.
- **Н-4. Лестница за дверью.** Game asset: the view through an open doorway in a brick wall — a narrow concrete staircase going up and away from the viewer, iron handrails, cold white light falling from the top of the stairs, the lower steps in shadow. Hand-painted, side-view game style.
- **Н-5. Свет и часы.** Game asset sheet, isolated on a transparent background, hand-painted, flat even lighting, unlit (bulbs off): an industrial enamel dish lamp hanging from a cable, a caged wall lamp with a glass globe, a red rotating emergency beacon, a large round factory clock in a cast-iron frame with cracked glass (no hands — hands are drawn by code).
- **Н-6. Игровые вещи.** Game asset sheet, isolated on a transparent background, hand-painted, flat even lighting: a worn signal-yellow metal crate with corrugated sides, dark scratches and rust at the bottom, stencil text B-07; a floor lever with a yellow base and a yellow knob; a yellow push button on a cast-iron post; a steel platform edge with yellow paint. Same style as old factory machine paint.
- **Н-7. Станки фона.** Game asset sheet, isolated on a transparent background, hand-painted, flat even lighting, dark low-contrast silhouettes with little detail: a tall riveted tank with a ladder, a hopper on legs, a catwalk segment with railings, a roller conveyor, pipes with flanges and an elbow, a crane hook with a pulley block.
- **Н-8. Наклейки разрухи.** Decal sheet, isolated on a transparent background, flat: a heap of fallen bricks, a fallen steel I-beam, a lump of fallen plaster, glass shards on the floor. Each item separate.
- **Кадр-ориентир всего уровня** (для сверки, не в игру). Screenshot of a 2D side-view puzzle-platformer, 16:9, hand-painted digital art, slight top-down tilt so floors and platforms show their top face. A dark night factory hall of red brick and black cast iron, broken arched windows with a dark night sky, no fire. The room is dark and lit only by islands of warm lamp light: dish lamps on cables and caged wall lamps above the things the player uses. A red rotating beacon above a heavy hermetic exit door with a red valve wheel; behind the open door a staircase goes up into cold light. The lever, the crate and the platform edge are painted worn signal yellow. A big factory clock on a pillar. Visible cast-iron mechanisms: a platform on a toothed column, gears, chains. A small heroine: a crane operator woman with a big head, a red hard hat on her back and a glowing gauntlet.

## 5. План Б

- **Героиня.** Пробуем оба способа и выбираем по виду в уровне (D71, к 21.11):
  - кукла из частей — нужен один удачный вид сбоку (Г-2); его режут на 12 частей, код двигает их вокруг точек вращения; разные позы рисовать не надо, поэтому несовпадение картинок Gemini не мешает;
  - силуэт и свет — нужен только силуэт (Г-3 или обводка Г-1); свет ламп ложится контуром, наруч светится; прощает неточности рисунка;
  - если Gemini не дал ни того, ни другого к 20.11 — силуэт со светом по заглушке из макета (код), детали добавим потом.
- **Детали набора.** Если текстуры Gemini не стыкуются без шва или не похожи друг на друга — рисуем деталь кодом, как в макете: весь макет «Ночной цех» нарисован кодом и уже смотрится. Gemini тогда только для героини и уникальных вещей (часы, ящик, бак).
- **Время.** Если к 21.11 не успеваем — режем в таком порядке: маяк, искрящий провод, слабые толчки (сильный с падением лампы оставляем), часы, эхо-силуэты (остаются волны), лестница за дверью (остаётся свет из проёма). Не режем: темноту с островками света, жёлтые игровые вещи, обе двери, героиню.

## 6. Технические заметки для задач

- **Частицы назад:** обычные частицы Godot (CPUParticles2D, GPUParticles2D) назад не крутятся. Нужен свой компонент: положение частицы — формула от времени мира, рисуется одним `MultiMeshInstance2D`; один компонент на пыль, пепел, искры, капли и осколки (Д2).
- **Свет:** `CanvasModulate` для общей темноты и несколько `PointLight2D` с мягкими текстурами; яркость и мигание — формулы от времени мира. В веб-сборке держать мало источников (5–6 на экран) и проверять скорость (Д3, Д9).
- **Уровень шире экрана** (3072 px, камера едет): фон собирается из плиток и деталей, а не одной картиной.
- **Ноги героини** — на середине верхней грани пола; столкновения не меняются.
- **Гермодверь выхода** — только вид: зона выхода и тест решения уровня не меняются. Когда открывается — решить в Д4; рекомендация — когда героиня встаёт на уступ.
- **Падение лампы** — событие в данных уровня через готовую лампу (2.8); проверить, что тест решения уровня 01 остаётся зелёным.
- **Таймер времени мира** — в `game/ui/` (рядом с `time_hud`), числа и вид — в `data/time_hud.json`; тексты игры — на английском (`WORLD 00:14.2`).

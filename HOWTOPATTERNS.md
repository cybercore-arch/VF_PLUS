# Как написать паттерн атаки

Паттерн — это отдельный `.gd` файл. Один файл — один паттерн. Менеджер вызывает метод `execute` у любого загруженного скрипта, никакого особого базового класса не нужно.

## Где лежат паттерны

- **Встроенные** — `res://entities/attacks/`. Попадают в сборку.
- **Внешние** — папка `patterns/` рядом с исполняемым файлом (в редакторе — в корне проекта). Загружаются во время выполнения.

Приоритет у внешних: если в `patterns/` есть файл с тем же именем, что и встроенный, загрузится внешний.

## Контракт

Скрипт должен наследоваться от **`RefCounted`** и иметь метод:

    func execute(arena: Node2D, params: Dictionary) -> void:

- `arena` — сцена арены. Через неё добавляешь пули (`arena.bullet_container`), берёшь игрока (`arena.get_node_or_null("player")`), проверяешь, что игра ещё идёт.
- `params` — словарь параметров из JSON. Читай через `params.get("ключ", значение_по_умолчанию)`.

Почему `RefCounted`, а не `Node`: объект паттерна создаётся на каждый запуск и нигде не хранится. `RefCounted` освобождается сам, когда `execute` закончится, а `Node` остался бы висеть в памяти до конца игры. Старые моды на `extends Node` продолжают работать (менеджер подвешивает их к арене), но для новых используй `RefCounted`.

Если хочешь, чтобы паттерн попадал в `random`, он должен работать с пустым `params`.

## Минимальный пример

    extends RefCounted

    func execute(arena: Node2D, params: Dictionary) -> void:
        var speed: float = params.get("speed", 200.0)
        var angle: float = params.get("angle", 0.0)
        var pos: Vector2 = PatternUtil.get_pos(arena, params)

        var dot := PatternUtil.spawn_dot(arena, pos, Color(1, 1, 1, 0.7))   # телеграф
        await PatternUtil.wait(arena, params.get("delay", 0.5))             # пауза уважается
        PatternUtil.free_node(dot)

        if not PatternUtil.arena_alive(arena):                              # после await всегда проверяй
            return

        PatternUtil.spawn_bullet(arena, pos, Vector2.RIGHT.rotated(deg_to_rad(angle)), speed)

## PatternUtil — набор готовых функций

`core/pattern_util.gd`, глобальный класс `PatternUtil`. Все функции статические.

**Арена и время**
- `arena_alive(arena)` — арена существует и в дереве. Проверяй после каждого `await`.
- `wait(arena, секунды)` — задержка, которая **останавливается на паузе**. Пиши `await PatternUtil.wait(arena, t)`.
- `next_frame(arena)` — ждёт физический кадр и возвращает `delta`. Для покадровых циклов: `elapsed += await PatternUtil.next_frame(arena)`.
- `get_player(arena)` — игрок или `null`.
- `free_node(node)` — `queue_free`, если узел ещё жив.

**Параметры**
- `get_pos(arena, params)` — позиция из `pos`, либо из `x`/`y`, либо центр.
- `resolve_point(val, arena, fallback)` — `"center"`, `"random"`, `"player"`/`"aimed"`, `[x, y]` или `Vector2` в `Vector2`.
- `to_color(val, по_умолчанию)` — `[r, g, b]`, `[r, g, b, a]` или `Color` в `Color`.

**Создание объектов**
- `spawn_bullet(arena, pos, dir, speed)` — создаёт пулю и возвращает её.
- `spawn_dot(arena, pos, color)` — мигающая точка-телеграф. Удали её через `free_node`.
- `make_line(arena, a, b, color, width)` — линия-телеграф.
- `spawn_laser(arena, pos, angle, opts)` — создаёт лазер (`angle` в радианах) и возвращает его. `opts` — настройки лазера, их можно собрать из `params` через `laser_options(params)`. Паттерны с лазерами называй с приставкой `laser_`.
- `side_geometry(side, размер)` и `side_pos(t, geo, отступ)` — геометрия сторон экрана (`wall`, `sakura`).

**Запуск других паттернов**
- `run_pattern(имя, arena, params)` — загрузит паттерн и вызовет его. Так делают `loop` и `random`.
- `pattern_pool()` — имена всех доступных паттернов без `random` и `loop`.

## Как менеджер обрабатывает параметры

Перед вызовом `execute` параметры проходят через `PatternUtil.prepare_params`:

1. **Цвета.** Любой массив из 3 или 4 чисел (на любой глубине, в том числе внутри вложенных объектов) становится `Color`. Формат `[r, g, b]` или `[r, g, b, a]`, числа от 0.0 до 1.0.
2. **`pos`.** Только это поле верхнего уровня превращается в `Vector2`: `"center"`, `"random"` (отступ 50 пикселей от краёв), `"player"`/`"aimed"` или `[x, y]`.

Остальные поля с позициями (например, `target`) остаются как есть: вызови `PatternUtil.resolve_point` сам. Так позиция игрока берётся в момент выстрела, а не в момент запуска паттерна.

## Общие правила

1. **После каждого `await` проверяй `PatternUtil.arena_alive(arena)`.** Игрок мог умереть, уровень мог перезапуститься.
2. **Для пауз используй `PatternUtil.wait` / `next_frame`, а не `get_tree().create_timer(t)`.** Стандартный таймер Godot идёт во время паузы, и пули продолжат появляться при открытом меню паузы. Внутри паттерна `get_tree()` вообще недоступен (объект не в дереве), берись за `arena.get_tree()`.
3. **Время в циклах копи из `delta`**, а не из `Time.get_ticks_msec()`: реальное время не знает о паузе.
4. **Твины привязывай к тому, что анимируешь** (`bullet.create_tween()`, `dot.create_tween()`), тогда они умирают вместе с объектом.
5. **Если паттерн запускает другие** — используй `PatternUtil.run_pattern`: он проверяет имя, наличие `execute` и подготавливает параметры.

## Безопасность внешних паттернов

Файлы из `patterns/` выполняются с полными правами игры. Не клади туда чужие `.gd`, если не доверяешь источнику.

## Отладка

- **Паттерн не вызывается** — проверь, что имя файла совпадает с `pattern` в JSON и что файл лежит в `entities/attacks/` или в `patterns/`. Имя не должно содержать `/` и `..`.
- **Пули летят не туда** — распечатай `params` через `print(params)`.
- **Паттерн продолжает стрелять после смерти или на паузе** — где-то остался `get_tree().create_timer(...)` или нет проверки `arena_alive` после `await`.
- **Цвет не применился** — он должен быть массивом чисел, строки (`"#ff0000"`) не конвертируются.

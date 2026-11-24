class_name WaterPipe
extends Node2D
## A water pipe drawn by code (level 03 playtest, D108): a thick pipe along
## `points` that shows the water in it. It keeps no history and is not in the
## group `temporal`: it reads the recorded state of the sprinkler it feeds
## (`source_path`) every frame. While the sprinkler is powered the pipe is
## full; while water runs to the nozzles (`flow` above 0) light dashes travel
## inside from the first point to the last. The dashes' place is a function of
## world time only (the group `world_clock`), so under Shift they run back
## towards the first point and stand still at frame 0. A closed line drains as
## its sprinkler's flow falls and then shows an empty, dark channel.
##
## Two kinds tell the lines apart by shape, not by colour alone: a feed pipe
## (`kind` FEED) is thinner and has flanges, a main (`kind` MAIN) is thick and
## plain. Sizes and colours: `pipe` in `data/look.json`.

enum Kind { FEED, MAIN }

## The path in local pixels, from where the water comes in to the nozzles.
@export var points := PackedVector2Array()
@export var kind := Kind.FEED
## The Sprinkler this line feeds.
@export var source_path: NodePath

## How full the pipe is (0…1) and how fast the water runs (0…1), as drawn.
var fill := 0.0
var run := 0.0

var _look := {}
var _per_second := 60.0
var _world_tick := 0


func _ready() -> void:
	_look = Content.look_pipe()
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))
	add_to_group("world_clock")
	refresh()


func _process(_delta: float) -> void:
	refresh()


func on_world_tick(tick: int, _recorded: bool) -> void:
	if tick != _world_tick:
		_world_tick = tick
		queue_redraw()


## Reads the sprinkler and redraws if the water in the pipe changed.
func refresh() -> void:
	var source := get_node_or_null(source_path) as Sprinkler
	var level := 0.0
	var speed := 0.0
	if source != null:
		speed = float(source.flow) / float(Sprinkler.FLOW_MAX)
		level = 1.0 if source.powered else speed
	if is_equal_approx(level, fill) and is_equal_approx(speed, run):
		return
	fill = level
	run = speed
	queue_redraw()


## The pipe's width in pixels for its kind.
func width() -> float:
	return float(_look.get("main_width_px" if kind == Kind.MAIN else "feed_width_px", 14))


## Where the first dash starts, in pixels along the path: grows with world time.
func dash_offset() -> float:
	var period := float(_look.get("dash_length_px", 14)) + float(_look.get("dash_gap_px", 26))
	return fposmod(float(_world_tick) / _per_second * float(_look.get("dash_speed_px", 240)), period)


func _color(key: String, fallback: String) -> Color:
	return Color(String(_look.get(key, fallback)))


func _draw() -> void:
	if points.size() < 2:
		return
	if _look.is_empty():
		_look = Content.look_pipe()
	var w := width()
	var wall := float(_look.get("wall_px", 3))
	var outline := Color(String(Content.look_mech().get("outline", "#1c1c20")))
	_stroke(w + 2.0, outline)
	_stroke(w, _color("shell", "#5a6068"))
	var inner := maxf(w - 2.0 * wall, 1.0)
	_stroke(inner, _color("empty", "#24282d"))
	if fill > 0.0:
		var water := _color("water", "#5f7f93")
		water.a *= fill
		_stroke(inner, water)
	if kind == Kind.FEED:
		_flanges(w)
	if run > 0.0:
		_dashes(inner * 0.5, run)


## The whole path as one line of `w` pixels with square joints.
func _stroke(w: float, color: Color) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var along := (b - a).normalized() * w / 2.0
		draw_line(a - along, b + along, color, w)


## Rings around the feed pipe every `flange_every_px` along each straight run.
func _flanges(w: float) -> void:
	var every := float(_look.get("flange_every_px", 128))
	var thick := float(_look.get("flange_px", 6))
	var color := _color("shell_light", "#767c84")
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var across := Vector2(-dir.y, dir.x) * (w / 2.0 + thick / 2.0)
		var s := every / 2.0
		while s < length:
			var p := a + dir * s
			draw_line(p - across, p + across, color, thick)
			s += every


## Light dashes along the inside of the path, moving with world time.
func _dashes(w: float, strength: float) -> void:
	var dash := float(_look.get("dash_length_px", 14))
	var period := dash + float(_look.get("dash_gap_px", 26))
	var color := _color("dash", "#cfe0ea")
	color.a *= strength
	var start := dash_offset() - period
	var walked := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		# Dashes are placed by their distance along the whole path, so they
		# turn the corners without jumping.
		var s: float = start + ceil((walked - start) / period) * period - period
		while s < walked + length:
			var from := maxf(s, walked)
			var to := minf(s + dash, walked + length)
			if to > from:
				draw_line(a + dir * (from - walked), a + dir * (to - walked), color, w)
			s += period
		walked += length

extends Node
## The palette the game draws with now (task Д1). Starts from `active_palette`
## of `art.json`; the style showcase switches it at run time, and everything
## drawn in palette colours listens to `palette_changed` and repaints.
## Presentation only: it changes no rule and nothing recorded.
##
## No `class_name`: a class with the autoload's name would hide the singleton.

signal palette_changed(palette: ArtPalette)

var palette: ArtPalette:
	get:
		return _palette
var _palette: ArtPalette
var _art := {}


func _init() -> void:
	_art = Content.art()
	_palette = ArtPalette.from_art(_art, str(_art.get("active_palette", "")))
	if _palette == null:
		_palette = ArtPalette.new("", {})


## Switch to the palette `palette_id` of `art.json`; false when there is none.
func use_palette(palette_id: String) -> bool:
	var next := ArtPalette.from_art(_art, palette_id)
	if next == null:
		return false
	if next.id != _palette.id:
		_palette = next
		palette_changed.emit(_palette)
	return true


## Switch to the next palette in show order (`step` -1: the one before).
func cycle(step: int = 1) -> void:
	use_palette(ArtPalette.next_id(_art, _palette.id, step))


## Back to `active_palette` of `art.json`.
func reset() -> void:
	use_palette(str(_art.get("active_palette", "")))

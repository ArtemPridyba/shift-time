class_name ArtPalette
extends RefCounted
## One palette of `art.json` (task Д1): colour ramps by role. A palette gives
## colour to roles, never to objects: steel, mechanism, time, fire and so on
## (`Content.ART_ROLES`). Each ramp holds `Content.ART_RAMP_SIZE` shades from
## dark to light; `BASE` is the main colour itself.

const BASE := 2

## The key of the palette in `art.json` (`plum_cobalt`, ...).
var id: String
var title: String
var skin: Color
var _ramps := {}


func _init(palette_id: String, data: Dictionary) -> void:
	id = palette_id
	title = str(data.get("title", palette_id))
	skin = Color.from_string(str(data.get("skin", "")), Color.MAGENTA)
	var ramps: Variant = data.get("ramps")
	if not ramps is Dictionary:
		return
	for role: Variant in ramps:
		var colors := PackedColorArray()
		for value: Variant in ramps[role]:
			colors.append(Color.from_string(str(value), Color.MAGENTA))
		_ramps[str(role)] = colors


## The five shades of a role, dark to light; magenta when the role is missing.
func ramp(role: String) -> PackedColorArray:
	if _ramps.has(role):
		return _ramps[role]
	var missing := PackedColorArray()
	missing.resize(Content.ART_RAMP_SIZE)
	missing.fill(Color.MAGENTA)
	return missing


## One shade of a role, clamped to the ramp: 0 is the darkest, `BASE` the main
## colour.
func shade(role: String, index: int = BASE) -> Color:
	var colors := ramp(role)
	return colors[clampi(index, 0, colors.size() - 1)]


## The common dark of the palette: outlines and the deepest shadow.
func dark() -> Color:
	return shade("background", 0)


## The palette ids of `art.json` in show order: the main palette first, then
## the reserves in the order of the file.
static func ids(art: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var palettes: Variant = art.get("palettes")
	if not palettes is Dictionary:
		return result
	for key: Variant in palettes:
		if palettes[key] is Dictionary and palettes[key].get("status") == "main":
			result.append(str(key))
	for key: Variant in palettes:
		if not str(key) in result:
			result.append(str(key))
	return result


## The palette after `current` in show order (`step` -1 for the one before),
## wrapping around; the first one when `current` is unknown.
static func next_id(art: Dictionary, current: String, step: int = 1) -> String:
	var all := ids(art)
	if all.is_empty():
		return ""
	var at := all.find(current)
	if at < 0:
		return all[0]
	return all[posmod(at + step, all.size())]


## The palette `palette_id` of `art.json`, or null when there is none.
static func from_art(art: Dictionary, palette_id: String) -> ArtPalette:
	var palettes: Variant = art.get("palettes")
	if not palettes is Dictionary or not palettes.get(palette_id) is Dictionary:
		return null
	return ArtPalette.new(palette_id, palettes[palette_id])

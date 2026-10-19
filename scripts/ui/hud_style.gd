class_name HudStyle
## The HUD's look (v15, owner 2026-10-17): our bar things - a shelf of bottles, the counter
## with the waiting cats, the glass and the tip jar - kept quiet so it sits in the dark: thin
## ledges instead of planks, small dim numbers, thin dark frames. Sprites are room pixels drawn
## 2x or 3x; text is on the UI grid (640x360 = half a room pixel). Printed through ui/ui_worn.tres.

const WORN := preload("res://ui/ui_worn.tres")
const LABEL_FONT := preload("res://art/fonts/tiny-5.fnt")				# 5 px caps
const VALUE_FONT := preload("res://art/fonts/PixelOperator8-Bold.ttf")	# 7 px
const BIG_FONT := preload("res://art/fonts/compass-9.ttf")				# 11 px
const TALK_FONT := preload("res://art/fonts/brief-9.ttf")	# the HUD's small text, 9 px caps (owner's pick)

# dark -> light, all muted so nothing jumps out of the dark
const INK := Color("0e0a08")
const SHADE := Color("0b0807")	# inside thin frames
const LIP := Color("1c1510")
const LINE := Color("3a2e26")	# thin frames, the ledges' shadow
const LEDGE := Color("534337")	# quiet ledges; the room carries the light
const EDGE := Color("5a4636")
const LABEL := Color("7d6a55")
const TEXT := Color("c9b693")
const BRIGHT := Color("e3cfa9")
const GOLD := Color("d9a24a")
const GOLD_LIGHT := Color("f0cf8a")
const WARN := Color("b5543a")
const RUN_TEXT := Color("a08f75")
const RUN_BRIGHT := Color("c7b28f")
const RUN_FONT_SIZE := 16
const RUN_ART := preload("res://scripts/ui/run_art.gd")

const ROOM_PX := 2		# a room pixel in UI pixels
const PAD := 8			# text never closer to a frame's edge than this


static func run_material() -> ShaderMaterial:
	var print: ShaderMaterial = WORN.duplicate()
	print.set_shader_parameter(&"gain", 0.78)
	print.set_shader_parameter(&"saturation", 0.8)
	print.set_shader_parameter(&"grain", 0.008)
	print.set_shader_parameter(&"blotch", 0.012)
	print.set_shader_parameter(&"chips", 0.0)
	return print


## A thin frame: 1 px line, dark inside.
static func plate(on: CanvasItem, r: Rect2) -> void:
	RUN_ART.panel(on, r)


## A pixel-art sprite drawn `px` UI pixels per art pixel, its top left at `at`.
static func sprite(on: CanvasItem, tex: Texture2D, at: Vector2, tint := Color.WHITE, px := ROOM_PX) -> void:
	on.draw_texture_rect(tex, Rect2(at, tex.get_size() * px), false, tint)


## A thin ledge things stand on: a lit line and its shadow, from `x0` to `x1` at `y`.
static func ledge(on: CanvasItem, x0: float, x1: float, y: float) -> void:
	on.draw_texture_rect(RUN_ART.SHELF, Rect2(x0, y, x1 - x0, 1), false)
	on.draw_texture_rect(RUN_ART.LEDGE_SHADOW, Rect2(x0 + 1, y + 1, x1 - x0 - 2, 1), false)


## Where a sprite's top goes so it stands on a ledge at `y`.
static func stand(tex: Texture2D, y: float, px := ROOM_PX) -> float:
	return y - tex.get_height() * px


## Speech: a thin dark frame, dim text, a tail at `tail_x` pointing down.
static func bubble(on: CanvasItem, r: Rect2, s: String, tail_x: float) -> void:
	RUN_ART.panel(on, r.grow(1))
	var tx := floorf(r.position.x + tail_x)
	var y := r.end.y
	on.draw_texture(RUN_ART.BUBBLE_TAIL, Vector2(tx - 3, y))
	text(on, r.position.x + 4, r.position.y + 10, s, TEXT, TALK_FONT)


## The box a bubble needs around `s`.
static func bubble_size(s: String) -> Vector2:
	return Vector2(width(s, TALK_FONT) + 8, 13)


static func width(s: String, font: Font = VALUE_FONT) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(font)).x - 1


## Draws `s` with its baseline at `baseline`, returns where it ends.
static func text(on: CanvasItem, x: float, baseline: float, s: String, color: Color, font: Font = VALUE_FONT) -> float:
	on.draw_string(font, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(font), color)
	return x + width(s, font)


## `s` centred on `x`.
static func centered(on: CanvasItem, x: float, baseline: float, s: String, color: Color, font: Font = VALUE_FONT) -> void:
	text(on, roundf(x - width(s, font) / 2.0), baseline, s, color, font)


static func _size(font: Font) -> int:
	return 16 if font == BIG_FONT or font == TALK_FONT else 8

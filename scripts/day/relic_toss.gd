extends Node2D
## A won relic: fades in at the cat, rises up into the black band over the room and shows
## itself there big, in its rarity's soft light (the day stands still, the camera leans in, a
## soft flash), then floats down onto the bar and sinks into it. Bigger for rarer relics.
## Lives on a UI layer (UI px, over the black bars) - `fly` takes room points.
## Its icon at 1 room px (2 UI px) per art px on the bar; no art = its shape in the rarity colour.

signal shown		# the show is over, it heads for the bar

const CELL := 5			# room px per backpack cell
const ROOM := 2.0		# UI px per room px
const BAND := 52.0		# UI px of black over the room (Letterbox.TOP x 2)
const APPEAR := 0.15	# fades and grows in at the cat
const RISE := 0.5
const HOLD := 0.65
const FLY := 0.5
const ARC := 16			# UI px the way down bulges up
const SINK := 0.25
const SHOW := {&"common": 2.5, &"rare": 3.0, &"epic": 3.5}	# UI px per art px up in the band
const ZOOM := {&"common": 0.03, &"rare": 0.04, &"epic": 0.06}
const FLASH := {&"common": 0.06, &"rare": 0.09, &"epic": 0.12}
const BOB := 2.0		# UI px it floats up and down while shown
const GLOW := Color(1.35, 1.35, 1.35)	# a soft glow as it leaves the cat, gone by the landing
const NAME_OVER := 52			# UI px over the landing spot the relic's name pops

var id: StringName
var _glow := 0.0		# the rarity light behind it, 0..1


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS		# a talk pausing the game doesn't freeze it mid-air


func fly(from_room: Vector2, to_room: Vector2) -> void:
	var rarity: StringName = Relics.get_def(id).get("rarity", &"common")
	var size := _size()
	# as big as the rarity says, but inside the band
	var big: float = minf(SHOW.get(rarity, SHOW.common), (BAND - 6.0) / size.y)
	var from := Feel.ui_point(from_room)
	var to := Feel.ui_point(to_room)
	var peak := Vector2(from.x, (BAND + size.y * big) / 2.0)	# bottom-centre origin: centred in the band
	position = from
	scale = Vector2.ONE * ROOM * 0.4
	modulate.a = 0.0
	self_modulate = GLOW

	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, APPEAR)
	t.parallel().tween_property(self, "scale", Vector2.ONE * ROOM, APPEAR)
	# up out of the cat into the black, growing
	t.tween_property(self, "position", peak, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE * big, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "_glow", 1.0, RISE)
	t.parallel().tween_callback(_show_off.bind(rarity))
	# it hangs there, breathing
	t.tween_method(func(k: float) -> void:
		position = peak + Vector2(0, -sin(k * TAU) * BOB)
		queue_redraw(), 0.0, 1.0, HOLD)
	t.tween_callback(shown.emit)
	# down onto the bar, back to its own size
	t.tween_method(func(k: float) -> void:
		position = peak.lerp(to, k) + Vector2(0, -sin(k * PI) * ARC)
		queue_redraw(), 0.0, 1.0, FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE * ROOM, FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "_glow", 0.0, FLY)
	t.parallel().tween_property(self, "self_modulate", Color.WHITE, FLY)
	t.tween_callback(_land.bind(to))
	t.tween_property(self, "scale", Vector2(ROOM * 1.15, 0.0), SINK).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


## The room under it: the camera leans in, a soft flash.
func _show_off(rarity: StringName) -> void:
	Feel.zoom(ZOOM.get(rarity, ZOOM.common), RISE)
	Feel.flash(FLASH.get(rarity, FLASH.common))


func _land(at: Vector2) -> void:
	Feel.play(&"relic/drop")
	Feel.pop_label(Relics.get_def(id).get("name", String(id)), at + Vector2(0, -NAME_OVER))


func _size() -> Vector2:
	var tex := Relics.icon(id)
	if tex:
		return tex.get_size()
	var cells := Vector2i.ONE
	for c in Backpack.turned(id, 0):
		cells = cells.max(c + Vector2i.ONE)
	return Vector2(cells * CELL)


## Bottom centre at the origin, so it lands on its bottom and sinks into the bar.
func _draw() -> void:
	var col: Color = Relics.RARITY_COLOR.get(Relics.get_def(id).get("rarity"), Color.WHITE)
	var size := _size()
	if _glow > 0.0:
		# a soft round light in its rarity colour, no specks
		var c := Vector2(0, -size.y / 2.0)
		var radius := maxf(size.x, size.y) * 0.7
		for i in 6:
			var k := 1.0 - i / 6.0
			draw_circle(c, radius * (0.5 + k), Color(col.lightened(0.3), 0.07 * _glow))
	var tex := Relics.icon(id)
	if tex:
		draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height()))
		return
	var r := Rect2(Vector2(-floorf(size.x / 2.0), -size.y), size)
	draw_rect(r, col)
	draw_rect(r.grow(-0.5), col.lightened(0.4), false, 1.0)

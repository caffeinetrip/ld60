extends Node
## Every game action goes through Feel.play(&"id", pos): it plays the sound with the
## same id and whatever juice `fx` lists for it. Ids without an entry just make a sound.

const SUCCESS := preload("res://scripts/feel/success_fx.gd")
const LABEL_GOLD := Color("ecc983")		# "+$12", a little brighter than the HUD text
const LABEL_OVER := 41					# UI px over the counter the word starts at
const LABEL_STEP := 10					# words of payments at the same moment stack up
const BIG_PAY := 40						# this much at once also punches the camera

const BURSTS := {
	&"sparks": {color = Color("ffe9a8"), amount = 10, speed = 60.0, life = 0.35, gravity = 0.0, size = 1.0},
	&"coins": {color = Color("ffd34d"), amount = 6, speed = 45.0, life = 0.6, gravity = 160.0, size = 2.0},
	&"hearts": {color = Color("ff8fb1"), amount = 4, speed = 25.0, life = 0.9, gravity = -30.0, size = 2.0},
	&"dust": {color = Color(1, 1, 1, 0.5), amount = 5, speed = 15.0, life = 0.4, gravity = -10.0, size = 1.0},
	&"glass": {color = Color("bfe6ff"), amount = 8, speed = 70.0, life = 0.5, gravity = 200.0, size = 1.0},
}

# shake = pixels, hitstop = seconds, flash = alpha, burst = key in BURSTS,
# sound = other sound id, volume = dB
var fx := {
	&"homeless/kick": {shake = 3.0, hitstop = 0.06, burst = &"dust"},
	&"machine/whack": {shake = 2.0, burst = &"sparks"},
	&"machine/break": {shake = 4.0, flash = 0.2, burst = &"glass"},
	&"machine/fixed": {burst = &"sparks"},
	&"hit/perfect": {shake = 1.0, burst = &"sparks"},
	&"hit/good": {shake = 0.5, burst = &"sparks"},
	&"hit/miss": {shake = 3.0, burst = &"glass"},
	&"bar/coin": {burst = &"coins"},
	&"cat/happy": {burst = &"hearts"},
	&"cat/dog_happy.wav": {burst = &"hearts"},
	&"boss/enter": {shake = 6.0, flash = 0.4},
	&"boss/hp": {shake = 2.0, burst = &"sparks"},
	&"boss/life_lost": {shake = 3.0, flash = 0.15, burst = &"hearts"},
	&"boss/phase": {shake = 2.0, burst = &"sparks"},
	&"boss/laugh": {shake = 2.0},
	&"kick/swing": {shake = 3.0, hitstop = 0.05, burst = &"dust"},
	&"kick/turn": {volume = -8.0},
	&"win/row": {sound = &"bar/coin"},
}

var shake_scale := 1.0
var speed := 1.0		# the player's 1x / 2x / 3x
var fast := false		# Day sets it: speed only counts while the day is live

var _trauma := 0.0
var _scale := 1.0
var _stop_until := 0
var _last_usec := 0
var _flash: ColorRect
var _sound: Node
var _rng := RandomNumberGenerator.new()
var _paid := 0
var _paid_at := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)
	_last_usec = Time.get_ticks_usec()


## `parent` = where the burst goes, the world by default (pass a UI node for UI points).
func play(id: StringName, at := Vector2.INF, strength := 1.0, parent: Node = null) -> void:
	var e: Dictionary = fx.get(id, {})
	_play_sound(e.get("sound", id), e.get("volume", 0.0))
	if e.has("shake"):
		shake(e.shake * strength)
	if e.has("hitstop"):
		hitstop(e.hitstop)
	if e.has("flash"):
		flash(e.flash)
	if e.has("burst") and at != Vector2.INF:
		burst(e.burst, at, strength, parent)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 12.0)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.02
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func flash(alpha: float, color := Color.WHITE) -> void:
	_flash.color = Color(color, alpha)


func burst(kind: StringName, at: Vector2, strength := 1.0, parent: Node = null) -> void:
	var b: Dictionary = BURSTS.get(kind, BURSTS[&"sparks"])
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.amount = maxi(1, int(b.amount * strength))
	p.lifetime = b.life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = b.speed * 0.5
	p.initial_velocity_max = b.speed
	p.gravity = Vector2(0, b.gravity)
	p.scale_amount_min = b.size
	p.scale_amount_max = b.size
	var ramp := Gradient.new()
	ramp.set_color(0, b.color)
	ramp.set_color(1, Color(b.color, 0.0))
	p.color_ramp = ramp
	p.z_index = 50
	p.process_mode = Node.PROCESS_MODE_ALWAYS	# a talk pausing the game doesn't freeze it mid-air
	p.position = at
	(parent if parent else _world()).add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Amounts stay on the UI; bills share the room's Z ordering below the visitors.
## More money - more bills. All of it keeps going while a talk pauses the game.
func gold_gain(amount: int, at: Vector2, register_at := Vector2.INF) -> void:
	if amount <= 0:
		return
	# Keep the coin sound, replacing the old square burst with animated bills.
	play(&"bar/coin")
	var sparkle := SUCCESS.new()
	sparkle.gold = true
	sparkle.count = clampi(roundi(1.0 + amount / 6.0), 2, 12)
	sparkle.process_mode = Node.PROCESS_MODE_ALWAYS
	sparkle.position = at + Vector2(0, -5)
	sparkle.scale = Vector2.ONE * 0.5
	var destination := at if register_at == Vector2.INF else register_at
	_world().add_child(sparkle)
	sparkle.gold_target = sparkle.to_local(destination)
	var screen_at := ui_point(at)
	if amount >= BIG_PAY:
		zoom(0.015)
	# two payments at once stack their words instead of covering each other
	if Time.get_ticks_msec() - _paid_at > 400:
		_paid = 0
	_paid_at = Time.get_ticks_msec()
	pop_label("+$%d" % amount, screen_at + Vector2(0, -LABEL_OVER - LABEL_STEP * mini(_paid, 3)))
	_paid += 1


## A gold word that pops in zoomed and rises from UI point `at` (its centre), "+$12" over the till.
func pop_label(msg: String, at: Vector2, color := LABEL_GOLD) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_override("font", preload("res://art/fonts/PixelOperator8-Bold.ttf"))
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(100, 14)
	label.position = at.round() - Vector2(50, 7)
	label.pivot_offset = Vector2(50, 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 60
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.scale = Vector2.ONE * 2.0
	_ui_layer(1.6).add_child(label)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rise := label.create_tween()
	rise.tween_method(func(y: float): label.position.y = roundf(y), label.position.y, label.position.y - 10.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.65)
	rise.tween_callback(label.queue_free)


## A camera punch: the room zooms in by `amount` and settles back. Keep it small.
## `lean` > 0 eases in over that many seconds instead of jumping.
func zoom(amount: float, lean := 0.0) -> void:
	var scene := get_tree().current_scene
	var room := scene.get_node_or_null(^"RoomView") if scene else null
	if room:
		room.call(&"punch", amount, lean)


## A room point on the UI grid.
func ui_point(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * at


## Floating text that rises and fades, e.g. "+$12" over the till.
func text(msg: String, at: Vector2, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 16)
	l.position = at + Vector2(-40, -18)
	l.modulate = color
	l.z_index = 60
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	_world().add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 12.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.tween_callback(l.queue_free)


## A canvas layer on the UI grid, under the HUD, that frees itself after `life` seconds
## and never pauses.
func _ui_layer(life: float) -> CanvasLayer:
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 2
	fx_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_world().add_child(fx_layer)
	var cleanup := fx_layer.create_tween()
	cleanup.tween_interval(life)
	cleanup.tween_callback(fx_layer.queue_free)
	return fx_layer


func _process(_delta: float) -> void:
	# hitstop scales delta down, so everything here runs on real time
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now

	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = _scale
	var want := speed if fast else 1.0
	if want != _scale:
		_scale = want
		if _stop_until == 0:
			Engine.time_scale = want

	_flash.color.a = move_toward(_flash.color.a, 0.0, dt * 4.0)

	_trauma = move_toward(_trauma, 0.0, dt * 30.0)
	var cam := get_viewport().get_camera_2d()
	if cam:
		var s := _trauma * shake_scale
		cam.offset = Vector2(_rng.randf_range(-s, s), _rng.randf_range(-s, s)).round()


func _play_sound(id: StringName, volume_db: float) -> void:
	if _sound == null:
		_sound = get_node_or_null(^"/root/SoundSystem")
		if _sound == null:
			return
	_sound.call(&"play", id, volume_db)


func _world() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else self

extends Node
## Every game action goes through Feel.play(&"id", pos): it plays the sound with the
## same id and whatever juice `fx` lists for it. Ids without an entry just make a sound.

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
	&"hit/perfect": {shake = 4.0, hitstop = 0.09, flash = 0.45, burst = &"sparks"},
	&"hit/good": {shake = 2.0, hitstop = 0.05, burst = &"sparks"},
	&"hit/miss": {shake = 3.0, burst = &"glass"},
	&"bar/coin": {burst = &"coins"},
	&"cat/happy": {burst = &"hearts"},
	&"relic/get": {flash = 0.3, burst = &"sparks"},
	&"boss/enter": {shake = 6.0, flash = 0.4},
}

var shake_scale := 1.0

var _trauma := 0.0
var _stop_until := 0
var _last_usec := 0
var _flash: ColorRect
var _sound: Node
var _rng := RandomNumberGenerator.new()


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


func play(id: StringName, at := Vector2.INF, strength := 1.0) -> void:
	var e: Dictionary = fx.get(id, {})
	_play_sound(e.get("sound", id), e.get("volume", 0.0))
	if e.has("shake"):
		shake(e.shake * strength)
	if e.has("hitstop"):
		hitstop(e.hitstop)
	if e.has("flash"):
		flash(e.flash)
	if e.has("burst") and at != Vector2.INF:
		burst(e.burst, at, strength)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 12.0)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.02
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func flash(alpha: float, color := Color.WHITE) -> void:
	_flash.color = Color(color, alpha)


func burst(kind: StringName, at: Vector2, strength := 1.0) -> void:
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
	p.position = at
	_world().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Floating text that rises and fades, e.g. "+$12" over the till.
func text(msg: String, at: Vector2, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 16)
	l.position = at + Vector2(-40, -18)
	l.modulate = color
	l.z_index = 60
	_world().add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 12.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.tween_callback(l.queue_free)


func _process(_delta: float) -> void:
	# hitstop scales delta down, so everything here runs on real time
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now

	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0

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

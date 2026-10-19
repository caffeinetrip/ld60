extends Node2D
## Day / night loop of the week.

@onready var _cafe: Node2D = $Cafe
@onready var _lighting: Node = $Cafe/Lighting
@onready var _day: Node = $Day
@onready var _night: Control = $UI/NightPanel
var _round_end: Control
var _transition: CanvasLayer
var _starting_day := false


func _ready() -> void:
	$Customers.setup(_cafe)
	var room := RoomView.new()
	add_child(room)
	room.show_room(self, $Camera2D)
	room.adopt($Cafe/ScreenFX)
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		dialogue.grade = _lighting.grade.material
	var letterbox := preload("res://scripts/ui/letterbox.gd").new()
	letterbox.name = "Letterbox"
	room.adopt(letterbox)
	add_child(preload("res://scripts/cafe_window_leaf.gd").new())
	add_child(preload("res://scripts/cafe_leaves.gd").new())
	RoomView.room_pixels(_night)
	_round_end = preload("res://scripts/ui/round_end.gd").new()
	_round_end.name = "RoundEnd"
	$UI.add_child(_round_end)
	_transition = preload("res://scripts/ui/day_transition.gd").new()
	_transition.name = "DayTransition"
	add_child(_transition)
	_day.finished.connect(_on_day_finished)
	_night.done.connect(_start_day)
	_cafe.set_entrance_open(false)
	_lighting.night = 1.0
	$Cafe/Props/Cashier.hide()
	$UI.hide()
	if Game.get_meta(&"debug_start_day", false):
		Game.remove_meta(&"debug_start_day")
		$UI.show()
		_night.hide()
		_start_day()
		return
	if Game.get_meta(&"debug_after_boss", false):
		Game.remove_meta(&"debug_after_boss")
		_debug_boss_beaten()
		return
	# Keep volume above the dialogue's full-screen input surface.
	var intro_controls := CanvasLayer.new()
	intro_controls.layer = 60
	add_child(intro_controls)
	var settings := $UI/SettingsButton
	settings.reparent(intro_controls, false)
	settings.set_intro_mode(true)
	var room_grade := _lighting.grade.material as ShaderMaterial
	# Portraits retain the gentle night grade; the empty room is slightly cooler.
	if dialogue:
		dialogue.grade = room_grade.duplicate() as ShaderMaterial
	room_grade.set_shader_parameter("intro_liminal", 1.0)
	await get_tree().process_frame
	Sound.music(&"music/intro.wav", 0.0)
	await _talk(&"intro")
	var settle := create_tween().set_ignore_time_scale(true)
	settle.tween_property(room_grade, "shader_parameter/intro_liminal", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if dialogue:
		dialogue.grade = room_grade
	settings.set_intro_mode(false)
	settings.reparent($UI, false)
	intro_controls.queue_free()
	$UI.show()
	# the first day starts like every other: prepared on the computer
	Sound.music(&"intro2.wav", 0.0)
	_night.open_prep()
	await _fade_night(true, 1.2).finished
	_night.guide(&"prep")


func _start_day() -> void:
	if _starting_day or _day.running:
		return
	_starting_day = true
	Feel.play(&"ui/click")
	Sound.music(&"", 0.6)
	if _night.visible:
		_fade_night(false)
	_lighting.set_night(0.0, 0.9)
	await _transition.cover()
	_night.hide()
	_cafe.set_story_day(Game.day)
	_night.modulate.a = 1.0
	$Cafe/Props/Cashier.show()
	await _transition.reveal()
	await _round_end.present_day(Game.day)
	await _show_machine()
	Sound.music(day_music(Game.day))
	_cafe.set_entrance_open(true)
	_day.start()
	if Game.get_meta(&"debug_bonus_chain", false):
		Game.remove_meta(&"debug_bonus_chain")
		for printer in Game.backpack.items_of(&"receipt_printer"):
			printer.mult = 3
		Game.backpack._changed()
		_day._specials.clear()
		Feel.text("BONUS TEST: printer x3 + amplifier", _day.counter + Vector2(0, -28))
	_starting_day = false


## The first day with the whack upgrade: the light finds the machine for a moment, no talk.
func _show_machine() -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue == null or Game.mod(&"whack") <= 0 or Game.flags.has(&"machine_shown"):
		return
	Game.flags[&"machine_shown"] = true
	var machine := $Machine as Node2D
	await dialogue.spotlight(machine.get_global_transform_with_canvas() * Rect2(-6, -14, 12, 14), Tune.MACHINE_SPOT)


## Day over: the banner (still today's number), then the night - the calendar turns, the
## report comes first, Next brings the story of the day if there is one, then Preparation.
func _on_day_finished(report: Dictionary) -> void:
	_cafe.set_entrance_open(false)
	await _round_end.present(report)
	await _transition.cover()
	Game.next_day()
	_cafe.set_story_day(0)
	_lighting.set_night(1.0, 1.5)
	Sound.music(night_music(Game.day), 1.5)
	Feel.play(&"night/start")
	_night.open_report()
	_fade_night(true)
	await _transition.reveal()
	_night.guide(&"report")
	await _night.report_read

	var beats := Game.director.beats_due()
	var story := Game.director.boss_due()
	for beat in beats:
		story = story or beat.has("dialogue")
	if story:
		await _fade_night(false).finished
		_night.hide()
		_night.modulate.a = 1.0
	for beat in beats:
		if beat.has("event"):
			Game.flags[beat.event] = true
			Game.set_mods(beat.event, Tune.EVENTS.get(beat.event, {}))
		if beat.has("dialogue"):
			await _talk(beat.dialogue)
	if Game.director.boss_due():
		# no dark cover after her talk: the room just lights up for the boss
		_lighting.set_night(0.0, 1.0)
		Sound.music(day_music(Game.day))
		await get_tree().create_timer(1.0).timeout
		await _day.boss_fight()
		await _after_boss()
		return
	_night.open_prep()
	if story:
		_fade_night(true)


## The computer fades in or out as a whole.
func _fade_night(in_: bool, seconds: float = -1.0) -> Tween:
	if in_:
		_night.modulate.a = 0.0
	var tween := create_tween()
	var duration := seconds if seconds >= 0.0 else (0.55 if in_ else 0.35)
	tween.tween_property(_night, "modulate:a", 1.0 if in_ else 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## The boss is beaten: the sister has her say, then the bar goes on for as long as you like
## (endless: no boss, no more talks) from tonight's Preparation.
func _after_boss() -> void:
	await get_tree().create_timer(1.0).timeout
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		var upgrades := 0
		for id in Game.upgrades:
			upgrades += Game.upgrades[id]
		var earned := 0
		for money in Game.earnings:
			earned += money
		dialogue.vars = {days = Game.earnings.size(), earned = earned, sold = Game.sold_total, upgrades = upgrades,
			relics = Game.backpack.items.size() + Game.backpack.pocket.size(), tries = maxi(_day.boss_tries, 1)}
	await _talk(&"win")
	Game.endless = true
	_cafe.set_entrance_open(false)
	await _transition.cover()
	_cafe.set_story_day(0)
	_lighting.set_night(1.0, 0.0)
	Sound.music(night_music(Game.day), 1.0)
	_night.open_prep()
	_fade_night(true)
	await _transition.reveal()


## F3: the day of the boss, the boss at the bar just satisfied, then what comes after.
func _debug_boss_beaten() -> void:
	$UI.show()
	_night.hide()
	_lighting.set_night(0.0, 0.0)
	_cafe.set_story_day(Game.day)
	$Cafe/Props/Cashier.show()
	$Customers.spawn(&"boss")
	await $Customers.at_counter
	$Customers.release_front(Cat.Mood.HAPPY)
	_after_boss()


func _talk(id: StringName) -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		_day._frozen = true
		await dialogue.play(id)
		_day._frozen = false


static func day_music(day: int) -> StringName:
	if day == 5:
		return &"music/prosto.wav"
	return &"ambience.wav" if day == 1 or day == 6 else &"music/day"


## The calendar already points to the upcoming day during the night.
static func night_music(upcoming_day: int) -> StringName:
	return &"ambience2.wav" if upcoming_day == 2 or upcoming_day == 6 else &"music/night"

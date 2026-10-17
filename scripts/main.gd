extends Node2D
## Day / night loop of the week.

@onready var _cafe: Node2D = $Cafe
@onready var _lighting: Node = $Cafe/Lighting
@onready var _day: Node = $Day
@onready var _night: Control = $UI/NightPanel


func _ready() -> void:
	$Customers.setup(_cafe)
	_day.finished.connect(_on_day_finished)
	_night.done.connect(_start_day)
	_cafe.set_entrance_open(false)
	await get_tree().process_frame
	await _talk(&"intro")
	_start_day()


func _start_day() -> void:
	Feel.play(&"ui/click")
	_night.hide()
	Sound.music(&"music/day")
	_lighting.set_night(0.0, 1.0)
	_cafe.set_entrance_open(true)
	_day.start()


func _on_day_finished(_report: Dictionary) -> void:
	_cafe.set_entrance_open(false)
	for beat in Game.director.beats_due():
		if beat.has("dialogue"):
			await _talk(beat.dialogue)
	if Game.director.boss_due():
		await _talk(&"boss")
		await _day.boss_fight()
		await _talk(&"win")
		_night.win("YOU WIN\n\nweek $%d" % Game.week_earned())
		return
	_lighting.set_night(1.0, 1.5)
	Sound.music(&"music/night", 1.5)
	Feel.play(&"night/start")
	_night.open()


func _talk(id: StringName) -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		await dialogue.play(id)

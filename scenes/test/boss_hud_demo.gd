extends Node2D
## BossHud on its own. LMB hits the boss, an empty bar goes to the next stage; RMB takes
## a life, none left starts over.

const HP := 100
const HIT := 35
const LIVES := 3
const STAGES := 2

@onready var _boss: Cat = $Boss
@onready var _hud: BossHud = $Boss/Hud
@onready var _info: Label = $UI/Info

var _stage := 0


func _ready() -> void:
	_boss.kind = &"boss"
	_reset()
	if OS.get_cmdline_user_args().has("capture"):
		_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_hit()
		MOUSE_BUTTON_RIGHT:
			if _hud.lives > 0:
				_hud.set_lives(_hud.lives - 1)
			else:
				_reset()
	_refresh()


func _hit() -> void:
	if _hud.hp > 0:
		_hud.set_hp(_hud.hp - HIT)
	elif _stage + 1 < STAGES:
		_stage += 1
		_hud.set_hp(HP)
		_hud.set_stage(_stage, STAGES)
	else:
		_reset()


func _reset() -> void:
	_stage = 0
	_hud.setup(HP, LIVES)
	_hud.set_stage(0, STAGES)
	_refresh()


func _refresh() -> void:
	_info.text = "LMB hit (-%d)\nRMB lose a life\nhp %d  lives %d  stage %d/%d" % [
		HIT, _hud.hp, _hud.lives, _stage + 1, STAGES]


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	await get_tree().create_timer(0.3).timeout
	await _shot("full")
	_hit()
	await get_tree().process_frame
	await _shot("hit")
	await get_tree().create_timer(0.6).timeout
	await _shot("drained")
	_hud.set_lives(1)
	await get_tree().create_timer(0.12).timeout
	await _shot("life_lost")
	_hit()
	_hit()
	await get_tree().create_timer(0.6).timeout
	await _shot("empty")
	_hit()
	await get_tree().create_timer(0.6).timeout
	await _shot("stage_2")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/boss_hud_%s.png" % label)

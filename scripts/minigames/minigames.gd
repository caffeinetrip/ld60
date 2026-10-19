class_name MiniGames
extends Control
## Plays a minigame by id over the game, frees it after.
## `var r := await mini_games.play(&"hit_bar")` -> {tier, quality}

const GAMES := {
	&"hit_bar": preload("res://scripts/minigames/hit_bar.gd"),
	&"kick": preload("res://scripts/minigames/kick.gd"),
}

var current: MiniGame
var _shade: TextureRect
var _shade_tween: Tween


func _focus_bar(focused: bool) -> void:
	if is_instance_valid(_shade):
		if _shade_tween:
			_shade_tween.kill()
		_shade_tween = create_tween()
		_shade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_shade_tween.tween_property(_shade, "modulate:a", 1.0 if focused else 0.0, 0.8)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	material = HudStyle.run_material()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
	gradient.colors = PackedColorArray([Color(0.025, 0.02, 0.04, 0.4), Color(0.025, 0.02, 0.04, 0.34), Color(0.025, 0.02, 0.04, 0.25), Color(0.025, 0.02, 0.04, 0.25)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	_shade = TextureRect.new()
	_shade.texture = texture
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	_shade.modulate.a = 0.0
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


## Run difficulty fills in a missing `difficulty`; `pace` and `zone` get the
## hit_slow / hit_zone mods multiplied in.
func play(id: StringName, params := {}) -> Dictionary:
	var p := params.duplicate()
	p["difficulty"] = p.get("difficulty", Game.difficulty())
	p["pace"] = p.get("pace", 1.0) * maxf(0.3, 1.0 - Game.mod(&"hit_slow"))
	p["zone"] = p.get("zone", 1.0) * (1.0 + Game.mod(&"hit_zone"))
	current = GAMES[id].new()
	add_child(current)
	_focus_bar(true)
	var r: Dictionary = await current.run(p)
	_focus_bar(false)
	current.queue_free()
	current = null
	return r

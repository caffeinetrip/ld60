class_name MiniGames
extends Control
## Plays a minigame by id over the game, frees it after.
## `var r := await mini_games.play(&"hit_bar")` -> {tier, quality}

const GAMES := {
	&"hit_bar": preload("res://scripts/minigames/hit_bar.gd"),
}

var current: MiniGame


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


## Run difficulty fills in a missing `difficulty`; `pace` and `zone` get the
## hit_slow / hit_zone mods multiplied in.
func play(id: StringName, params := {}) -> Dictionary:
	var p := params.duplicate()
	p["difficulty"] = p.get("difficulty", Game.difficulty())
	p["pace"] = p.get("pace", 1.0) * maxf(0.3, 1.0 - Game.mod(&"hit_slow"))
	p["zone"] = p.get("zone", 1.0) * (1.0 + Game.mod(&"hit_zone"))
	current = GAMES[id].new()
	add_child(current)
	var r: Dictionary = await current.run(p)
	current.queue_free()
	current = null
	return r

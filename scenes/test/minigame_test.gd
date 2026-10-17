extends Node2D
## Sandbox for tuning minigames. LMB plays, wheel changes difficulty, RMB next game.

@onready var _games: MiniGames = $UI/MiniGames
@onready var _info: Label = $UI/Info

var _ids: Array = MiniGames.GAMES.keys()
var _index := 0
var _difficulty := 0.0
var _busy := false
var _log: Array[String] = []


func _ready() -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or _busy:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_go()
		MOUSE_BUTTON_RIGHT:
			_index = (_index + 1) % _ids.size()
		MOUSE_BUTTON_WHEEL_UP:
			_difficulty = minf(_difficulty + 0.1, 1.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			_difficulty = maxf(_difficulty - 0.1, 0.0)
	_refresh()


func _go() -> void:
	_busy = true
	var r := await _games.play(_ids[_index], {difficulty = _difficulty})
	_log.push_front("%s %.2f" % [r.tier, r.quality])
	if _log.size() > 4:
		_log.pop_back()
	_busy = false
	_refresh()


func _refresh() -> void:
	_info.text = "%s (RMB)\ndifficulty %.1f (wheel)\nclick to play\n%s" % [
		_ids[_index], _difficulty, "\n".join(_log)]

extends Node2D
## Sandbox for the timing bar. LMB starts a bar, wheel changes difficulty.

@onready var _bar: HitBar = $UI/HitBar
@onready var _info: Label = $UI/Info

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
		MOUSE_BUTTON_WHEEL_UP:
			_difficulty = minf(_difficulty + 0.1, 1.0)
			_refresh()
		MOUSE_BUTTON_WHEEL_DOWN:
			_difficulty = maxf(_difficulty - 0.1, 0.0)
			_refresh()


func _go() -> void:
	_busy = true
	var r := await _bar.run(_params())
	_log.push_front("%s %.2f" % [r.tier, r.quality])
	if _log.size() > 4:
		_log.pop_back()
	_busy = false
	_refresh()


func _params() -> Dictionary:
	return {
		speed = lerpf(120.0, 240.0, _difficulty),
		good_zone = lerpf(0.40, 0.22, _difficulty),
		perfect_zone = lerpf(0.12, 0.05, _difficulty),
	}


func _refresh() -> void:
	_info.text = "difficulty %.1f  (wheel)\nclick to pour\n%s" % [_difficulty, "\n".join(_log)]

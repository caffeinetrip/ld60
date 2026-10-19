extends Control
## The day tray: waiting cats, a filling tumbler and today's tips. The timing game replaces it.

const HOURGLASS := preload("res://art/ui/hud/hourglass.png")
const HEADS := 5			# more waiting -> "+n"
const TIPS_FULL := 100.0	# income that fills the jar
const CORNER := 16			# the timer sits in the bottom left corner,
const MIDDLE := 344			# level with the buttons in the other one
const TIMER_FONT_SIZE := HudStyle.RUN_FONT_SIZE
const INCOME_FONT_SIZE := HudStyle.RUN_FONT_SIZE
const COUNTER_BASE := 334

@export var day_path: NodePath
@export var games_path: NodePath

var _day: Node
var _games: MiniGames
var _income := -1
var _bump := 0.0
var _cats: Dictionary = {}
var _shown_income := 0.0
var _extra := 0
var _extra_alpha := 0.0
var _income_at := Vector2(376, COUNTER_BASE)
var _guide := 0.0			# the timer alone at night while the sister points at it
var _dialogue: Node


func _ready() -> void:
	_day = get_node(day_path)
	_games = get_node(games_path)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = PROCESS_MODE_ALWAYS		# the tips number finishes its hop during a talk
	var worn: ShaderMaterial = HudStyle.run_material()
	worn.set_shader_parameter(&"cell", 2.0)
	material = worn
	hide()
	preload("res://scripts/ui/appear.gd").attach(self)
	_dialogue = get_node_or_null(^"/root/Dialogue")
	if _dialogue:
		_dialogue.spots[&"timer"] = func(): return Rect2(global_position + Vector2(CORNER - 2, MIDDLE - 7), Vector2(16 + _timer_width(), 14))


func _process(delta: float) -> void:
	var pointed: bool = _dialogue != null and _dialogue.pointing == &"timer"
	_guide = move_toward(_guide, 1.0 if pointed and not _day.running else 0.0, delta / 0.3)
	visible = _day.running or _guide > 0.0
	if not _day.running:
		queue_redraw()
		_cats.clear()
		_income = -1
		_extra_alpha = 0.0
		_bump = 0.0
		return
	if _income < 0:
		_shown_income = Game.today.revenue
		_income_at = Vector2(376, COUNTER_BASE)
	if _income >= 0 and Game.today.revenue != _income:
		_bump = 1.0
	_income = Game.today.revenue
	_bump = maxf(_bump - delta / 0.3, 0.0)
	_shown_income = lerpf(_shown_income, float(_income), 1.0 - exp(-delta * 22.0))
	_update_cats(delta)
	queue_redraw()


func _update_cats(delta: float) -> void:
	var line: Array = _day._customers.line() if _day._customers else []
	var total: int = _day.queue_size()
	var count := mini(total, HEADS)
	var active := {}
	var weight := 1.0 - exp(-delta * 22.0)
	for i in count:
		var id: int = line[i].get_instance_id() if i < line.size() else -(i + 1)
		var fur: Color = line[i].body_color() if i < line.size() else Cat.COLORS[0]
		active[id] = {fur = fur.darkened(0.25), x = 306 - count * 19 + i * 19}
	# Keep the actual queue order. Let departing cats clear before closing gaps.
	var departing := false
	for id in _cats.keys():
		var icon: Dictionary = _cats[id]
		if not active.has(id):
			icon.alpha = move_toward(icon.alpha, 0.0, delta / 0.12)
			if icon.alpha <= 0.0:
				_cats.erase(id)
				continue
			departing = true
	if not departing:
		for id in active:
			if _cats.has(id):
				var icon: Dictionary = _cats[id]
				icon.at.x = move_toward(icon.at.x, active[id].x, delta * 160.0)
	for id in active:
		if not _cats.has(id):
			var clear := not departing
			for other in _cats.values():
				if absf(other.at.x - active[id].x) < 18.0:
					clear = false
			if not clear:
				continue
			_cats[id] = {at = Vector2(active[id].x, COUNTER_BASE - 14), alpha = 0.0, fur = active[id].fur}
		var icon: Dictionary = _cats[id]
		icon.at.y = lerpf(icon.at.y, COUNTER_BASE - 16, weight)
		icon.alpha = move_toward(icon.alpha, 1.0, delta / 0.14)
	if total > HEADS:
		_extra = total - HEADS
	_extra_alpha = move_toward(_extra_alpha, 1.0 if total > HEADS else 0.0, delta / 0.14)
	var income := "+$%d" % roundi(_shown_income)
	var width := HudStyle.TALK_FONT.get_string_size(income, HORIZONTAL_ALIGNMENT_LEFT, -1, INCOME_FONT_SIZE).x
	var target := Vector2(320 - width * 0.5, 353) if width > 39 else Vector2(376, COUNTER_BASE)
	_income_at = _income_at.lerp(target, weight)


## queue, sold, income, spilled.
func numbers() -> Array:
	return [_day.queue_size(), Game.today.sold, Game.today.revenue, Game.today.spilled]


func _draw() -> void:
	if _day.running and _games.current == null:
		_draw_counter()

	var left_s := _time_left()
	var col := HudStyle.RUN_TEXT if left_s > 5.0 else HudStyle.RUN_BRIGHT
	if not _day.running:
		col.a = _guide
	draw_texture(HOURGLASS, Vector2(CORNER, MIDDLE - 4), col)
	draw_string(HudStyle.TALK_FONT, Vector2(CORNER + 12, MIDDLE + 4),
		"%.1f" % left_s, HORIZONTAL_ALIGNMENT_LEFT, -1, TIMER_FONT_SIZE, col)


## Before the day starts the whole day is left.
func _time_left() -> float:
	return maxf(Game.day_length() - (_day.time if _day.running else 0.0), 0.0)


func _timer_width() -> float:
	return HudStyle.TALK_FONT.get_string_size("%.1f" % _time_left(), HORIZONTAL_ALIGNMENT_LEFT, -1, TIMER_FONT_SIZE).x


func _draw_counter() -> void:
	HudStyle.RUN_ART.wood(self, Rect2(206, 314, 208, 28))
	for icon in _cats.values():
		var alpha: float = smoothstep(0.0, 1.0, icon.alpha)
		var fur: Color = icon.fur
		fur.a = alpha
		draw_texture(HudStyle.RUN_ART.CAT_BASE, icon.at, Color(1, 1, 1, alpha))
		draw_texture(HudStyle.RUN_ART.CAT_FUR, icon.at, fur)
	# The glass has a 2 px dark outline below its visible foot.
	HudStyle.RUN_ART.glass(self, Vector2(308, COUNTER_BASE - 30), _day.order)
	HudStyle.RUN_ART.jar(self, Vector2(344, COUNTER_BASE - 30), _shown_income / TIPS_FULL)
	if _extra_alpha > 0.0:
		var queue_at := Vector2(232, 312 + 3.0 * (1.0 - _extra_alpha))
		var color := HudStyle.RUN_TEXT
		color.a = smoothstep(0.0, 1.0, _extra_alpha)
		draw_string(HudStyle.TALK_FONT, queue_at, "+%d" % _extra, HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.RUN_FONT_SIZE, color)
	var pulse := sin(_bump * PI)
	var income := "+$%d" % roundi(_shown_income)
	var at := _income_at - Vector2(0, 2.0 * pulse)
	var ink := HudStyle.RUN_TEXT.lerp(HudStyle.RUN_BRIGHT, pulse * 0.6)
	draw_string(HudStyle.TALK_FONT, at, income, HORIZONTAL_ALIGNMENT_LEFT, -1, INCOME_FONT_SIZE, ink)

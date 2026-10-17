extends PanelContainer
## Placeholder bottom bar for the day: open time, order in progress, today's numbers.

@export var day_path: NodePath

var _day: Node
var _open := ProgressBar.new()
var _order := ProgressBar.new()
var _stats := Label.new()


func _ready() -> void:
	_day = get_node(day_path)
	position = Vector2(4, 148)
	size = Vector2(312, 30)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	add_child(rows)
	var bars := HBoxContainer.new()
	rows.add_child(bars)
	for pair in [["Open", _open], ["Order", _order]]:
		var label := Label.new()
		label.text = pair[0]
		bars.add_child(label)
		var bar: ProgressBar = pair[1]
		bar.max_value = 1.0
		bar.step = 0.0
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bars.add_child(bar)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_stats)
	_ignore_mouse(self)
	hide()


func _process(_delta: float) -> void:
	visible = _day.running
	if not visible:
		return
	_open.value = _day.open_time()
	_order.value = _day.order
	_stats.text = "Queue: %d  Sale: %d  Income: $%d  Left: %d" % [
		_day.queue_size(), Game.today.sold, Game.today.revenue, Game.today.spilled]


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

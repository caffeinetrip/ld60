extends CanvasLayer
## Plain black bars around the room, with no edge fade. The HUD sits above them.

const TOP := 26			# black ends here
const BOTTOM := 138		# black starts here


func _ready() -> void:
	layer = 15
	var bars := Control.new()
	bars.name = "Bars"
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.draw.connect(_draw_bars.bind(bars))
	add_child(bars)


func _draw_bars(bars: Control) -> void:
	bars.draw_rect(Rect2(0, 0, bars.size.x, TOP), Color.BLACK)
	bars.draw_rect(Rect2(0, BOTTOM, bars.size.x, bars.size.y - BOTTOM), Color.BLACK)

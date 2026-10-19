class_name RoomView
extends CanvasLayer
## Two pixel sizes (owner 2026-10-17): the room is drawn at 320x180 in its own viewport and
## shown 2x, the UI is drawn over it on the window's 640x360 - a UI pixel is half a room pixel.
## The room's nodes stay where they are: the viewport shares the window's 2D world and the
## window skips them (render layer 2 on the room's root). The camera zooms 2x, so clicks and
## get_global_transform_with_canvas() come out in UI pixels.

const SIZE := Vector2i(320, 180)
const SCALE := 2
const ROOM_LAYER := 1		# bit index of render layer 2

var view := SubViewport.new()
var _screen := TextureRect.new()
var _punch: Tween


func _init() -> void:
	name = "RoomView"
	layer = 1


func _ready() -> void:
	view.size = SIZE
	view.world_2d = get_viewport().world_2d
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	_screen.texture = view.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.size = Vector2(SIZE * SCALE)
	_screen.pivot_offset = _screen.size * 0.5
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	RenderingServer.frame_pre_draw.connect(_follow_camera)


func _exit_tree() -> void:
	get_viewport().set_canvas_cull_mask_bit(ROOM_LAYER, true)


## `room` and everything under it is drawn here, not in the window; `camera` frames it.
func show_room(room: CanvasItem, camera: Camera2D) -> void:
	room.visibility_layer = 1 << ROOM_LAYER
	get_viewport().set_canvas_cull_mask_bit(ROOM_LAYER, false)
	camera.zoom = Vector2.ONE * SCALE


## The camera punches in by `amount` (0.02 = 2 %) and eases back (Feel.zoom); with `lean`
## it eases in over that many seconds first.
func punch(amount: float, lean := 0.0) -> void:
	if _punch:
		_punch.kill()
	_punch = create_tween()
	if lean > 0.0:
		_punch.tween_property(_screen, "scale", Vector2.ONE * (1.0 + amount), lean).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_punch.tween_property(_screen, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	_screen.scale = Vector2.ONE * (1.0 + amount)
	_punch.tween_property(_screen, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A canvas layer that belongs to the picture (grade, black bars) moves in here.
func adopt(picture: CanvasLayer) -> void:
	if picture.is_inside_tree():
		picture.reparent(view, false)
	else:
		view.add_child(picture)


## UI drawn for room pixels (the computer): shown 2x, top left.
static func room_pixels(ui: Control) -> void:
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.position = Vector2.ZERO
	ui.size = SIZE
	ui.scale = Vector2.ONE * SCALE


func _follow_camera() -> void:
	if not is_inside_tree():
		return	# a reloaded scene's old view, about to be freed
	view.canvas_transform = get_viewport().canvas_transform.scaled(Vector2.ONE / SCALE)

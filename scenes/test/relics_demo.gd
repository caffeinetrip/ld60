extends Node2D
## Relic sandbox: the night panel's Inventory with every relic in the pocket on the
## biggest grid. `-- capture` lays out a backpack and saves shots to build/shots/.

const LAYOUT := [
	[&"amplifier", Vector2i(0, 0), 0], [&"receipt_printer", Vector2i(0, 1), 0],
	[&"cctv", Vector2i(2, 1), 0], [&"pos_terminal", Vector2i(3, 0), 0],
	[&"pager", Vector2i(3, 2), 0], [&"scoreboard", Vector2i(3, 3), 0],
	[&"power_strip", Vector2i(4, 1), 1], [&"arcade", Vector2i(5, 0), 0],
	[&"fuse_box", Vector2i(0, 2), 0], [&"crt_tv", Vector2i(1, 3), 0],
	[&"wire_tangle", Vector2i(2, 2), 0],
]

var _view: BackpackView


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var night: Control = $Main.get_node("UI/NightPanel")
	night.open_prep()
	night._tabs.current_tab = 2
	_view = night.find_children("*", "BackpackView", true, false)[0]
	Game.set_mods(&"demo", {grid = 3})
	if not OS.get_cmdline_user_args().has("capture"):
		for id in Relics.DEFS:
			Game.backpack.add_to_pocket(id)
		return
	for row in LAYOUT:
		Game.backpack.place(row[0], row[1], row[2])
	for id in [&"cash_register", &"boombox", &"calculator", &"equalizer", &"pc_tower"]:
		Game.backpack.add_to_pocket(id)
	await _hover(Vector2(8, 8))
	await _shot("amplifier")
	await _hover(Vector2(2, 1) * 16 + Vector2(8, 8))
	await _shot("cctv")
	await _hover(Vector2(3, 0) * 16 + Vector2(8, 8))
	await _shot("pos")
	await _hover(Vector2(4, 1) * 16 + Vector2(8, 8))
	await _shot("strip")
	await _hover(_view._top_left(Game.backpack.pocket[-1], false) + Vector2(5, 5))
	await _shot("pocket")
	_view._hold(&"wire_tangle", 0, {})
	await _hover(Vector2(4, 0) * 16 + Vector2(8, 8))
	await _shot("held")
	await _hover(Vector2(4, 3) * 16 + Vector2(8, 8))
	await _shot("held_blocked")
	_view._put_back()
	Game.backpack.clear()
	Game.set_mods(&"demo", {})
	Game.backpack.place(&"cash_register", Vector2i(0, 0), 0)
	Game.backpack.place(&"boombox", Vector2i(2, 2), 0)
	Game.backpack.place(&"cctv", Vector2i(2, 1), 0)
	for id in [&"pager", &"crt_tv", &"scoreboard"]:
		Game.backpack.add_to_pocket(id)
	await _hover(Vector2(2, 2) * 16 + Vector2(8, 8))
	await _shot("small")
	get_tree().quit()


func _hover(at: Vector2) -> void:
	get_viewport().warp_mouse(_view.global_position + at)
	await get_tree().process_frame
	_view._refresh()


func _shot(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/relics_%s.png" % label)

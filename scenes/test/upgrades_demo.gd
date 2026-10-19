extends Node2D


func _ready() -> void:
	if OS.get_cmdline_user_args().has("capture"):
		_capture.call_deferred()


func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var main := $Main
	var day: Node = main.get_node("Day")
	var machine: Node = main.get_node("Machine")
	var night: Control = main.get_node("UI/NightPanel")
	Game.money = 10000
	main._start_day()
	await get_tree().create_timer(1.5).timeout
	Game.buy_upgrade(&"whack")
	Game.flags[&"newspaper"] = true
	day._spawn_in = 1000.0
	main.get_node("Customers").spawn()
	day._spawned = 1
	await get_tree().create_timer(8.0).timeout
	machine.whack()
	await get_tree().create_timer(0.2).timeout
	await _shot("room")
	machine.break_now()
	await get_tree().create_timer(0.3).timeout
	await _shot("broken")
	day._end(&"time")
	while not (night.visible and night._tabs.current_tab == night.REPORT):
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	night._on_report_next()
	night._tabs.current_tab = 3
	await _shot("upgrades")
	night._tabs.current_tab = 1
	Game.target = 200
	night._refresh()
	await _shot("preparation")
	get_tree().quit()


func _shot(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/upgrades_%s.png" % label)

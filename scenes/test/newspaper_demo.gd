extends Node2D


func _ready() -> void:
	if OS.get_cmdline_user_args().has("capture"):
		_capture.call_deferred()


func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var day: Node = $Main/Day
	var customers: Customers = $Main/Customers
	day._spawn_in = 10000.0
	var cat := customers.spawn(&"homeless")
	customers.spawn()
	day._spawned = 1
	await get_tree().create_timer(10.0).timeout
	cat.say("Spare a drink?", 4.0)
	await _shot("queue")
	customers.kick_result(cat, &"good")
	await get_tree().create_timer(0.25).timeout
	await _shot("kick")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/newspaper_%s.png" % label)

extends Node2D

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _spawn_in := 0.0
var _serve_in := 0.8
var _count := 0
var _shot := 0


func _ready() -> void:
	$Customers.setup($Cafe)
	$Cafe.set_entrance_open(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_in -= delta
	if _spawn_in <= 0.0 and $Customers.waiting() < $Customers.max_queue():
		_spawn_in = 1.0
		_count += 1
		$Customers.spawn(&"special" if _count % 5 == 0 else &"normal")
	if $Customers.front():
		_serve_in -= delta
		if _serve_in <= 0.0:
			$Customers.release_front(_rng.randi_range(0, 2))
			_serve_in = 0.8
	if _shot < 2 and _elapsed >= 9.0 + _shot * 9.0:
		_shot += 1
		_capture(_shot)
	if _elapsed > 24.0 and OS.get_cmdline_user_args().has("capture"):
		get_tree().quit()


func _capture(index: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/customers_%d.png" % index)

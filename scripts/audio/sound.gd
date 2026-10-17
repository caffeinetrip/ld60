class_name Sound
extends RefCounted


static func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var system := _system()
	if system != null:
		system.call(&"play", id, volume_db, pitch)


static func music(id: StringName, fade: float = 1.0) -> void:
	var system := _system()
	if system != null:
		system.call(&"music", id, fade)


static func set_bus_volume(bus: StringName, linear: float) -> void:
	var system := _system()
	if system != null:
		system.call(&"set_bus_volume", bus, linear)


static func get_bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return AudioServer.get_bus_volume_linear(index)


static func _system() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"SoundSystem") if tree != null else null

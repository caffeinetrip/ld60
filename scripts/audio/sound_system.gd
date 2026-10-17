extends Node

const POOL_SIZE := 12
const SETTINGS := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

var _rng := RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _folders: Dictionary[StringName, PackedStringArray] = {}
var _last: Dictionary[StringName, int] = {}
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[StringName, bool] = {}
var _next := 0
var _music_slot := 0
var _music_id: StringName = &""
var _fade: Tween
var _settings := ConfigFile.new()


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_rng.randomize()
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	var error := _settings.load(SETTINGS)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Sound: could not read settings (%s)" % error)
	for bus in BUSES:
		var value: Variant = _settings.get_value("audio", String(bus), 1.0)
		if value is float or value is int:
			_apply_volume(bus, float(value))
	for i in POOL_SIZE:
		_players.append(_new_player(&"SFX"))
	for i in 2:
		_music_players.append(_new_player(&"Music"))


func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if String(id).begins_with("music/"):
		music(id)
		return
	var stream := _pick(id, false)
	if stream == null:
		return
	var player := _players[_next]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	_next = (_players.find(player) + 1) % POOL_SIZE
	player.stop()
	player.stream = stream
	player.volume_db = volume_db - (20.0 if id == &"cat/step" else 0.0)
	player.pitch_scale = maxf(0.01, pitch) * _rng.randf_range(0.95, 1.05)
	player.play()


func music(id: StringName, fade: float = 1.0) -> void:
	if id == _music_id:
		return
	var stream: AudioStream
	if id != &"":
		stream = _pick(id, true)
		if stream == null:
			return
	if _fade != null:
		_fade.kill()
	_music_id = id
	var incoming: AudioStreamPlayer
	if stream != null:
		_music_slot = 1 - _music_slot
		incoming = _music_players[_music_slot]
		incoming.stop()
		incoming.stream = stream
		incoming.pitch_scale = 1.0
		incoming.volume_linear = 0.0
		incoming.play()
	_fade = create_tween().set_parallel(true).set_ignore_time_scale(true)
	for player in _music_players:
		var target := 1.0 if player == incoming else 0.0
		if fade <= 0.0:
			player.volume_linear = target
			if target == 0.0:
				player.stop()
		else:
			_fade.tween_property(player, "volume_linear", target, fade)
	if fade <= 0.0:
		_fade.kill()
	else:
		_fade.chain().tween_callback(_stop_silent_music)


func set_bus_volume(bus: StringName, linear: float) -> void:
	if bus not in BUSES or not is_finite(linear):
		return
	_apply_volume(bus, linear)
	_settings.set_value("audio", String(bus), clampf(linear, 0.0, 1.0))
	var error := _settings.save(SETTINGS)
	if error != OK:
		push_warning("Sound: could not save settings (%s)" % error)


func _apply_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	var level := clampf(linear, 0.0, 1.0) if is_finite(linear) else 1.0
	AudioServer.set_bus_mute(index, level == 0.0)
	AudioServer.set_bus_volume_linear(index, maxf(level, 0.0001))


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _stop_silent_music() -> void:
	for player in _music_players:
		if player.volume_linear < 0.0001:
			player.stop()


func _pick(id: StringName, looping: bool) -> AudioStream:
	if not _folders.has(id):
		var paths := PackedStringArray()
		var folder := "res://audio/" + String(id)
		if DirAccess.dir_exists_absolute(folder):
			for file in ResourceLoader.list_directory(folder):
				if file.get_extension().to_lower() in ["wav", "ogg"]:
					paths.append(folder.path_join(file))
		paths.sort()
		_folders[id] = paths
	var choices := _folders[id]
	if choices.is_empty():
		if not _warned.has(id):
			push_warning("Sound: no audio files for '%s'" % id)
			_warned[id] = true
		return null
	var previous: int = _last.get(id, -1)
	var index := _rng.randi_range(0, choices.size() - 2) if choices.size() > 1 and previous >= 0 else _rng.randi_range(0, choices.size() - 1)
	if choices.size() > 1 and previous >= 0 and index >= previous:
		index += 1
	_last[id] = index
	var path := choices[index]
	var key := path + (":loop" if looping else "")
	if not _streams.has(key):
		var stream := load(path) as AudioStream
		if stream == null:
			return null
		if looping:
			stream = stream.duplicate() as AudioStream
			if stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
		_streams[key] = stream
	return _streams[key]

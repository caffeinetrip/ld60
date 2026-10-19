extends Node

const POOL_SIZE := 32
# spammy sounds keep to a few voices and are the first to give theirs away
const LIMITS: Dictionary[StringName, int] = {&"cat/step": 3}
const SETTINGS := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
# every sfx plays at a random pitch within +-this (music stays in tune)
const PITCH_JITTER := 0.2

var _rng := RandomNumberGenerator.new()
var _players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _folders: Dictionary[StringName, PackedStringArray] = {}
var _last: Dictionary[StringName, int] = {}
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[StringName, bool] = {}
var _ids: Dictionary[AudioStreamPlayer, StringName] = {}
var _ends: Dictionary[AudioStreamPlayer, int] = {}
var _starts: Dictionary[AudioStreamPlayer, int] = {}
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
	var player := _voice(id)
	if player == null:
		return
	player.stop()
	player.stream = stream
	player.volume_db = volume_db - (20.0 if id == &"cat/step" else 0.0)
	player.pitch_scale = maxf(0.01, pitch) * _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	player.play()
	var now := Time.get_ticks_msec()
	_ids[player] = id
	_starts[player] = now
	_ends[player] = now + int(stream.get_length() / player.pitch_scale * 1000.0) + 50


# On web the samples play in the browser and `playing` can lag, so the end time is ours.
func _busy(player: AudioStreamPlayer, now: int) -> bool:
	return player.playing and _ends.get(player, 0) > now


# A free player; else the same id's oldest one when it is over its limit;
# else the oldest limited sound; else the sound closest to its end.
func _voice(id: StringName) -> AudioStreamPlayer:
	var now := Time.get_ticks_msec()
	var limit: int = LIMITS.get(id, POOL_SIZE)
	var same: Array[AudioStreamPlayer] = []
	var free: AudioStreamPlayer
	for player in _players:
		if not _busy(player, now):
			if free == null:
				free = player
		elif _ids.get(player) == id:
			same.append(player)
	if same.size() >= limit:
		same.sort_custom(func(a, b): return _starts[a] < _starts[b])
		return same[0]
	if free != null:
		return free
	var best: AudioStreamPlayer
	for player in _players:
		if LIMITS.has(_ids.get(player, &"")) and (best == null or _starts[player] < _starts[best]):
			best = player
	if best != null:
		return best
	if id in LIMITS:
		return null
	for player in _players:
		if best == null or _ends[player] < _ends[best]:
			best = player
	return best


func music(id: StringName, fade: float = 1.0, quiet_intro: bool = false) -> void:
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
		elif quiet_intro and player == incoming:
			# Fade in perceived loudness, with a quiet first half and soft endpoints.
			player.volume_db = -60.0
			_fade.tween_property(player, "volume_db", -32.0, fade * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_fade.tween_property(player, "volume_db", 0.0, fade * 0.5).from(-32.0).set_delay(fade * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			_fade.tween_property(player, "volume_linear", target, minf(fade, 0.6) if quiet_intro else fade)
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
		if folder.get_extension().to_lower() in ["wav", "ogg"] and ResourceLoader.exists(folder):
			paths.append(folder)
		elif DirAccess.dir_exists_absolute(folder):
			for file in ResourceLoader.list_directory(folder):
				if file.get_extension().to_lower() in ["wav", "ogg"]:
					paths.append(folder.path_join(file))
		paths.sort()
		_folders[id] = paths
	var choices := _folders[id]
	if choices.is_empty():
		# headless = tests and builds: a sound that isn't made yet is just silent there
		if not _warned.has(id) and DisplayServer.get_name() != "headless":
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

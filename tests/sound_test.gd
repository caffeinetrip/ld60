extends "res://tests/suite.gd"

# every id the game plays right now
const PLAYED := [
	&"day/start", &"day/end", &"night/start", &"bar/pour", &"bar/coin", &"relic/get",
	&"boss/enter", &"game/win", &"hit/start", &"hit/perfect", &"hit/good", &"hit/meh",
	&"hit/miss", &"ui/click", &"ui/buy", &"ui/error", &"music/day", &"music/night",
]


func test_every_sound_has_files() -> void:
	for id in PLAYED:
		var files := Array(ResourceLoader.list_directory("res://audio/" + id)).filter(
			func(f: String): return f.get_extension() in ["wav", "ogg"])
		check(not files.is_empty(), "audio/%s has no wav/ogg" % id)


func test_every_sound_plays() -> void:
	for id in PLAYED:
		Feel.play(id)
	await frames(2)
	check(true, "no warnings")

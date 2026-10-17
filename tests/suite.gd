extends RefCounted
## Base for tests/*_test.gd. Every test_* method runs on a fresh Game.new_run(), in file
## order, and may await. Any engine error or warning while it runs fails it too.

var tree: SceneTree
var failures := PackedStringArray()

var _listening: Array[Array] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [what, expected, actual])


func near(actual: float, expected: float, what: String, eps := 0.001) -> void:
	if absf(actual - expected) > eps:
		failures.append("%s: expected %.3f, got %.3f" % [what, expected, actual])


## Collects the first argument of every emission until the test ends.
func record(sig: Signal) -> Array:
	var got := []
	var f := func(a: Variant = null, _b: Variant = null) -> void: got.append(a)
	sig.connect(f)
	_listening.append([sig, f])
	return got


func drop_listeners() -> void:
	for pair in _listening:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_listening.clear()


func frames(n := 1) -> void:
	for i in n:
		await tree.process_frame


## Waits up to `seconds` of game time for `done` to return true. Game time, because
## hitstop slows it down by real milliseconds, and headless frames are much faster.
func wait_for(done: Callable, seconds := 30.0) -> bool:
	var t := 0.0
	var frames_left := int(seconds * 60.0 * 20.0)
	while t < seconds and frames_left > 0:
		if done.call():
			return true
		await tree.process_frame
		t += tree.root.get_process_delta_time()
		frames_left -= 1
	return done.call()


## Left click at a point of the 320x180 viewport, through the real input path.
func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		tree.root.push_input(e, true)

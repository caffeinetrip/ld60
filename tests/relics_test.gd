extends "res://tests/suite.gd"

var bp: Backpack


func before_each() -> void:
	bp = Game.backpack


func test_defs() -> void:
	for id in Relics.DEFS:
		var d: Dictionary = Relics.DEFS[id]
		check(Relics.RARITY_COLOR.has(d.rarity), "%s rarity" % id)
		check(not d.tags.is_empty(), "%s tags" % id)
		check(d.shape.has(Vector2i.ZERO), "%s shape starts at 0,0" % id)
		for s in d.stars:
			check(not d.shape.has(s), "%s star %s outside the shape" % [id, s])
		for key in d.mods.keys() + d.star_mods.keys():
			check(Relics.MOD_TEXT.has(key), "%s mod %s has text" % [id, key])
		check(Relics.info(id).contains(d.name), "%s info" % id)
	var rng := RandomNumberGenerator.new()
	for rarity in Relics.RARITY_COLOR:
		eq(Relics.get_def(Relics.roll(rarity, rng)).rarity, rarity, "roll %s" % rarity)


func test_turn() -> void:
	var t := Backpack.turned(&"bar_spoon", 1)
	eq(t[0], [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)] as Array[Vector2i], "standing up")
	eq(t[1], [Vector2i(-1, 0), Vector2i(-1, 2)] as Array[Vector2i], "stars follow")
	eq(Backpack.turned(&"bar_spoon", 4), Backpack.turned(&"bar_spoon", 0), "full circle")
	eq(Relics.describe({tip_mult = 0.1, capacity = 1}), "+10% tips, +1 unit per glass", "describe")


func test_place() -> void:
	check(not bp.place(&"lemon_bowl", Vector2i(0, 0), 0).is_empty(), "2x2 in the corner")
	check(not bp.can_place(&"tip_jar", Vector2i(1, 1), 0), "overlap")
	check(bp.can_place(&"tip_jar", Vector2i(2, 0), 0), "next to it")
	check(not bp.can_place(&"lemon_bowl", Vector2i(5, 3), 0), "off the grid")
	check(not bp.can_place(&"bar_spoon", Vector2i(0, 2), 1), "standing spoon is too tall")
	eq(bp.placed(), [&"lemon_bowl"] as Array[StringName], "placed")
	bp.take(bp.item_at(Vector2i(1, 1)))
	eq(bp.items.size(), 0, "taken off")


func test_stars_feed_mods() -> void:
	bp.place(&"tip_jar", Vector2i(0, 0), 0)
	near(Game.mod(&"tip_mult"), 0.1, "placed tip jar")
	bp.place(&"lucky_coaster", Vector2i(1, 0), 0)
	eq(bp.lit_stars(bp.item_at(Vector2i(0, 0))), 1, "tip jar star takes any relic")
	near(Game.mod(&"tip_mult"), 0.15, "+ star")
	near(Game.mod(&"demand_mult"), 0.05, "coaster, its stars want glass")
	bp.take(bp.item_at(Vector2i(1, 0)))
	bp.place(&"lucky_coaster", Vector2i(0, 1), 0)
	eq(bp.lit_stars(bp.item_at(Vector2i(0, 1))), 1, "glass tip jar above the coaster")
	near(Game.mod(&"demand_mult"), 0.1, "coaster star")
	near(Game.mod(&"tip_mult"), 0.1, "tip jar star empty again")
	eq(bp.lit_total(), 1, "lit total")


func test_pocket() -> void:
	bp.add_to_pocket(&"tip_jar")
	bp.add_to_pocket(&"cat_bell")
	near(Game.mod(&"tip_mult"), 0.0, "pocket gives nothing")
	eq(bp.take_from_pocket(0), &"tip_jar", "take")
	eq(bp.pocket, [&"cat_bell"] as Array[StringName], "left")
	Game.new_run()
	eq(bp.pocket.size(), 0, "new run empties it")


func test_view() -> void:
	var layer := CanvasLayer.new()
	var view := BackpackView.new()
	layer.add_child(view)
	tree.root.add_child(layer)
	bp.add_to_pocket(&"lemon_bowl")
	await frames(2)
	view._click(view._pocket_rects()[0].get_center())
	eq(bp.pocket.size(), 0, "picked from the pocket")
	view._click(Vector2(5 * BackpackView.STEP + 8, 8))
	eq(bp.items.size(), 0, "doesn't fit at the edge, still held")
	view._click(Vector2(8, 8))
	eq(bp.placed(), [&"lemon_bowl"] as Array[StringName], "placed")
	view._click(Vector2(8, 8))
	view._held.rot = 1
	view._click(BackpackView.POCKET.get_center())
	eq(bp.pocket, [&"lemon_bowl"] as Array[StringName], "back to the pocket")
	view._click(view._pocket_rects()[0].get_center())
	view.hide()
	eq(bp.pocket, [&"lemon_bowl"] as Array[StringName], "closed mid-drag: back where it was")
	view.show()
	view._click(view._pocket_rects()[0].get_center())
	view._click(Vector2(8, 8))
	view._click(Vector2(8, 8))
	layer.free()
	eq(bp.placed(), [&"lemon_bowl"] as Array[StringName], "freed mid-drag: back on the grid")

extends "res://tests/suite.gd"


func test_four_of_each_kind() -> void:
	eq(Ingredients.ids().size(), 12, "ingredients")
	for kind in Ingredients.KINDS:
		eq(Ingredients.of_kind(kind).size(), 4, Ingredients.KIND_NAMES[kind])
		for id in Ingredients.of_kind(kind):
			eq(Ingredients.kind_of(id), kind, "kind of %s" % id)


func test_tiers_grow() -> void:
	for kind in Ingredients.KINDS:
		var ids := Ingredients.of_kind(kind)
		for i in range(1, ids.size()):
			var a: Dictionary = Ingredients.DEFS[ids[i - 1]]
			var b: Dictionary = Ingredients.DEFS[ids[i]]
			check(b.cost > a.cost, "%s costs more than %s" % [b.name, a.name])
			check(b.value > a.value, "%s worth more than %s" % [b.name, a.name])
			check(b.unlock > a.unlock, "%s unlocks after %s" % [b.name, a.name])


func test_first_tier_is_open() -> void:
	for kind in Ingredients.KINDS:
		var ids := Ingredients.of_kind(kind)
		eq(Ingredients.DEFS[ids[0]].unlock, 0, "%s open" % ids[0])
		for i in range(1, ids.size()):
			check(Ingredients.DEFS[ids[i]].unlock > 0, "%s locked" % ids[i])


func test_worth_more_than_it_costs() -> void:
	for id in Ingredients.ids():
		check(Ingredients.DEFS[id].value > Ingredients.cost(id), "%s value > cost" % id)
		check(Ingredients.display_name(id) != "", "%s has a name" % id)

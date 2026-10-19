class_name Ingredients
## What a drink is made of: one alcohol, one mixer, one flavor (owner 2026-10-17: no
## variants, just these three). `value` = what cats feel it's worth. The right drink is
## the same as in a real bar: `dose` = units of the thing itself, the alcohol's `mix` =
## units of mixer it wants. `unlock` 0 = open from the start. Optional `proc` = a minigame
## hook while it's on sale, same format as in Relics.

enum Kind { ALCOHOL, MIXER, FLAVOR }

const KINDS := [Kind.ALCOHOL, Kind.MIXER, Kind.FLAVOR]
const KIND_NAMES := ["Alcohol", "Mixer", "Flavor"]
const KIND_NEED := ["a kick", "something to mix", "some flavor"]	# "Needs ..." when missing

const DEFS := {
	&"alcohol": {name = "Alcohol", desc = "The base of every drink.", kind = Kind.ALCOHOL, cost = 2, value = 5, dose = 1, mix = 2, unlock = 0, color = Color("c0702a")},
	&"mixer": {name = "Mixer", desc = "Balances the alcohol.", kind = Kind.MIXER, cost = 1, value = 2, unlock = 0, color = Color("e8c872")},
	&"flavor": {name = "Flavor", desc = "Adds the finishing touch.", kind = Kind.FLAVOR, cost = 1, value = 2, dose = 1, unlock = 0, color = Color("b0402a")},
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in DEFS:
		out.append(id)
	return out


static func of_kind(kind: Kind) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in DEFS:
		if DEFS[id].kind == kind:
			out.append(id)
	return out


static func kind_of(id: StringName) -> Kind:
	return DEFS[id].kind


static func display_name(id: StringName) -> String:
	return DEFS[id].name


static func cost(id: StringName) -> int:
	return DEFS[id].cost


static func color(id: StringName) -> Color:
	return DEFS[id].color

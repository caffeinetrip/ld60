class_name Ingredients
## The twelve things a drink can be made of, four tiers per kind in DEFS order.
## Higher tier = costs more per unit, but cats accept a higher price for it (`value`).
## `unlock` = price to open it in the shop grid, 0 = open from the start.
## The right drink is the same as in a real bar: `dose` = units of the thing itself,
## an alcohol's `mix` = units of mixer it wants (strong ones get more, light ones less).

enum Kind { ALCOHOL, MIXER, FLAVOR }

const KINDS := [Kind.ALCOHOL, Kind.MIXER, Kind.FLAVOR]
const KIND_NAMES := ["Alcohol", "Mixer", "Flavor"]

const DEFS := {
	&"brandy": {name = "Brandy", kind = Kind.ALCOHOL, cost = 2, value = 6, dose = 1, mix = 2, unlock = 0, color = Color("b5651d")},
	&"sake": {name = "Sake", kind = Kind.ALCOHOL, cost = 4, value = 10, dose = 2, mix = 1, unlock = 120, color = Color("eae6d8")},
	&"absinthe": {name = "Absinthe", kind = Kind.ALCOHOL, cost = 6, value = 16, dose = 1, mix = 3, unlock = 300, color = Color("7fc241")},
	&"vermouth": {name = "Vermouth", kind = Kind.ALCOHOL, cost = 9, value = 24, dose = 2, mix = 2, unlock = 600, color = Color("8c2f39")},

	&"ginger_ale": {name = "Ginger Ale", kind = Kind.MIXER, cost = 1, value = 2, unlock = 0, color = Color("e8c872")},
	&"grapefruit": {name = "Grapefruit Juice", kind = Kind.MIXER, cost = 2, value = 4, unlock = 60, color = Color("f28b82")},
	&"apple": {name = "Apple Juice", kind = Kind.MIXER, cost = 3, value = 6, unlock = 150, color = Color("d8e27a")},
	&"coconut": {name = "Coconut Water", kind = Kind.MIXER, cost = 4, value = 9, unlock = 320, color = Color("f4f1ea")},

	&"cinnamon": {name = "Cinnamon", kind = Kind.FLAVOR, cost = 1, value = 2, dose = 1, unlock = 0, color = Color("a0522d")},
	&"peach": {name = "Peach", kind = Kind.FLAVOR, cost = 2, value = 4, dose = 1, unlock = 60, color = Color("ffb38a")},
	&"cherry": {name = "Cherry", kind = Kind.FLAVOR, cost = 3, value = 7, dose = 1, unlock = 160, color = Color("d2042d")},
	&"lavender": {name = "Lavender", kind = Kind.FLAVOR, cost = 5, value = 10, dose = 1, unlock = 340, color = Color("b497d6")},
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

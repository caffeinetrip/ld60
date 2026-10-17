extends Control
## Placeholder night screen, plain controls built in code. Goes away with the redesign.

signal done

const ENDED := {&"stock": "Out of drinks", &"time": "Closing time", &"nobody": "Nobody came"}
const SURE := "Are you sure?
You won't have money left
for tomorrow's drinks."

var _tabs := TabContainer.new()
var _next := Button.new()
var _report := Label.new()
var _picks := {}		# Kind -> OptionButton
var _units := {}		# Kind -> Label
var _glass := Label.new()
var _restock_n := 0
var _restock_label: Label
var _restock := Button.new()
var _price: Label
var _info := Label.new()
var _upgrades := {}		# upgrade id -> [Label, Button]
var _ask := Control.new()
var _ask_yes: Callable
var _rescued := false


func _ready() -> void:
	position = Vector2(4, 24)
	size = Vector2(312, 154)
	theme = Theme.new()
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBox = ThemeDB.get_default_theme().get_stylebox(state, type).duplicate()
			style.content_margin_top = 0
			style.content_margin_bottom = 0
			theme.set_stylebox(state, type, style)
	theme.set_constant("line_spacing", "Label", -5)
	theme.set_constant("separation", "VBoxContainer", 0)
	theme.set_constant("separation", "HBoxContainer", 2)
	_tabs.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_tabs)

	_page("Report").add_child(_report)

	var prep := _page("Preparation")
	var row: HBoxContainer
	for kind in Ingredients.KINDS:
		row = _row(prep)
		_label(row, Ingredients.KIND_NAMES[kind]).custom_minimum_size.x = 48
		var pick := OptionButton.new()
		pick.custom_minimum_size.x = 130
		for id in Ingredients.of_kind(kind):
			pick.add_item("")
		pick.item_selected.connect(_on_pick.bind(kind))
		row.add_child(pick)
		_picks[kind] = pick
		_units[kind] = _stepper(row, _on_units.bind(kind, -1), _on_units.bind(kind, 1))
	row = _row(prep)
	_label(row, "Restock to")
	_restock_label = _stepper(row, _on_restock_n.bind(-1), _on_restock_n.bind(1))
	_label(row, "drinks")
	_restock.pressed.connect(_on_restock)
	row.add_child(_restock)
	row = _row(prep)
	_label(row, "Price")
	_price = _stepper(row, _on_price.bind(-1), _on_price.bind(1))
	_glass.size_flags_horizontal = SIZE_EXPAND_FILL
	_glass.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_glass)
	prep.add_child(_info)

	_page("Inventory").add_child(BackpackView.new())

	var up := _page("Upgrade")
	for id in Tune.UPGRADES:
		row = _row(up)
		var label := _label(row)
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		var buy := Button.new()
		buy.pressed.connect(_on_upgrade.bind(id))
		row.add_child(buy)
		_upgrades[id] = [label, buy]

	_next.text = "Next"
	_next.position = Vector2(276, 1)
	_next.pressed.connect(done.emit)
	add_child(_next)

	_ask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_ask)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ask.add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_CENTER)
	box.grow_horizontal = GROW_DIRECTION_BOTH
	box.grow_vertical = GROW_DIRECTION_BOTH
	_ask.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	_label(col, SURE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row = _row(col)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for answer in [["Buy", true], ["Cancel", false]]:
		var b := Button.new()
		b.text = answer[0]
		b.pressed.connect(_on_ask.bind(answer[1]))
		row.add_child(b)
	_ask.hide()

	Game.money_changed.connect(_refresh.unbind(1))
	Game.stock_changed.connect(_refresh)
	hide()


func open() -> void:
	_ask.hide()
	_rescued = false
	_rescue()
	_restock_n = Game.max_restock()
	_tabs.current_tab = 0
	_next.show()
	show()
	_refresh()


func win(text: String) -> void:
	open()
	_report.text = text
	_next.hide()


func _refresh() -> void:
	if not visible:
		return
	var r := Game.last_report
	var lines := PackedStringArray()
	if not r.is_empty():
		lines.append("Day %d ended: %s" % [Game.day - 1, ENDED.get(r.ended_by, r.ended_by)])
		lines.append("Sold %d   Income $%d (tips $%d)" % [r.sold, r.revenue, r.tips])
		lines.append("Spilled %d   Specials won %d / lost %d" % [r.spilled, r.specials_won, r.specials_lost])
		lines.append("Walked away - too pricey: %d" % r.walked)
		for line in r.complaints:
			lines.append("\"%s\" x%d" % [line, r.complaints[line]])
		if r.complaints.is_empty() and r.sold > 0:
			lines.append("Everyone loved it!")
	if _rescued:
		lines.append("The guide left supplies for %d drinks." % Tune.RESCUE)
	lines.append("Week $%d / $%d" % [Game.week_earned(), Tune.QUOTA])
	_report.text = "\n".join(lines)

	for kind in Ingredients.KINDS:
		var pick: OptionButton = _picks[kind]
		var ids := Ingredients.of_kind(kind)
		for i in ids.size():
			var id := ids[i]
			var text := Ingredients.display_name(id)
			if not Game.is_unlocked(id):
				text += " $%d" % Game.unlock_cost(id)
			pick.set_item_text(i, text)
		pick.select(ids.find(Game.selected[kind]))
		_units[kind].text = str(Game.recipe[kind])
	_glass.text = "Glass: %d / %d units" % [Game.units_per_glass(), Game.capacity()]
	_restock_n = clampi(_restock_n, 0, Game.storage())
	_restock_label.text = str(_restock_n)
	var cost := Game.restock_cost(_restock_n)
	_restock.text = "Buy $%d" % cost
	_restock.disabled = cost <= 0 or cost > Game.money
	_price.text = "$%d" % Game.price
	_info.text = "In stock: %d drinks   Cost $%d   Profit %+d" % [Game.drinks_possible(),
		Game.cost_per_drink(), Game.price - Game.cost_per_drink()]
	if _rescued:
		_info.text += "
The guide left supplies for %d drinks." % Tune.RESCUE
	_next.disabled = Game.drinks_possible() == 0

	for id in _upgrades:
		var def: Dictionary = Tune.UPGRADES[id]
		var c := Game.upgrade_cost(id)
		_upgrades[id][0].text = "%s %d/%d\n%s" % [def.name, Game.level(id), def.costs.size(), def.desc]
		_upgrades[id][1].text = "$%d" % c if c >= 0 else "MAX"
		_upgrades[id][1].disabled = c < 0 or c > Game.money


func _on_pick(index: int, kind: Ingredients.Kind) -> void:
	var id := Ingredients.of_kind(kind)[index]
	if Game.is_unlocked(id):
		Feel.play(&"ui/click")
		Game.select(id)
	elif Game.money < Game.unlock_cost(id):
		Feel.play(&"ui/error")
	elif Game.strands(Game.unlock_cost(id), id):
		_confirm(_unlock.bind(id))
	else:
		_unlock(id)
	_refresh()


func _unlock(id: StringName) -> void:
	if Game.unlock(id):
		Feel.play(&"ui/buy")
		Game.select(id)
		_rescue()
	else:
		Feel.play(&"ui/error")


func _on_units(kind: Ingredients.Kind, d: int) -> void:
	Feel.play(&"ui/click" if Game.set_recipe(kind, Game.recipe[kind] + d) else &"ui/error")


func _on_restock_n(d: int) -> void:
	Feel.play(&"ui/click")
	_restock_n += d
	_refresh()


func _on_restock() -> void:
	Feel.play(&"ui/buy" if Game.restock(_restock_n) else &"ui/error")


func _on_price(d: int) -> void:
	Feel.play(&"ui/click")
	Game.price = maxi(1, Game.price + d)
	_refresh()


func _on_upgrade(id: StringName) -> void:
	var c := Game.upgrade_cost(id)
	if c >= 0 and c <= Game.money and Game.strands(c):
		_confirm(_upgrade.bind(id))
	else:
		_upgrade(id)


func _upgrade(id: StringName) -> void:
	if Game.buy_upgrade(id):
		Feel.play(&"ui/buy")
		_rescue()
	else:
		Feel.play(&"ui/error")


## Broke with an empty shelf: the guide brings a few drinks.
func _rescue() -> void:
	if Game.rescue():
		_rescued = true
		Feel.play(&"ui/buy")


## "Are you sure" over the panel, `yes` runs on Buy.
func _confirm(yes: Callable) -> void:
	_ask_yes = yes
	_ask.modulate.a = 0.0
	_ask.show()
	create_tween().tween_property(_ask, "modulate:a", 1.0, 0.1)
	Feel.play(&"ui/click")


func _on_ask(buy: bool) -> void:
	_ask.hide()
	if buy:
		_ask_yes.call()
	else:
		Feel.play(&"ui/click")
	_refresh()


func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	_tabs.add_child(page)
	return page


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _label(parent: Node, text := "") -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


## [-] value [+], returns the value label.
func _stepper(parent: Node, minus: Callable, plus: Callable) -> Label:
	var b := Button.new()
	b.text = "-"
	b.pressed.connect(minus)
	parent.add_child(b)
	var value := _label(parent)
	value.custom_minimum_size.x = 16
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b = Button.new()
	b.text = "+"
	b.pressed.connect(plus)
	parent.add_child(b)
	return value

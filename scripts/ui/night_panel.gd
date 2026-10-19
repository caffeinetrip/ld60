extends Control
## Night screen = the computer: a beige CRT running an old Windows window, soft greys.
## After a day it shows the Report alone (Next), then Preparation | Inventory | Upgrade;
## a run opens straight on Preparation. Preparation: the owner's screen 2 arrangement at
## the sizes of the boba-shop ref - what goes in a glass on the left, the glass in the
## middle, stock-up target / restock / cost / price on the right, Start Day bottom right (only
## there). All pages share the computer palette and native pixel layout.

signal done
signal report_read

const FONT := preload("res://art/fonts/tiny-5.fnt")
const COMPUTER := preload("res://art/ui/computer.png")
const GLARE := preload("res://art/ui/computer_glass.png")
const CRT := preload("res://shaders/computer_crt.gdshader")
const CASING := preload("res://shaders/computer_casing.gdshader")
const AT := Vector2(17, 19)				# the computer art on screen
const SCREEN := Rect2(95, 33, 149, 131)	# its glass
const PAGE := Rect2(3, 23, 143, 105)	# inside the tab panel, screen coordinates
const TABS := ["Report", "Preparation", "Inventory", "Upgrade"]
const REPORT := 0
const PREP := 1
const BAG := 2
const UPGRADE := 3
const TALK_DELAY := 0.6		# s between opening Inventory the first time and the sister's talk
const NEW_TAB := 1.6		# s per breath of a tab with pending items
const START_GUARD := 400	# ms after Preparation opens when Start Day ignores clicks (a double click on Next)
# Preparation, page coordinates
const GLASS := Rect2(47, 3, 40, 92)
const SPINS := {		# what -> value field; the arrows sit right of it
	&"alcohol": Rect2(7, 25, 20, 9), &"mixer": Rect2(7, 47, 20, 9), &"flavor": Rect2(7, 69, 20, 9),
	&"target": Rect2(93, 12, 22, 9), &"price": Rect2(93, 81, 22, 9),
}
const LABELS := {&"alcohol": "Alcohol", &"mixer": "Mixer", &"flavor": "Flavor"}
# what the sister points at in her guides (Dialogue.spots): id -> [page, rect in page px]
const GUIDE_SPOTS := {
	&"glass": [PREP, GLASS], &"price": [PREP, Rect2(91, 72, 34, 20)], &"target": [PREP, Rect2(91, 3, 50, 43)],
	&"feedback": [REPORT, Rect2(87, 3, 55, 88)],
	&"backpack": [BAG, Rect2(77, 0, 66, 104)],
}
# one new thing a night: the day being prepared for from which it shows (endless: all)
const UNLOCK := {&"stock": 2, &"upgrades": 2, &"price": 3, &"bag": 4}
const SPIN_PART := {&"target": &"stock", &"price": &"price"}
const GUIDE_LIFT := 24.0	# room px the computer rises so the talk's bar doesn't cover what she shows
# soft old greys
const FACE := Color("abb3aa")
const LIGHT := Color("d8dfce")
const SHADOW := Color("69796f")
const EDGE := Color("354b45")
const INK := Color("142422")
const FIELD := Color("c6cebc")
const NAVY := Color("244d55")
const RED := Color("8b3e37")
const GREEN := Color("286342")
const QUIET := Color("626f67")	# the day's numbers sit back, the feedback reads first
const OFF := 0.4		# how much of a greyed-out button shows
const WINDOW := preload("res://art/ui/night/window.png")			# face, title bar, the raised panel under the tabs
const CASING_ART := preload("res://art/ui/night/casing_details.png")	# vents + power LED, at (179, 169)
const ARROWS := preload("res://art/ui/night/spin_arrows.png")		# 7x5: normal / hover / pressed across, up then down
const DIVIDER := preload("res://art/ui/night/divider.png")
const ICONS := preload("res://art/ui/night/upgrade_icons.png")		# hand-pixelled desktop icons, white, 12x10 each
const UPGRADE_BOX := preload("res://art/ui/night/upgrade_detail.png")
const ASK_BOX := preload("res://art/ui/night/ask_box.png")
const COIN := preload("res://art/fx/money_atlas.png")	# row 7: a coin spinning, 10 frames of 16 px
const COIN_TINT := Color(0.84, 0.75, 0.52, 0.85)	# gold, toned down to sit in the window
const COIN_LIFT := 420.0		# a buy's coins are tossed up off the glass and fall back onto it
const COIN_REST := 0.6			# s a landed coin lies there, fading over its last .3
const COINS_MAX := 14			# a buy throws 3 ($10) .. 14 ($450+) coins
const ENDED := {&"stock": "Out of drinks", &"time": "Closing time", &"nobody": "Nobody came"}
const SURE := "You won't have money left\nfor tomorrow's drinks."

var _rig := Control.new()		# everything that slides in
var _screen := Control.new()
var _tabs := TabContainer.new()
var _prep := Control.new()
var _next := Button.new()
var _next_shake: Tween
var _report_next := Button.new()
var _report := Label.new()
var _restock := Button.new()
var _info := Label.new()		# cost and profit of one drink
var _profit_value := Label.new()
var _glass_info := Control.new()
var _upgrades := {}				# upgrade id -> [Label, Buy, Return]
var _ask := Control.new()
var _ask_shake: Tween
var _ask_fade: Tween
var _ask_yes: Callable
var _ask_title := ""
var _ask_text: Label
var _ask_buttons: Array[Button] = []	# Buy, Cancel, OK
var _rescued := false
var _bag: Control
var _fill := {}					# Kind -> units the glass shows, eases to the recipe
var _repeat := Timer.new()		# held spin arrows repeat
var _repeat_do: Callable
var _tab_buttons: Array[Button] = []
var _shown: Array[int] = [PREP, BAG, UPGRADE]	# the tabs of this phase
var _prep_at := -START_GUARD
var _clickables: Array[Button] = []
var _number_fields: Dictionary = {}
var _parts := {&"stock": [], &"price": []}	# controls that come with a feature
var _prep_guiding := false
var _report_page: Control
var _feedback := Label.new()
var _upgrade_tiles := {}
var _selected_upgrade: StringName = &"tips"
var _upgrade_page: Control
var _fx: Array[Dictionary] = []		# a buy's gold coins on the screen
var _fx_view := Control.new()		# draws it inside the window, under the glass
var _seen_buyable := {}			# upgrade ids already affordable when the Upgrade tab was last opened
var _blink := {}					# upgrade id -> seconds its tile keeps blinking


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = _theme()
	for kind in Ingredients.KINDS:
		_fill[kind] = float(Game.recipe[kind])
	_repeat.timeout.connect(func() -> void:
		_repeat.wait_time = 0.06
		_repeat_do.call())
	add_child(_repeat)

	_rig.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_rig.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_rig)
	var art := TextureRect.new()
	art.texture = COMPUTER
	var casing := ShaderMaterial.new()
	casing.shader = CASING
	art.material = casing
	art.position = AT
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.add_child(art)
	_screen.position = SCREEN.position
	_screen.size = SCREEN.size
	_screen.clip_contents = true
	_screen.draw.connect(_draw_window)
	_rig.add_child(_screen)
	_tabs.tabs_visible = false
	_tabs.tab_changed.connect(_on_tab_changed)
	_screen.add_child(_tabs)
	_tabs.position = PAGE.position
	_tabs.size = PAGE.size

	_report_page = _page("Report")
	_report_page.draw.connect(_draw_report)
	_report_page.add_child(_report)
	_report.position = Vector2(4, 14)
	_report.size = Vector2(135, 73)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.hide()
	_report_next.text = "Next"
	_report_next.focus_mode = FOCUS_NONE
	_report_next.pressed.connect(_on_report_next)
	_report_page.add_child(_report_next)
	_report_next.position = Vector2(98, 93)
	_report_next.size = Vector2(42, 11)
	var feedback_scroll := ScrollContainer.new()
	feedback_scroll.position = Vector2(89, 16)
	feedback_scroll.size = Vector2(51, 73)
	feedback_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feedback_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_report_page.add_child(feedback_scroll)
	feedback_scroll.add_child(_feedback)
	_feedback.custom_minimum_size.x = 51
	_feedback.size_flags_horizontal = SIZE_EXPAND_FILL
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.mouse_filter = MOUSE_FILTER_IGNORE
	_build_prep()
	_bag = _page("Inventory")
	_build_upgrades()

	_next.text = "Start Day"
	_next.focus_mode = FOCUS_NONE
	_next.pressed.connect(done.emit)
	_next.gui_input.connect(_on_next_input)
	_prep.add_child(_next)
	_next.position = Vector2(98, 93)
	_next.size = Vector2(42, 11)
	_build_tab_buttons()
	_build_crt()

	var glare := TextureRect.new()
	glare.texture = GLARE
	glare.modulate = Color(0.70, 0.83, 0.78, 0.22)
	glare.position = AT
	glare.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.add_child(glare)
	var details := Control.new()
	details.mouse_filter = MOUSE_FILTER_IGNORE
	details.draw.connect(_draw_casing_details.bind(details))
	_rig.add_child(details)

	_build_bag()
	_build_ask()
	_fx_view.size = SCREEN.size
	_fx_view.mouse_filter = MOUSE_FILTER_IGNORE
	_fx_view.draw.connect(_draw_fx)
	_screen.add_child(_fx_view)
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		_clickables.append(button)
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		button.mouse_entered.connect(button.queue_redraw)
		button.mouse_exited.connect(button.queue_redraw)

	Game.money_changed.connect(_refresh.unbind(1))
	Game.stock_changed.connect(_refresh)
	Game.backpack.changed.connect(_screen.queue_redraw)
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		var pages := {PREP: _prep, REPORT: _report_page, BAG: _bag, UPGRADE: _upgrade_page}
		for id in GUIDE_SPOTS:
			var page: Control = pages[GUIDE_SPOTS[id][0]]
			var rect: Rect2 = GUIDE_SPOTS[id][1]
			dialogue.spots[id] = func(): return page.get_global_transform_with_canvas() * rect
	hide()


func _draw_casing_details(on: Control) -> void:
	on.draw_circle(Vector2(236, 172), 3.0, Color(0.52, 0.68, 0.22, 0.10))	# the power LED's glow
	on.draw_texture(CASING_ART, Vector2(179, 169))


func _build_tab_buttons() -> void:
	for i in TABS.size():
		var button := Button.new()
		button.name = TABS[i] + "Tab"
		button.focus_mode = FOCUS_NONE
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.position = _tab_rect(i).position
		button.size = _tab_rect(i).size
		button.mouse_entered.connect(_screen.queue_redraw)
		button.mouse_exited.connect(_screen.queue_redraw)
		button.pressed.connect(func() -> void:
			if _tabs.current_tab != i and _shown.has(i):
				Feel.play(&"ui/click")
				_tabs.current_tab = i)
		_screen.add_child(button)
		_tab_buttons.append(button)


func _build_crt() -> void:
	# Capture the complete screen subtree (including confirmation dialogs) before
	# the glass pass. The global postprocess makes a fresh copy later for the HUD.
	var copy := BackBufferCopy.new()
	copy.name = "CRTCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_rig.add_child(copy)
	var glass := ColorRect.new()
	glass.name = "CRTGlass"
	glass.position = SCREEN.position
	glass.size = SCREEN.size
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	var crt := ShaderMaterial.new()
	crt.shader = CRT
	crt.set_shader_parameter(&"screen_size", SCREEN.size)
	glass.material = crt
	_rig.add_child(glass)


## After a day: the report alone, Next goes on (report_read).
func open_report() -> void:
	_rescued = false
	_open([REPORT], REPORT)


## The night's shop: restock, recipe, price, upgrades, relics; Start Day (done).
## Yesterday's report stays the first tab (none before day 1); Inventory from night 2.
func open_prep() -> void:
	_rescued = false
	_prep_at = Time.get_ticks_msec()
	for part in _parts:
		for control: Control in _parts[part]:
			control.visible = unlocked(part)
	var tabs: Array[int] = [PREP]
	if unlocked(&"bag"):
		tabs.append(BAG)
	if unlocked(&"upgrades"):
		tabs.append(UPGRADE)
	if not Game.earnings.is_empty():
		tabs.push_front(REPORT)
	_open(tabs, PREP)
	_rescue()


func _open(tabs: Array[int], first: int) -> void:
	_ask.hide()
	_shown = tabs
	for i in _tab_buttons.size():
		_tab_buttons[i].visible = _shown.has(i)
	_tabs.current_tab = first
	_on_tab_changed(first)
	show()
	_refresh()
	# Keep the whole computer in frame; Main fades the complete panel together.
	_rig.position.y = 0.0


func _on_report_next() -> void:
	Feel.play(&"ui/click")
	if _shown.has(PREP):
		_tabs.current_tab = PREP
	else:
		report_read.emit()


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
			lines.append("%s x%d" % [line, r.complaints[line]])
		if r.complaints.is_empty() and r.sold > 0:
			lines.append("Everyone loved it!")
	if _rescued:
		lines.append("The guide left supplies for %d drinks." % Tune.RESCUE)
	lines.append("Week $%d / $%d" % [Game.week_earned(), Tune.QUOTA])
	_report.text = "\n".join(lines)
	_report.hide()
	_feedback.show()
	var comments := PackedStringArray()
	if not r.is_empty():
		for comment in r.complaints:
			comments.append("%s x%d" % [comment, r.complaints[comment]])
		if r.complaints.is_empty() and r.sold > 0:
			comments.append("Everyone loved it!")
	if r.get("refund", 0) > 0:
		comments.insert(0, "Sister paid back $%d." % r.refund)
	_feedback.text = "\n".join(comments) if not comments.is_empty() else "No feedback yet."
	if _rescued:
		_feedback.text = "The guide left supplies for %d drinks.\n" % Tune.RESCUE + _feedback.text
	_report_page.queue_redraw()

	var cost := Game.restock_cost(Game.target)
	_glass_info.tooltip_text = "Glass\nEach drink uses one glass.\nHolds up to %d ingredient units.\nRestocking costs $%d per glass." % [Game.capacity(), Tune.GLASS_COST]
	_restock.text = "Restock $%d" % cost
	_restock.disabled = cost <= 0 or cost > Game.money
	var profit := roundi(Game.price * Tune.GOLD_MULT) - Game.cost_per_drink()
	_info.text = "Cost $%d\nProfit" % Game.cost_per_drink()
	_profit_value.text = "%s$%d" % ["+" if profit >= 0 else "-", absi(profit)]
	_profit_value.add_theme_color_override("font_color", GREEN if profit >= 0 else RED)
	_next.disabled = Game.drinks_possible() == 0

	for id in _upgrades:
		var def: Dictionary = Tune.UPGRADES[id]
		var c := Game.upgrade_cost(id)
		# `after` = a night panel feature it needs (the backpack upgrade waits for the Inventory)
		var shown: bool = (not def.has("requires") or Game.flags.has(def.requires)) and unlocked(def.get("after", &""))
		_upgrade_tiles[id].visible = shown
		_upgrades[id][0].get_parent().visible = shown and id == _selected_upgrade
		_upgrade_tiles[id].queue_redraw()
		var single: bool = def.costs.size() == 1
		_upgrades[id][0].text = def.name if single else "%s %d/%d" % [def.name, Game.level(id), def.costs.size()]
		_upgrades[id][1].text = "$%d" % c if c >= 0 else ("OWNED" if single else "MAX")
		_upgrades[id][1].disabled = c < 0 or c > Game.money
		var owned := Game.level(id)
		_upgrades[id][2].visible = owned > 0
		if owned > 0:
			_upgrades[id][2].tooltip_text = "Sell the last level back for $%d." % def.costs[owned - 1]
	_prep.queue_redraw()
	_screen.queue_redraw()
	for button in _clickables:
		button.mouse_default_cursor_shape = CURSOR_ARROW if button.disabled else CURSOR_POINTING_HAND
	for what in _number_fields:
		var edit: LineEdit = _number_fields[what]
		if not edit.has_focus():
			edit.text = _spin_value(what).trim_prefix("$")


func _process(delta: float) -> void:
	if not visible:
		return
	if _tab_needs_attention(BAG) or _tab_needs_attention(UPGRADE):
		_screen.queue_redraw()
	if not _fx.is_empty() or not _blink.is_empty():
		_tick_fx(delta)
	var moving := false
	for kind in Ingredients.KINDS:
		var want := float(Game.recipe[kind])
		if _fill[kind] != want:
			_fill[kind] = move_toward(_fill[kind], want, delta * 8.0)
			moving = true
	if moving:
		_prep.queue_redraw()


# --- Preparation ---------------------------------------------------------------

func _build_prep() -> void:
	_prep.name = "Preparation"
	_tabs.add_child(_prep)
	_prep.draw.connect(_draw_prep)
	_prep.gui_input.connect(_on_prep_input)
	_glass_info.name = "GlassInfo"
	_glass_info.position = GLASS.position
	_glass_info.size = GLASS.size
	_glass_info.mouse_filter = MOUSE_FILTER_PASS
	_prep.add_child(_glass_info)
	for what in SPINS:
		var field: Rect2 = SPINS[what]
		var edit := LineEdit.new()
		edit.name = String(what).capitalize() + "Input"
		edit.position = field.position
		edit.add_theme_constant_override("minimum_character_width", 1)
		edit.add_theme_font_override("font", FONT)
		edit.add_theme_font_size_override("font_size", 8)
		edit.max_length = 6
		edit.select_all_on_focus = true
		edit.caret_blink = true
		edit.text = _spin_value(what).trim_prefix("$")
		edit.mouse_default_cursor_shape = CURSOR_IBEAM
		edit.tooltip_text = _prep_description(what)
		edit.text_submitted.connect(func(_text: String) -> void: edit.release_focus())
		edit.focus_exited.connect(_commit_number.bind(what))
		edit.gui_input.connect(_on_number_input.bind(what))
		_prep.add_child(edit)
		edit.size = field.size
		_number_fields[what] = edit
		if SPIN_PART.has(what):
			_parts[SPIN_PART[what]].append(edit)
		for d in [1, -1]:
			var b := Button.new()
			b.focus_mode = FOCUS_NONE
			b.flat = true
			b.tooltip_text = _prep_description(what)
			b.button_down.connect(_on_spin.bind(what, d))
			b.button_up.connect(_repeat.stop)
			b.draw.connect(_draw_arrow.bind(b, d))
			_prep.add_child(b)
			b.position = Vector2(field.end.x + 1, field.position.y + (0 if d > 0 else 5))
			b.size = Vector2(6, 4)
			if SPIN_PART.has(what):
				_parts[SPIN_PART[what]].append(b)
	_prep.add_child(_restock)
	_restock.focus_mode = FOCUS_NONE
	_restock.tooltip_text = "Buy the ingredients and glasses\nneeded to reach your stock target\nwith the current recipe."
	_restock.pressed.connect(_on_restock)
	_restock.position = Vector2(93, 24)
	_restock.size = Vector2(47, 11)
	_prep.add_child(_info)
	_info.position = Vector2(93, 52)
	_prep.add_child(_profit_value)
	_profit_value.position = Vector2(93 + FONT.get_string_size("Profit ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 60)
	_parts[&"stock"].append(_restock)
	_parts[&"price"].append_array([_info, _profit_value])


static func unlocked(what: StringName) -> bool:
	return Game.endless or Game.day >= UNLOCK.get(what, 0)


func _prep_description(what: StringName) -> String:
	match what:
		&"target":
			return "Choose how many drinks you want\nto have supplies for after restocking."
		&"price":
			return "Set the price of one drink.\nHigh prices can drive customers away."
	return "%s\n%s\nSet the number of units in each drink." % [Ingredients.display_name(what), Ingredients.DEFS[what].desc]


func _spin_value(what: StringName) -> String:
	match what:
		&"target":
			return str(Game.target)
		&"price":
			return "$%d" % Game.price
	return str(Game.recipe[Ingredients.kind_of(what)])


func _commit_number(what: StringName) -> void:
	var edit: LineEdit = _number_fields[what]
	var raw := edit.text.strip_edges()
	var minimum := 1 if what in [&"price", &"alcohol"] else 0
	var valid := raw.is_valid_int() and raw.to_int() >= minimum
	if valid:
		var value := raw.to_int()
		match what:
			&"target":
				Game.target = value
			&"price":
				Game.price = value
			_:
				valid = Game.set_recipe(Ingredients.kind_of(what), value)
	if not valid:
		Feel.play(&"ui/error")
	edit.text = _spin_value(what).trim_prefix("$")
	_refresh()


func _on_number_input(event: InputEvent, what: StringName) -> void:
	var edit: LineEdit = _number_fields[what]
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		edit.text = _spin_value(what).trim_prefix("$")
		edit.release_focus()
		edit.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		edit.release_focus()
		_step(what, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		edit.accept_event()


func _input(event: InputEvent) -> void:
	# Buttons deliberately don't take keyboard focus. Commit before their click
	# handlers run, so Restock/Start Day and arrows use the number just typed.
	if not is_visible_in_tree() or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	for edit: LineEdit in _number_fields.values():
		if edit.has_focus():
			var local: Vector2 = edit.get_global_transform_with_canvas().affine_inverse() * event.position
			if not Rect2(Vector2.ZERO, edit.size).has_point(local):
				edit.release_focus()


func _draw_prep() -> void:
	for what in LABELS:
		var field: Rect2 = SPINS[what]
		_text(_prep, LABELS[what], Vector2(field.position.x, field.position.y - 3), field.size.x + 7)
	if unlocked(&"stock"):
		_text(_prep, "Stock up to", Vector2(93, 9))
		var makes := Game.drinks_possible()
		_text(_prep, "Makes %d" % makes, Vector2(93, 44), -1, INK if makes > 0 else RED)
	if unlocked(&"price"):
		_prep.draw_texture(DIVIDER, Vector2(93, 47))
		_text(_prep, "Price $", Vector2(93, 78))
	_draw_glass(GLASS)


## `width` > 0 centres the text in that width.
func _text(on: CanvasItem, text: String, baseline_at: Vector2, width := -1.0, color := INK) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	on.draw_string(FONT, baseline_at, text, align, width, 8, color)


## The hover frame sits 1 px up-left of the 6x4 button, so the cells are 7x5.
func _draw_arrow(b: Button, d: int) -> void:
	var state := 0
	if b.get_draw_mode() == BaseButton.DRAW_PRESSED:
		state = 2
	elif b.is_hovered() and not b.disabled:
		state = 1
	b.draw_texture_rect_region(ARROWS, Rect2(-1, -1, 7, 5), Rect2(state * 7, 0 if d > 0 else 5, 7, 5))


## A see-through tumbler; what's poured stacks up from the bottom, alcohol first, with a
## tick at every unit like a measuring glass.
func _draw_glass(g: Rect2) -> void:
	var h := int(g.size.y)
	var top_w := int(g.size.x)
	var bottom_w := top_w - 4
	var base := 4
	var unit := float(h - 3 - base) / maxf(Game.capacity(), 1)
	var layers := []		# [top row from the bottom, color]
	var level := 0.0
	for kind in Ingredients.KINDS:
		if _fill[kind] <= 0.0:
			continue
		level += _fill[kind] * unit
		layers.append([level, Ingredients.DEFS[Game.selected[kind]].color])
	for y in h:
		var w := roundi(lerpf(top_w, bottom_w, float(y) / (h - 1)))
		var x := g.position.x + floorf((top_w - w) / 2.0)
		var row := g.position.y + y
		if y >= h - base:
			_prep.draw_rect(Rect2(x, row, w, 1), EDGE if y == h - 1 else LIGHT.lerp(FACE, 0.4))
			_prep.draw_rect(Rect2(x, row, 1, 1), EDGE)
			_prep.draw_rect(Rect2(x + w - 1, row, 1, 1), EDGE)
			continue
		_prep.draw_rect(Rect2(x + 1, row, w - 2, 1), Color(LIGHT, 0.25))
		var from_bottom := float(h - base - y)
		for layer in layers:
			if from_bottom <= layer[0]:
				var col: Color = layer[1]
				if from_bottom > layer[0] - 1.0:
					col = col.lightened(0.3)
				_prep.draw_rect(Rect2(x + 1, row, w - 2, 1), col)
				break
		if y >= 3 and y < h - base - 2:
			_prep.draw_rect(Rect2(x + 3, row, 1, 1), Color(LIGHT, 0.55))
		_prep.draw_rect(Rect2(x, row, 1, 1), EDGE)
		_prep.draw_rect(Rect2(x + w - 1, row, 1, 1), EDGE)
	_prep.draw_rect(Rect2(g.position.x, g.position.y, top_w, 1), EDGE)
	_prep.draw_rect(Rect2(g.position.x + 1, g.position.y + 1, top_w - 2, 1), LIGHT)
	for u in range(1, Game.capacity()):
		var y := roundi(h - base - u * unit)
		var w := roundi(lerpf(top_w, bottom_w, float(y) / (h - 1)))
		var x := g.position.x + floorf((top_w - w) / 2.0) + w - 6
		_prep.draw_rect(Rect2(x, g.position.y + y, 3, 1), Color(EDGE, 0.45))


func _on_prep_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		for what in SPINS:
			if SPIN_PART.has(what) and not unlocked(SPIN_PART[what]):
				continue
			if SPINS[what].grow_individual(1, 1, 8, 1).has_point(mb.position):
				_step(what, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				_prep.accept_event()


## Arrow pressed: one step now, more while it's held.
func _on_spin(what: StringName, d: int) -> void:
	_step(what, d)
	_repeat_do = _step.bind(what, d)
	_repeat.start(0.35)


func _step(what: StringName, d: int) -> void:
	match what:
		&"target":
			_on_target(d)
		&"price":
			_on_price(d)
		_:
			_on_units(Ingredients.kind_of(what), d)


func _on_units(kind: Ingredients.Kind, d: int) -> void:
	if Game.set_recipe(kind, Game.recipe[kind] + d):
		Feel.play(&"bar/pour" if d > 0 else &"ui/click")
	else:
		Feel.play(&"ui/error")


func _on_target(d: int) -> void:
	if Game.target + d < 0:
		Feel.play(&"ui/error")
		return
	Feel.play(&"ui/click")
	Game.target += d
	_refresh()


func _on_restock() -> void:
	var cost := Game.restock_cost(Game.target)
	if Game.restock(Game.target):
		Feel.play(&"ui/buy")
		_bought(_restock, cost)
	else:
		Feel.play(&"ui/error")


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
	var cost := Game.upgrade_cost(id)
	if Game.buy_upgrade(id):
		Feel.play(&"ui/buy")
		_blink[id] = 0.5
		_bought(_upgrade_tiles[id], cost, true)
		_rescue()
	else:
		Feel.play(&"ui/error")


## Changed your mind: the last level goes back, all its money returns.
func _return_upgrade(id: StringName) -> void:
	if Game.sell_upgrade(id):
		Feel.play(&"ui/click")
		_punch(_upgrade_tiles[id], 0.9, _upgrade_tiles[id].size * 0.5)
	else:
		Feel.play(&"ui/error")


## Broke with an empty shelf: the guide brings a few drinks.
func _rescue() -> void:
	if Game.rescue():
		_rescued = true
		Feel.play(&"ui/buy")
		_show_box("A little help", "The guide left supplies\nfor %d drinks." % Tune.RESCUE, true)


## A buy pays off inside the window: the button punches, gold coins are tossed out of it and
## land on the glass - the more it cost, the more coins - and the whole computer punches in a
## little. `big` = an upgrade level.
func _bought(on: Control, cost: int, big := false) -> void:
	var xf := _screen.get_global_transform().affine_inverse() * on.get_global_transform()
	var r := Rect2(xf.origin.round(), on.size)
	var n := clampi(roundi(1.0 + sqrt(maxf(cost, 0.0)) * 0.55), 3, COINS_MAX)
	for i in n:
		# 3D on the flat screen: `pos` moves on the glass, `height` lifts it off with a shadow under
		var lift := randf_range(120.0, 165.0)
		_fx.append({pos = r.get_center(), t = -i * 0.04, life = 2.0 * lift / COIN_LIFT + COIN_REST,
			vel = Vector2(randf_range(20.0, 40.0 + n * 2.0) * (1.0 if i % 2 else -1.0), randf_range(4.0, 22.0)),
			height = 0.0, lift = lift, spin = randf_range(14.0, 20.0), phase = randf_range(0.0, 10.0)})
	_punch(on, 1.25, on.size * 0.5)
	_punch(_rig, 1.03 if big else 1.015, SCREEN.get_center())


## Zoomed in around `pivot`, settles back.
func _punch(c: Control, amount: float, pivot: Vector2) -> void:
	c.pivot_offset = pivot
	c.scale = Vector2.ONE * amount
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tick_fx(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var e: Dictionary = _fx[i]
		e.t += delta
		if e.t >= e.life:
			_fx.remove_at(i)
		elif e.t > 0.0 and e.lift != 0.0:
			e.height += e.lift * delta
			e.lift -= COIN_LIFT * delta
			e.pos += e.vel * delta
			if e.height <= 0.0:
				e.height = 0.0
				e.lift = 0.0		# landed: lies flat where it fell
	for id in _blink.keys():
		_blink[id] -= delta
		if _blink[id] <= 0.0:
			_blink.erase(id)
		_upgrade_tiles[id].queue_redraw()
	_fx_view.queue_redraw()


func _draw_fx() -> void:
	for e in _fx:
		if e.t < 0.0:
			continue
		var tint := COIN_TINT
		# eases in, melts away at the end
		tint.a *= minf(e.t / 0.12, 1.0) * clampf((e.life - e.t) / 0.3, 0.0, 1.0)
		var ground: Vector2 = e.pos.round()
		# its shadow on the glass, smaller the higher it is
		var w := 10.0 - minf(e.height / 6.0, 4.0)
		_fx_view.draw_rect(Rect2(ground.x - roundf(w * 0.5), ground.y + 6, w, 2), Color(INK, 0.22 * tint.a))
		var frame := int(e.phase + e.t * e.spin) % 10 if e.height > 0.0 else 0
		_fx_view.draw_texture_rect_region(COIN, Rect2(ground - Vector2(8, 8 + roundf(e.height)), Vector2(16, 16)),
			Rect2(frame * 16, 112, 16, 16), tint)


# --- the window: title bar, tabs ------------------------------------------------

func _tab_rect(i: int) -> Rect2:
	var x := 2.0
	for j in _shown:
		if j == i:
			break
		x += FONT.get_string_size(TABS[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4
	var r := Rect2(x, 12, FONT.get_string_size(TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4, 9)
	if i == _tabs.current_tab:
		r = r.grow_individual(1, 1, 1, 1)
	return r


func _draw_window() -> void:
	var s := _screen.size
	# Title only: no decorative controls that look clickable.
	_screen.draw_texture(WINDOW, Vector2.ZERO)
	_text(_screen, TABS[_tabs.current_tab], Vector2(0, 8), s.x, LIGHT)
	# the tabs; the open one sits on the panel's edge
	for i in _shown:
		var r := _tab_rect(i)
		var on := i == _tabs.current_tab
		var hovered := i < _tab_buttons.size() and _tab_buttons[i].is_hovered()
		_screen.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), LIGHT)
		_screen.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 1), LIGHT)
		_screen.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 1), SHADOW)
		var fill := NAVY if on else (Color("e5e8c7") if hovered else FACE.lightened(0.08))
		_screen.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - (0 if on else 1)), fill)
		var pending := _tab_needs_attention(i)
		if pending:
			var k := 0.5 - 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU / NEW_TAB)
			_screen.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 1), Color(NAVY, 0.25 + 0.45 * k))
			_screen.draw_rect(Rect2(r.end.x - 4, r.position.y + 2, 2, 2), RED)
		_text(_screen, TABS[i], r.position + Vector2(2, 7), -1, LIGHT if on or pending else INK)
		if hovered and not on:
			_screen.draw_line(Vector2(r.position.x + 2, r.end.y - 2), Vector2(r.end.x - 2, r.end.y - 2), NAVY)


## Upgrade ids buyable right now (unlocked, levels left, enough money).
func _buyable_upgrades() -> Dictionary:
	var out := {}
	for id in Tune.UPGRADES:
		var def: Dictionary = Tune.UPGRADES[id]
		if def.has("requires") and not Game.flags.has(def.requires):
			continue
		var c := Game.upgrade_cost(id)
		if c >= 0 and Game.money >= c:
			out[id] = true
	return out


## The Upgrade mark shows while something is affordable that wasn't when the tab was last opened.
func _tab_needs_attention(tab: int) -> bool:
	if not _shown.has(tab):
		return false
	if tab == BAG:
		return not Game.backpack.pocket.is_empty()
	if tab == UPGRADE:
		for id in _buyable_upgrades():
			if not _seen_buyable.has(id):
				return true
	return false


func _on_tab_changed(tab: int) -> void:
	if tab == UPGRADE:
		_seen_buyable = _buyable_upgrades()
	for i in _tab_buttons.size():
		_tab_buttons[i].position = _tab_rect(i).position
		_tab_buttons[i].size = _tab_rect(i).size
	_screen.queue_redraw()
	if tab == PREP and visible:
		_prep_guides()
	if tab == BAG and visible and not Game.flags.has(&"seen_inventory"):
		Game.flags[&"seen_inventory"] = true
		_inventory_talk()


## The sister explains the backpack the first time it's opened (placeholder lines): the
## page shows first, clicks are held for a moment, then she comes in.
func _inventory_talk() -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if not dialogue:
		return
	var vp := get_viewport()
	vp.gui_disable_input = true
	await get_tree().create_timer(TALK_DELAY).timeout
	vp.gui_disable_input = false
	guide(&"inventory")


## What Preparation got tonight is explained the first time it shows, one talk after another.
func _prep_guides() -> void:
	if _prep_guiding:
		return
	_prep_guiding = true
	if unlocked(&"stock"):
		await guide(&"stock")
	if unlocked(&"price"):
		await guide(&"price")
	_prep_guiding = false


## The sister walks through what's on the screen, once a run: the computer rises above her
## bar first and settles back after.
func guide(id: StringName) -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue == null or Game.endless or Game.flags.has(id):
		return
	Game.flags[id] = true
	var vp := get_viewport()
	vp.gui_disable_input = true
	var up := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(_rig, "position:y", -GUIDE_LIFT, 0.4)
	await up.finished
	vp.gui_disable_input = false
	await dialogue.play(id)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_rig, "position:y", 0.0, 0.4)


# --- Report, inventory and upgrades -------------------------------------------

func _draw_report() -> void:
	if _report.visible:
		return
	_text(_report_page, "Daily Report", Vector2(3, 9), -1, QUIET)
	_text(_report_page, "Feedback", Vector2(89, 9))
	_report_page.draw_line(Vector2(85, 3), Vector2(85, 89), SHADOW)
	var r := Game.last_report
	var rows: Array = [["Day ended", "-"], ["Sold", "0"], ["Income", "$0"], ["Tips", "$0"], ["Spilled", "0"], ["Won / lost", "0 / 0"], ["Too pricey", "0"]]
	if not r.is_empty():
		rows = [["Day %d ended" % (Game.day - 1), ENDED.get(r.ended_by, r.ended_by)], ["Sold", str(r.sold)], ["Income", "$%d" % r.revenue], ["Tips", "$%d" % r.tips], ["Spilled", str(r.spilled)], ["Won / lost", "%d / %d" % [r.specials_won, r.specials_lost]], ["Too pricey", str(r.walked)]]
	for i in rows.size():
		var y := 13 if i == 0 else 31 + (i - 1) * 9
		if i % 2 == 0:
			_report_page.draw_rect(Rect2(2, y, 80, 18 if i == 0 else 9), Color(SHADOW.lightened(0.23), 0.5))
		if i == 0:
			_text(_report_page, rows[i][0], Vector2(4, y + 7), -1, QUIET)
			_text(_report_page, rows[i][1], Vector2(4, y + 15), -1, QUIET)
		else:
			_text(_report_page, rows[i][0], Vector2(4, y + 7), -1, QUIET)
			# the money made is the one number in colour
			var value_color := GREEN if rows[i][0] == "Income" else QUIET
			_report_page.draw_string(FONT, Vector2(4, y + 7), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, 76, 8, value_color)
	_report_page.draw_line(Vector2(3, 89), Vector2(81, 89), SHADOW)
	_text(_report_page, "Week $%d / $%d" % [Game.week_earned(), Tune.QUOTA], Vector2(4, 98))



func _build_bag() -> void:
	_label(_bag, "Inventory", Vector2(4, 1))
	_label(_bag, "Backpack", Vector2(80, 1))
	var view := BackpackView.new()
	view.compact = true
	view.position = Vector2(4, 12)
	_bag.add_child(view)


func _build_upgrades() -> void:
	_upgrade_page = _page("Upgrade")
	var index := 0
	for id in Tune.UPGRADES:
		var tile := _button(_upgrade_page, "", Vector2(4 + (index % 5) * 27, 3 + (index / 5) * 27))
		tile.size = Vector2(25, 25)
		var definition: Dictionary = Tune.UPGRADES[id]
		tile.tooltip_text = "%s\n%s" % [definition.name, definition.details]
		tile.pressed.connect(func() -> void:
			_selected_upgrade = id
			Feel.play(&"ui/click")
			_refresh())
		tile.draw.connect(_draw_upgrade_tile.bind(tile, id, index))
		_upgrade_tiles[id] = tile
		var detail := Control.new()
		detail.position = Vector2(3, 58)
		detail.size = Vector2(137, 33)
		_upgrade_page.add_child(detail)
		detail.draw.connect(func() -> void: detail.draw_texture(UPGRADE_BOX, Vector2.ZERO))
		var title := _label(detail, "", Vector2(3, 2))
		title.size.x = 131
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = MOUSE_FILTER_PASS
		title.tooltip_text = tile.tooltip_text
		var description := _label(detail, Tune.UPGRADES[id].desc, Vector2(3, 11))
		description.size = Vector2(91, 20)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.clip_text = true
		description.mouse_filter = MOUSE_FILTER_PASS
		description.tooltip_text = tile.tooltip_text
		var buy := _button(detail, "", Vector2(96, 20))
		buy.size = Vector2(38, 11)
		buy.pressed.connect(_on_upgrade.bind(id))
		var back := _button(detail, "Return", Vector2(96, 8))
		back.size = Vector2(38, 11)
		back.pressed.connect(_return_upgrade.bind(id))
		_upgrades[id] = [title, buy, back]
		index += 1


func _draw_upgrade_tile(tile: Button, id: StringName, index: int) -> void:
	var color := NAVY if id == _selected_upgrade else INK
	if id == _selected_upgrade:
		tile.draw_rect(Rect2(1, 1, 23, 23), NAVY, false)
	# just bought: the tile blinks inverted, like a selected icon
	var lit := _blink.has(id) and int(_blink[id] * 14.0) % 2 == 1
	if lit:
		tile.draw_rect(Rect2(1, 1, 23, 23), NAVY)
		color = LIGHT
	tile.draw_texture_rect_region(ICONS, Rect2(6, 4, 12, 10), Rect2(index * 12, 0, 12, 10), color)
	var count: int = Tune.UPGRADES[id].costs.size()
	for level in count:
		var on := Game.level(id) > level
		tile.draw_rect(Rect2(4 + level * 6, 19, 4, 2), (LIGHT if lit else NAVY) if on else SHADOW)


## An old message box over the screen: "Are you sure" (`yes` runs on Buy) or a plain note with OK.
func _build_ask() -> void:
	_ask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ask.draw.connect(func() -> void: _ask.draw_rect(Rect2(Vector2.ZERO, _ask.size), Color(INK, 0.5)))
	_screen.add_child(_ask)
	var box := Control.new()
	box.position = Vector2(19, 44)
	box.size = Vector2(111, 44)
	box.draw.connect(func() -> void:
		box.draw_texture(ASK_BOX, Vector2.ZERO)
		_text(box, _ask_title, Vector2(0, 8), box.size.x, LIGHT))
	_ask.add_child(box)
	_ask_text = _label(box, SURE, Vector2(6, 13))
	_ask_text.size.x = 99
	_ask_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for answer in [["Buy", true, 14], ["Cancel", false, 61]]:
		var b := _button(box, answer[0], Vector2(answer[2], 30))
		b.size = Vector2(36, 11)
		b.pressed.connect(_on_ask.bind(answer[1]))
		_ask_buttons.append(b)
	var ok := _button(box, "OK", Vector2(37, 30))
	ok.size = Vector2(36, 11)
	ok.pressed.connect(_on_ok)
	_ask_buttons.append(ok)
	_ask.hide()


func _show_box(title: String, text: String, note: bool) -> void:
	if _ask_shake and _ask_shake.is_valid():
		_ask_shake.kill()
	if _ask_fade and _ask_fade.is_valid():
		_ask_fade.kill()
	_ask.modulate.a = 1.0
	var box := _ask_text.get_parent() as Control
	box.position = Vector2(19, 44)
	_ask_title = title
	_ask_text.text = text
	_ask_buttons[0].visible = not note
	_ask_buttons[1].visible = not note
	_ask_buttons[2].visible = note
	_ask.show()
	_ask_text.get_parent().queue_redraw()
	if title == "Nothing to sell":
		_ask.modulate.a = 0.0
		_ask_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_ask_fade.tween_property(_ask, "modulate:a", 1.0, 0.2)
		_ask_shake = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for offset in [-1.0, 1.0, -0.75, 0.75, 0.0]:
			_ask_shake.tween_property(box, "position:x", 19.0 + offset, 0.06)


func _confirm(yes: Callable) -> void:
	_ask_yes = yes
	_show_box("Are you sure?", SURE, false)
	Feel.play(&"ui/click")


## Start Day is greyed out: a click on it says why instead of doing nothing.
func _on_next_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if not mb or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Time.get_ticks_msec() - _prep_at < START_GUARD:
		_next.accept_event()		# the second half of a double click on Next
		return
	if not _next.disabled:
		return
	_shake_next()
	if Game.restock_cost(1) > Game.money:
		_show_box("Nothing to sell", "Not enough money\nfor one drink.", true)
	else:
		_show_box("Nothing to sell", "Restock supplies\nfor a few drinks first.", true)
	Feel.play(&"ui/error")


func _shake_next() -> void:
	if _next_shake and _next_shake.is_valid():
		_next_shake.kill()
	var home := Vector2(98, 93)
	_next.position = home
	_next_shake = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for offset in [-2.0, 2.0, -1.5, 1.5, 0.0]:
		_next_shake.tween_property(_next, "position:x", home.x + offset, 0.06)


## OK on a note: off to Preparation, where it gets fixed.
func _on_ok() -> void:
	_ask.hide()
	Feel.play(&"ui/click")
	_tabs.current_tab = PREP


func _on_ask(buy: bool) -> void:
	_ask.hide()
	if buy:
		_ask_yes.call()
	else:
		Feel.play(&"ui/click")
	_refresh()


# --- helpers -------------------------------------------------------------------

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 8
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://art/ui/win_button_pressed.png" if state == "pressed" else "res://art/ui/win_button.png")
		style.set_texture_margin_all(2)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 2
		style.content_margin_bottom = 1
		if state == "disabled":
			style.modulate_color = Color(1, 1, 1, OFF)	# greyed out = the same button, faded into the panel
		t.set_stylebox(state, "Button", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("e5e8c7")
	hover.border_color = NAVY
	hover.set_border_width_all(1)
	hover.content_margin_left = 3
	hover.content_margin_right = 3
	hover.content_margin_top = 2
	hover.content_margin_bottom = 1
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("hover_pressed", "Button", t.get_stylebox("pressed", "Button"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, OFF))
	t.set_color("font_color", "Label", INK)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = FIELD
	input_style.border_color = SHADOW
	input_style.set_border_width_all(1)
	input_style.content_margin_left = 3
	input_style.content_margin_right = 1
	input_style.content_margin_top = 0
	input_style.content_margin_bottom = 0
	t.set_stylebox("normal", "LineEdit", input_style)
	t.set_stylebox("read_only", "LineEdit", input_style)
	# Keep native theme assets small enough for the pixel-sized fields.
	t.set_icon("clear", "LineEdit", ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	var input_focus := StyleBoxFlat.new()
	input_focus.bg_color = Color.TRANSPARENT
	input_focus.border_color = NAVY
	input_focus.set_border_width_all(1)
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", NAVY)
	t.set_color("font_selected_color", "LineEdit", LIGHT)
	t.set_constant("line_spacing", "Label", 0)
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 2)
	return t


func _page(title: String) -> Control:
	var page := Control.new()
	page.name = title
	_tabs.add_child(page)
	return page


func _label(parent: Node, text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	label.position = at
	return label


func _button(parent: Node, text: String, at := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	parent.add_child(b)
	b.position = at
	return b

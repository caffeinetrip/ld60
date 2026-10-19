extends RefCounted
## Runtime sprites. All artwork lives in art/ui/hud/run/*.png.

const BOARD_DAY := preload("res://art/ui/hud/run/board_day.png")
const BOARD_MINIGAME := preload("res://art/ui/hud/run/board_minigame.png")
const GLASS := preload("res://art/ui/hud/run/glass_fill.png")
const JAR := preload("res://art/ui/hud/run/jar_fill.png")
const CAT_BASE := preload("res://art/ui/hud/run/cat_base.png")
const CAT_FUR := preload("res://art/ui/hud/run/cat_fur.png")
const CUP := preload("res://art/ui/hud/run/cup.png")
const BILL := preload("res://art/ui/hud/run/bill.png")
const SHELF := preload("res://art/ui/hud/run/shelf.png")
const LEDGE_SHADOW := preload("res://art/ui/hud/run/ledge_shadow.png")
const PANEL := preload("res://art/ui/hud/run/panel.png")
const BUBBLE_TAIL := preload("res://art/ui/hud/run/bubble_tail.png")
const HIT_TRACK := preload("res://art/ui/hud/run/hit_track.png")
const HIT_ZONE := preload("res://art/ui/hud/run/hit_zone.png")
const HIT_CURSOR_BORDER := preload("res://art/ui/hud/run/hit_cursor_border.png")
const HIT_CURSOR := preload("res://art/ui/hud/run/hit_cursor.png")
const HIT_TRAIL := preload("res://art/ui/hud/run/hit_trail.png")


static func wood(on: CanvasItem, r: Rect2) -> void:
	on.draw_texture_rect(BOARD_DAY if r.size.x <= 208 else BOARD_MINIGAME, r, false)


static func glass(on: CanvasItem, at: Vector2, fill: float) -> void:
	var frame := roundi(clampf(fill, 0.0, 1.0) * 13.0)
	on.draw_texture_rect_region(GLASS, Rect2(at, Vector2(26, 32)), Rect2(frame * 26, 0, 26, 32))


static func jar(on: CanvasItem, at: Vector2, fill: float) -> void:
	var frame := ceili(clampf(fill, 0.0, 1.0) * 9.0)
	on.draw_texture_rect_region(JAR, Rect2(at, Vector2(26, 30)), Rect2(frame * 26, 0, 26, 30))


static func cat(on: CanvasItem, at: Vector2, fur: Color) -> void:
	on.draw_texture(CAT_BASE, at)
	on.draw_texture(CAT_FUR, at, fur)


static func cup(on: CanvasItem, at: Vector2) -> void:
	on.draw_texture(CUP, at)


static func panel(on: CanvasItem, r: Rect2) -> void:
	var style := StyleBoxTexture.new()
	style.texture = PANEL
	style.set_texture_margin_all(1)
	on.draw_style_box(style, r)

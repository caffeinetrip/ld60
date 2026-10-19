@tool
extends Node
## Light of the cafe. One source - the windows - and one lit place - the bar: three soft
## window patches across the counter, the stools and the floor where customers order.
## A restrained warm-neutral fill reveals furniture beneath pale, nearly white windows.
##
## night: 0 = muted warm daylight, 1 = deeper blue-grey night.
## Drag it in the inspector or call set_night(). Every value of both
## moods is exported, so a mood is retuned here without touching the scene.

@export_range(0.0, 1.0, 0.01) var night := 0.0:
	set(value):
		night = value
		_apply()

@export_group("Day")
@export var day_ambient := Color(0.44, 0.425, 0.40)
@export var day_fill := Color(0.98, 0.92, 0.83)
@export var day_fill_energy := 0.78
@export var day_sun := Color(1.0, 0.94, 0.84)
@export var day_sun_energy := 1.35
@export var day_glass := Color(1.0, 0.97, 0.90)
@export var day_glass_energy := 1.6
@export var day_haze := Color(0.96, 0.90, 0.80, 0.025)
@export var day_door := Color(1.0, 0.94, 0.85)
@export var day_door_energy := 1.2
@export var day_saturation := 1.10
@export var day_vignette := 0.28
@export var day_shadow_tint := Color(0.49, 0.50, 0.515)
@export var day_highlight_tint := Color(0.53, 0.515, 0.49)

@export_group("Night")
@export var night_ambient := Color(0.20, 0.225, 0.25)
@export var night_fill := Color(0.88, 0.84, 0.77)
@export var night_fill_energy := 0.44
@export var night_sun := Color(0.62, 0.73, 0.76)
@export var night_sun_energy := 1.1
@export var night_glass := Color(0.50, 0.62, 0.64)
@export var night_glass_energy := 0.9
@export var night_haze := Color(0.52, 0.63, 0.66, 0.035)
@export var night_door := Color(0.45, 0.55, 0.8)
@export var night_door_energy := 0.6
@export var night_saturation := 0.96
@export var night_vignette := 0.44
@export var night_shadow_tint := Color(0.49, 0.50, 0.515)
@export var night_highlight_tint := Color(0.515, 0.51, 0.495)

@export_group("Nodes")
@export var ambient: CanvasModulate
@export var fill: PointLight2D
@export var sun: PointLight2D
@export var door: PointLight2D
@export var haze: CanvasItem
@export var glass: Array[CanvasItem] = []
@export var grade: CanvasItem


func _ready() -> void:
	_apply()


## Tween to a mood: 0 day, 1 night.
func set_night(target: float, seconds := 2.5) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "night", clampf(target, 0.0, 1.0), seconds).set_trans(Tween.TRANS_SINE)
	return tween


func _apply() -> void:
	var t := night
	if ambient:
		ambient.color = day_ambient.lerp(night_ambient, t)
	if fill:
		fill.color = day_fill.lerp(night_fill, t)
		fill.energy = lerpf(day_fill_energy, night_fill_energy, t)
	if sun:
		sun.color = day_sun.lerp(night_sun, t)
		sun.energy = lerpf(day_sun_energy, night_sun_energy, t)
	if door:
		door.color = day_door.lerp(night_door, t)
		door.energy = lerpf(day_door_energy, night_door_energy, t)
	if haze:
		haze.modulate = day_haze.lerp(night_haze, t)
	for item in glass:
		var m := item.material as ShaderMaterial if item else null
		if m:
			m.set_shader_parameter("glass_color", day_glass.lerp(night_glass, t))
			m.set_shader_parameter("energy", lerpf(day_glass_energy, night_glass_energy, t))
	var g := grade.material as ShaderMaterial if grade else null
	if g:
		g.set_shader_parameter("night_shadow_grain", t * 0.012)
		g.set_shader_parameter("saturation", lerpf(day_saturation, night_saturation, t))
		g.set_shader_parameter("vignette", lerpf(day_vignette, night_vignette, t))
		g.set_shader_parameter("shadow_tint", day_shadow_tint.lerp(night_shadow_tint, t))
		g.set_shader_parameter("highlight_tint", day_highlight_tint.lerp(night_highlight_tint, t))

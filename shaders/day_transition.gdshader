shader_type canvas_item;
render_mode unshaded;

// A faint warm veil: the cafe stays visible throughout the change of day.
uniform vec4 base_color : source_color = vec4(0.055, 0.039, 0.031, 1.0);
uniform float factor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = smoothstep(0.15, 0.75, length(UV - vec2(0.5)));
	COLOR = vec4(base_color.rgb, factor * mix(0.08, 0.14, edge));
}

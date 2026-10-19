shader_type canvas_item;
render_mode unshaded;

varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV * vec2(textureSize(TEXTURE, 0));
	// The left flank stays in the room's shadow; the face catches the screen light.
	float face = smoothstep(58.0, 80.0, p.x);
	vec3 plastic = mix(vec3(0.38, 0.36, 0.29), vec3(0.67, 0.64, 0.51), face);
	plastic *= mix(1.06, 0.83, UV.y);
	vec2 gap = max(max(vec2(78.0, 14.0) - p, p - vec2(227.0, 145.0)), vec2(0.0));
	float spill = exp(-length(gap) / 7.0) * face;
	vec3 c = art.rgb * plastic;
	c += vec3(0.055, 0.085, 0.070) * spill;
	COLOR = vec4(c, art.a) * item_modulate;
}

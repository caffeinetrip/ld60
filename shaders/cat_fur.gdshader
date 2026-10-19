shader_type canvas_item;

// Lift character fill separately from direct light to keep sunlit details intact.
uniform float direct_light_strength : hint_range(0.0, 1.0) = 0.42;
uniform float ambient_boost : hint_range(1.0, 1.5) = 1.0;
uniform float midtone_gamma : hint_range(0.5, 1.0) = 1.0;

void fragment() {
	// Reveal faces and darker markings while leaving white fur's peak unchanged.
	COLOR.rgb = pow(max(COLOR.rgb, vec3(0.0)), vec3(midtone_gamma)) * ambient_boost;
}

void light() {
	float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	LIGHT = vec4((COLOR.rgb / ambient_boost) * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse * direct_light_strength, LIGHT_COLOR.a);
}

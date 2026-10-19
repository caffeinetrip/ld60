shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Final 640x360 composite: room, HUD, menus and feedback share one screen.
// Base sampling stays pixel-exact; only the faint phosphor halo is filtered.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(0.5, 1.5) = 1.06;
uniform float midtone_gamma : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 1.5) = 0.92;
uniform float warmth : hint_range(0.0, 0.3) = 0.07;
uniform float shadow_teal : hint_range(0.0, 0.3) = 0.08;
uniform float bloom : hint_range(0.0, 1.0) = 0.24;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.52;
uniform float bloom_radius : hint_range(0.5, 4.0) = 1.5;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.16;
uniform float scanlines : hint_range(0.0, 0.4) = 0.10;
uniform float phosphor_mask : hint_range(0.0, 0.2) = 0.045;
uniform float grain : hint_range(0.0, 0.1) = 0.025;
uniform float grain_speed : hint_range(0.0, 30.0) = 8.0;
uniform float dither : hint_range(0.0, 0.03) = 0.004;
uniform float vignette : hint_range(0.0, 0.5) = 0.14;
uniform float intro_glitch : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 sample_screen(vec2 uv) {
	return texture(screen_tex, uv).rgb;
}

vec3 bright(vec2 uv) {
	vec3 c = sample_screen(uv);
	float peak = max(max(c.r, c.g), c.b);
	return c * smoothstep(bloom_threshold, 1.0, peak);
}

void fragment() {
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 uv = (pixel + 0.5) * SCREEN_PIXEL_SIZE;
	vec3 original = sample_screen(uv);
	// Brief, faint tracking slips in the room, above the dialogue text.
	float glitch_tick = floor(TIME * 9.0);
	float glitch_gate = step(0.88, hash(vec2(glitch_tick, 41.0)));
	float band = floor(pixel.y / 12.0);
	float slip = (hash(vec2(band, glitch_tick)) * 2.0 - 1.0);
	float room_mask = 1.0 - smoothstep(0.65, 0.74, SCREEN_UV.y);
	uv.x += slip * glitch_gate * intro_glitch * room_mask * SCREEN_PIXEL_SIZE.x * 1.5;
	vec3 c = sample_screen(uv);
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float edge = dot(centered, centered) * 0.5;
	if (chromatic_aberration > 0.0) {
		vec2 shift = vec2(chromatic_aberration * edge + intro_glitch * room_mask * 0.18, 0.0) * SCREEN_PIXEL_SIZE;
		c.r = sample_screen(uv + shift).r;
		c.b = sample_screen(uv - shift).b;
	}

	if (bloom > 0.0) {
		vec2 step_uv = SCREEN_PIXEL_SIZE * bloom_radius;
		vec3 halo = vec3(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				float weight = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
				halo += bright(uv + vec2(float(x), float(y)) * step_uv) * weight;
			}
		}
		// Screen blend keeps bright text from clipping into a solid white block.
		c += (vec3(1.0) - c) * halo * (bloom / 16.0);
	}

	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	float shadows = 1.0 - smoothstep(0.05, 0.55, luma);
	c *= mix(vec3(1.0), vec3(0.80, 1.06, 1.12), shadows * shadow_teal);
	c *= mix(vec3(1.0), vec3(1.06, 1.025, 0.80), warmth);
	c *= exposure;
	// Lift room and UI midtones without adding light to black or boosting white.
	c = pow(max(c, vec3(0.0)), vec3(midtone_gamma));

	// Two output pixels per room pixel: stable rows instead of rolling/flickering bands.
	float row = mod(pixel.y, 2.0);
	c *= 1.0 - scanlines * row;
	float column = mod(pixel.x, 3.0);
	vec3 mask = column < 1.0 ? vec3(1.0, 0.35, 0.35) :
		(column < 2.0 ? vec3(0.35, 1.0, 0.35) : vec3(0.35, 0.35, 1.0));
	c *= mix(vec3(1.0), mask, phosphor_mask);
	// Compensate average CRT absorption so the already-dark room remains readable.
	c /= (1.0 - scanlines * 0.5) * (1.0 - phosphor_mask * 0.433333);

	float tick = floor(TIME * grain_speed);
	float noise = hash(pixel + mod(tick, 256.0) * vec2(17.0, 29.0)) * 2.0 - 1.0;
	c *= 1.0 + noise * (grain + intro_glitch * room_mask * 0.012);
	float checker = mod(pixel.x + pixel.y, 2.0) - 0.5;
	c += checker * dither * smoothstep(0.0, 0.12, luma);
	c *= 1.0 - vignette * smoothstep(0.22, 1.0, edge);
	COLOR = vec4(mix(original, clamp(c, 0.0, 1.0), strength), 1.0);
}

shader_type canvas_item;
// Whole-screen look on a full-rect ColorRect in a CanvasLayer. In order:
//   diffusion  - a soft halo: the image is pulled towards a lightly blurred copy
//   bloom      - bright pixels (the window, the lit bar) glow softly
//   exposure, contrast, saturation, split toning (shadow / highlight tints)
//   palette    - optional gradient map (dark -> light) to try colour schemes later
//   vignette   - the room dissolves into black at the edges
//   aberration - colour fringe growing towards the edges (px at the corners)
//   grain      - fine film grain, re-rolled 12 times a second
// Blur comes from the screen texture's mip levels, so it is cheap at 320x180.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float exposure = 1.0;
uniform float contrast = 1.0;
// Lift interior midtones separately from the black frame and bright windows.
uniform float midtone_gamma : hint_range(0.5, 1.5) = 1.0;
uniform float saturation = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);     // 0.5 grey = neutral
uniform vec4 highlight_tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float tint_strength = 0.5;

uniform float diffusion : hint_range(0.0, 1.0) = 0.4;
uniform float bloom = 1.0;
uniform float bloom_threshold = 0.5;

uniform sampler2D palette : filter_linear, repeat_disable;
uniform float palette_mix : hint_range(0.0, 1.0) = 0.0;

uniform float aberration = 0.0;
uniform float grain = 0.0;
uniform float night_shadow_grain : hint_range(0.0, 0.03) = 0.0;

uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius = 0.62;
uniform float vignette_softness = 0.45;

// Match the HUD's muted, worn material while retaining the day/night lighting.
uniform float worn_mix : hint_range(0.0, 1.0) = 0.7;
uniform float worn_grain : hint_range(0.0, 0.1) = 0.03;

// Room-only film response: cool grey-green shadows and pale window whites.
// This happens before the HUD is composited, so small text retains its contrast.
uniform float atmosphere : hint_range(0.0, 1.0) = 0.75;
uniform float shadow_detail : hint_range(0.0, 0.1) = 0.025;
uniform float highlight_rolloff : hint_range(0.0, 1.0) = 0.55;
uniform float intro_liminal : hint_range(0.0, 1.0) = 0.0;
uniform float day_five_dread : hint_range(0.0, 1.0) = 0.0;

float worn_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float worn_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(worn_hash(i), worn_hash(i + vec2(1.0, 0.0)), f.x),
		mix(worn_hash(i + vec2(0.0, 1.0)), worn_hash(i + vec2(1.0)), f.x), f.y);
}

vec3 blurred_screen(vec2 uv, vec2 pixel_size, float lod) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility has a narrower blur and caps this viewport's mip chain early.
	if (lod <= 2.0) {
		return textureLod(screen_tex, uv, lod + 1.0).rgb;
	}
	float radius = sqrt(exp2(2.0 * (lod + 1.0)) - 64.0);
	vec3 result = vec3(0.0);
	for (int y = -2; y <= 2; y++) {
		float wy = y == 0 ? 6.0 : (abs(y) == 1 ? 4.0 : 1.0);
		for (int x = -2; x <= 2; x++) {
			float wx = x == 0 ? 6.0 : (abs(x) == 1 ? 4.0 : 1.0);
			vec2 offset = vec2(float(x), float(y)) * pixel_size * radius;
			result += textureLod(screen_tex, clamp(uv + offset, vec2(0.0), vec2(1.0)), 3.0).rgb * wx * wy;
		}
	}
	return result / 256.0;
#else
	return textureLod(screen_tex, uv, lod).rgb;
#endif
}

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (aberration > 0.0) {
		vec2 shift = (SCREEN_UV - 0.5) * 2.0 * aberration * SCREEN_PIXEL_SIZE;
		c.r = textureLod(screen_tex, SCREEN_UV + shift, 0.0).r;
		c.b = textureLod(screen_tex, SCREEN_UV - shift, 0.0).b;
	}
	vec3 b1 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 1.2);
	vec3 b2 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 2.5);
	vec3 b3 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 4.0);

	c = mix(c, max(c, b1), diffusion * mix(1.0, 0.25, worn_mix));
	vec3 glow = max(b2 - bloom_threshold, vec3(0.0)) * 0.7 + max(b3 - bloom_threshold * 0.7, vec3(0.0)) * 0.9;
	c += glow * bloom * mix(1.0, 0.4, worn_mix);

	c *= exposure;
	c = (c - 0.5) * contrast + 0.5;
	float l = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	c = mix(vec3(l), c, saturation);
	float shadows = 1.0 - smoothstep(0.0, 0.45, l);
	float highlights = smoothstep(0.35, 1.0, l);
	c += (shadow_tint.rgb - 0.5) * shadows * tint_strength;
	c += (highlight_tint.rgb - 0.5) * highlights * tint_strength;

	// UI art uses saturation 0.75 and gain 0.62. Keep the room's light sources
	// brighter, but bring its midtones into that same subdued material range.
	float material_luma = max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0);
	vec3 worn = mix(vec3(material_luma), c, 0.75);
	worn *= mix(0.78, 0.94, smoothstep(0.35, 0.9, material_luma));
	// One room pixel is two UI pixels: the same grain size as ui_worn.
	vec2 material_cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	float speckle = (worn_hash(material_cell) - 0.5) * 2.0 * worn_grain;
	float patches = (worn_noise(material_cell / 3.0) - 0.5) * 0.1;
	worn *= 1.0 + speckle + patches;
	c = mix(c, worn, worn_mix);

	float room_luma = max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0);
	float dim = 1.0 - smoothstep(0.12, 0.48, room_luma);
	vec3 film = mix(c, vec3(room_luma) * vec3(0.94, 1.0, 1.02), dim * 0.32);
	// Reveal the furniture in the dark without lifting the black void around it.
	float detail_mask = smoothstep(0.018, 0.10, room_luma) * dim;
	film += vec3(0.92, 0.98, 1.0) * shadow_detail * detail_mask;
	film = max(film, vec3(0.0));
	film /= vec3(1.0) + max(film - vec3(0.38), vec3(0.0)) * highlight_rolloff;
	// A little light scattered from the windows; no full-screen grey fog layer.
	film += b3 * vec3(0.90, 0.98, 1.0) * 0.025 * detail_mask;
	c = mix(c, film, atmosphere);

	float interior = smoothstep(0.008, 0.035, max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0));
	c = mix(c, pow(max(c, vec3(0.0)), vec3(midtone_gamma)), interior);

	if (palette_mix > 0.001) {
		vec3 p = texture(palette, vec2(l, 0.5)).rgb;
		c = mix(c, p, palette_mix);
	}

	vec2 q = (SCREEN_UV - 0.5) * vec2(1.0, 1.15);
	float v = 1.0 - smoothstep(vignette_radius - vignette_softness, vignette_radius, length(q));
	c *= mix(1.0 - vignette, 1.0, v);

	if (grain > 0.0) {
		vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + floor(TIME * 12.0) * vec2(17.0, 31.0);
		c += (fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * grain;
	}

	// Barely visible night noise: strongest in deep shadows, absent in lit areas.
	float darkness = 1.0 - smoothstep(0.015, 0.35, max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0));
	vec2 noise_cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + mod(floor(TIME * 10.0), 256.0) * vec2(19.0, 37.0);
	c += (worn_hash(noise_cell) - 0.5) * night_shadow_grain * darkness;
	if (intro_liminal > 0.0) {
		// Quiet, empty-room mood: pale cool light and soft shadows, no interference.
		float quiet_luma = max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0);
		vec3 quiet = mix(vec3(quiet_luma), c, 0.78) * vec3(0.93, 0.99, 1.02);
		quiet = mix(quiet, max(quiet, b1 * vec3(0.93, 0.99, 1.02)), 0.08);
		quiet *= 1.0 - 0.08 * smoothstep(0.18, 0.65, length(q));
		c = mix(c, quiet, intro_liminal);
	}
	if (day_five_dread > 0.0) {
		float breath = 0.5 + 0.5 * sin(TIME * 0.7);
		float dread_luma = max(dot(c, vec3(0.299, 0.587, 0.114)), 0.0);
		vec3 dread = mix(vec3(dread_luma), c, 0.55) * vec3(0.82, 0.94, 0.91);
		dread *= 0.94 - 0.05 * breath;
		dread *= 1.0 - (0.30 + 0.06 * breath) * smoothstep(0.18, 0.62, length(q));
		dread += (worn_hash(noise_cell) - 0.5) * 0.018 * smoothstep(0.01, 0.08, dread_luma);
		c = mix(c, dread, day_five_dread);
	}
	// The screen's own alpha: 1 in the room, the portraits' outline in Dialogue's viewport.
	COLOR = vec4(clamp(c, 0.0, 1.0), textureLod(screen_tex, SCREEN_UV, 0.0).a);
}

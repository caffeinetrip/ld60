shader_type canvas_item;
// Whole-screen look on a full-rect ColorRect in a CanvasLayer. In order:
//   diffusion  - a soft halo: the image is pulled towards a lightly blurred copy
//   bloom      - bright pixels (the window, the lit bar) glow softly
//   exposure, contrast, saturation, split toning (shadow / highlight tints)
//   palette    - optional gradient map (dark -> light) to try colour schemes later
//   vignette   - the room dissolves into black at the edges
// Blur comes from the screen texture's mip levels, so it is cheap at 320x180.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);     // 0.5 grey = neutral
uniform vec4 highlight_tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float tint_strength = 0.5;

uniform float diffusion : hint_range(0.0, 1.0) = 0.4;
uniform float bloom = 1.0;
uniform float bloom_threshold = 0.5;

uniform sampler2D palette : filter_linear, repeat_disable;
uniform float palette_mix : hint_range(0.0, 1.0) = 0.0;

uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius = 0.62;
uniform float vignette_softness = 0.45;

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
	vec3 b1 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 1.2);
	vec3 b2 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 2.5);
	vec3 b3 = blurred_screen(SCREEN_UV, SCREEN_PIXEL_SIZE, 4.0);

	c = mix(c, max(c, b1), diffusion);
	vec3 glow = max(b2 - bloom_threshold, vec3(0.0)) * 0.7 + max(b3 - bloom_threshold * 0.7, vec3(0.0)) * 0.9;
	c += glow * bloom;

	c *= exposure;
	c = (c - 0.5) * contrast + 0.5;
	float l = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	c = mix(vec3(l), c, saturation);
	float shadows = 1.0 - smoothstep(0.0, 0.45, l);
	float highlights = smoothstep(0.35, 1.0, l);
	c += (shadow_tint.rgb - 0.5) * shadows * tint_strength;
	c += (highlight_tint.rgb - 0.5) * highlights * tint_strength;

	if (palette_mix > 0.001) {
		vec3 p = texture(palette, vec2(l, 0.5)).rgb;
		c = mix(c, p, palette_mix);
	}

	vec2 q = (SCREEN_UV - 0.5) * vec2(1.0, 1.15);
	float v = 1.0 - smoothstep(vignette_radius - vignette_softness, vignette_radius, length(q));
	c *= mix(1.0 - vignette, 1.0, v);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 screen_size = vec2(149.0, 131.0);
uniform float curvature : hint_range(0.0, 0.05) = 0.015;
uniform float scanlines : hint_range(0.0, 0.5) = 0.13;
uniform float phosphor : hint_range(0.0, 0.3) = 0.065;
uniform float glow : hint_range(0.0, 0.5) = 0.28;

varying vec2 origin;
varying vec2 axis_x;
varying vec2 axis_y;
varying float panel_opacity;

void vertex() {
	panel_opacity = COLOR.a;
	// Follow the monitor's slide-in, its 2x scale and window resizing.
	mat4 canvas = CANVAS_MATRIX * MODEL_MATRIX;
	origin = (canvas * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	axis_x = (canvas * vec4(screen_size.x, 0.0, 0.0, 0.0)).xy;
	axis_y = (canvas * vec4(0.0, screen_size.y, 0.0, 0.0)).xy;
}

vec3 sample_glass(vec2 uv, vec2 pixel_size) {
	// Sample only the display, never the beige casing or another menu.
	vec2 safe_uv = clamp(uv, 0.5 / screen_size, vec2(1.0) - 0.5 / screen_size);
	return texture(screen_tex, (origin + axis_x * safe_uv.x + axis_y * safe_uv.y) * pixel_size).rgb;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 curved = p * (vec2(1.0) + curvature * p.yx * p.yx);
	vec2 uv = curved * 0.5 + 0.5;
	vec2 texel = 1.0 / screen_size;
	vec3 c = sample_glass(uv, SCREEN_PIXEL_SIZE);
	// Sub-pixel RGB convergence: less than a third of a logical display pixel.
	c.r = mix(c.r, sample_glass(uv + vec2(texel.x * 0.28, 0.0), SCREEN_PIXEL_SIZE).r, 0.4);
	c.b = mix(c.b, sample_glass(uv - vec2(texel.x * 0.28, 0.0), SCREEN_PIXEL_SIZE).b, 0.4);
	vec3 halo = sample_glass(uv + vec2(texel.x, 0.0), SCREEN_PIXEL_SIZE)
		+ sample_glass(uv - vec2(texel.x, 0.0), SCREEN_PIXEL_SIZE)
		+ sample_glass(uv + vec2(0.0, texel.y), SCREEN_PIXEL_SIZE)
		+ sample_glass(uv - vec2(0.0, texel.y), SCREEN_PIXEL_SIZE);
	c += max(halo * 0.25 - vec3(0.48), vec3(0.0)) * (1.0 - c) * glow;
	c = pow(max(c, vec3(0.0)), vec3(0.92)) * vec3(0.91, 0.98, 0.95);

	// Two output rows per display pixel. Stable scanlines, no rolling band.
	vec2 raster = floor(UV * vec2(length(axis_x), length(axis_y)));
	c *= 1.0 - scanlines * mod(raster.y, 2.0);
	float column = mod(raster.x, 3.0);
	vec3 mask = column < 1.0 ? vec3(1.0, 0.4, 0.4) :
		(column < 2.0 ? vec3(0.4, 1.0, 0.4) : vec3(0.4, 0.4, 1.0));
	c *= mix(vec3(1.0), mask, phosphor);
	c /= (1.0 - scanlines * 0.5) * (1.0 - phosphor * 0.4);
	float edge = dot(p, p) * 0.5;
	c *= 1.0 - 0.27 * smoothstep(0.18, 1.0, edge);
	// Broad, faint reflection on the convex glass, strongest over the dark desktop.
	float reflection = exp(-dot((UV - vec2(0.25, 0.16)) * vec2(2.4, 5.0),
		(UV - vec2(0.25, 0.16)) * vec2(2.4, 5.0)));
	c += vec3(0.025, 0.037, 0.033) * reflection * (1.0 - c);
	float grain = fract(sin(dot(raster + floor(TIME * 8.0), vec2(12.9898, 78.233))) * 43758.5453);
	c *= 1.0 + (grain - 0.5) * 0.025;
	// Rounded glass opening and dark rim create a convex tube silhouette.
	vec2 corner = abs(curved) - vec2(0.955);
	float distance_to_rim = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - 0.035;
	float glass = 1.0 - smoothstep(-0.008, 0.006, distance_to_rim);
	c = mix(vec3(0.014, 0.022, 0.020), c, glass);
	// The captured UI already includes the parent's fade. Fade only the CRT
	// treatment, leaving that composite untouched when the computer is invisible.
	vec3 original = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(original, clamp(c, 0.0, 1.0), panel_opacity), 1.0);
}

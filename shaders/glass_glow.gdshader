shader_type canvas_item;
render_mode unshaded;
// Overlay layer over the window tiles (and the open entrance): keeps only the glass and
// lets it glow in the colour of the time of day. Frames, transoms' bars and walls are
// discarded, so they stay lit by the room's lights in the layer below. Unshaded: the
// ambient darkness does not dim the glass. Clouds drift over it slowly and softly.

uniform vec4 glass_color : source_color = vec4(1.0, 0.93, 0.8, 1.0);
uniform float energy = 1.0;
uniform float transom_energy = 0.4;   // the frosted strip at the top of each window
uniform float cloud_depth : hint_range(0.0, 0.5) = 0.12;
uniform float rain_strength : hint_range(0.0, 1.0) = 0.65;
uniform float rain_speed : hint_range(0.0, 4.0) = 2.5;
uniform sampler2D deadcat_texture : source_color, filter_nearest, repeat_disable;
uniform bool deadcat_visible = false;
uniform vec2 deadcat_origin = vec2(270.0, 43.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float rain_layer(vec2 p, float spacing, float speed, float seed) {
	// Slightly slanted, independently staggered streaks in room pixels.
	p.x -= p.y * 0.055;
	float lane = floor(p.x / spacing);
	float h = fract(sin(lane * 127.1 + seed) * 43758.5453);
	float center = (0.2 + h * 0.6) * spacing;
	float line = 1.0 - smoothstep(0.2, 0.8, abs(mod(p.x, spacing) - center));
	float cycle = 27.0 + h * 23.0;
	float y = mod(p.y - TIME * speed * rain_speed * (0.8 + h * 0.4) + h * 97.0, cycle);
	float length = 3.0 + h * 5.0;
	float tail = smoothstep(0.0, length, y) * (1.0 - smoothstep(length, length + 1.0, y));
	return line * tail;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luma = (c.r + c.g + c.b) / 3.0;
	float clear = step(0.55, luma);
	float frosted = (1.0 - clear) * step(0.04, c.g - c.r) * step(c.r, c.b);
	if (c.a < 0.5 || clear + frosted < 0.5) {
		discard;
	}
	float cloud = 0.5 + 0.5 * sin(world.x * 0.035 + TIME * 0.12) * sin(world.y * 0.05 - TIME * 0.08 + 1.3);
	float k = clear * luma + frosted * transom_energy;
	vec3 glass = glass_color.rgb * energy * k * (1.0 - cloud_depth * cloud);
	if (deadcat_visible) {
		vec2 cat_uv = (world - deadcat_origin) / vec2(textureSize(deadcat_texture, 0));
		if (all(greaterThanEqual(cat_uv, vec2(0.0))) && all(lessThan(cat_uv, vec2(1.0)))) {
			vec4 cat = texture(deadcat_texture, cat_uv);
			// Inside the original glass mask: the frame occludes the cat, rain crosses it.
			glass = mix(glass, cat.rgb * vec3(0.72, 0.79, 0.77), cat.a * clear * 0.92);
		}
	}
	float rain = rain_layer(world, 5.5, 43.0, 1.7) * 0.65
		+ rain_layer(world + vec2(13.0, 7.0), 8.0, 68.0, 8.3) * 0.45;
	// The original glass mask clips rain behind frames, walls and furniture.
	float wet = rain * rain_strength * (clear + frosted * 0.2);
	glass = mix(glass, glass * 0.48 + vec3(0.10, 0.12, 0.11), clamp(wet, 0.0, 1.0));
	COLOR = vec4(glass, 1.0);
}

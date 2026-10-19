shader_type canvas_item;
render_mode unshaded;
// Draws the sprite's shape in one flat colour, softened, and only where the picture behind it
// is as bright as `from_light`..`to_light`: a leaf outside seen through the window glass, or
// its shadow on the lit stripes of the floor. Nothing above `above_y` (world px) is drawn.
// The draw call's colour alpha fades it.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float from_light = 0.7;
uniform float full_light = 0.86;
uniform float to_light = 2.0;
uniform float soft = 0.6;			// blur radius in texels
uniform float above_y = -10000.0;

varying vec2 world;
varying float fade;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	fade = COLOR.a;
}

void fragment() {
	float a = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float w = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
			a += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * soft).a * w;
		}
	}
	a /= 16.0;
	float light = dot(texture(screen, SCREEN_UV).rgb, vec3(0.299, 0.587, 0.114));
	float mask = smoothstep(from_light, full_light, light) * (1.0 - smoothstep(to_light, to_light + 0.04, light));
	mask *= step(above_y, world.y);
	COLOR = vec4(tint.rgb, tint.a * a * mask * fade);
}

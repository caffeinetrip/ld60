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

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	COLOR = vec4(glass_color.rgb * energy * k * (1.0 - cloud_depth * cloud), 1.0);
}

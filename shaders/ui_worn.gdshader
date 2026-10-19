shader_type canvas_item;
// Old, worn print for the HUD, sunk into the shadow (owner's pick, v12 "in the shadow"): light
// grain, a few blotches and chipped pixels, then a bit less colour and a lot less light. The
// noise sits on the node's own grid of art pixels (`cell` UI px), so nothing crawls and it is
// as chunky as the art.

uniform float cell = 2.0;
uniform float grain = 0.03;
uniform float blotch = 0.05;
uniform float chips = 0.01;		// share of pixels worn darker
uniform float chip_dark = 0.6;
uniform float saturation = 0.75;
uniform float gain = 0.62;

varying vec2 px;

void vertex() {
	px = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = floor(px / cell);
	vec3 c = COLOR.rgb;
	float g = (hash(p) - 0.5) * 2.0 * grain;
	float b = (noise(p / 3.0) - 0.5) * 2.0 * blotch;
	c *= 1.0 + g + b;
	if (hash(p + vec2(17.31, 5.7)) < chips) {
		c *= chip_dark;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * gain;
	COLOR = vec4(max(c, vec3(0.0)), COLOR.a);
}

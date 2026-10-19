shader_type canvas_item;
// The talk's dim over the room. With `veil` up, everything but a soft rounded hole
// around `spot` (UI px) goes dark; a faint warm light sits in the hole.

uniform float dim = 0.12;
uniform float dark = 0.78;
uniform vec4 light : source_color = vec4(0.94, 0.81, 0.54, 1.0);
uniform float glow = 0.1;
uniform float veil = 0.0;
uniform vec4 spot = vec4(0.0);
uniform float soft = 16.0;
uniform float radius = 6.0;
uniform vec2 size = vec2(640.0, 360.0);

void fragment() {
	vec2 p = floor(UV * size) + 0.5;
	vec2 half_size = spot.zw * 0.5;
	vec2 d = abs(p - (spot.xy + half_size)) - (half_size - radius);
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
	float outside = smoothstep(0.0, soft, dist);
	float shade = mix(dim, dark * outside, veil);
	float lit = glow * (1.0 - outside) * veil;
	float a = shade + lit;
	COLOR = vec4(light.rgb * lit / max(a, 0.001), COLOR.a * a);
}

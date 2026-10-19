shader_type canvas_item;
// The HUD in four colours taken from the room. Whatever the UI draws is mapped by
// brightness: black -> c0, ~0.2 -> c1, ~0.5 -> c2, white -> c3. Alpha is kept.

uniform vec4 c0 : source_color = vec4(0.063, 0.043, 0.031, 1.0);	// #100b08 the dark
uniform vec4 c1 : source_color = vec4(0.227, 0.173, 0.133, 1.0);	// #3a2c22 dim
uniform vec4 c2 : source_color = vec4(0.565, 0.494, 0.400, 1.0);	// #907e66 mid
uniform vec4 c3 : source_color = vec4(0.973, 0.824, 0.627, 1.0);	// #f8d2a0 window light
uniform vec3 steps = vec3(0.12, 0.32, 0.62);

void fragment() {
	float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c = l < steps.x ? c0.rgb : (l < steps.y ? c1.rgb : (l < steps.z ? c2.rgb : c3.rgb));
	COLOR = vec4(c, COLOR.a);
}

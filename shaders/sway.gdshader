shader_type canvas_item;
// Hanging lamp swaying from its hook. Rows shift by whole pixels, more towards the
// bottom; nothing rotates, so the pixels stay crisp. The sprite's origin is the hook.

uniform float amplitude_px = 1.0;
uniform float speed = 0.8;
uniform float phase = 0.0;
uniform float length_px = 52.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float k = clamp(local_y / length_px, 0.0, 1.0);
	float shift = floor(sin(TIME * speed + phase) * amplitude_px * k + 0.5);
	COLOR = texture(TEXTURE, UV - vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0));
}

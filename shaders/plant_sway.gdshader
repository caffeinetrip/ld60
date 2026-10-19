shader_type canvas_item;
// Bend foliage above the pot; sample only this sprite's atlas region.
uniform float amplitude_px = 1.3;
uniform float speed = 0.85;
uniform float phase = 0.0;
uniform float foliage_height = 32.0;
uniform vec4 atlas_region = vec4(0.0, 176.0, 32.0, 48.0);
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float height = clamp(-local_y / foliage_height, 0.0, 1.0);
	float bend = height * height;
	float breeze = sin(TIME * speed + phase) * 0.8
		+ sin(TIME * speed * 0.47 + phase + 1.2) * 0.2;
	float flutter = sin(TIME * 1.7 + local_y * 0.22 + phase) * 0.18 * bend;
	vec2 sample_uv = UV - vec2((breeze * amplitude_px * bend + flutter) * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec2 lower = atlas_region.xy * TEXTURE_PIXEL_SIZE;
	vec2 upper = (atlas_region.xy + atlas_region.zw) * TEXTURE_PIXEL_SIZE;
	if (any(lessThan(sample_uv, lower)) || any(greaterThanEqual(sample_uv, upper))) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, sample_uv);
	}
}

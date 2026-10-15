shader_type canvas_item;
// ランタンに照らされた夜の木の机。描画フェーズの背景。

uniform vec4 wood_light : source_color = vec4(0.36, 0.25, 0.17, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.14, 0.1, 0.08, 1.0);
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec2 light_pos = vec2(0.5, 0.45);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * size;
	float plank = floor(p.y / 180.0);
	float n = noise(vec2(p.x * 0.004 + plank * 13.0, p.y * 0.06));
	float grain = sin(p.y * 0.12 + n * 9.0 + plank * 2.0) * 0.5 + 0.5;
	vec3 col = mix(wood_dark.rgb, wood_light.rgb, 0.3 + 0.4 * grain + 0.2 * noise(p * 0.05));
	float seam = 1.0 - smoothstep(0.0, 2.0, abs(mod(p.y, 180.0) - 1.0));
	col *= 1.0 - seam * 0.4;
	vec2 d = (UV - light_pos) * vec2(size.x / size.y, 1.0);
	float light = exp(-dot(d, d) * 1.6);
	col *= 0.35 + 0.95 * light;
	col += vec3(0.25, 0.14, 0.04) * light * 0.25;
	COLOR = vec4(col, 1.0);
}

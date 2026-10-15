shader_type canvas_item;
// 流れる霧。上下の端は透明にして帯にする。

uniform vec4 fog_color : source_color = vec4(0.68, 0.71, 0.76, 1.0);
uniform float density = 0.6;
uniform float speed = 0.02;
uniform vec2 size = vec2(1360.0, 200.0);
uniform float scale = 220.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * size / scale;
	p.x += TIME * speed;
	float f = fbm(vec2(p.x, p.y * 2.5) + vec2(fbm(p + TIME * speed * 0.7), 0.0));
	float band = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	float a = smoothstep(0.35, 0.75, f) * band * density;
	COLOR = vec4(fog_color.rgb, a);
}

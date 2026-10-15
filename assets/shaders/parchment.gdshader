shader_type canvas_item;
// 古い記録帳の紙。シミ・ムラ・縁の焼け。

uniform vec4 paper : source_color = vec4(0.9, 0.85, 0.72, 1.0);
uniform vec4 stain : source_color = vec4(0.62, 0.5, 0.33, 1.0);
uniform vec2 size = vec2(480.0, 450.0);

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
	vec2 p = UV * size;
	vec3 col = paper.rgb * (0.94 + 0.08 * fbm(p * 0.02));
	col = mix(col, stain.rgb, smoothstep(0.62, 0.8, fbm(p * 0.012 + 3.0)) * 0.25);
	col -= 0.03 * hash(floor(p));
	vec2 e = min(UV, 1.0 - UV) * size;
	float edge = 1.0 - smoothstep(0.0, 26.0, min(e.x, e.y));
	col = mix(col, stain.rgb * 0.8, edge * 0.45);
	COLOR = vec4(col, 1.0);
}

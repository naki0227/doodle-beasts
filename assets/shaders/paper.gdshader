shader_type canvas_item;
// ノートの紙。罫線・余白線・紙の繊維・周辺減光。

uniform vec4 paper : source_color = vec4(0.984, 0.965, 0.918, 1.0);
uniform vec4 line_color : source_color = vec4(0.62, 0.76, 0.9, 1.0);
uniform vec4 margin_color : source_color = vec4(0.9, 0.52, 0.52, 1.0);
uniform vec2 size = vec2(1280.0, 720.0);
uniform float line_spacing = 40.0;
uniform float line_strength = 0.5;
uniform float margin_x = 110.0;
uniform float vignette = 0.32;

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
	vec3 col = paper.rgb;
	// 紙のムラと繊維
	col *= 0.97 + 0.04 * noise(p * 0.02) + 0.02 * noise(p * 0.3);
	col -= 0.035 * smoothstep(0.75, 1.0, noise(vec2(p.x * 0.6, p.y * 0.02)));
	col -= 0.02 * hash(floor(p));
	// 罫線
	float fy = mod(p.y, line_spacing);
	float line = 1.0 - smoothstep(0.4, 1.6, min(fy, line_spacing - fy));
	col = mix(col, line_color.rgb, line * line_strength);
	// 余白の赤線（二本）
	float m1 = 1.0 - smoothstep(0.5, 1.5, abs(p.x - margin_x));
	float m2 = 1.0 - smoothstep(0.5, 1.5, abs(p.x - margin_x - 5.0));
	col = mix(col, margin_color.rgb, max(m1, m2) * 0.6);
	// 周辺減光
	vec2 d = UV - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(col, 1.0);
}

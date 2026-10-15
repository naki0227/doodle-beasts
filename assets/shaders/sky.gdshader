shader_type canvas_item;
// 夕暮れの空。上は灰青、地平線に近いほど暖かい色。流れる雲と、世界樹の後ろの光。

uniform vec4 top_color : source_color = vec4(0.17, 0.2, 0.28, 1.0);
uniform vec4 mid_color : source_color = vec4(0.36, 0.4, 0.5, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.83, 0.64, 0.45, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.22, 0.24, 0.31, 1.0);
uniform vec2 size = vec2(1360.0, 300.0);
uniform vec2 sun = vec2(0.74, 0.86);
uniform float horizon = 0.92;

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
	float y = UV.y / horizon;
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.6, y));
	col = mix(col, horizon_color.rgb, smoothstep(0.55, 1.0, y) * 0.85);
	vec2 d = (UV - sun) * vec2(size.x / size.y, 1.0);
	float glow = exp(-dot(d, d) * 5.0);
	col += horizon_color.rgb * glow * 0.45;
	vec2 p = UV * size / 140.0;
	p.x += TIME * 0.015;
	float c = fbm(vec2(p.x * 0.6, p.y * 2.2));
	float band = smoothstep(0.48, 0.72, c) * (1.0 - smoothstep(0.75, 1.0, y));
	col = mix(col, cloud_color.rgb + horizon_color.rgb * glow * 0.3, band * 0.75);
	float rim = smoothstep(0.66, 0.7, c) - smoothstep(0.7, 0.76, c);
	col += horizon_color.rgb * rim * 0.12 * (0.4 + glow);
	COLOR = vec4(col, 1.0);
}

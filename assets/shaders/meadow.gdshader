shader_type canvas_item;
// 苔と草の地面。奥（上）ほど霧に溶ける。白い小花と石が点々とある。

uniform vec4 moss_dark : source_color = vec4(0.27, 0.31, 0.18, 1.0);
uniform vec4 moss : source_color = vec4(0.4, 0.45, 0.24, 1.0);
uniform vec4 moss_light : source_color = vec4(0.56, 0.6, 0.33, 1.0);
uniform vec4 earth : source_color = vec4(0.33, 0.29, 0.22, 1.0);
uniform vec4 fog_color : source_color = vec4(0.6, 0.63, 0.68, 1.0);
uniform vec2 size = vec2(1360.0, 600.0);
uniform float fog_depth = 0.3;

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
	float n = fbm(p * 0.008);
	float n2 = fbm(p * 0.03 + 4.0);
	vec3 col = mix(moss_dark.rgb, moss.rgb, smoothstep(0.32, 0.68, n));
	col = mix(col, moss_light.rgb, smoothstep(0.58, 0.85, n2) * 0.55);
	col = mix(col, earth.rgb, smoothstep(0.66, 0.8, fbm(p * 0.012 + 20.0)) * 0.6);
	float blade = hash(floor(p / vec2(2.0, 6.0)));
	col *= 0.86 + 0.2 * blade;
	float f = hash(floor(p / 3.0) + 7.0);
	float cluster = smoothstep(0.55, 0.7, fbm(p * 0.02 + 9.0));
	if (f > 0.985 && cluster > 0.0) {
		col = mix(col, vec3(0.9, 0.88, 0.82), 0.85 * cluster);
	} else if (f < 0.006 && cluster > 0.0) {
		col = mix(col, vec3(0.66, 0.6, 0.78), 0.8 * cluster);
	}
	float depth = smoothstep(0.0, fog_depth, UV.y);
	col = mix(fog_color.rgb, col, 0.35 + 0.65 * depth);
	COLOR = vec4(col, 1.0);
}

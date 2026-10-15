shader_type canvas_item;
// 石・骨・布の表面の質感。明るい色の面にだけ粒とムラを乗せ、moss > 0 なら苔の斑点を混ぜる。
// 暗い色（輪郭線）と金の線には何もしない。boil > 0 で線を手描きアニメのように揺らす（既定はなし）。

uniform float boil_amount = 0.0;
uniform float boil_fps = 8.0;
uniform float grain = 1.0;
uniform float moss = 0.0;
uniform vec4 moss_color : source_color = vec4(0.36, 0.41, 0.2, 1.0);

varying vec2 local_pos;

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

void vertex() {
	local_pos = VERTEX;
	if (boil_amount > 0.0) {
		float step_t = floor(TIME * boil_fps);
		vec2 key = floor(VERTEX * 0.5) + vec2(step_t * 17.13, step_t * 3.71);
		VERTEX += (vec2(hash(key), hash(key.yx + 7.0)) - 0.5) * 2.0 * boil_amount;
	}
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	bool golden = c.r > 0.7 && c.g > 0.5 && c.b < 0.5;
	if (lum > 0.3 && !golden) {
		vec2 p = local_pos;
		float n = noise(p * 0.07);
		float speck = hash(floor(p * 0.6));
		c.rgb *= mix(1.0, 0.86 + 0.1 * n + 0.08 * speck, grain);
		if (moss > 0.0) {
			float m = smoothstep(0.62, 0.78, noise(p * 0.05 + 11.0) * 0.7 + speck * 0.3);
			c.rgb = mix(c.rgb, moss_color.rgb * (0.85 + 0.3 * speck), m * moss);
		}
	}
	COLOR = c;
}

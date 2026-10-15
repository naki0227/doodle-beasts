shader_type canvas_item;
// らくがきの質感。頂点を 1 秒に数回ずつ揺らして手描きアニメの「線のふるえ」を出し、
// 明るい色の塗りにはクレヨンのムラを乗せる。暗い色（インクの線）はムラを乗せない。

uniform float boil_amount = 1.2;
uniform float boil_fps = 8.0;
uniform float crayon = 1.0;

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
	float step_t = floor(TIME * boil_fps);
	vec2 key = floor(VERTEX * 0.5) + vec2(step_t * 17.13, step_t * 3.71);
	VERTEX += (vec2(hash(key), hash(key.yx + 7.0)) - 0.5) * 2.0 * boil_amount;
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (crayon > 0.0 && lum > 0.4) {
		vec2 p = local_pos;
		float n = noise(p * 0.08);
		float streak = sin((p.x + p.y) * 0.9 + n * 6.0) * 0.5 + 0.5;
		float grain = hash(floor(p * 1.3));
		float k = mix(0.88, 1.05, streak * 0.55 + grain * 0.45);
		c.rgb *= mix(1.0, k, crayon);
		float holes = smoothstep(0.0, 0.25, streak * 0.7 + grain * 0.6 - 0.1);
		c.a *= mix(1.0, mix(0.72, 1.0, holes), crayon);
	}
	COLOR = c;
}

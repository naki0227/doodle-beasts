shader_type canvas_item;
// 画面全体をピクセルアート風にする後処理。この層より下（ゲームの世界）だけにかかり、上の文字はくっきり残る。
// 一定の大きさのマスに区切り、色の段階を減らし、ベイヤー配列でディザをかけ、暗部を青く・明部を暖かく寄せる。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;
uniform float levels = 14.0;
uniform float dither = 0.6;
uniform float vignette = 0.45;
uniform vec4 shadow_tint : source_color = vec4(0.82, 0.88, 1.08, 1.0);
uniform vec4 light_tint : source_color = vec4(1.06, 1.0, 0.9, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[x + y * 4] / 16.0 - 0.5;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * res / pixel_size);
	vec2 uv = (cell * pixel_size + pixel_size * 0.5) / res;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(shadow_tint.rgb, light_tint.rgb, smoothstep(0.15, 0.75, lum));
	col = floor(col * levels + 0.5 + bayer4(cell) * dither) / levels;
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 1.8;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

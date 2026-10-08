shader_type canvas_item;
// v8.6 battle board ground: per-cell terrain textures blended with organic feathered edges,
// biome grade, board-edge falloff, faint corner ticks (no full grid — grid only on hover/move range).
uniform sampler2D t_base : repeat_enable, filter_linear;
uniform sampler2D t_forest : repeat_enable, filter_linear;
uniform sampler2D t_hill : repeat_enable, filter_linear;
uniform sampler2D t_water : repeat_enable, filter_linear;
uniform sampler2D t_fort : repeat_enable, filter_linear;
uniform sampler2D t_bridge : repeat_enable, filter_linear;
uniform sampler2D t_noise : repeat_enable, filter_linear;
uniform sampler2D idmap : filter_nearest;
uniform vec2 grid = vec2(8.0, 6.0);
uniform float cell_px = 104.0;
uniform float tex_px = 256.0;
uniform vec3 grade = vec3(1.0);
uniform float tick_alpha = 0.18;
uniform float saturation = 0.86;

int tid(ivec2 c) {
	return int(texelFetch(idmap, c, 0).r * 255.0 / 32.0 + 0.5);
}
vec3 samp(int id, vec2 uv) {
	if (id == 1) return texture(t_forest, uv).rgb;
	if (id == 2) return texture(t_hill, uv).rgb;
	if (id == 3) return texture(t_water, uv).rgb;
	if (id == 4) return texture(t_fort, uv).rgb;
	if (id == 5) return texture(t_bridge, uv).rgb;
	return texture(t_base, uv).rgb;
}
float prio(int id) {
	if (id == 4 || id == 5) return 4.0;
	if (id == 1) return 1.7;
	if (id == 3) return 1.5;
	if (id == 2) return 1.25;
	return 1.0;
}
float feather(int id) {
	if (id == 4 || id == 5) return 0.05;
	if (id == 3) return 0.22;
	return 0.30;
}
void fragment() {
	vec2 p = UV * grid;
	ivec2 c = ivec2(floor(p));
	vec2 uv = p * cell_px / tex_px;
	float n = texture(t_noise, uv * 0.55).r - 0.5;
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 cc = c + ivec2(dx, dy);
			if (cc.x < 0 || cc.y < 0 || cc.x >= int(grid.x) || cc.y >= int(grid.y)) continue;
			int id = tid(cc);
			vec2 q = abs(p - (vec2(cc) + 0.5)) - 0.5;
			float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
			float f = feather(id);
			float w = 1.0 - smoothstep(-f, f, d + n * f * 1.6);
			w *= prio(id);
			acc += samp(id, uv) * w;
			wsum += w;
		}
	}
	vec3 col = acc / max(wsum, 1e-4);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation) * grade;
	// soft board-edge falloff (sits in the ink void)
	vec2 e2 = min(p, grid - p);
	float e = min(e2.x, e2.y);
	col *= mix(0.62, 1.0, smoothstep(0.0, 1.1, e));
	// faint cell-corner ticks
	vec2 fr = fract(p);
	vec2 dc = min(fr, 1.0 - fr) * cell_px;
	float tick = ((dc.x < 0.8 && dc.y < 5.0) || (dc.y < 0.8 && dc.x < 5.0)) ? 1.0 : 0.0;
	tick *= step(0.5, e);
	col = mix(col, vec3(0.86, 0.95, 1.0), tick * tick_alpha);
	COLOR = vec4(col, 1.0);
}

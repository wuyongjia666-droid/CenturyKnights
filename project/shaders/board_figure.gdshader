shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// Single-mesh farm casts: height bands paint skin/coat/pants (no textures).
// board_compact flattens lighting so board-scale figures stay readable (not grey clay).
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 skin : source_color = vec4(0.78, 0.62, 0.52, 1.0);
uniform vec4 coat : source_color = vec4(0.55, 0.58, 0.62, 1.0);
uniform vec4 pants : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform vec4 boots : source_color = vec4(0.12, 0.11, 0.11, 1.0);
uniform vec4 hair : source_color = vec4(0.25, 0.20, 0.18, 1.0);
uniform float use_bands = 0.0; // 1 = height bands from skin/coat/...; 0 = flat base
uniform float model_h = 1.85;
uniform float board_compact = 0.0;
uniform float metal = 0.0;
uniform float sheen = 0.0;
uniform float glow = 0.0;
uniform vec4 rim_col : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_amt = 0.55;
uniform float face = 1.0;
uniform vec3 shadow_mul = vec3(0.42, 0.45, 0.56);
uniform float key_gain = 1.05;
uniform float top_fill = 0.08;
varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / max(model_h, 0.01), 0.0, 1.0);
}

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 albedo = base.rgb;
	if (use_bands > 0.5) {
		// Head hair cap → skin face → coat torso → pants → boots
		vec3 band = mix(boots.rgb, pants.rgb, smoothstep(0.06, 0.14, v_h));
		band = mix(band, coat.rgb, smoothstep(0.28, 0.40, v_h));
		band = mix(band, skin.rgb, smoothstep(0.70, 0.78, v_h));
		band = mix(band, hair.rgb, smoothstep(0.88, 0.95, v_h));
		albedo = band;
	}
	vec3 L = normalize((VIEW_MATRIX * vec4(0.55 * face, 0.65, 0.52, 0.0)).xyz);
	float wrap = clamp((dot(N, L) + 0.50) / 1.50, 0.0, 1.0);
	float d = smoothstep(0.0, 1.0, wrap);
	// board_compact: lift shadow floor so whole-mesh farm casts read as solid cloth, not clay.
	vec3 sh = mix(shadow_mul, vec3(0.78, 0.80, 0.84), board_compact);
	float kg = mix(key_gain, 1.08, board_compact);
	d = mix(d, mix(0.72, 1.0, d), board_compact);
	vec3 col = albedo * mix(sh, vec3(kg, kg, kg * 1.02), d);
	if (!FRONT_FACING) { col *= mix(0.55, 0.82, board_compact); }
	vec3 U = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	col += albedo * top_fill * clamp(dot(N, U), 0.0, 1.0);
	vec3 Hh = normalize(L + VIEW);
	float sp = pow(clamp(dot(N, Hh), 0.0, 1.0), mix(14.0, 36.0, metal));
	float sp_amt = (0.04 + 0.42 * metal + 0.22 * sheen) * mix(1.0, 0.35, board_compact);
	col += vec3(0.92, 0.96, 1.0) * sp * sp_amt;
	vec3 R = normalize((VIEW_MATRIX * vec4(-0.75 * face, 0.25, -0.60, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 2.6);
	float rim = fres * smoothstep(-0.05, 0.55, dot(N, R));
	float ra = rim_amt * mix(1.0, 0.25, board_compact);
	col = mix(col, rim_col.rgb, clamp(rim * ra, 0.0, 0.85));
	col = mix(col, albedo * 1.3, glow);
	ALBEDO = col;
}

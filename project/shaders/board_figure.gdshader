shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float metal = 0.0;
uniform float sheen = 0.0;
uniform float glow = 0.0;
uniform vec4 rim_col : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_amt = 0.55;
uniform float face = 1.0;
uniform vec3 shadow_mul = vec3(0.42, 0.45, 0.56);
uniform float key_gain = 1.05;
uniform float top_fill = 0.08;
void fragment() {
	vec3 N = normalize(NORMAL);
	// Key light on the facing side (mirrors with face); face=-1 is style-lock vector.
	vec3 L = normalize((VIEW_MATRIX * vec4(0.55 * face, 0.65, 0.52, 0.0)).xyz);
	float wrap = clamp((dot(N, L) + 0.50) / 1.50, 0.0, 1.0);
	float d = smoothstep(0.0, 1.0, wrap);
	vec3 col = base.rgb * mix(shadow_mul, vec3(key_gain, key_gain, key_gain * 1.02), d);
	if (!FRONT_FACING) { col *= 0.55; }
	vec3 U = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	col += base.rgb * top_fill * clamp(dot(N, U), 0.0, 1.0);
	vec3 Hh = normalize(L + VIEW);
	float sp = pow(clamp(dot(N, Hh), 0.0, 1.0), mix(14.0, 36.0, metal));
	col += vec3(0.92, 0.96, 1.0) * sp * (0.04 + 0.42 * metal + 0.22 * sheen);
	vec3 R = normalize((VIEW_MATRIX * vec4(-0.75 * face, 0.25, -0.60, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 2.6);
	float rim = fres * smoothstep(-0.05, 0.55, dot(N, R));
	col = mix(col, rim_col.rgb, clamp(rim * rim_amt, 0.0, 0.85));
	col = mix(col, base.rgb * 1.3, glow);
	ALBEDO = col;
}

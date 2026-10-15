shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// Formal board figure (pawn-redesign-opus §3.4 / 附录 B).
// Vertex COLOR: R = palette slot / 255, G = baked AO, B = flags (metal≈0.25, glow≈0.50, both≈0.75).

uniform vec4 palette[20];
uniform float face = 1.0;
uniform vec4 rim_col : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_amt = 0.55;
uniform vec3 shadow_mul = vec3(0.42, 0.45, 0.56);
uniform float key_gain = 1.05;
uniform float top_fill = 0.08;
uniform float dim_amt = 0.0;

void fragment() {
	int slot = int(clamp(floor(COLOR.r * 255.0 + 0.5), 0.0, 19.0));
	vec3 base = palette[slot].rgb;
	float ao = clamp(COLOR.g, 0.55, 1.0);
	float metal = 0.0;
	float glow = 0.0;
	if (COLOR.b >= 0.60) { metal = 1.0; glow = 1.0; }
	else if (COLOR.b >= 0.40) { glow = 1.0; }
	else if (COLOR.b >= 0.15) { metal = 1.0; }
	float sheen = metal * 0.35;

	vec3 N = normalize(NORMAL);
	vec3 L = normalize((VIEW_MATRIX * vec4(0.55 * face, 0.65, 0.52, 0.0)).xyz);
	float wrap = clamp((dot(N, L) + 0.50) / 1.50, 0.0, 1.0);
	float d = smoothstep(0.0, 1.0, wrap);
	vec3 col = base * mix(shadow_mul, vec3(key_gain, key_gain, key_gain * 1.02), d);
	if (!FRONT_FACING) { col *= 0.55; }
	vec3 U = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	col += base * top_fill * clamp(dot(N, U), 0.0, 1.0);
	vec3 Hh = normalize(L + VIEW);
	float sp = pow(clamp(dot(N, Hh), 0.0, 1.0), mix(14.0, 36.0, metal));
	col += vec3(0.92, 0.96, 1.0) * sp * (0.04 + 0.42 * metal + 0.22 * sheen);
	vec3 R = normalize((VIEW_MATRIX * vec4(-0.75 * face, 0.25, -0.60, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(N, VIEW), 0.0, 1.0), 2.6);
	float rim = fres * smoothstep(-0.05, 0.55, dot(N, R));
	col = mix(col, rim_col.rgb, clamp(rim * rim_amt, 0.0, 0.85));
	col = mix(col, base * 1.3, glow);
	col *= ao;
	if (dim_amt > 0.001) {
		float g = dot(col, vec3(0.2126, 0.7152, 0.0722));
		col = mix(col, vec3(g), 0.60 * dim_amt) * (1.0 - 0.25 * dim_amt);
	}
	ALBEDO = col;
}

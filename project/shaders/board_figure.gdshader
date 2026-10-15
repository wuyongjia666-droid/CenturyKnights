shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// Board figure: plate_palette slots.
// Path A — vertex COLOR.r = slot/255 (kit / baked).
// Path B — albedo_tex + height: classify hair/skin/cloth/boots → palette (演出整模).

uniform vec4 palette[20];
uniform float face = 1.0;
uniform vec4 rim_col : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_amt = 0.55;
uniform vec3 shadow_mul = vec3(0.42, 0.45, 0.56);
uniform float key_gain = 1.05;
uniform float top_fill = 0.08;
uniform float dim_amt = 0.0;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float use_albedo = 0.0;
uniform float force_slot = -1.0;
uniform float model_h = 1.85;
uniform float y_min = 0.0;
uniform float y_span = 1.85;

varying float v_h01;

void vertex() {
	v_h01 = clamp((VERTEX.y - y_min) / max(0.05, y_span), 0.0, 1.0);
}

int classify_albedo(vec3 t, float h01) {
	float lum = dot(t, vec3(0.2126, 0.7152, 0.0722));
	float warm = t.r - t.b;
	float sat = max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
	// Hair crown only (keep clear of shoulders — face≈0.88–0.95 of body AABB)
	if (h01 > 0.91 && lum < 0.55) {
		return 0;
	}
	if (lum < 0.30 && h01 > 0.86) {
		return 0;
	}
	// Face: high AND warm (or mid-lum greyscale head on outfits)
	if (h01 > 0.86 && warm > 0.04 && lum > 0.28 && lum < 0.93) {
		return 1;
	}
	if (h01 > 0.88 && sat < 0.16 && lum > 0.32 && lum < 0.85) {
		return 1;
	}
	// Hands/forearms: warm mid height
	if (warm > 0.07 && lum > 0.30 && lum < 0.92 && h01 > 0.45 && h01 < 0.80) {
		return 1;
	}
	// Boots: dark low
	if (lum < 0.40 && h01 < 0.16) {
		return 13;
	}
	// Trousers: lower body
	if (h01 < 0.38 && lum < 0.55) {
		return 12;
	}
	// Greyscale / low-sat mid body (outfit fill targets) → coat, not black mush
	if (sat < 0.12 && h01 > 0.16 && h01 < 0.86) {
		return 3;
	}
	// Bright low-sat fabric → coat
	if (lum > 0.62 && sat < 0.14 && h01 > 0.16 && h01 < 0.88) {
		return 3;
	}
	// Metal: bright cool
	if (lum > 0.78 && sat < 0.10 && warm < 0.04 && h01 < 0.55) {
		return 7;
	}
	// Dark lining only in deep folds (keep rare)
	if (lum < 0.18 && sat < 0.20) {
		return 4;
	}
	// Default coat
	return 3;
}

void fragment() {
	int slot = 3;
	float ao = 0.92;
	float metal = 0.0;
	float glow = 0.0;
	if (force_slot >= 0.0) {
		slot = int(force_slot);
		ao = 0.92;
	} else if (use_albedo > 0.5) {
		// LOD for stable region classify (mip 2); fine sample only for AO.
		vec3 t = textureLod(albedo_tex, UV, 2.0).rgb;
		vec3 t_fine = texture(albedo_tex, UV).rgb;
		slot = classify_albedo(t, v_h01);
		ao = clamp(0.70 + 0.35 * dot(t_fine, vec3(0.2126, 0.7152, 0.0722)), 0.55, 1.0);
	} else {
		slot = int(clamp(floor(COLOR.r * 255.0 + 0.5), 0.0, 19.0));
		ao = clamp(COLOR.g, 0.55, 1.0);
		if (COLOR.b >= 0.60) { metal = 1.0; glow = 1.0; }
		else if (COLOR.b >= 0.40) { glow = 1.0; }
		else if (COLOR.b >= 0.15) { metal = 1.0; }
	}
	vec3 base = palette[slot].rgb;
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

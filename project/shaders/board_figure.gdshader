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

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float use_albedo = 0.0;
// P1 grade: 1 = soft portrait grade on cleaned __albedo_board.png (keeps painted
// face/fold detail, no hard slot thresholds → no jagged zone edges).
uniform float grade_mode = 0.0;
uniform float head_h = 0.865;
// P1b portrait face decal: x=cx, y=brow y, z=chin y, w=face width (Body-mesh local).
uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 face_box = vec4(0.0, 1.8, 1.6, 0.15);
uniform float face_zc = 0.0;
uniform float face_yaw = 0.0;
uniform float use_face = 0.0;
uniform float exposure = 1.0;
uniform float head_raw = 0.0;
uniform float face_clear = 0.0;
uniform float collar_dark = 0.0;
uniform float force_metal = 0.0;
uniform float force_slot = -1.0;
uniform float model_h = 1.85;
uniform float y_min = 0.0;
uniform float y_span = 1.85;

varying float v_h01;
varying vec3 v_mn;
varying vec3 v_mp;
varying float v_bnz;

void vertex() {
	v_h01 = clamp((VERTEX.y - y_min) / max(0.05, y_span), 0.0, 1.0);
	v_mn = NORMAL;
	v_mp = CUSTOM0.xyz;
	v_bnz = CUSTOM0.w;
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

vec3 grade_albedo(vec4 t4, vec4 tc, float h01, vec3 mn) {
	vec3 t = t4.rgb;
	float lum_c = dot(tc.rgb, vec3(0.2126, 0.7152, 0.0722));
	float plain = 1.0 - t4.a;  // unfilled key → plain cloth
	float lum = dot(t, vec3(0.2126, 0.7152, 0.0722));
	float warm = t.r - t.b;
	float head = smoothstep(head_h - 0.02, head_h + 0.02, h01);
	float hands = smoothstep(0.40, 0.46, h01) * (1.0 - smoothstep(0.78, 0.84, h01));
	// Head: geometric split — front of head (model +Z) below crown = face,
	// crown / back / sides = hair (portrait: short dark swept hair, clear face).
	float crown = smoothstep(head_h + 0.075, head_h + 0.095, h01);
	// lower head (cheeks/jaw/ears) wraps further round than the brow line
	float lowhead = 1.0 - smoothstep(head_h + 0.035, head_h + 0.06, h01);
	float front = smoothstep(mix(0.05, -0.12, lowhead), mix(0.40, 0.18, lowhead), mn.z);
	float face_w = head * front * (1.0 - crown) * (1.0 - smoothstep(0.6, 0.85, mn.y));
	// jaw band: high coat collars sit here too — require warm painted texel
	face_w *= mix(1.0, smoothstep(-0.05, 0.0, warm) * (1.0 - plain * 0.6), lowhead);
	float hand_w = hands * smoothstep(0.03, 0.10, warm) * smoothstep(0.22, 0.34, lum)
		* (1.0 - smoothstep(0.92, 0.98, lum)) * (1.0 - plain);
	float skin_w = max(face_w, hand_w);
	float hair_w = head * (1.0 - face_w) * mix(1.0, 0.0, lowhead * (1.0 - front * 0.0));
	// cloth: luminance → coat_dark..coat ramp (portrait two-tone: grey coat / dark inner)
	// Narrow ramp: only genuinely dark garment (inner shirt, trousers) goes coat_dark;
	// baked seam shadows stay coat → no dark blotches on the grey coat.
	// coarse mip for cloth tone (no specks); fine texel only nudges ±6 %
	float tone = mix(mix(0.38, 1.0, smoothstep(0.08, 0.36, lum_c)), 0.90, 1.0 - tc.a);
	tone = clamp(tone + (lum - lum_c) * 0.25, 0.0, 1.0);
	vec3 cloth = mix(palette[4].rgb, palette[3].rgb, tone);
	float boots_w = (1.0 - smoothstep(0.07, 0.12, h01)) * (1.0 - smoothstep(0.35, 0.55, lum));
	cloth = mix(cloth, palette[13].rgb, boots_w);
	// skin/hair keep painted detail (brows, eyes, nose shadow) as luminance ratio
	// face keeps painted brow/eye darkening as a soft ratio (not raw texels)
	float fd = clamp(lum / 0.55, 0.0, 1.0);
	vec3 skin = palette[1].rgb * mix(0.72, 1.0, smoothstep(0.10, 0.40, fd));
	vec3 hair = palette[0].rgb * clamp(0.85 + lum * 0.6, 0.85, 1.25);
	// eye/brow: very dark pixels inside face → eye colour
	float eye_w = head * skin_w * 0.0;
	vec3 col = mix(cloth, skin, skin_w);
	col = mix(col, hair, hair_w);
	// enemy hooded faces: keep the model's own painted head (hood shadow, stubble, eyes)
	vec3 raw = t * vec3(1.06, 1.0, 0.96);
	col = mix(col, raw, head_raw * head * (1.0 - plain));
	// captain: standing collar band under the jaw = black high-neck shirt (no grey blob)
	// narrow, front-only band (no shoulder/back spill)
	float collar_band = smoothstep(head_h - 0.035, head_h - 0.022, h01) * (1.0 - smoothstep(head_h - 0.002, head_h + 0.012, h01))
		* smoothstep(0.15, 0.55, mn.z);
	col = mix(col, palette[4].rgb, collar_dark * collar_band * (1.0 - skin_w));
	return mix(col, palette[2].rgb, eye_w);
}

void fragment() {
	float v_face_w = 0.0;
	int slot = 3;
	float ao = 0.92;
	float metal = 0.0;
	float glow = 0.0;
	if (force_slot >= 0.0) {
		slot = int(force_slot);
		ao = 0.92;
		metal = force_metal;
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
	if (grade_mode > 0.5 && force_slot < 0.0) {
		base = grade_albedo(textureLod(albedo_tex, UV, 1.0), textureLod(albedo_tex, UV, 3.0), v_h01, normalize(v_mn));
		if (use_face > 0.5) {
			// Cylindrical wrap around the (de-yawed) head axis: 3/4 views read the
			// cheek side of the portrait instead of a stretched planar smear.
			float cy = cos(face_yaw);
			float sy = sin(face_yaw);
			vec2 rel = vec2(v_mp.x - face_box.x, v_mp.z - face_zc);
			vec2 rr = vec2(cy * rel.x - sy * rel.y, sy * rel.x + cy * rel.y);
			float ang = atan(rr.x, max(1e-4, rr.y) + 0.0) ;
			ang = atan(rr.x, rr.y);
			float rad = face_box.w * 0.62;
			float u = 0.5 + (ang * rad) / face_box.w;
			float vv = (face_box.y - v_mp.y) / max(0.001, face_box.y - face_box.z);
			vec2 fuv = vec2(u, vv);
			float inb = step(0.0, fuv.x) * step(fuv.x, 1.0) * step(0.0, fuv.y) * step(fuv.y, 1.0);
			// angle-based front mask (mesh normals on the remeshed head are noisy)
			float fr = 1.0 - smoothstep(1.05, 1.45, abs(ang));
			vec4 fd = texture(face_tex, clamp(fuv, 0.0, 1.0));
			// Board LOD: when a face texel covers many screen px→ few, push a
			// simplified, high-contrast face (brows/eyes/hair shapes) from a coarse mip.
			float px = length(fwidth(fuv)) * 96.0;
			float lodw = smoothstep(2.0, 6.0, px);
			vec4 fl = textureLod(face_tex, clamp(fuv, 0.0, 1.0), 2.0);
			float fl_l = dot(fl.rgb, vec3(0.299, 0.587, 0.114));
			float sk_l = dot(palette[1].rgb, vec3(0.299, 0.587, 0.114));
			float dark = smoothstep(sk_l * 0.92, sk_l * 0.55, fl_l);
			vec3 simple = mix(palette[1].rgb, palette[0].rgb * 0.55, dark);
			vec3 fc = fd.rgb * mix(vec3(1.0), palette[1].rgb / max(vec3(0.2), vec3(dot(fd.rgb, vec3(0.333)))) * 0.55, 0.25);
			fc = mix(fc * 1.08, simple, lodw);
			float fw = mix(fd.a, max(fd.a, fl.a), lodw) * inb * fr;
			// hunter: clear the model's dark hair card inside the face oval
			vec2 oc = (fuv - vec2(0.5, 0.55)) / vec2(0.36, 0.40);
			float oval = 1.0 - smoothstep(0.75, 1.0, length(oc));
			base = mix(base, palette[1].rgb, face_clear * oval * fr * (1.0 - fw));
			fw = max(fw, face_clear * oval * fr * 0.9 * step(0.05, fd.a));
			base = mix(base, fc, fw);
			v_face_w = fw;
		}
		ao = 0.96;
	}
	float sheen = metal * 0.35;

	vec3 N = normalize(NORMAL);
	vec3 L = normalize((VIEW_MATRIX * vec4(0.55 * face, 0.65, 0.52, 0.0)).xyz);
	float wrap = clamp((dot(N, L) + 0.50) / 1.50, 0.0, 1.0);
	float d = smoothstep(0.0, 1.0, wrap);
	// smooth head front: flatten noisy remesh shading under the face decal
	d = mix(d, 0.82, v_face_w * 0.85);
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
	ALBEDO = col * exposure;
}

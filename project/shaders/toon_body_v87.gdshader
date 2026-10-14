// v8.7 style-lock toon (docs/art/style-lock-v87.json · toon_3d) for farmed textured bodies.
// ramp: 2 bands + soft edge · rim optional · P0 fill paints Hunyuan white/pale holes with cloth colour.
shader_type spatial;
render_mode cull_back, specular_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.165, 0.204, 0.259, 1.0);
uniform float shadow_mix = 0.55;
uniform float lit_level = 0.78;
uniform vec4 rim_color : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.22;
// P0: Hunyuan3D bakes leave bright unbaked / pale patches. Repaint with the unit's cloth
// colour (allies: genome/outfit dye · enemies: theme palette). a = 0 disables.
uniform vec4 fill_color : source_color = vec4(0.0);
// 1 = board-scale: derive form from albedo luminance, paint solid cloth from fill_color.
uniform float board_compact = 0.0;

void fragment() {
	vec4 samp = texture(albedo_tex, UV);
	vec3 t = samp.rgb;
	float mn = min(t.r, min(t.g, t.b));
	float mx = max(t.r, max(t.g, t.b));
	float lum = (t.r + t.g + t.b) / 3.0;
	// Pure-white holes + pale near-gray wash (board-scale readability).
	float hole = smoothstep(0.55, 0.75, mn) * (1.0 - smoothstep(0.06, 0.22, mx - mn));
	float pale = smoothstep(0.42, 0.78, mn) * (1.0 - smoothstep(0.05, 0.32, mx - mn));
	float w = max(hole, pale * 0.85) * fill_color.a;
	vec3 filled = fill_color.rgb * (0.70 + 0.40 * lum);
	vec3 base = mix(t, filled, w);
	// Softly pull remaining bright wash toward cloth so figures stay solid, not chalk.
	float wash = smoothstep(0.70, 0.95, lum) * fill_color.a * 0.25;
	base = mix(base, mix(base, filled, 0.55), wash);
	if (board_compact > 0.5 && fill_color.a > 0.5) {
		// Solid cloth people: keep wrinkles/AO from albedo, replace hue with fill.
		float form = clamp(0.35 + 0.90 * lum, 0.25, 1.15);
		base = fill_color.rgb * form;
	}
	ALBEDO = base * tint.rgb;
	ROUGHNESS = 0.85;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fres * rim_strength * 0.35;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.04, 0.04, ndl);
	vec3 ramp = mix(shadow_tint.rgb * shadow_mix, vec3(lit_level), band);
	DIFFUSE_LIGHT += ramp * LIGHT_COLOR * ATTENUATION / PI;
}

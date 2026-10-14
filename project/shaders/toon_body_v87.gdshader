// v8.7 style-lock toon (docs/art/style-lock-v87.json · toon_3d) for farmed textured bodies.
// ramp: 2 bands + 0.08 soft edge, shadow tint #2A3442 at 0.55 · rim #6ED4FF (enemy #FF7A70) power 3 strength 0.55
// specular: none (cloth/skin); metal highlights come from the shared weapon kit materials.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.165, 0.204, 0.259, 1.0);
uniform float shadow_mix = 0.55;
uniform float lit_level = 0.92;
uniform vec4 rim_color : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.55;
// P0: Hunyuan3D bakes leave pure-white unbaked patches (13–32% of each albedo). Repaint them
// with the unit's cloth colour (allies: genome/outfit dye · enemies: theme palette). a = 0 disables.
uniform vec4 fill_color : source_color = vec4(0.0);

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float mn = min(t.r, min(t.g, t.b));
	float mx = max(t.r, max(t.g, t.b));
	float hole = smoothstep(0.60, 0.78, mn) * (1.0 - smoothstep(0.08, 0.20, mx - mn)) * fill_color.a;
	vec3 filled = fill_color.rgb * (0.70 + 0.40 * (t.r + t.g + t.b) / 3.0);
	ALBEDO = mix(t, filled, hole) * tint.rgb;
	ROUGHNESS = 0.8;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fres * rim_strength * 0.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.04, 0.04, ndl);
	vec3 ramp = mix(shadow_tint.rgb * shadow_mix, vec3(lit_level), band);
	DIFFUSE_LIGHT += ramp * LIGHT_COLOR * ATTENUATION / PI;
}

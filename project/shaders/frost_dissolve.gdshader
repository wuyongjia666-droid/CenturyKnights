// Kill dissolve: the body breaks into frost crystal, then disappears.
// Palette is frost #6ED4FF on slate #2A3442. Crystal shards only, no warm light.
shader_type spatial;
render_mode cull_disabled, diffuse_toon;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.431, 0.831, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.165, 0.204, 0.259, 1.0);

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	// Quantize so the body breaks into crystal chunks instead of pixel noise.
	vec3 cell = floor(VERTEX * 5.0);
	float n = hash31(cell);
	if (n < dissolve) {
		discard;
	}
	float edge = smoothstep(dissolve, dissolve + 0.18, n);
	ALBEDO = mix(frost_color.rgb, shadow_tint.rgb, edge * 0.65);
	EMISSION = frost_color.rgb * (1.0 - edge) * 2.2;
	ROUGHNESS = 0.25;
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
// #310 P1e: clumped hair cards with soft alpha edges (procedural strands, no texture).
uniform vec4 hair_col : source_color = vec4(0.15, 0.18, 0.27, 1.0);
uniform vec4 rim_col : source_color = vec4(0.43, 0.83, 1.0, 1.0);
uniform float rim_amt = 0.3;
uniform float face = 1.0;
uniform float exposure = 1.0;
uniform float seed = 0.0;

float h1(float x) { return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453); }

void fragment() {
	float u = UV.x;
	float v = UV.y;
	// card silhouette: soft sides, tapering + feathered tip
	float half_w = mix(0.5, 0.18, smoothstep(0.2, 1.0, v));
	float d = abs(u - 0.5) / max(0.01, half_w);
	float edge = 1.0 - smoothstep(0.55, 1.0, d);
	float strand = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float c = 0.5 + (h1(fi) - 0.5) * half_w * 1.6 + sin(v * 5.0 + fi) * 0.03;
		strand = max(strand, 1.0 - smoothstep(0.02, 0.09, abs(u - c)));
	}
	float tip = 1.0 - smoothstep(0.72, 1.0, v) * (1.0 - strand * 0.7);
	float a = edge * tip * mix(0.78, 1.0, strand);
	vec3 N = normalize(NORMAL);
	if (!FRONT_FACING) { N = -N; }
	vec3 L = normalize((VIEW_MATRIX * vec4(0.55 * face, 0.65, 0.52, 0.0)).xyz);
	float wrap = clamp((dot(N, L) + 0.6) / 1.6, 0.0, 1.0);
	vec3 col = hair_col.rgb * mix(0.55, 1.15, wrap) * mix(0.82, 1.12, strand);
	// anisotropic sheen band (silky blue-black)
	float band = exp(-pow((v - 0.28) * 7.0, 2.0)) * 0.22 * wrap;
	col += vec3(0.62, 0.70, 0.86) * band;
	float fres = pow(1.0 - clamp(abs(dot(N, VIEW)), 0.0, 1.0), 2.4);
	col = mix(col, rim_col.rgb, clamp(fres * rim_amt, 0.0, 0.6));
	ALBEDO = col * exposure;
	ALPHA = clamp(a, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.04;
}

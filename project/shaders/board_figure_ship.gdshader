shader_type spatial;
// Path C ship piece: baked albedo + faction rim + P2 dim/flash (§3.9).
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 rim_col : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float rim_amt = 0.0;
uniform float rim_pow = 2.4;
uniform float dim_amt = 0.0;
uniform float flash_amt = 0.0;

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	if (dim_amt > 0.001) {
		float g = dot(a, vec3(0.2126, 0.7152, 0.0722));
		a = mix(a, vec3(g), 0.60 * dim_amt) * (1.0 - 0.25 * dim_amt);
	}
	ALBEDO = a;
	ROUGHNESS = 0.78;
	SPECULAR = 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_pow);
	vec3 emis = rim_col.rgb * fres * rim_amt;
	emis += vec3(1.0, 1.0, 1.0) * flash_amt;
	EMISSION = emis;
}

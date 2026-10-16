shader_type spatial;
// Path C ship piece: keeps its own baked albedo; adds faction rim only (enemy red).
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 rim_col : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float rim_amt = 0.0;
uniform float rim_pow = 2.4;
uniform float dim_amt = 0.0;

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	ALBEDO = a * (1.0 - 0.45 * dim_amt);
	ROUGHNESS = 0.78;
	SPECULAR = 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_pow);
	EMISSION = rim_col.rgb * fres * rim_amt;
}

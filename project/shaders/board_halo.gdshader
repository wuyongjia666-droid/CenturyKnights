shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float px = 1.0;
uniform vec4 halo : source_color = vec4(0.039, 0.055, 0.078, 1.0);
uniform float halo_a = 0.95;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 o = TEXTURE_PIXEL_SIZE * px;
	float m = 0.0;
	m = max(m, texture(TEXTURE, UV + vec2(o.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV - vec2(o.x, 0.0)).a);
	m = max(m, texture(TEXTURE, UV + vec2(0.0, o.y)).a);
	m = max(m, texture(TEXTURE, UV - vec2(0.0, o.y)).a);
	m = max(m, 0.6 * texture(TEXTURE, UV + o).a);
	m = max(m, 0.6 * texture(TEXTURE, UV - o).a);
	m = max(m, 0.6 * texture(TEXTURE, UV + vec2(o.x, -o.y)).a);
	m = max(m, 0.6 * texture(TEXTURE, UV + vec2(-o.x, o.y)).a);
	float h = clamp(m - c.a, 0.0, 1.0) * halo_a;
	COLOR = vec4(c.rgb + halo.rgb * h * (1.0 - c.a), c.a + h * (1.0 - c.a));
}

shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 2.0;
	vec3 c = textureLod(screen_tex, SCREEN_UV, 1.5).rgb * 0.36;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), 1.5).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), 1.5).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), 1.5).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), 1.5).rgb * 0.16;
	COLOR = vec4(c, 0.9);
}

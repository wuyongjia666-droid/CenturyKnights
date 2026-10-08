shader_type canvas_item;
// v8.6 Stitch "luminous ink void": near-black base, faint 48px tactical grid, cool top glow, vignette.
uniform vec4 base : source_color = vec4(0.027, 0.031, 0.047, 1.0);
uniform vec4 glow : source_color = vec4(0.063, 0.078, 0.110, 1.0);
uniform float grid_px = 48.0;
uniform float grid_a = 0.030;
uniform vec2 size_px = vec2(1280.0, 720.0);
void fragment() {
	vec2 p = UV * size_px;
	vec3 c = base.rgb;
	float g = length((UV - vec2(0.5, 0.0)) * vec2(1.0, 1.6));
	c = mix(glow.rgb, c, smoothstep(0.0, 0.95, g));
	vec2 f = abs(fract(p / grid_px + 0.5) - 0.5) * grid_px;
	float line = 1.0 - smoothstep(0.0, 1.0, min(f.x, f.y));
	vec2 f2 = abs(fract(p / (grid_px * 4.0) + 0.5) - 0.5) * grid_px * 4.0;
	float major = 1.0 - smoothstep(0.0, 1.0, min(f2.x, f2.y));
	c += vec3(0.75, 0.9, 1.0) * (line * grid_a + major * grid_a * 0.8);
	float v = length((UV - 0.5) * vec2(1.0, 0.8));
	c *= 1.0 - smoothstep(0.45, 0.9, v) * 0.45;
	COLOR = vec4(c, 1.0);
}

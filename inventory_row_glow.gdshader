shader_type canvas_item;
render_mode blend_add, unshaded;

/// Dim rarity-tinted core + soft neon halo that bleeds past the quad edges slightly (HDR-friendly).
uniform vec4 base_color : source_color = vec4(0.35, 0.28, 0.08, 0.55);
uniform float halo_boost : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float ax = abs(uv.x);
	float ay = abs(uv.y);
	float d = max(ax, ay);
	float core = (1.0 - smoothstep(0.72, 1.0, d)) * base_color.a;
	float bleed = smoothstep(0.35, 1.25, d) * (1.0 - smoothstep(1.25, 1.65, max(ax, ay)));
	float a = core + bleed * halo_boost * base_color.a;
	COLOR = vec4(base_color.rgb, clamp(a, 0.0, 1.0));
}

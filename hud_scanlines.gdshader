shader_type canvas_item;
render_mode unshaded;

/// Vertical resolution used with UV.y so scanlines stay consistent when the window resizes.
uniform float display_height : hint_range(256.0, 4320.0) = 1080.0;
/// Every N screen pixels, draw one horizontal black scan line.
uniform float line_spacing : hint_range(2.0, 8.0) = 4.0;
/// Alpha of the black scan lines (10% default).
uniform float line_opacity : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	float row_px = floor(UV.y * display_height);
	float in_band = mod(row_px, line_spacing);
	// Darken one pixel row every `line_spacing` screen pixels.
	float line_mask = 1.0 - step(0.5, in_band);
	COLOR = vec4(0.0, 0.0, 0.0, line_mask * line_opacity);
}

shader_type canvas_item;

// Use this one for CRISP pixel art (no smoothing)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
// If you want smoothing instead, comment the line above and uncomment below:
// uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform sampler2D mask_tex;
uniform vec2 mask_pos = vec2(0.0);       // top-left in screen pixels
uniform vec2 mask_size = vec2(512.0);    // size in pixels
uniform float boost = 0.6;               // 0..1 extra brightness

void fragment() {
	// Current screen color at this pixel
	vec4 src = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Convert SCREEN_UV (0..1) to screen pixels
	vec2 screen_px = SCREEN_UV * vec2(textureSize(SCREEN_TEXTURE, 0));

	// Map to mask UVs
	vec2 uv = (screen_px - mask_pos) / max(mask_size, vec2(1.0));

	float m = 0.0;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
		// White = 1 → brighten; Black = 0 → no change
		m = texture(mask_tex, uv).r;
	}

	vec3 brightened = mix(src.rgb, vec3(1.0), m * boost);
	COLOR = vec4(brightened, src.a);
}

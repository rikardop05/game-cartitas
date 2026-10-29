shader_type canvas_item;

// Calms the painted background so cards and HUD read on top of it: a light
// blur, lower brightness and saturation, a warm tint toward the game palette
// and a vignette that darkens the edges.

uniform float blur_texels = 1.2;
uniform float brightness : hint_range(0.0, 1.5) = 0.72;
uniform float saturation : hint_range(0.0, 1.5) = 0.82;
uniform vec4 tint : source_color = vec4(0.78, 0.52, 0.33, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.14;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_texels;
	vec3 c = texture(TEXTURE, UV).rgb * 0.25;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb * 0.125;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb * 0.125;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)).rgb * 0.125;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)).rgb * 0.125;
	c += texture(TEXTURE, UV + px).rgb * 0.0625;
	c += texture(TEXTURE, UV - px).rgb * 0.0625;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)).rgb * 0.0625;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)).rgb * 0.0625;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = mix(c, c * tint.rgb * 1.6, tint_strength);
	c *= brightness;
	vec2 d = UV - vec2(0.5);
	float vignette = 1.0 - vignette_strength * smoothstep(0.25, 0.75, length(d * vec2(1.0, 1.15)));
	COLOR = vec4(c * vignette, 1.0);
}

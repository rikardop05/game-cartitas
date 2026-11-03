shader_type canvas_item;

// Card "juice": pointer-driven perspective tilt + specular shine (board / deck cards),
// idle sway + holographic foil (Clearing Zone cards) and the depth dim (brightness/saturation).
//
// Credits (both MIT):
//  - "2D Perspective" by Hei, https://godotshaders.com/shader/2d-perspective/ (the vertex/fragment
//    perspective below, with the `rect_size` fix for a TextureRect whose size differs from its texture).
//  - MrEliptik/godot_ui_components, scene `balatro` (Victor Meunier): the tilt/hover/reset feel
//    that level_screen.gd drives these uniforms with.
// Tuning constants live at the top of scripts/ui/level_screen.gd (JUICE_*).

uniform vec2 rect_size = vec2(64.0);
uniform float fov : hint_range(1, 179) = 50.0;
uniform float y_rot : hint_range(-360.0, 360.0) = 0.0;
uniform float x_rot : hint_range(-360.0, 360.0) = 0.0;
uniform float inset : hint_range(0, 1) = 0.0;

// Depth dim (same look as the former dim shader).
uniform float brightness = 1.0;
uniform float saturation = 1.0;

// Effects.
uniform float shine_strength = 0.0;
uniform float holo_strength = 0.0;
uniform float sway_amount = 0.0;   // degrees
uniform float sway_phase = 0.0;
uniform float sway_speed = 1.4;

varying flat vec2 o;
varying vec3 p;
varying vec2 tilt;
varying vec4 vcol;

void vertex() {
	float t_time = TIME * sway_speed + sway_phase;
	float xr = x_rot + sway_amount * 0.7 * sin(t_time * 0.83 + sway_phase * 1.7);
	float yr = y_rot + sway_amount * sin(t_time);
	float sin_b = sin(yr / 180.0 * PI);
	float cos_b = cos(yr / 180.0 * PI);
	float sin_c = sin(xr / 180.0 * PI);
	float cos_c = cos(xr / 180.0 * PI);

	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;
	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;
	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;
	tilt = vec2(yr, xr) / 20.0;
	vcol = COLOR;

	VERTEX += (UV - 0.5) * rect_size * t * (1.0 - inset);
}

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2831853 * (h + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	if (p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o;
	vec4 tex = texture(TEXTURE, uv + 0.5);
	tex.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
	COLOR = tex * vcol;

	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(grey), COLOR.rgb, saturation) * brightness;

	vec2 c = uv; // -0.5..0.5 across the card
	if (shine_strength > 0.0) {
		// A soft diagonal sweep whose position follows the tilt.
		float axis = dot(c, normalize(vec2(1.0, -0.7)));
		float centre = tilt.x * 0.8 - tilt.y * 0.5;
		float band = exp(-pow((axis - centre) * 4.5, 2.0));
		COLOR.rgb += shine_strength * band * 0.5 * COLOR.a * vec3(1.0, 0.96, 0.86);
	}
	if (holo_strength > 0.0) {
		float h = fract((c.x * 0.9 + c.y * 1.1) * 1.3 + TIME * 0.12 + tilt.x * 0.6 + sway_phase * 0.1);
		vec3 foil = rainbow(h);
		float bands = 0.5 + 0.5 * sin((c.x - c.y) * 7.0 + TIME * 0.9 + sway_phase);
		float lum = 0.55 + 0.45 * grey;
		COLOR.rgb += foil * holo_strength * (0.25 + 0.75 * bands) * 0.32 * lum * COLOR.a;
	}
}

shader_type canvas_item;

uniform float  u_alpha;
uniform vec4  u_color_ok  : source_color;
uniform vec4  u_color_bad : source_color;

uniform bool  u_ok = true;

void fragment() {
	vec4 base = mix(u_color_bad, u_color_ok, u_ok ? 1.0 : 0.0);
	COLOR = base.rgba;
}
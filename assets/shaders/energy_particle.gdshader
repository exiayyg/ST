shader_type canvas_item;
// Unit-quad shape only: the existing MultiMesh supplies state, color and size.
uniform bool wave_point = false;
uniform float edge_ratio;
uniform float core_ratio;
uniform float white_ratio;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float distance_from_core = wave_point ? abs(p.x) + abs(p.y) : length(p);
	float edge = 1.0 - smoothstep(edge_ratio, 1.0, distance_from_core);
	float core = 1.0 - smoothstep(0.0, core_ratio, distance_from_core);
	COLOR = vec4(mix(COLOR.rgb, vec3(1.0), core * white_ratio), COLOR.a * edge);
}

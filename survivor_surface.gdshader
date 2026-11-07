shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float roughness_value = 0.85;
uniform float metal_value = 0.0;
uniform float wear = 0.12;
uniform float weave = 0.0;
uniform float stubble = 0.0;
varying vec3 local_position;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.27, 0.43));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	float mottling = noise(local_position * 35.0) * 0.65 + noise(local_position * 180.0) * 0.35;
	float thread = sin(local_position.y * 2100.0) * sin((local_position.x + local_position.z) * 1900.0);
	ALBEDO = base_color.rgb * (1.0 + (mottling - 0.5) * wear * 1.8 + thread * weave * 0.035);
	ALBEDO = mix(ALBEDO, vec3(0.33, 0.27, 0.19), smoothstep(0.66, 0.85, mottling) * wear);
	float beard_mask = (1.0 - smoothstep(0.038, 0.071, local_position.y)) * (1.0 - smoothstep(-0.03, 0.01, local_position.z));
	float follicles = smoothstep(0.63, 0.77, noise(local_position * 1800.0));
	ALBEDO *= 1.0 - beard_mask * stubble * (0.16 + follicles * 0.7);
	ROUGHNESS = clamp(roughness_value + (mottling - 0.5) * 0.1, 0.1, 1.0);
	METALLIC = metal_value;
}

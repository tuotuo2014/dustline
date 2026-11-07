shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D scene : source_color;
void fragment() {
	vec3 source=texture(scene,UV).rgb;
	float tone=dot(source,vec3(.299,.587,.114));
	vec3 color=mix(vec3(.09,.065,.032),vec3(.52,.37,.15),smoothstep(.02,.7,tone));
	float halo=exp(-length((UV-vec2(.5,.45))*vec2(2.5,1.2))*2.0);
	color+=vec3(.14,.10,.045)*halo;
	ALBEDO=color;
}

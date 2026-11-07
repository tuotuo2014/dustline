shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 hair_color : source_color = vec4(.129,.102,.078,1.0);
uniform vec4 skin_color : source_color = vec4(.741,.565,.467,1.0);
varying vec3 p;

float hash(vec3 q) {
	q=fract(q*.3183099+vec3(.17,.39,.73));
	q*=17.0;
	return fract(q.x*q.y*q.z*(q.x+q.y+q.z));
}

void vertex() { p=VERTEX; }

void fragment() {
	float angle=atan(p.z-.019,p.x);
	float front=max(-sin(angle),0.0);
	float forelock=smoothstep(.58,.91,front);
	float fade=smoothstep(.150,.227,p.y);
	fade=mix(fade,1.0,forelock);
	float follicle=step(.69,hash(floor(p*2900.0)));
	vec3 cropped=mix(skin_color.rgb*.86,hair_color.rgb,.32+follicle*.38);
	float footprint=max(length(dFdx(p)),length(dFdy(p)));
	float strand_lod=1.0-smoothstep(.0005,.0017,footprint);
	float grain=.5+.5*sin(p.y*3300.0+p.x*500.0+sin(p.z*70.0)*6.0)*strand_lod;
	vec3 longer=hair_color.rgb*(.91+grain*.13);
	ALBEDO=mix(cropped,longer,fade);
	ROUGHNESS=.87;
	SPECULAR=.23;
}

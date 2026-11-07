shader_type canvas_item;
uniform float drift = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec3 source=texture(TEXTURE,UV).rgb;
	float light=dot(source,vec3(.299,.587,.114));
	vec3 ink=vec3(.14,.095,.035), sand=vec3(.94,.71,.29);
	vec3 grade=mix(ink,sand,smoothstep(.04,.78,light));
	float sun=exp(-length((UV-vec2(.21,.16))*vec2(1.0,1.2))*3.0);
	grade=mix(grade,vec3(.98,.80,.42),sun*.48);
	// A restrained dust veil moves independently of the camera and game clock.
	float dust=noise(UV*vec2(7.0,14.0)+vec2(drift*.025,drift*.003));
	grade=mix(grade,vec3(.84,.59,.23),smoothstep(.32,.86,dust)*.16);
	float grain=hash(floor(UV*vec2(1800,1100)));
	grade+=(grain-.5)*.045;
	float vignette=smoothstep(.36,.80,length((UV-.5)*vec2(1.0,.85)));
	grade*=1.0-vignette*.35;
	COLOR=vec4(grade,1.0);
}

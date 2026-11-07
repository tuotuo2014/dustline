shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(.31,.28,.21,1.0);
uniform float roughness_value = .88;
uniform float surface_kind = 0.0; // Hide, fur, weathered bone, wet nose, scar, face, amber iris.
uniform float variation = .45;
uniform float glow = 0.0;
uniform float coat_length = .056;
varying float coat_layer;
varying vec3 local_p;

float hash3(vec3 p) {
	p=fract(p*.3183099+vec3(.17,.39,.73));
	p*=17.0;
	return fract(p.x*p.y*p.z*(p.x+p.y+p.z));
}
float n3(vec3 p) {
	vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
	coat_layer=COLOR.a;
	local_p=VERTEX;
	if(surface_kind>6.5) local_p-=NORMAL*coat_length*coat_layer+vec3(0.0,-.014,.012)*coat_layer*coat_layer;
}
void fragment() {
	float broad=n3(local_p*8.0), mid=n3(local_p*41.0), fine=n3(local_p*350.0);
	vec3 color=base_color.rgb*COLOR.rgb;
	color*=mix(1.0,.61+broad*.57+mid*.2,variation);
	float height=(mid*.7+fine*.3)*.00016;
	float specular_value=.28;
	ALPHA=1.0;
	ALPHA_SCISSOR_THRESHOLD=.5;
	if (surface_kind<.5) {
		// Leathery hide with patchy, dusty undercoat and shallow skin creases.
		float mottle=smoothstep(.42,.69,n3(local_p*13.0+9.0));
		color=mix(color,color*vec3(.57,.51,.44),mottle*.44);
		float skin_fold=n3(local_p*vec3(112.0,37.0,91.0));
		float crease=pow(1.0-abs(skin_fold*2.0-1.0),24.0);
		color*=1.0-crease*.08;
		height-=crease*.00010;
	} else if (surface_kind<1.5) {
		float strands=n3(vec3(local_p.x*810.0,local_p.y*480.0,local_p.z*54.0));
		color*=.88+strands*.22;
		specular_value=.18;
		height=(strands*.75+fine*.25)*.00015;
	} else if (surface_kind<2.5) {
		color=mix(color,color*vec3(.64,.50,.29),smoothstep(.5,.8,mid)*.45);
		height=fine*.00015;
	} else if (surface_kind<3.5) {
		height=pow(fine,3.0)*.00015;
		specular_value=.39;
	} else if (surface_kind<4.5) {
		color=mix(color,color*vec3(.65,.48,.37),mid*.48);
		height=mid*.0003;
	} else if (surface_kind<5.5) {
		float muzzle=(1.0-smoothstep(-.67,-.33,local_p.z))*(1.0-smoothstep(.07,.19,local_p.y));
		color=mix(color,vec3(.26,.245,.198)*(.83+mid*.25),muzzle*.78);
		float short_fur=n3(vec3(local_p.x*800.0,local_p.y*500.0,local_p.z*75.0));
		color*=.90+short_fur*.20;
		float brow_mask=exp(-pow((abs(local_p.x)-.228)/.070,2.0)-pow((local_p.y-.117)/.065,2.0)-pow((local_p.z+.282)/.133,2.0));
		float crown_mask=smoothstep(.12,.25,local_p.y)*(1.0-smoothstep(-.28,-.04,local_p.z));
		color=mix(color,color*vec3(.30,.32,.31),brow_mask*.80+crown_mask*.27);
		float scar=exp(-pow((abs(local_p.x)-.229)/.035,2.0)-pow((local_p.y+.012)/.080,2.0)-pow((local_p.z+.28)/.100,2.0));
		color=mix(color,color*vec3(.73,.44,.32),scar*smoothstep(.30,.66,mid)*.65);
		height=short_fur*.00012;
	} else if (surface_kind<6.5) {
		// Radial iris fibers and a round canine pupil share one continuous corneal mesh.
		vec2 q=vec2(local_p.x/0.022,(local_p.y-.001)/.020);
		float radius=length(q), angle=atan(q.y,q.x);
		float spokes=.5+.5*sin(angle*69.0+sin(angle*17.0)*2.8+radius*11.0);
		float fibers=n3(vec3(angle*28.0,radius*10.0,1.0));
		vec3 iris=mix(vec3(.092,.055,.014),vec3(.31,.203,.060),spokes*.45+fibers*.43);
		iris*=.70+.28*sin(clamp(radius,0.0,1.0)*3.14159);
		iris=mix(iris,vec3(.013,.014,.009),smoothstep(.79,.99,radius));
		iris=mix(vec3(.003,.004,.002),iris,smoothstep(.35,.42,radius));
		color=mix(iris,vec3(.092,.085,.055),smoothstep(.98,1.14,radius));
		height=0.0;
		specular_value=.55;
		CLEARCOAT=.16;
		CLEARCOAT_ROUGHNESS=.18;
	} else {
		// Six opaque cutout shells form continuous, dense short fur under the guard hairs.
		// The sampling stays at the root position so fibers remain attached between layers.
		vec3 flow=vec3(local_p.x,dot(local_p,vec3(0.0,.83,.55)),dot(local_p,vec3(0.0,-.55,.83)));
		float strands=n3(flow*vec3(615.0,587.0,72.0)+vec3(3.0));
		float short_strands=n3(flow*vec3(1080.0,1010.0,153.0));
		float clumps=n3(local_p*vec3(27.0,32.0,13.0));
		float fiber=clamp(strands*.78+short_strands*.22+clumps*.06,0.0,1.0);
		float threshold=.30+coat_layer*.38;
		ALPHA=coat_layer<.01 ? 1.0 : step(threshold,fiber);
		float salt=n3(local_p*vec3(21.0,28.0,8.0));
		color*=mix(.73,1.17,smoothstep(.22,.81,salt))*(.73+strands*.56);
		color*=mix(.82,1.10,coat_layer);
		if(surface_kind>7.5) {
			float eye_mask=exp(-pow((abs(local_p.x)-.225)/.075,2.0)-pow((local_p.y-.113)/.080,2.0)-pow((local_p.z+.28)/.125,2.0));
			float crown=smoothstep(.10,.24,local_p.y)*(1.0-smoothstep(-.24,.17,local_p.z));
			float muzzle=1.0-smoothstep(-.64,-.38,local_p.z);
			color*=1.0-eye_mask*.53-crown*.23;
			if(coat_layer>.01 && eye_mask>.22) ALPHA=0.0;
			color=mix(color,color*vec3(1.13,1.13,1.10),muzzle*.5);
		}
		height=(strands*.70+short_strands*.30)*.00034;
		specular_value=.14;
	}
	ALBEDO=color;
	ROUGHNESS=clamp(roughness_value+(fine-.5)*.09,.19,1.0);
	SPECULAR=specular_value;
	EMISSION=color*glow;
	vec3 sx=dFdx(VERTEX), sy=dFdy(VERTEX);
	vec3 r1=cross(sy,NORMAL), r2=cross(NORMAL,sx);
	float det=dot(sx,r1);
	if(abs(det)>1e-12) {
		vec3 grad=sign(det)*(dFdx(height)*r1+dFdy(height)*r2);
		NORMAL=normalize(abs(det)*NORMAL-grad);
	}
}

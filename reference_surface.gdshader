shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(.24,.20,.15,1.0);
uniform float roughness_value = .9;
uniform float metal_value = 0.0;
uniform float wear = .3;
uniform float weave = 0.0;
uniform float material_kind = 0.0; // 0 fabric, 1 skin, 2 hair, 3 steel, 4 wood, 5 rubber, 6 eye, 7 lip
uniform float face_detail = 0.0;
uniform float eye_closure = 0.0;
uniform float eyelid_detail = 0.0;
uniform vec2 eye_gaze = vec2(0.0);
instance uniform float eye_side = 1.0;
uniform float cloth_motion = 0.0;
uniform float cloth_clock = 0.0;
uniform float cloth_movement = 0.0;
uniform float cloth_turn = 0.0;
varying vec3 p;

float hash(vec3 q) {
	q=fract(q*.3183099+vec3(.17,.39,.73));
	q*=17.0;
	return fract(q.x*q.y*q.z*(q.x+q.y+q.z));
}
float noise(vec3 q) {
	vec3 i=floor(q), f=fract(q);
	f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float line_mask(vec2 uv,vec2 a,vec2 b,float width) {
	vec2 v=uv-a, d=b-a;
	return 1.0-smoothstep(width*.4,width,length(v-d*clamp(dot(v,d)/dot(d,d),0.0,1.0)));
}
void vertex() {
	p=VERTEX;
	if (cloth_motion>.5) {
		// Shoulder attachment stays fixed; lower fabric trails and ripples.
		float fall=clamp((.42-VERTEX.y)/.72,0.0,1.0);
		float weight=fall*fall;
		float wave=sin(VERTEX.x*15.0-VERTEX.y*8.0+cloth_clock*3.2);
		VERTEX.z+=weight*(.010*wave+cloth_movement*(.07+.023*wave));
		VERTEX.x+=weight*(cloth_turn*.065+sin(cloth_clock*2.1-VERTEX.y*5.0)*.006);
	}
}
void fragment() {
	float broad=noise(p*23.0);
	float fine=noise(p*220.0);
	float pores=noise(p*1300.0);
	float dirt=smoothstep(.37,.72,noise(p*47.0+4.0));
	float dust=smoothstep(.54,.79,broad*.55+fine*.45);
	vec3 color=base_color.rgb*(.86+.20*broad+.07*fine);
	color=mix(color,color*.52,dirt*wear*.55);
	color=mix(color,base_color.rgb*1.6+vec3(.032,.025,.016),dust*wear*.62);
	float height=(fine*.7+pores*.3)*.00022;
	float local_roughness=roughness_value;
	SPECULAR=.38;
	if (weave>.0) {
		float footprint=max(length(dFdx(p)),length(dFdy(p)));
		float fabric_lod=1.0-smoothstep(.0007,.0025,footprint);
		float fibres=sin(p.y*1850.0)*sin((p.x+p.z)*2100.0)*fabric_lod;
		color*=1.0+fibres*.025;
		height+=fibres*.00005*weave;
	}
	if (material_kind>3.5 && material_kind<4.5) {
		float grain=noise(vec3(p.x*380.0,p.y*9.0,p.z*380.0));
		color*=.72+grain*.52;
		height+=grain*.00012;
	}
	if (material_kind>1.5 && material_kind<2.5) {
		color*=.8+.30*noise(vec3(p.x*950.0,p.y*45.0,p.z*950.0));
	}
	if (material_kind>.5 && material_kind<1.5) {
		color=base_color.rgb*(.965+.075*broad+.025*fine);
		height=pores*.000032+fine*.000012;
		local_roughness+=.035*(pores-.5);
		SPECULAR=.27;
		SSS_STRENGTH=.045;
	}
	if (face_detail>.5) {
		float front=1.0-smoothstep(-.021,.01,p.z);
		float jaw=1.0-smoothstep(.035,.092,p.y);
		float sideburn=smoothstep(.064,.079,abs(p.x))*(1.0-smoothstep(.127,.154,p.y));
		float moustache=exp(-pow((p.y-.0775)/.0055,2.0)-pow(p.x/.025,4.0))*.42*(.5+.5*smoothstep(.003,.008,abs(p.x)));
		float lips=smoothstep(.052,.058,p.y)*(1.0-smoothstep(.07,.075,p.y))*(1.0-smoothstep(.02,.032,abs(p.x)));
		float beard=clamp(max(max(jaw,sideburn),moustache)*front-lips,0.0,1.0);
		// A short even stubble keeps skin and the jaw shape visible.
		float follicles=smoothstep(.60,.81,noise(p*2600.0));
		color=mix(color,color*vec3(.68,.65,.62),beard*.57);
		color=mix(color,vec3(.09,.064,.045),beard*follicles*.24);
		height+=beard*follicles*.000025;
		// Eyebrows live directly on the brow plane, with softly tapered ends.
		float brow_t=clamp((abs(p.x)-.018)/.046,0.0,1.0);
		float brow_y=.1630+brow_t*.0054-.0035*smoothstep(.65,1.0,brow_t);
		float brow_width=mix(.0033,.00070,pow(brow_t,2.0));
		float brow_edge=abs(p.y-brow_y)+noise(p*1350.0)*.00036;
		float brow=(1.0-smoothstep(brow_width*.40,brow_width,brow_edge));
		brow*=smoothstep(.017,.023,abs(p.x))*(1.0-smoothstep(.060,.065,abs(p.x)))*front;
		float brow_hair=.48+.52*smoothstep(-.5,.4,sin((abs(p.x)-p.y*.28)*8400.0+noise(p*950.0)*3.0));
		color=mix(color,vec3(.034,.023,.016)*brow_hair,brow*.94);
		float cheek_flush=exp(-pow((abs(p.x)-.053)/.019,2.0)-pow((p.y-.116)/.023,2.0))*front;
		color=mix(color,color*vec3(1.07,.96,.94),cheek_flush*.3);
		float orbital=exp(-pow((abs(p.x)-.037)/.021,2.0)-pow((p.y-.142)/.008,2.0))*front;
		color=mix(color,color*vec3(.87,.83,.82),orbital*.35);
		float nose_warmth=exp(-pow(p.x/.017,2.0)-pow((p.y-.105)/.017,2.0))*front;
		color=mix(color,color*vec3(1.045,.958,.943),nose_warmth*.55);
		float temple=exp(-pow((abs(p.x)-.071)/.012,2.0)-pow((p.y-.164)/.021,2.0))*front;
		color=mix(color,color*vec3(.95,.94,.92),temple*.45);
		float malar=exp(-pow((abs(p.x)-.053)/.017,2.0)-pow((p.y-.099)/.012,2.0))*front;
		color=mix(color,color*vec3(.86,.82,.77),malar*.28);
		float jaw_edge=exp(-pow((abs(p.x)-.061)/.017,2.0)-pow((p.y-.041)/.012,2.0))*front;
		color=mix(color,color*vec3(.79,.76,.71),jaw_edge*.24);
		float oil=exp(-pow(p.x/.021,2.0)-pow((p.y-.139)/.073,2.0))*front;
		local_roughness-=oil*.065;
		// One faint healed mark retains the survivor's history without a painted scar pattern.
		float scar=line_mask(p.xy,vec2(.058,.124),vec2(.052,.109),.0009)*front;
		color=mix(color,color*vec3(1.09,.92,.87),scar*.38);
		height-=scar*.00008;
	}
	if (eyelid_detail>.5) {
		float ex=abs(p.x)-.037;
		float arc=pow(max(0.0,cos(clamp(ex/.0164,-1.0,1.0)*1.570796)),.83);
		float upper=.1508+ex*.060+arc*(.0039*(1.0-eye_closure)-.0010*eye_closure);
		float lower=.1508+ex*.060+arc*(-.0033*(1.0-eye_closure)-.0010*eye_closure);
		float lash=(1.0-smoothstep(.00008,.00032,abs(p.y-upper)))*arc;
		float waterline=(1.0-smoothstep(.00007,.00023,abs(p.y-lower)))*arc;
		color=mix(color,color*vec3(.62,.48,.43),lash*.67);
		color=mix(color,color*vec3(1.05,.86,.84),waterline*.25);
	}
	if (material_kind>5.5 && material_kind<6.5) {
		float arc=pow(max(0.0,cos(clamp(p.x/.0164,-1.0,1.0)*1.570796)),.83);
		float top=p.x*eye_side*.060+arc*(.0039*(1.0-eye_closure)-.0010*eye_closure);
		float bottom=p.x*eye_side*.060+arc*(-.0033*(1.0-eye_closure)-.0010*eye_closure);
		if (p.y>top+.00035 || p.y<bottom-.00035 || eye_closure>.97) discard;
		vec2 eye=p.xy-eye_gaze;
		float radius=length(eye);
		float iris=1.0-smoothstep(.0050,.00535,radius);
		float angle=atan(eye.y,eye.x);
		float fibres=.5+.5*sin(angle*113.0+noise(vec3(eye*1600.0,2.0))*5.0);
		float ring=.5+.5*sin(radius*3100.0+sin(angle*31.0)*.8);
		vec3 iris_color=mix(vec3(.038,.029,.021),vec3(.155,.107,.053),fibres*.5+ring*.22);
		float amber=1.0-smoothstep(.0021,.0037,radius);
		iris_color=mix(iris_color,vec3(.19,.126,.047),amber*.43);
		float limbus=smoothstep(.00425,.0052,radius);
		iris_color=mix(iris_color,vec3(.014,.017,.015),limbus*.8);
		float edge=smoothstep(.006,.0155,abs(p.x));
		color=base_color.rgb*(.78-edge*.18);
		color=mix(color,color*vec3(1.04,.87,.84),edge*.40);
		color=mix(color,iris_color,iris);
		float lid_shadow=smoothstep(bottom,top,eye.y)*.20;
		color*=1.0-lid_shadow;
		float pupil=1.0-smoothstep(.0020,.00225,radius);
		color=mix(color,vec3(.006,.009,.007),pupil);
		float glint=1.0-smoothstep(.00012,.00042,length(eye-vec2(-.0014,.0019)));
		color=mix(color,vec3(.62,.69,.65),glint*.65);
		local_roughness=.22;
		height=0.0;
		SPECULAR=.48;
	}
	if (material_kind>6.5 && material_kind<7.5) {
		float lip_lines=sin(p.x*7300.0+sin(p.y*1800.0)*.5);
		color=base_color.rgb*(.96+fine*.07+lip_lines*.013);
		height=lip_lines*.000007;
		SPECULAR=.25;
		SSS_STRENGTH=.035;
	}
	ALBEDO=color;
	ROUGHNESS=clamp(local_roughness+(fine-.5)*.09,.16,1.0);
	METALLIC=metal_value;
	// Surface-gradient bump mapping also works on meshes without texture tangents.
	vec3 sx=dFdx(VERTEX), sy=dFdy(VERTEX);
	vec3 r1=cross(sy,NORMAL), r2=cross(NORMAL,sx);
	float det=dot(sx,r1);
	if (abs(det)>1e-12) {
		vec3 grad=sign(det)*(dFdx(height)*r1+dFdy(height)*r2);
		NORMAL=normalize(abs(det)*NORMAL-grad);
	}
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(.45,.34,.22,1.0);
uniform float kind=0.0;
uniform float roughness_value=.93;
uniform float metal_value=0.0;
varying vec3 p;
varying vec3 world_normal;
float hash(vec3 q){ q=fract(q*.3183099+vec3(.11,.39,.71));q*=17.0;return fract(q.x*q.y*q.z*(q.x+q.y+q.z)); }
float noise(vec3 q){vec3 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fractal(vec3 q){return noise(q)*.55+noise(q*2.07)*.28+noise(q*4.31)*.12+noise(q*9.73)*.05;}
float cracks(vec2 q){vec2 i=floor(q),f=fract(q);float d1=10.0,d2=10.0;for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){vec2 g=vec2(float(x),float(y));vec2 jitter=vec2(hash(vec3(i+g,1)),hash(vec3(i+g,9)));float d=length(g+jitter-f);if(d<d1){d2=d1;d1=d;}else if(d<d2){d2=d;}}}return 1.0-smoothstep(.008,.025,d2-d1);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float macro=fractal(p*.6), grain=noise(p*125.0), medium=noise(p*12.0);
 vec3 c=base_color.rgb*(.72+macro*.5+medium*.10);
 float h=grain*.0012;
 float rough=roughness_value;
 if(kind<.5){
  float ripples=sin(p.x*7.0+p.z*1.4+noise(p*.3)*5.0)*.5+.5;
  float gravel=smoothstep(.71,.85,noise(p*7.0));
  c*=.91+ripples*.09;
  c=mix(c,c*.38,gravel*.36);
  h+=ripples*.008;
 }else if(kind<1.5){
  float streak=noise(vec3(p.x*13.0,p.y*.28,p.z*13.0));
  float joints=1.0-smoothstep(.006,.024,abs(fract(p.y*.31)-.5));
  float fracture=cracks((p.xy+p.zy*.19)*.64)*smoothstep(.32,.67,macro);
  c*=.72+streak*.38;
  c=mix(c,vec3(.058,.045,.027),fracture*.65+joints*.25);
  h-=fracture*.005;
 }else if(kind<3.5){
  float flake=fractal(p*7.0)+noise(p*77.0)*.12;
  float rust=smoothstep(.43,.57,flake);
  vec3 oxide=mix(vec3(.09,.032,.012),vec3(.32,.112,.036),noise(p*19.0));
  float drip=noise(vec3(p.x*42.0,p.y*.5,p.z*42.0));
  c=mix(c,oxide,rust);
  c*=.78+drip*.29;
  h+=rust*.0012+noise(p*130.0)*.0008;
  rough=mix(.68,.97,rust);
 }else if(kind<4.5){
  c*=.64+medium*.37;h=grain*.0006;
 }else if(kind<5.5){
  c*=.7+noise(p*4.0)*.5;h+=noise(p*40.0)*.003;
 }else if(kind<6.5){
  float fracture=cracks(p.xz*.44)*smoothstep(.25,.70,macro);
  float sand_drift=smoothstep(.55,.76,fractal(p*.37+vec3(4.0)));
  c*=.76+grain*.46;
  c=mix(c,vec3(.30,.245,.17),sand_drift*.73);
  c=mix(c,vec3(.025,.023,.02),fracture*.74);
  h+=grain*.002-fracture*.004;
 }else if(kind>7.5 && kind<8.5){
  vec2 brick_uv=vec2(abs(world_normal.z)>.5?p.x:p.z,p.y)*vec2(2.8,5.6);
  brick_uv.x+=mod(floor(brick_uv.y),2.0)*.5;
  vec2 cell=fract(brick_uv);
  float mortar=(1.0-smoothstep(.025,.07,min(cell.x,1.0-cell.x)))+(1.0-smoothstep(.045,.085,min(cell.y,1.0-cell.y)));
  float brick_shade=hash(vec3(floor(brick_uv),2.0));
  c*=.76+brick_shade*.48;
  c=mix(c,vec3(.29,.28,.245),clamp(mortar,0.0,1.0)*.86);
  float chipped=smoothstep(.66,.82,noise(p*38.0));
  c*=1.0-chipped*.16;
  h+=noise(p*54.0)*.0018-clamp(mortar,0.0,1.0)*.007;
 }else if(kind>8.5 && kind<9.5){
  float fibres=noise(vec3(p.x*74.0,p.y*2.4,p.z*74.0));
  float splits=smoothstep(.78,.91,fibres)*smoothstep(.4,.7,macro);
  c*=.67+fibres*.59;
  c=mix(c,vec3(.063,.047,.032),splits*.62);
  h+=fibres*.0014-splits*.003;
 }else if(kind>9.5){
  float chipped=smoothstep(.54,.73,noise(p*83.0)+noise(p*7.0)*.16);
  c=mix(c,vec3(.15,.14,.12),chipped*.72);
  rough=.97;
  h+=grain*.0003;
 }
 ALBEDO=c;ROUGHNESS=rough;METALLIC=metal_value;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX),r1=cross(sy,NORMAL),r2=cross(NORMAL,sx);float det=dot(sx,r1);
 if(abs(det)>1e-12)NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(h)*r1+dFdy(h)*r2));
}

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform int effect_mode = 0;
uniform float energy = 1.4;
uniform float phase = 0.0;
uniform float opacity = 1.0;
varying vec3 local_point;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y); }
void vertex(){ local_point=VERTEX; }
void fragment(){
 float edge=pow(max(0.0,sin(UV.y*3.14159265)),1.7);
 float alpha=edge*.64;
 vec3 color=tint.rgb;
 if(effect_mode==1){
  float cloud=noise(UV*vec2(9,4)+vec2(phase*.4,-phase*.15));
  alpha=edge*smoothstep(.18,.73,cloud)*.22;
 }else if(effect_mode==2){
  alpha=edge*(.35+.65*smoothstep(.2,.72,noise(vec2(UV.x*16.0-phase*4.0,2.0))))*.72;
 }else if(effect_mode==3){
  float ends=smoothstep(0.0,.10,UV.y)*(1.0-smoothstep(.6,1.0,UV.y));
  float strands=.55+.45*noise(vec2(UV.x*22.0,UV.y*3.0-phase*.3));
  alpha=ends*strands*.15;
 }else if(effect_mode==4){
  float flicker=noise(vec2(UV.x*6.0-phase*5.0,UV.y*4.0));
  alpha=edge*(1.0-UV.x)*smoothstep(.18,.7,flicker)*.9;
  color=mix(tint.rgb,vec3(1.0,.86,.46),1.0-UV.x);
 }
 ALBEDO=color;
 EMISSION=color*energy;
 ALPHA=clamp(alpha*opacity*tint.a,0.0,.8);
}

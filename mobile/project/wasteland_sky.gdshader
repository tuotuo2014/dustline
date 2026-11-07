shader_type sky;
render_mode use_half_res_pass;
uniform float twilight = 0.0;
uniform float overcast = 0.0;
uniform vec3 sun_direction=vec3(-.53,.22,-.82);
float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){return noise(p)*.52+noise(p*2.03)*.27+noise(p*4.09)*.14+noise(p*8.21)*.07;}
void sky(){
 vec3 d=normalize(EYEDIR),sun=normalize(sun_direction);
 float altitude=max(d.y,0.0);
 float proximity=max(dot(d,sun),0.0);
 vec3 col=mix(vec3(.67,.34,.13),vec3(.29,.32,.33),pow(altitude,.55));
 col+=vec3(.55,.19,.028)*pow(proximity,18.0);
 vec3 cloud_p=d/max(.14,d.y+.18)*2.5+vec3(1.1,0.0,3.0);
 float cloud=fbm(cloud_p);
 float coverage=smoothstep(.40,.67,cloud)*smoothstep(-.025,.22,d.y);
 vec3 cloud_col=mix(vec3(.23,.22,.20),vec3(.86,.50,.19),pow(proximity,9.0));
 col=mix(col,cloud_col,coverage*.8);
 float disc=smoothstep(cos(.018),cos(.015),dot(d,sun));
 col+=vec3(8.0,4.4,1.6)*disc*(1.0-coverage*.70);
 col+=vec3(.5,.15,.02)*pow(proximity,200.0);
 vec3 evening=mix(vec3(.84,.34,.18),vec3(.095,.075,.19),pow(altitude,.34));
 evening+=vec3(.25,.08,.018)*pow(proximity,24.0);
 evening=mix(evening,vec3(.045,.052,.090),coverage*.68);
 col=mix(col,mix(col,vec3(.28,.30,.29),coverage*.5)*.88,overcast);
 COLOR=mix(col,evening,twilight);
}

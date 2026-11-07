extends RefCounted
## Each face has its own anatomical cross sections, nose, cheeks and jaw.
const LIN := [Vector4(0,.024,.030,-.007),Vector4(.014,.038,.041,-.008),Vector4(.035,.051,.049,-.006),Vector4(.058,.060,.056,-.002),Vector4(.082,.067,.063,.004),Vector4(.106,.075,.070,.008),Vector4(.132,.080,.076,.010),Vector4(.156,.081,.078,.014),Vector4(.182,.079,.082,.018),Vector4(.208,.077,.082,.021),Vector4(.231,.065,.073,.022),Vector4(.248,.045,.052,.023),Vector4(.260,.015,.018,.024),Vector4(.262,.002,.003,.024)]
const RAVEN := [Vector4(0,.021,.027,-.008),Vector4(.014,.034,.037,-.008),Vector4(.035,.045,.046,-.005),Vector4(.058,.056,.053,.0),Vector4(.082,.065,.060,.005),Vector4(.106,.076,.068,.009),Vector4(.132,.083,.074,.011),Vector4(.156,.082,.076,.014),Vector4(.182,.080,.080,.019),Vector4(.208,.076,.080,.021),Vector4(.231,.064,.070,.023),Vector4(.248,.044,.049,.024),Vector4(.260,.015,.017,.024),Vector4(.262,.002,.003,.024)]
const MORROW := [Vector4(0,.035,.037,-.015),Vector4(.014,.053,.049,-.015),Vector4(.035,.068,.056,-.010),Vector4(.058,.076,.061,-.006),Vector4(.082,.078,.066,.0),Vector4(.106,.083,.073,.003),Vector4(.132,.090,.080,.005),Vector4(.156,.088,.080,.009),Vector4(.182,.087,.085,.014),Vector4(.208,.083,.083,.018),Vector4(.231,.069,.074,.020),Vector4(.248,.048,.052,.020),Vector4(.260,.017,.019,.020),Vector4(.262,.002,.003,.020)]

static func profile(id: int,y: float) -> Vector4:
	var rings: Array=LIN if id==1 else (RAVEN if id==2 else MORROW)
	var i := 0
	while i<rings.size()-2 and y>rings[i+1].x: i+=1
	var a: Vector4=rings[maxi(0,i-1)]
	var b: Vector4=rings[i]
	var c: Vector4=rings[i+1]
	var d: Vector4=rings[mini(rings.size()-1,i+2)]
	var t := clampf((y-b.x)/(c.x-b.x),0,1)
	var v: Vector4=.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
	v.x=y
	return v

static func surface_z(id: int,x: float,y: float) -> float:
	var pr := profile(id,y)
	var s := sqrt(maxf(0.0,1.0-pow(x/maxf(pr.y,.001),2)))
	var mask := pow(s,2.5)
	var z := -pow(s,.65)*pr.z+pr.w
	var female := id<3
	var nose_bridge := (.013 if female else .021)*exp(-pow((y-.139)/.032,2)-pow(x/(.008 if female else .012),2))
	var nose_tip := (.0205 if id==1 else (.0180 if id==2 else .029))*exp(-pow((y-.110)/(.010 if female else .014),2)-pow(x/(.010 if female else .014),2))
	var alar := (.0045 if female else .009)*exp(-pow((y-.103)/.007,2)-pow((absf(x)-.011)/.005,2))
	var cheek := (.0078 if female else .0105)*exp(-pow((y-(.120 if id==2 else .125))/.024,2)-pow((absf(x)-.053)/.020,2))
	var hollow := (.0020 if female else .004)*exp(-pow((y-.092)/.019,2)-pow((absf(x)-.055)/.017,2))
	var mouth := (.005 if female else .007)*exp(-pow((y-.064)/.018,2)-pow(x/(.028 if female else .033),2))
	var chin := (.0045 if female else .009)*exp(-pow((y-.024)/.014,2)-pow(x/(.022 if female else .032),4))
	var socket := (.0058 if female else .009)*exp(-pow((y-.151)/.012,2)-pow((absf(x)-.037)/.019,2))
	var brow := (.0042 if female else .010)*exp(-pow((y-.168)/.009,2)-pow((absf(x)-.037)/.027,2))
	var philtrum := .0010*exp(-pow((y-.084)/.010,2)-pow(x/.003,2))
	var lip_fold := .0015*exp(-pow((y-.047)/.005,2)-pow(x/.025,4))
	var under_eye := .0014*exp(-pow((y-.135)/.007,2)-pow((absf(x)-.037)/.020,2))
	z-=(nose_bridge+nose_tip+alar+cheek+mouth+chin+brow+under_eye-socket-hollow-philtrum-lip_fold)*mask
	if id==3:
		var folds := exp(-pow((absf(x)-(.022+(.107-y)*.30))/.0013,2))*exp(-pow((y-.079)/.027,4))*.0009
		z+=folds*mask
		for crease in [.194,.207,.220]:
			z+=exp(-pow((y-crease-.002*cos(x*60))/.0008,2))*exp(-pow(x/.061,6))*.0006*mask
	return z

static func eye_point(id: int,side: float,t: float,upper: bool,opening: float) -> Vector3:
	var width := .0164 if id==3 else .0176
	var x := side*.037+lerpf(-width,width,t)
	var arc := pow(sin(t*PI),.83)
	var tilt := side*(x-side*.037)*(.09 if id<3 else .04)
	var amount := 1.30 if id==1 else (1.38 if id==2 else .92)
	var y := .1508+tilt+arc*((.0039 if upper else -.0033)*opening*amount-.0010*(1-opening))
	return Vector3(x,y,surface_z(id,x,y)-.00050-arc*.00055)

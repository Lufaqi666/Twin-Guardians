extends RefCounted

# Code-native effects use bounded geometry; animation never mutates match state.
const PALETTES = {
	"archer": [Color("8bffc1"), Color("ffd879")],
	"barracks": [Color("ffe399"), Color("ff9772")],
	"frost": [Color("8ef2ff"), Color("a4acff")],
	"cannon": [Color("ffb457"), Color("b7eeff")],
	"alchemy": [Color("b2ff6f"), Color("ff8c4b")],
	"ballista": [Color("ffe799"), Color("82e4ff")],
	"storm": [Color("9be5ff"), Color("df9cff")],
	"beacon": [Color("a6ffe0"), Color("ffe099")]
}
const SECOND_BRANCHES = ["hunter", "mobile", "deep", "shatter", "volatile", "piercer", "overload", "banner"]

static func tint(kind: String, branch: String) -> Color:
	var colors: Array = PALETTES.get(kind, [Color.WHITE, Color.WHITE])
	return colors[1 if branch in SECOND_BRANCHES else 0]

static func ring(c: CanvasItem, p: Vector2, radius: Vector2, color: Color, phase: float, span := TAU) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		points.append(p + Vector2.from_angle(phase + span * i / 32.0) * radius)
	c.draw_polyline(points, color, 1.5, true)

static func spark(c: CanvasItem, p: Vector2, color: Color, size := 3.0) -> void:
	c.draw_line(p-Vector2(size,0), p+Vector2(size,0), color, 1.4, true)
	c.draw_line(p-Vector2(0,size), p+Vector2(0,size), color, 1.4, true)

static func lightning(c: CanvasItem, a: Vector2, b: Vector2, color: Color, phase: float) -> void:
	var points := PackedVector2Array([a])
	var normal := (b-a).normalized().orthogonal()
	for i in range(1,6):
		points.append(a.lerp(b,i/6.0)+normal*sin(phase*9+i*2.7)*5)
	points.append(b)
	c.draw_polyline(points, Color(color,.16), 7, true)
	c.draw_polyline(points, color, 2, true)

static func idle(c: CanvasItem, p: Vector2, tower: Dictionary, clock: float, enabled: bool, pulse: float) -> void:
	if int(tower.level) < 3 or str(tower.get("branch", "")).is_empty(): return
	var kind: String = tower.id
	var branch: String = tower.branch
	var color := tint(kind,branch)
	var strength := 1.0 if enabled else .18
	var t := clock + float(tower.pos.x)*.31 + float(tower.pos.y)*.17
	var scale := 1.16
	c.draw_set_transform(p,0,Vector2.ONE*scale)
	# Narrow ground runes leave roads and targeting indicators readable.
	ring(c,Vector2(0,3),Vector2(29,13),Color(color,.34*strength),t*.35,PI*1.45)
	ring(c,Vector2(0,3),Vector2(33,15),Color(color,.16*strength),-t*.3,PI)
	var crown := Vector2(0,-57)
	match kind:
		"archer":
			for i in range(3):
				var q := Vector2(sin(t*1.3+i*2.1)*24,-48-cos(t*1.3+i*2.1)*8)
				c.draw_line(q-Vector2(8,3),q,Color(color,.7*strength),2,true)
				spark(c,q,Color(color,.65*strength),2)
			if branch=="hunter":
				c.draw_arc(crown,21,-.8,.8,20,Color(color,.6*strength),2,true)
		"barracks":
			for side in [-1,1]:
				var q := Vector2(side*24,-27+sin(t*2)*3)
				var pts := PackedVector2Array([q+Vector2(-7,-8),q+Vector2(7,-8),q+Vector2(6,3),q+Vector2(0,10),q+Vector2(-6,3),q+Vector2(-7,-8)])
				c.draw_colored_polygon(pts,Color(color,.12*strength))
				c.draw_polyline(pts,Color(color,.65*strength),1.5,true)
				if branch=="mobile":c.draw_line(q+Vector2(-3,3),q+Vector2(3,-5),Color(color,strength),2,true)
		"frost":
			crown=Vector2(0,-65)
			for i in range(5):
				var q := crown + Vector2.from_angle(t*.6+i*TAU/5)*Vector2(23,13)
				c.draw_colored_polygon(PackedVector2Array([q+Vector2(0,-6),q+Vector2(3,0),q+Vector2(0,6),q-Vector2(3,0)]),Color(color,.8*strength))
				spark(c,Vector2(sin(t+i*2)*22,-20-fmod(t*8+i*9,32)),Color(color,.55*strength),2)
		"cannon":
			crown=Vector2(-11,-53)
			for i in range(4):
				var q := crown+Vector2(sin(t*3+i)*7,-fmod(t*17+i*8,30))
				c.draw_circle(q,1.8,Color(color,(1-fmod(t*17+i*8,30)/30)*strength))
			c.draw_arc(crown,11,t, t+PI*1.4,18,Color(color,.55*strength),2,true)
		"alchemy":
			crown=Vector2(0,-46)
			for i in range(5):
				var height := fmod(t*12+i*9,43)
				var q := Vector2(21+sin(t*2+i)*8,-48-height)
				c.draw_arc(q,2+i%3,0,TAU,12,Color(color,(1-height/43)*.7*strength),1.3,true)
			if branch=="volatile":
				c.draw_colored_polygon(PackedVector2Array([Vector2(-6,-42),Vector2(sin(t*8)*4,-67),Vector2(7,-43)]),Color(color,.35*strength))
		"ballista":
			crown=Vector2(23,-55)
			for i in range(3):
				var q := Vector2(-24,-39).lerp(crown,fmod(t*.65+i*.33,1))
				c.draw_line(q-Vector2(7,-2),q,Color(color,.8*strength),2,true)
			c.draw_arc(crown,10,t,t+PI*1.5,18,Color(color,.55*strength),1.5,true)
		"storm":
			crown=Vector2(0,-61)
			for i in range(3):
				var q := crown+Vector2.from_angle(-t*1.2+i*TAU/3)*Vector2(25,16)
				lightning(c,crown,q,Color(color,.7*strength),t+i)
				c.draw_circle(q,2.5,Color(color,strength))
		"beacon":
			crown=Vector2(0,-58)
			for i in range(3):
				var height := fmod(t*8+i*17,50)
				ring(c,crown+Vector2(0,-height*.45),Vector2(16+height*.23,5+height*.08),Color(color,(1-height/50)*.5*strength),0)
				spark(c,Vector2(sin(t+i*2)*23,-12-height),Color(color,.65*strength),3)
	# Compact halo intensifies on real attacks and active skill casts.
	for i in range(2):
		c.draw_circle(crown,9+i*6,Color(color,(.035+.12*pulse)*strength))
	if pulse>0:
		ring(c,crown,Vector2.ONE*(12+(1-pulse)*19),Color(color,pulse*.85*strength),t)
	c.draw_set_transform(Vector2.ZERO)

static func trail(c: CanvasItem, p: Vector2, direction: Vector2, kind: String, branch: String, clock: float) -> void:
	var color := tint(kind,branch)
	for i in range(3):
		c.draw_line(p-direction*(8+i*8),p-direction*i*8,Color(color,.42-i*.11),4-i,true)
	if kind=="cannon":
		c.draw_circle(p,9,Color(color,.14))
		spark(c,p-direction*18+direction.orthogonal()*sin(clock*22)*5,Color(color,.7),2)
	elif kind=="frost":spark(c,p,Color(color,.9),5)

static func cast(c: CanvasItem, p: Vector2, origin: Vector2, effect: Dictionary, life: float, scale: Vector2, quality := 2) -> void:
	var kind: String = effect.tower_kind
	var skill: String = effect.tower_skill
	var color := tint(kind,str(effect.get("branch","")))
	var fade := 1-life
	var radius := scale*float(effect.get("radius",2.3))
	ring(c,p,radius*(.3+life*.7),Color(color,.7*fade),0)
	if quality==0:return
	if skill in ["line","execute"]:
		var direction := (p-origin).normalized()
		var end := p+direction*90 if skill=="line" else p
		c.draw_line(origin+Vector2(0,-45),end+Vector2(0,-12),Color(color,.15*fade),13*fade,true)
		c.draw_line(origin+Vector2(0,-45),end+Vector2(0,-12),Color(color,fade),3*fade,true)
	elif skill in ["surge","rod"]:
		for i in range(5):
			var q := p+Vector2.from_angle(i*TAU/5)*radius*(.3+life*.6)
			lightning(c,q+Vector2(0,-75*fade),q,Color(color,fade),life+i)
	elif skill in ["wall","heal","banner"]:
		for i in range(6):
			var q := p+Vector2.from_angle(i*TAU/6)*radius*.65+Vector2(0,-life*25)
			spark(c,q,Color(color,fade),5)
			c.draw_line(q+Vector2(0,10),q+Vector2(0,-15),Color(color,.24*fade),4,true)
	else:
		for i in range(10 if quality==2 else 5):
			var q := p+Vector2.from_angle(i*TAU/10)*radius*(.25+life*.65)
			if kind=="frost":
				c.draw_colored_polygon(PackedVector2Array([q-Vector2(5,0),q+Vector2(0,-26*fade),q+Vector2(5,0)]),Color(color,.8*fade))
			elif kind=="archer":
				c.draw_line(q+Vector2(10,-50*fade),q,Color(color,fade),2,true)
			else:
				c.draw_circle(q+Vector2(0,-sin(life*PI)*18),3+fade*5,Color(color,.55*fade))

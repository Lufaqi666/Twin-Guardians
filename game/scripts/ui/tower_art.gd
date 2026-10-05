extends RefCounted

const INK = Color("332c27")

static func poly(c: CanvasItem, pts: Array, fill: Color, outline := true) -> void:
	var points := PackedVector2Array(pts)
	c.draw_colored_polygon(points, fill)
	if outline:
		points.append(points[0])
		c.draw_polyline(points, INK, 1.7, true)

static func ellipse(c: CanvasItem, p: Vector2, radius: Vector2, fill: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		points.append(p + Vector2.from_angle(TAU * i / 32) * radius)
	c.draw_colored_polygon(points, fill)

static func block(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	poly(c, [Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)], color)
	poly(c, [Vector2(x+w,y),Vector2(x+w+9,y-6),Vector2(x+w+9,y+h-6),Vector2(x+w,y+h)], color.darkened(0.32))
	poly(c, [Vector2(x,y),Vector2(x+9,y-6),Vector2(x+w+9,y-6),Vector2(x+w,y)],color.lightened(0.16))
	c.draw_line(Vector2(x+2,y+2),Vector2(x+w-2,y+2),color.lightened(0.38),1.2,true)

static func wall(c: CanvasItem, x: float, y: float, w: float, h: float, stone: Color) -> void:
	block(c,x,y,w,h,stone)
	for row in range(int(h/7)):
		var yy := y+row*7+6
		c.draw_line(Vector2(x+1,yy),Vector2(x+w-1,yy),stone.darkened(.3),1,true)
		for col in range(4):
			var xx := x+col*10+(5 if row%2==0 else 0)
			if xx>x+1 and xx<x+w-1:
				c.draw_line(Vector2(xx,yy-5),Vector2(xx,yy),stone.darkened(.25),1,true)
			var chip := Vector2(x + 3 + fmod(row * 13 + col * 9, maxf(1,w-6)), yy - 3)
			c.draw_line(chip,chip + Vector2(3,0),stone.lightened(0.23),1,true)
	c.draw_line(Vector2(x+2,y+h-2),Vector2(x+w-1,y+h-2),stone.darkened(0.37),2,true)

static func roof(c: CanvasItem, p: Vector2, width: float, color: Color) -> void:
	poly(c,[p+Vector2(-width,5),p+Vector2(-3,-14),p+Vector2(width,5)],color)
	poly(c,[p+Vector2(-3,-14),p+Vector2(6,-20),p+Vector2(width+9,-1),p+Vector2(width,5)],color.darkened(.25))
	for i in range(3):
		var yy := -5+i*4
		c.draw_line(p+Vector2(-width*.65+i*3,yy),p+Vector2(width*.65-i*2,yy),color.darkened(.23),2,true)
		c.draw_line(p+Vector2(-width*.65+i*3,yy-1),p+Vector2(width*.65-i*2,yy-1),color.lightened(.25),1,true)
		for tile in range(4):
			var tx := -width*.45 + tile*width*.28 + (i%2)*3
			c.draw_line(p+Vector2(tx,yy-4),p+Vector2(tx+2,yy),color.darkened(.2),1,true)
	c.draw_line(p+Vector2(-3,-14),p+Vector2(6,-20),color.lightened(.4),2,true)

static func flag(c: CanvasItem, p: Vector2, color: Color, clock: float) -> void:
	c.draw_line(p,p+Vector2(0,-26),INK,3,true)
	poly(c,[p+Vector2(0,-25),p+Vector2(16,-23+sin(clock*3)*2),p+Vector2(12,-12),p+Vector2(0,-14)],color)
	c.draw_line(p+Vector2(2,-24),p+Vector2(13,-22),color.lightened(.35),1.4,true)

static func paint(c: CanvasItem, p: Vector2, kind: String, level: int, owner_color: Color, clock: float, art_scale := 1.0) -> void:
	c.draw_set_transform(p,0,Vector2.ONE*(1+float(level-1)*.08)*art_scale)
	for layer in range(3):
		ellipse(c,Vector2(8,9),Vector2(29+layer*5,9+layer*2),Color(0.07,.1,.07,.18-layer*.045))
	ellipse(c,Vector2(0,5),Vector2(25,12),Color("68624c"))
	ellipse(c,Vector2(0,1),Vector2(25,12),Color("aea487"))
	for i in range(9):
		var angle := i*TAU/9
		c.draw_line(Vector2.from_angle(angle)*Vector2(21,9),Vector2.from_angle(angle)*Vector2(25,12),Color("716c55"),1.3,true)
	var stone := Color("c1baa2")
	match kind:
		"ballista":
			wall(c,-19,-30,34,31,Color("b4ac95"))
			block(c,-23,-39,45,10,Color("876443"))
			c.draw_line(Vector2(-17,-56),Vector2(21,-35),INK,7,true)
			c.draw_line(Vector2(-17,-56),Vector2(21,-35),Color("c6a86a"),4,true)
			c.draw_line(Vector2(-25,-39),Vector2(-17,-56),Color("ddd5b7"),2,true)
			c.draw_line(Vector2(-25,-39),Vector2(21,-35),Color("ddd5b7"),2,true)
			c.draw_line(Vector2(-29,-39),Vector2(23,-55),Color("384638"),5,true)
			poly(c,[Vector2(20,-60),Vector2(30,-58),Vector2(24,-50)],Color("d9dfd2"))
			if level >= 2: block(c,-10,-27,18,14,Color("4b563e"))
			if level == 3: flag(c,Vector2(-19,-42),Color("d9c070"),clock)
		"storm":
			wall(c,-15,-36,28,37,Color("a5a0b7"))
			block(c,-19,-40,37,7,Color("6c5b83"))
			poly(c,[Vector2(0,-79),Vector2(-13,-60),Vector2(-5,-44),Vector2(12,-60)],Color("aa91e7"))
			poly(c,[Vector2(0,-76),Vector2(-6,-59),Vector2(5,-61),Vector2(-1,-47),Vector2(10,-66)],Color("efe7ff"),false)
			for i in range(level):
				c.draw_arc(Vector2(0,-61),18+i*5,clock+i,clock+i+PI*1.4,24,Color("d0b7f3"),2,true)
			block(c,-5,-26,10,15,Color("47344d"))
		"beacon":
			wall(c,-16,-34,29,35,Color("aeb8a1"))
			roof(c,Vector2(0,-40),23,Color("5b8171"))
			block(c,-7,-58,15,19,Color("e5ce83"))
			poly(c,[Vector2(0,-76),Vector2(-11,-59),Vector2(0,-46),Vector2(11,-59)],Color("95ead2"))
			c.draw_line(Vector2(-5,-58),Vector2(5,-58),Color("fff1c1"),3,true)
			c.draw_line(Vector2(0,-64),Vector2(0,-52),Color("fff1c1"),3,true)
			for i in range(level):
				ellipse(c,Vector2(0,-58),Vector2(17+i*6,22+i*6),Color(.5,.9,.72,.07))
			if level == 3: flag(c,Vector2(-15,-39),Color("e6d48b"),clock)
		"archer":
			wall(c,-16,-28,29,29,stone)
			block(c,-19,-41,35,12,Color("946746"))
			for x in [-15,0,14]:
				c.draw_line(Vector2(x,-40),Vector2(x,-13),Color("684b36"),4,true)
				c.draw_line(Vector2(x-1,-39),Vector2(x-1,-15),Color("c69965"),1,true)
			roof(c,Vector2(0,-51 if level>=2 else -43),24,Color("8c4b35"))
			block(c,-9,-39,16,12,Color("473e31"))
			c.draw_circle(Vector2(-1,-34),4,Color("deb485"))
			c.draw_arc(Vector2(9,-33),9,-1.35,1.35,18,Color("e7c88d"),2.5,true)
			c.draw_line(Vector2(11,-42),Vector2(11,-24),Color("e5dfc6"),1,true)
			if level>=2:
				flag(c,Vector2(-17,-41),owner_color,clock)
			if level==3:
				c.draw_line(Vector2(-18,-33),Vector2(19,-33),Color("d7b071"),4,true)
				c.draw_line(Vector2(-10,-47),Vector2(15,-26),Color("4a352b"),4,true)
		"frost":
			wall(c,-15,-40,27,40,Color("919cab"))
			block(c,-20,-42,36,6,Color("636f85"))
			roof(c,Vector2(-1,-45),21,Color("52699a"))
			for x in [-15,15]:
				wall(c,x-3,-48,6,25,Color("abb7bd"))
				poly(c,[Vector2(x-7,-49),Vector2(x,-61),Vector2(x+7,-49)],Color("516793"))
			for i in range(3):
				ellipse(c,Vector2(0,-64),Vector2(13+i*5,17+i*4),Color(.35,.8,1,.05))
			poly(c,[Vector2(0,-83),Vector2(-10,-65),Vector2(0,-47),Vector2(10,-65)],Color("6cd0ef"))
			poly(c,[Vector2(0,-83),Vector2(-10,-65),Vector2(0,-47)],Color("bcf4ff"),false)
			c.draw_line(Vector2(0,-81),Vector2(0,-50),Color("e9ffff"),1.5,true)
			block(c,-5,-27,9,15,Color("304451"))
			c.draw_line(Vector2(-2,-23),Vector2(-2,-16),Color("94e2ee"),2,true)
			if level>=2:
				for x in [-18,18]:
					poly(c,[Vector2(x,-25),Vector2(x-4,-17),Vector2(x,-8),Vector2(x+4,-17)],Color("90dcea"))
			if level==3:
				c.draw_arc(Vector2(0,-65),18,0,TAU,28,Color("d9c680"),2,true)
		"cannon":
			wall(c,-23,-17,41,18,Color("9b9e92"))
			for x in [-22,-8,7,19]:
				block(c,x,-22,7,8,Color("b8bba9"))
			ellipse(c,Vector2(0,-24),Vector2(18,10),INK)
			ellipse(c,Vector2(0,-26),Vector2(17,9),Color("936947"))
			for x in [-15,13]:
				c.draw_circle(Vector2(x,-25),7,Color("58493b"))
				c.draw_circle(Vector2(x,-25),3,Color("c49356"))
			poly(c,[Vector2(-10,-26),Vector2(-18,-52),Vector2(-5,-56),Vector2(6,-29)],Color("424e54"))
			poly(c,[Vector2(-10,-26),Vector2(-18,-52),Vector2(-13,-54),Vector2(-4,-29)],Color("839495"),false)
			ellipse(c,Vector2(-11,-53),Vector2(9,5),Color("ccad71"))
			ellipse(c,Vector2(-11,-53),Vector2(6,3.5),Color("222c30"))
			c.draw_line(Vector2(-15,-44),Vector2(-3,-48),Color("c9a672"),3,true)
			c.draw_line(Vector2(-12,-36),Vector2(0,-39),Color("c9a672"),3,true)
			for i in range(level+1):
				c.draw_circle(Vector2(16+i%2*6,-7-i/2*5),4,Color("3b4040"))
			if level>=2:
				flag(c,Vector2(23,-18),owner_color,clock)
			if level==3:
				block(c,-30,-17,7,12,Color("b48b4f"))
		"barracks":
			wall(c,-22,-31,39,32,stone)
			roof(c,Vector2(-2,-35),28,Color("af533d"))
			c.draw_circle(Vector2(-3,-17),8,Color("403931"))
			c.draw_rect(Rect2(-11,-17,16,18),Color("403931"))
			for x in [-17,11]:
				c.draw_rect(Rect2(x,-25,5,9),Color("49453b"))
			c.draw_line(Vector2(-12,-12),Vector2(-12,-3),Color("edbb61"),3,true)
			flag(c,Vector2(24,-19),owner_color,clock)
			if level>=2:
				wall(c,-30,-35,10,35,Color("afa792"))
				for x in [-30,-23]:
					block(c,x,-40,5,7,stone)
			if level==3:
				poly(c,[Vector2(10,-35),Vector2(16,-40),Vector2(22,-35),Vector2(17,-24)],Color("d3b978"))
		"alchemy":
			wall(c,-18,-30,32,31,Color("c0b28b"))
			roof(c,Vector2(-1,-33),24,Color("527955"))
			block(c,-7,-20,12,15,Color("514a39"))
			block(c,15,-47,8,34,Color("97846c"))
			for i in range(3):
				c.draw_circle(Vector2(21+sin(clock*1.8+i)*4,-57-i*10-fmod(clock*8,8)),5+i,Color(.67,.7,.5,.18))
			c.draw_line(Vector2(-17,-34),Vector2(-23,-15),Color("997c45"),5,true)
			ellipse(c,Vector2(-21,-13),Vector2(9,10),Color("4b6a42"))
			ellipse(c,Vector2(-23,-15),Vector2(5,7),Color("97cc66"))
			block(c,-24,-28,6,8,Color("e2d9b2"))
			c.draw_circle(Vector2(-24,-16),2,Color("e1efb3"))
			if level>=2:
				c.draw_line(Vector2(25,-25),Vector2(29,-9),Color("bda472"),5,true)
				ellipse(c,Vector2(27,-7),Vector2(8,5),Color("bd8b48"))
			if level==3:
				poly(c,[Vector2(1,-56),Vector2(-6,-46),Vector2(0,-39),Vector2(7,-46)],Color("c7e580"))
	flag(c,Vector2(23,0),owner_color,clock)
	for i in range(level):
		c.draw_circle(Vector2(-7+i*7,9),2.5,Color("f2d87e"))
	c.draw_set_transform(Vector2.ZERO)

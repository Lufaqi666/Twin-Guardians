extends RefCounted

# Original vector character art shared by portraits and battlefield units.
const INK = Color("2c3038")
const GOLD = Color("eac780")
const SKIN = Color("efc69e")

static func poly(c: CanvasItem, points: Array, color: Color) -> void:
	var shape := PackedVector2Array(points)
	c.draw_colored_polygon(shape, color)
	shape.append(shape[0])
	c.draw_polyline(shape, INK, 1.15, true)

static func ellipse(c: CanvasItem, p: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32): points.append(p + Vector2.from_angle(i * TAU / 32) * radius)
	c.draw_colored_polygon(points, color)

static func line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	c.draw_line(a, b, INK, width + 1.7, true)
	c.draw_line(a, b, color, width, true)

static func paint(c: CanvasItem, p: Vector2, kind: String, accent: Color, clock := 0.0, moving := false, attack := 0.0, facing := Vector2.RIGHT, art_scale := 1.0) -> void:
	var bob := sin(clock * 7) * 0.75 if moving else sin(clock * 2) * 0.35
	c.draw_set_transform(p + Vector2(0, bob), 0, Vector2.ONE * art_scale)
	ellipse(c, Vector2(1, 3), Vector2(13, 4), Color(0.07, 0.1, 0.14, 0.25))
	var width := 12.0 if kind == "sentinel" else 9.0
	var cloak := accent.darkened(0.35)
	var sway := sin(clock * 3) * 1.5
	poly(c, [Vector2(-width,-25),Vector2(width,-24),Vector2(width+4+sway,0),Vector2(1,-3),Vector2(-width-5+sway,0)], cloak)
	line(c, Vector2(-width+2,-20),Vector2(-width-2+sway,-2),accent.lightened(0.05),1)
	var stride := sin(clock * 9) * 2 if moving else 0.0
	line(c,Vector2(-4,-8),Vector2(-5+stride,0),Color("687183"),4)
	line(c,Vector2(4,-8),Vector2(5-stride,0),Color("4b5467"),4)
	ellipse(c,Vector2(-5+stride,0),Vector2(4,2.5),Color("393c46"))
	ellipse(c,Vector2(5-stride,0),Vector2(4,2.5),Color("393c46"))
	poly(c,[Vector2(-width,-25),Vector2(width,-25),Vector2(width-2,-7),Vector2(-width+2,-7)],accent)
	poly(c,[Vector2(-width+2,-24),Vector2(-1,-24),Vector2(-2,-9),Vector2(-width+3,-9)],accent.lightened(0.24))
	poly(c,[Vector2(3,-23),Vector2(width-1,-23),Vector2(width-2,-8),Vector2(3,-9)],accent.darkened(0.23))
	line(c,Vector2(-width+1,-10),Vector2(width-1,-10),Color("60463e"),2.4)
	c.draw_circle(Vector2(0,-10),2.1,GOLD)
	# Oversized head, asymmetric light, bright eyes and role-specific headgear.
	ellipse(c,Vector2(0,-33),Vector2(11.8,11),INK)
	ellipse(c,Vector2(0,-33),Vector2(10.5,9.8),SKIN.darkened(0.19))
	ellipse(c,Vector2(-2,-34.5),Vector2(8.7,8.3),SKIN)
	ellipse(c,Vector2(-3,-36),Vector2(5.5,5),SKIN.lightened(0.12))
	var eye_y := -32.0
	for x in [-4.0,4.0]:
		ellipse(c,Vector2(x,eye_y),Vector2(2.1,2.8),Color("f6f1df"))
		ellipse(c,Vector2(x+0.5,eye_y+0.3),Vector2(1.25,2),Color("394d58"))
		c.draw_circle(Vector2(x,eye_y-0.6),0.65,Color.WHITE)
		c.draw_line(Vector2(x-2,eye_y-3.5),Vector2(x+1.6,eye_y-3.9),INK,1.2,true)
	c.draw_arc(Vector2(0,-28),2.3,0.15,PI-0.15,12,Color("a26958"),0.9,true)
	var hand_y := -19.0 - attack * 2
	var side := 1.0 if facing.x >= 0 else -1.0
	match kind:
		"commander":
			poly(c,[Vector2(-12,-35),Vector2(-10,-44),Vector2(-4,-46),Vector2(0,-42),Vector2(7,-45),Vector2(12,-37),Vector2(8,-35),Vector2(0,-39),Vector2(-8,-35)],Color("e3ebef"))
			poly(c,[Vector2(-8,-41),Vector2(-7,-49),Vector2(-2,-44),Vector2(0,-51),Vector2(3,-44),Vector2(8,-48),Vector2(9,-40)],Color("92cbdc"))
			c.draw_circle(Vector2(0,-43),2.4,Color("d6fcff"))
			poly(c,[Vector2(-14,-24),Vector2(-7,-27),Vector2(-5,-21),Vector2(-13,-18)],Color("d1e5ea"))
			poly(c,[Vector2(7,-27),Vector2(14,-24),Vector2(13,-18),Vector2(5,-21)],Color("a4c9d4"))
			line(c,Vector2(-5,-24),Vector2(0,-16),GOLD,1.2)
			line(c,Vector2(0,-16),Vector2(5,-24),GOLD,1.2)
			line(c,Vector2(14*side,-5),Vector2(14*side,-36),Color("698d9a"),2.5)
			poly(c,[Vector2(14*side,-45),Vector2(9*side,-36),Vector2(14*side,-30),Vector2(19*side,-36)],Color("9debf0"))
			line(c,Vector2(14*side,-42),Vector2(14*side,-34),Color("e7ffff"),1.2)
		"skirmisher":
			poly(c,[Vector2(-11,-35),Vector2(-12,-43),Vector2(-6,-42),Vector2(-8,-48),Vector2(-1,-45),Vector2(3,-50),Vector2(6,-43),Vector2(12,-45),Vector2(10,-35),Vector2(6,-39),Vector2(0,-37),Vector2(-5,-40)],Color("ad4b32"))
			line(c,Vector2(-6,-43),Vector2(2,-44),Color("f4b562"),2)
			poly(c,[Vector2(-11,-25),Vector2(10,-26),Vector2(7,-21),Vector2(-8,-22)],Color("cf4c40"))
			poly(c,[Vector2(-8,-24),Vector2(-19+sway,-21),Vector2(-22+sway,-11),Vector2(-16+sway,-15)],Color("f06c48"))
			for direction in [-1.0,1.0]:
				var a := Vector2(direction*12,hand_y)
				poly(c,[a,a+Vector2(direction*9,-13-attack*6),a+Vector2(direction*10,-3),a+Vector2(direction*3,4)],Color("f3d6ab"))
				line(c,a+Vector2(direction*2,-1),a+Vector2(direction*7,-8),Color("ff9255"),1.5)
		"sentinel":
			poly(c,[Vector2(-12,-31),Vector2(-12,-43),Vector2(0,-49),Vector2(12,-43),Vector2(12,-31),Vector2(7,-34),Vector2(6,-40),Vector2(-6,-40),Vector2(-7,-33)],Color("99a8b5"))
			line(c,Vector2(-9,-43),Vector2(1,-46),Color("e1edf0"),1.6)
			poly(c,[Vector2(-3,-46),Vector2(1,-51),Vector2(5,-46),Vector2(4,-39),Vector2(-2,-39)],GOLD)
			poly(c,[Vector2(-16,-25),Vector2(-7,-28),Vector2(-4,-20),Vector2(-13,-17)],Color("c8bb8d"))
			poly(c,[Vector2(7,-28),Vector2(16,-25),Vector2(13,-17),Vector2(4,-20)],Color("ad9c72"))
			poly(c,[Vector2(-6,-22),Vector2(6,-22),Vector2(5,-13),Vector2(0,-10),Vector2(-5,-13)],Color("c2cbd0"))
			poly(c,[Vector2(-20,-24),Vector2(-10,-26),Vector2(-6,-20),Vector2(-10,-6),Vector2(-16,-2),Vector2(-22,-12)],Color("8e9ba3"))
			poly(c,[Vector2(-17,-21),Vector2(-11,-21),Vector2(-11,-11),Vector2(-15,-7),Vector2(-19,-12)],GOLD)
			line(c,Vector2(15,-4),Vector2(15,-30-attack*5),Color("795b40"),3)
			poly(c,[Vector2(9,-36-attack*5),Vector2(24,-36-attack*5),Vector2(23,-25-attack*5),Vector2(9,-25-attack*5)],Color("bac7ca"))
		"ranger":
			poly(c,[Vector2(-12,-33),Vector2(-11,-43),Vector2(0,-49),Vector2(11,-42),Vector2(13,-32),Vector2(6,-37),Vector2(0,-41),Vector2(-7,-37)],Color("416751"))
			line(c,Vector2(-8,-42),Vector2(0,-46),Color("9fbc7c"),1.5)
			poly(c,[Vector2(6,-43),Vector2(11,-52),Vector2(14,-49),Vector2(10,-41)],Color("e8d5a6"))
			poly(c,[Vector2(-11,-32),Vector2(-15,-34),Vector2(-11,-27)],SKIN)
			line(c,Vector2(-7,-24),Vector2(7,-11),Color("ad8c59"),2)
			c.draw_arc(Vector2(13,hand_y),13,-1.4,1.4,28,INK,4,true)
			c.draw_arc(Vector2(13,hand_y),13,-1.4,1.4,28,Color("dbc58c"),2,true)
			c.draw_line(Vector2(15,hand_y-13),Vector2(15,hand_y+13),Color("f2e7cb"),0.9,true)
			line(c,Vector2(9,hand_y),Vector2(28+attack*4,hand_y),Color("e7d7af"),1)
			poly(c,[Vector2(28+attack*4,hand_y),Vector2(25+attack*4,hand_y-2),Vector2(25+attack*4,hand_y+2)],Color("d7e6dd"))
		"pyromancer":
			poly(c,[Vector2(-11,-35),Vector2(-9,-44),Vector2(-2,-47),Vector2(8,-42),Vector2(11,-33),Vector2(6,-36),Vector2(3,-40),Vector2(-5,-37)],Color("e5d8ba"))
			poly(c,[Vector2(-14,-40),Vector2(-7,-43),Vector2(-2,-54),Vector2(7,-50),Vector2(9,-42),Vector2(15,-38)],Color("974839"))
			line(c,Vector2(-10,-40),Vector2(11,-39),GOLD,1.7)
			poly(c,[Vector2(-8,-21),Vector2(-5,-8),Vector2(0,-5),Vector2(7,-9),Vector2(8,-21),Vector2(1,-17)],Color("6e3e40"))
			line(c,Vector2(0,-17),Vector2(0,-7),GOLD,1.2)
			line(c,Vector2(14,-4),Vector2(14,-35),Color("915e43"),2.4)
			ellipse(c,Vector2(14,-37),Vector2(7,9),Color(1,.52,.22,.16))
			poly(c,[Vector2(14,-47),Vector2(10,-39),Vector2(12,-33),Vector2(18,-34),Vector2(20,-40),Vector2(17,-37)],Color("f4ad54"))
			c.draw_circle(Vector2(14,-38),2.4,Color("fff0b3"))
		"stormcaller":
			poly(c,[Vector2(-11,-34),Vector2(-10,-43),Vector2(-4,-46),Vector2(6,-44),Vector2(12,-36),Vector2(6,-38),Vector2(2,-42),Vector2(-6,-38)],Color("494868"))
			line(c,Vector2(-8,-35),Vector2(-12,-21),Color("a2a9d9"),2.5)
			line(c,Vector2(9,-34),Vector2(12,-23),Color("a2a9d9"),2.5)
			c.draw_arc(Vector2(0,-45),11,PI,TAU,28,GOLD,1.6,true)
			poly(c,[Vector2(-7,-23),Vector2(0,-17),Vector2(7,-23),Vector2(5,-12),Vector2(-5,-12)],Color("655b91"))
			line(c,Vector2(-7,-23),Vector2(0,-17),GOLD,1)
			line(c,Vector2(7,-23),Vector2(0,-17),GOLD,1)
			line(c,Vector2(16,-4),Vector2(16,-39),Color("b9a5c6"),2.5)
			poly(c,[Vector2(16,-49),Vector2(11,-40),Vector2(17,-41),Vector2(13,-31),Vector2(22,-43),Vector2(17,-42)],Color("acf0f0"))
			for i in range(3):
				var orb := Vector2.from_angle(clock+i*TAU/3)*Vector2(9,5)+Vector2(16,-39)
				c.draw_circle(orb,1.4,Color("eadbff"))
	# Hands and tiny glints unify the six character designs.
	c.draw_circle(Vector2(-width-1,hand_y),2.7,SKIN)
	c.draw_circle(Vector2(width+1,hand_y),2.7,SKIN)
	c.draw_circle(Vector2(-3,-21),0.8,Color("fff0c4"))
	c.draw_set_transform(Vector2.ZERO)

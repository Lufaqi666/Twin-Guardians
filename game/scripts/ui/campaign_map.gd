extends Node2D

const Materials = preload("res://scripts/ui/art_materials.gd")

var levels: Dictionary = {}
var selected := "confluence_courtyard"
var stage_stars: Dictionary = {}
var clock := 0.0
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var frame := Rect2(18, 110, 810, 465)
	draw_rect(frame.grow(4), Color("493b2c"))
	draw_style_box(Materials.panel("dbcda2", "6f5439", 8), frame)
	# Water, land contours and distant mountains, all original vector artwork.
	for i in range(10):
		draw_rect(Rect2(24, 116 + i * 45, 798, 45), Color("6c9299").lerp(Color("354f69"), float(i) / 14))
	var land := PackedVector2Array([Vector2(42,142),Vector2(327,134),Vector2(387,170),Vector2(562,135),Vector2(804,155),Vector2(804,526),Vector2(649,544),Vector2(572,496),Vector2(425,540),Vector2(326,477),Vector2(249,500),Vector2(166,458),Vector2(110,370),Vector2(137,297),Vector2(62,252)])
	draw_colored_polygon(land, Color("5d6f50"))
	var coast := land.duplicate()
	coast.append(land[0])
	draw_polyline(coast, Color("d8ca98"), 7, true)
	draw_polyline(coast, Color("435948"), 2, true)
	var inner := land.duplicate()
	for i in range(inner.size()):
		inner[i] = inner[i].lerp(Vector2(430,330), 0.035)
	draw_colored_polygon(inner, Color("9cac72"))
	for i in range(85):
		var p := Vector2(155 + fmod(i * 73.7, 590), 190 + fmod(i * 47.3, 310))
		if Geometry2D.is_point_in_polygon(p, inner):
			draw_line(p, p + Vector2(12 + i%9, -2), Color(0.92, 0.89, 0.63, 0.13), 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(358,172),Vector2(560,147),Vector2(659,234),Vector2(556,314),Vector2(430,267)]), Color("b7c3b0"))
	draw_colored_polygon(PackedVector2Array([Vector2(484,328),Vector2(641,300),Vector2(801,346),Vector2(804,522),Vector2(654,533),Vector2(576,477)]), Color("cdab70"))
	for i in range(32):
		var x := 157 + fmod(i * 67.0, 254)
		var y := 213 + fmod(i * 41.0, 241)
		draw_line(Vector2(x,y),Vector2(x,y+9),Color("634f34"),3)
		draw_colored_polygon(PackedVector2Array([Vector2(x-12,y+2),Vector2(x,y-20),Vector2(x+12,y+2)]),Color("416644"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-8,y-4),Vector2(x,y-20),Vector2(x+3,y-4)]),Color("648a51"))
	for i in range(9):
		var p := Vector2(412 + i * 34, 175 + (i % 3) * 24)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-25,30),p+Vector2(0,-28),p+Vector2(27,30)]),Color("778c90"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-10,-4),p+Vector2(0,-28),p+Vector2(12,-3),p+Vector2(3,-10),p+Vector2(-2,-2)]),Color("e3e7d6"))
	for i in range(9):
		var p := Vector2(595 + fmod(i*37.0,160), 367 + fmod(i*29.0,140))
		draw_arc(p,22,PI,TAU,18,Color("b78b58"),4,true)
		draw_line(p+Vector2(13,-3),p+Vector2(13,-29),Color("ab8057"),6)
		draw_line(p+Vector2(6,-29),p+Vector2(20,-29),Color("dbc68e"),7)
	var trail := PackedVector2Array()
	for stage in levels.values():
		trail.append(Vector2(stage.position[0], stage.position[1]))
	for i in range(trail.size()-1):
		var length := trail[i].distance_to(trail[i+1])
		for j in range(int(length/12)):
			draw_circle(trail[i].lerp(trail[i+1],float(j)*12/length),2.5,Color("786045"))
	draw_string(font,Vector2(52,161),"双子王国 · 战役地图",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f3e9bd"))
	draw_string(font,Vector2(52,545),"选择旗帜，集结英雄，守住水晶",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f3e9bd"))
	for id in levels:
		var coords: Array = levels[id].position
		var p := Vector2(coords[0], coords[1])
		for index in range(3):
			var star := PackedVector2Array()
			var center := p + Vector2((index - 1) * 21, 88)
			for point in range(10):
				star.append(center + Vector2.from_angle(-PI / 2 + point * PI / 5) * (9 if point % 2 == 0 else 4))
			draw_colored_polygon(star, Color("ffdb70") if index < int(stage_stars.get(id, 0)) else Color("56604d"))
		if id == selected:
			draw_arc(p,44+sin(clock*3)*2,0,TAU,48,Color("ffe5a0"),3,true)
		draw_circle(p+Vector2(0,7),32,Color(0.1,0.15,0.1,0.24))
		draw_circle(p,27,Color("533c28"))
		draw_circle(p,23,Color("c1a263"))
		draw_line(p+Vector2(-5,13),p+Vector2(-5,-22),Color("493a2e"),4)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-21),p+Vector2(18,-16),p+Vector2(-4,-8)]),Color("d67047") if id==selected else Color("6f8174"))

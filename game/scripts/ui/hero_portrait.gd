extends Control

const HeroArt = preload("res://scripts/ui/hero_art.gd")
var kind := "commander"
var accent := Color("77b8df")

func _draw() -> void:
	var scale_factor := minf(size.x / 100, size.y / 120)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("24333c")
	box.border_color = accent.darkened(0.2)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	for i in range(5):
		draw_circle(size * Vector2(0.5, 0.45), (44-i*6) * scale_factor, Color(accent, 0.04))
	HeroArt.paint(self, Vector2(size.x*0.5,size.y*0.94), kind, accent, 0, false, 0, Vector2.RIGHT, scale_factor*1.93)

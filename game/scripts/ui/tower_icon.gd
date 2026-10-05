extends Control

const Art = preload("res://scripts/ui/tower_art.gd")
var kind := "archer"

func _draw() -> void:
	Art.paint(self, Vector2(16, 30), kind, 1, Color("72b6d2"), 0, 0.36)

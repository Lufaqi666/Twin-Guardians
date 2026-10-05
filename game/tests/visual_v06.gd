extends SceneTree

const Portrait = preload("res://scripts/ui/hero_portrait.gd")
const HeroArt = preload("res://scripts/ui/hero_art.gd")

class UnitPreview extends Control:
	var kind := "commander"
	var tint := Color.WHITE
	func _draw() -> void:
		HeroArt.paint(self,Vector2(size.x/2,size.y-12),kind,tint,0.8,false,0,Vector2.RIGHT,1.65)

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/"+name+"-v06.png"))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	await capture("campaign")
	game.ui.hide()
	var gallery := Control.new()
	gallery.size = Vector2(1280,800)
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("26343e")
	background.size = Vector2(1280,800)
	gallery.add_child(background)
	var title: Label = game._label("双子守护者 · 六英雄奇幻 Q 版",30,"f4e6c3")
	title.position = Vector2(32,38)
	gallery.add_child(title)
	var subtitle: Label = game._label("统一头像与战场形象 · 独立头饰、武器、披风和轮廓",17,"b3c4c8")
	subtitle.position = Vector2(32,86)
	gallery.add_child(subtitle)
	var i := 0
	for kind in game.session.match_model.cfg.heroes:
		var spec: Dictionary = game.session.match_model.cfg.heroes[kind]
		var panel: PanelContainer = game._panel(Rect2(24+i*207,137,196,594),gallery)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",16)
		panel.add_child(column)
		var name_label: Label = game._label(spec.name,21)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var avatar := Portrait.new()
		avatar.kind = kind
		avatar.accent = Color(spec.color)
		avatar.custom_minimum_size = Vector2(176,218)
		column.add_child(avatar)
		var skill: Label = game._label(spec.skill.name,15)
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(skill)
		var hint: Label = game._label("战场形象",13,"6b785d")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(hint)
		var unit := UnitPreview.new()
		unit.kind = kind
		unit.tint = Color(spec.color)
		unit.custom_minimum_size = Vector2(176,130)
		column.add_child(unit)
		i += 1
	await capture("hero-gallery")
	gallery.queue_free()
	await process_frame
	game.ui.show()
	for stage in ["moonbrook","sunken_temple","glacier_keep","eclipse_gate"]:
		game.session.practice(stage,"commander","stormcaller",true)
		game.session.set_physics_process(false)
		var m = game.session.match_model
		m.command("p1","build",{"node":"shared_01","tower":"ballista"},"preview1")
		m.command("p2","build",{"node":"shared_02","tower":"storm"},"preview2")
		m.state.heroes.p1.pos = Vector2(15,11)
		m.state.heroes.p1.target = m.state.heroes.p1.pos
		m.state.heroes.p2.pos = Vector2(17,13)
		m.state.heroes.p2.target = m.state.heroes.p2.pos
		m.state.phase = "battle"
		m.state.wave = 4
		m.state.time = 8
		m._stage_events(0.05)
		game._process(0.05)
		await capture(stage)
	game.queue_free()
	await process_frame
	print("VISUAL_V06_PASS")
	quit()

extends SceneTree

var serial := 0
var checks := 0
var failed := false
var suffix := "v07"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suffix="):suffix=arg.trim_prefix("--suffix=")
	call_deferred("run")

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		printerr("FAIL ", label)

func order(game, kind: String, payload: Dictionary) -> void:
	serial += 1
	var result: Dictionary = game.session.match_model.command("p1", kind, payload, "visual07-" + str(serial))
	verify(result.accepted, "production command " + kind)

func capture(game, name: String) -> void:
	game.tower_menu.refresh(true)
	await process_frame
	await process_frame
	game._process(0.05)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/" + name + "-"+suffix+".png"))
	verify(Rect2(23,110,955,580).encloses(Rect2(game.tower_menu.position,game.tower_menu.size)), "menu bounds " + name)
	var anchor: Vector2 = game.field.screen(game.session.match_model.cfg.vector(game.session.match_model.cfg.nodes[game.selected].position))
	verify(not Rect2(game.tower_menu.position,game.tower_menu.size).grow(16).has_point(anchor), "selected tower visible " + name)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	game._start_practice()
	game.session.set_physics_process(false)
	var m = game.session.match_model
	# Layout fixtures grant funds only for preview; this is not a playthrough.
	m.state.gold = {"p1": 40000, "p2": 40000}
	game.selected = "shared_01"
	await capture(game, "base-towers")
	verify(game.build_buttons.size() == 4, "four base buttons")
	order(game,"build",{"node":"shared_01","tower":"archer"})
	await capture(game, "tower-level1")
	order(game,"upgrade",{"node":"shared_01"})
	m.state.time = 3
	await capture(game, "tower-level2")
	order(game,"upgrade",{"node":"shared_01"})
	m.state.time = 6
	await capture(game, "tower-routes")
	# Exercise actual branch UI closure binding and exact type transformation.
	var chosen: Button
	for item in game.tower_menu.tracked:
		if item.button.text.begins_with("贯甲重弩"): chosen = item.button
	verify(is_instance_valid(chosen), "advanced branch button exists")
	chosen.mouse_entered.emit()
	game._process(0.05)
	verify(game.field.preview_kind == "ballista" and game.field.preview_branch == "piercer", "hover previews branch, not base")
	chosen.pressed.emit()
	verify(m.state.towers.shared_01.id == "ballista" and m.state.towers.shared_01.branch == "piercer", "branch button selects exact type and ability")
	m.state.time = 9
	await capture(game, "tower-evolved")
	# Tallest menu: barracks controls and expanded descriptions at every node.
	order(game,"build",{"node":"shared_02","tower":"barracks"})
	order(game,"upgrade",{"node":"shared_02"})
	m.state.time = 12
	order(game,"upgrade",{"node":"shared_02"})
	m.state.time = 15
	game.selected = "shared_02"
	game.tower_menu.refresh(true)
	game.tower_menu.expanded = true
	await capture(game, "tower-routes-details")
	var source: Dictionary = m.state.towers.shared_02.duplicate(true)
	for node in m.cfg.nodes:
		var fixture: Dictionary = source.duplicate(true)
		fixture.pos = m.cfg.vector(m.cfg.nodes[node].position)
		m.state.towers[node] = fixture
		game.selected = node
		game.tower_menu.refresh(true)
		game.tower_menu.expanded = true
		game.tower_menu._update_details()
		await process_frame
		await process_frame
		game.tower_menu.refresh()
		verify(Rect2(23,110,955,580).encloses(Rect2(game.tower_menu.position,game.tower_menu.size)), "expanded route menu " + node)
		verify(not Rect2(game.tower_menu.position,game.tower_menu.size).grow(16).has_point(game.field.screen(fixture.pos)), "route menu leaves tower visible " + node)
	game.queue_free()
	await process_frame
	print("VISUAL_V07 ", checks, " checks ", "FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

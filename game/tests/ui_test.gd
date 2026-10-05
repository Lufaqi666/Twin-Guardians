extends SceneTree

var failures: Array[String] = []
var count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, name: String) -> void:
	count += 1
	if not ok:
		failures.append(name)
		printerr("FAIL ", name)

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	game.persist_progress = false
	root.add_child(game)
	check(game.menu.visible and not game.game_ui.visible, "menu is initially visible")
	game.mode_choice.select(0)
	game.practice_button.pressed.emit()
	check(not game.menu.visible and game.game_ui.visible, "practice enters playable scene")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = game.field.screen(Vector2(14, 10))
	game._unhandled_input(mouse)
	check(game.selected == "shared_01", "map click selects exact logical node")
	for button in game.build_buttons:
		if button.text.begins_with("法师塔"):
			button.pressed.emit()
			break
	check(game.session.match_model.state.towers.get("shared_01", {}).get("id", "") == "frost", "build button captures correct tower type")
	game._rebuild_sidebar()
	var tab := InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	game._unhandled_input(tab)
	check(game.session.player == "p2", "Tab switches practice seat")
	mouse.position = game.field.screen(Vector2(14, 14))
	game._unhandled_input(mouse)
	for button in game.build_buttons:
		if button.text.begins_with("火炮塔"):
			button.pressed.emit()
			break
	check(game.session.match_model.state.towers.get("shared_02", {}).get("id", "") == "cannon", "P2 builds second combo tower")
	game._ready_wave()
	check(game.session.match_model.state.phase == "battle", "local ready confirms both seats")
	game._return_menu()
	check(game.menu.visible and game.session.mode == "menu", "return menu releases session")
	game.stage_buttons.frost_pass.pressed.emit()
	check(game.selected_level == "frost_pass" and game.mission_title.text == "霜脊隘口", "campaign flag selects stage")
	game.hero_choice.select(3)
	game.hero_choice.item_selected.emit(3)
	game.hero2_choice.select(4)
	game.hero2_choice.item_selected.emit(4)
	game.mode_choice.select(0)
	game.practice_button.pressed.emit()
	check(game.session.match_model.cfg.level_id == "frost_pass" and game.session.match_model.state.heroes.p1.kind == "ranger" and game.session.match_model.state.heroes.p2.kind == "pyromancer", "chosen stage and independent heroes launch")
	check(game.session.match_model.state.heroes.p1.skill.id == "arrow_storm" and game.session.match_model.state.heroes.p2.skill.id == "meteor", "fixed preview matches actual skills")
	var model = game.session.match_model
	game._rebuild_sidebar()
	var snapshot: Dictionary = model.snapshot()
	snapshot.heroes.p1.pos = Vector2(16, 12)
	model.apply_snapshot(snapshot)
	model.spawn("infantry", "a")
	var enemy: Dictionary = model.state.enemies.values()[0]
	enemy.pos = Vector2(17, 12)
	enemy.hp = 1000
	enemy.max_hp = 1000
	game.skill_buttons[0].pressed.emit()
	model.state.time += 0.4
	model._resolve_casts()
	check(enemy.mark_end > 0, "skill button targets current snapshot rather than stale UI state")
	check(game.skill_buttons.size() == 1, "only one hero active button")
	model._gain_xp(model.state.heroes.p1, 200)
	game._rebuild_sidebar()
	game.skill_upgrade.pressed.emit()
	check(model.state.heroes.p1.skill_level == 2, "skill upgrade button spends earned point")
	game._process(0.016)
	check(game.skill_upgrade.tooltip_text.contains("35%") and game.hero_info.text.contains("Lv.3"), "growth HUD updates between frames")
	game._return_menu()
	game.invitation.show()
	check(game.invitation.position.x == 18 and game.invitation.position.y == 76, "invitation panel anchored upper-left")
	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("UI_TESTS ", count - failures.size(), "/", count, " passed")
	quit(0 if failures.is_empty() else 1)

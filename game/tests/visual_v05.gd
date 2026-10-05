extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/" + name + "-v05.png"))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	await capture("campaign")
	game._start_practice()
	game.session.set_physics_process(false)
	game.selected = "shared_01"
	game._process(0.05)
	await capture("tower-choices")
	game.tower_menu._show_detail("storm")
	await capture("tower-details")
	var m = game.session.match_model
	m.state.gold = {"p1": 10000, "p2": 10000}
	game._send("build", {"node": "shared_01", "tower": "cannon"})
	game._send("upgrade", {"node": "shared_01"})
	m.state.time = 3
	game._process(0.05)
	await capture("tower-specialization")
	game._send("upgrade", {"node": "shared_01", "branch": "siege"})
	for row in [["p1_02","ballista"],["shared_02","storm"],["p1_03","beacon"],["p1_04","barracks"]]:
		game._send("build", {"node": row[0], "tower": row[1]})
	m.state.time = 6
	game.selected = "p1_02"
	game.tower_menu.refresh(true)
	await capture("tower-edge")
	game.selected = ""
	game._send("hero_talent", {"talent": "support"})
	m.state.phase = "battle"
	m.state.wave = 3
	m.state.wave_start = m.state.time
	m.state.time += 8
	m._stage_events(0.05)
	for kind in ["warden","mender","heavy","flyer"]:
		m.spawn(kind,"a")
		var enemy: Dictionary = m.state.enemies.values().back()
		enemy.s = 10 + m.state.enemies.size()
		enemy.pos = m.cfg.route_position(enemy.route, enemy.s)
	m.state.heroes.p1.pos = m.state.stage_event.beacons[0]
	m.state.heroes.p1.target = m.state.heroes.p1.pos
	m.state.heroes.p2.pos = m.state.stage_event.beacons[1]
	m.state.heroes.p2.target = m.state.heroes.p2.pos
	game._process(0.05)
	await capture("cooperation")
	game._return_menu()
	game.session.practice("ember_ruins", "commander", "skirmisher", true)
	game.session.set_physics_process(false)
	m = game.session.match_model
	m.state.phase = "battle"
	m.state.wave = 4
	m.state.time = 8
	m._stage_events(0.05)
	game._process(0.05)
	await capture("event-warning")
	m.state.time = 14
	m._stage_events(0.05)
	game._process(0.05)
	await capture("event-active")
	game.queue_free()
	await process_frame
	print("VISUAL_V05_PASS")
	quit()

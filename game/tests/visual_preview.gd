extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://../docs/design/" + name + "-v041.png"))

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	await capture("campaign")
	game.settings_panel.show()
	await capture("settings")
	game.settings_panel.hide()
	game._select_level("skywatch")
	game.mode_choice.select(1)
	game._start_practice()
	game.session.set_physics_process(false)
	game._process(0.05)
	await capture("wave-intel")
	game._return_menu()
	game._demo()
	game.session.set_physics_process(false)
	game._process(0.05)
	await capture("combat")
	for stage in ["frost_pass", "ember_ruins"]:
		game.session.practice(stage)
		game.session.set_physics_process(false)
		var model = game.session.match_model
		model.command("p1", "build", {"node": "shared_01", "tower": "frost"}, "art1")
		model.command("p2", "build", {"node": "shared_02", "tower": "cannon"}, "art2")
		game.selected = "shared_01"
		game._process(0.05)
		await capture(stage)
	game.session.match_model.state.phase = "lost"
	game.session.match_model.state.leak_log = [{"wave": 4, "kind": "flyer", "exit": "exit_p1"}]
	game._process(0.05)
	await capture("debrief")
	game.queue_free()
	await process_frame
	quit()

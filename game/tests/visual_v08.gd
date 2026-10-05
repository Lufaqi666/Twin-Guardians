extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/"+name+"-v08.png"))

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	game.set_process(false)
	# Isolated visual fixtures, not normal-economy playthrough evidence.
	for hp in [20,10,1]:
		game._start_practice()
		game.session.set_physics_process(false)
		var state: Dictionary = game.session.match_model.state
		state.phase = "won"
		state.wave = 10
		state.hp = hp
		game._process(0.01)
		await capture("victory-"+str(game.session.career.stars_for("won",hp))+"stars")
		game._process(3.01)
	# Several stage fixtures show earned and empty stars on the campaign map.
	game.session.career.record_stage("frost_pass","won",10)
	game.session.career.record_stage("moonbrook","won",1)
	game.session.career.record_stage("glacier_keep","won",18)
	game.campaign.stage_stars = game.session.career.stage_stars
	game._select_level("confluence_courtyard")
	await capture("campaign-stars")
	game.queue_free()
	await process_frame
	print("VISUAL_V08_PASS")
	quit()

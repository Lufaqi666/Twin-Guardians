extends SceneTree

const Career = preload("res://scripts/core/career.gd")
const Session = preload("res://scripts/network/session.gd")
var count := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func run() -> void:
	for hp in range(1,21):
		check(Career.stars_for("won", hp) == (3 if hp >= 18 else (2 if hp >= 10 else 1)), "rating HP " + str(hp))
	for phase in ["prepare", "battle", "lost"]:
		check(Career.stars_for(phase, 20) == 0, "no stars without victory " + phase)
	check(Career.stars_for("won", 0) == 0 and Career.stars_for("won", 99) == 3, "invalid health and star cap")
	var career = Career.new()
	career.path = ProjectSettings.globalize_path("res://../.work/tests/rating-progress.json")
	# Migration fixture deliberately models the previous version's save.
	var file := FileAccess.open(career.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"heroes":{"p1:ranger":{"xp":360,"skill_level":3}}}))
	file.close()
	career.read()
	check(career.profile("p1","ranger").xp == 360 and career.stage_stars.is_empty(), "old hero-only save migration")
	check(career.record_stage("moonbrook","won",1) == 1 and career.stage_stars.moonbrook == 1, "clear earns at least one star")
	career.record_stage("moonbrook","won",10)
	career.record_stage("moonbrook","won",18)
	career.record_stage("moonbrook","won",1)
	career.record_stage("moonbrook","lost",0)
	check(career.stage_stars.moonbrook == 3, "lower result and failure cannot roll back best")
	check(career.write() == OK, "atomic combined progress save")
	var loaded = Career.new()
	loaded.path = career.path
	loaded.read()
	check(loaded.stage_stars.moonbrook == 3 and loaded.profile("p1","ranger").xp == 360, "reload preserves stars and heroes")
	var session = Session.new()
	session.persist_progress = false
	root.add_child(session)
	session.career = loaded
	session.practice("frost_pass","ranger","stormcaller",true)
	session.set_physics_process(false)
	session.match_model.state.phase = "won"
	session.match_model.state.hp = 10
	session.persist_progress = true
	session.persist_now()
	check(session.career.stage_stars.frost_pass == 2 and session.career.profile("p1","ranger").xp == 360, "challenge saves stars without overwriting XP")
	session.leave()
	session.queue_free()
	await process_frame
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	game._start_practice()
	game.session.set_physics_process(false)
	var m = game.session.match_model
	# Exercise the real final-wave victory transition, without a full playthrough.
	m.state.phase = "battle"
	m.state.wave = 10
	m.state.hp = 9
	m.state.spawn_index = m.cfg.waves[9].events.size()
	m.step(0.05)
	check(m.state.phase == "won", "real final wave completes victory")
	game._process(0.01)
	var deadline: float = game.victory_return_at
	check(game.victory_panel.visible and game.victory_grade.text == "★☆☆", "one-star result displayed")
	check(game.session.career.stage_stars.confluence_courtyard == 1, "rating recorded before return")
	game._process(0.5)
	check(game.victory_return_at == deadline, "repeated victory frames do not reset countdown")
	game._process(2.51)
	check(game.menu.visible and not game.game_ui.visible and game.session.mode == "menu", "automatic return after three seconds")
	check(not game.victory_panel.visible and game.victory_return_at == 0 and game.campaign.stage_stars.confluence_courtyard == 1, "return clears timer and refreshes campaign")
	check(game.mission_info.text.contains("★☆☆"), "stage details show best stars")
	game._start_practice()
	game.session.set_physics_process(false)
	check(game.victory_epoch == -1 and game.victory_return_at == 0, "new match has no stale result timer")
	game.session.match_model.state.phase = "lost"
	game._process(4)
	check(game.game_ui.visible and not game.victory_panel.visible and game.session.career.stage_stars.confluence_courtyard == 1, "failure has no rating or automatic victory return")
	game.session.match_model.state.phase = "won"
	game.session.match_model.state.hp = 20
	game._process(0.01)
	check(game.victory_grade.text == "★★★", "three-star clear UI")
	game._return_menu()
	game._start_practice()
	game.session.set_physics_process(false)
	game._process(4)
	check(game.game_ui.visible and not game.menu.visible, "manual exit cancels previous countdown")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(career.path)
	print("RATING_TESTS ", count-failures.size(), "/", count, " passed")
	quit(0 if failures.is_empty() else 1)

extends SceneTree

const Career = preload("res://scripts/core/career.gd")
var game: Node
var role := "host"
var started := 0.0
var injected := false
var saw_result := false
var finishing := false
var save_path := ""

func _initialize() -> void:
	role = "client" if "--client" in OS.get_cmdline_user_args() else "host"
	call_deferred("run")

func run() -> void:
	started = Time.get_ticks_msec()/1000.0
	game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	game.combat_audio.enabled = false
	save_path = ProjectSettings.globalize_path("res://../.work/tests/rating-network-" + role + ".json")
	DirAccess.remove_absolute(save_path)
	game.session.career.path = save_path
	game.session.persist_progress = true
	if role == "host":
		if game.session.host("commander",25983,"moonbrook",{},true) != OK: quit(1)
	else:
		if game.session.join("127.0.0.1","stormcaller",25983) != OK: quit(1)

func _process(_delta: float) -> bool:
	if game == null or finishing: return false
	if Time.get_ticks_msec()/1000.0 - started > 16:
		printerr("RATING_NETWORK_TIMEOUT ",role)
		quit(1)
		return false
	var session = game.session
	var s: Dictionary = session.match_model.state
	if role == "host" and session.authenticated and game.game_ui.visible and not injected:
		# Final-wave fixture forces an odd terminal tick: the regular even-tick
		# snapshot cannot deliver it, so the reliable result RPC must do so.
		s.phase = "battle"
		s.wave = 10
		s.hp = 10
		s.spawn_index = session.match_model.cfg.waves[9].events.size()
		s.tick = 100
		session.match_model.step(0.05)
		injected = true
	if game.victory_panel.visible:
		if game.victory_grade.text != "★★☆" or s.hp != 10 or s.level_id != "moonbrook":
			printerr("RATING_NETWORK_WRONG_RESULT ",role)
			quit(1)
		saw_result = true
	if saw_result and game.menu.visible and session.mode == "menu":
		var loaded = Career.new()
		loaded.path = save_path
		loaded.read()
		if loaded.stage_stars.get("moonbrook",0) != 2 or not loaded.records.is_empty() or session.auto_retry_end != 0:
			printerr("RATING_NETWORK_SAVE_OR_RETURN_FAILED ",role)
			quit(1)
			return false
		finishing = true
		call_deferred("finish")
	return false

func finish() -> void:
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("RATING_NETWORK_",role.to_upper(),"_PASS reliable final result, two-star save and automatic lobby return")
	quit(0)

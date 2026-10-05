extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
const Preferences = preload("res://scripts/core/preferences.gd")
var count := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = Match.new()
	m.configure("skywatch", {"p1": "ranger", "p2": "sentinel"}, {"p1": {"xp": 1400, "skill_level": 3}}, true)
	check(m.state.heroes.p1.level == 4 and m.state.heroes.p2.level == 4, "challenge normalizes both unequal profiles")
	m._gain_xp(m.state.heroes.p1, 1000)
	check(m.state.heroes.p1.xp == 360, "challenge level remains fixed after kills")
	check(m.hero_profiles.p1.xp == 1400, "challenge leaves original growth profile intact")
	m.set_hero("p2", "stormcaller", {"xp": 1400, "skill_level": 3})
	check(m.state.heroes.p2.level == 4 and m.state.heroes.p2.skill_level == 3, "joining hero also normalized")
	var remote = Match.new()
	remote.apply_snapshot(m.snapshot())
	check(remote.challenge and remote.cfg.level_id == "skywatch", "challenge state and new stage survive snapshot")
	remote.state.phase = "won"
	remote.command("p1", "restart", {}, "restart")
	check(remote.state.challenge and remote.state.heroes.p1.level == 4, "challenge restart remains normalized")
	check(m.command("p2", "ping", {"pos": Vector2(24, 4), "label": "防空"}, "ping").accepted, "valid tactical marker accepted")
	check(not m.command("p2", "ping", {"pos": Vector2(24, 4), "label": "防空"}, "spam").accepted, "markers rate limited")
	check(not m.command("p1", "ping", {"pos": Vector2(NAN, 4)}, "nan").accepted, "nonfinite marker rejected")
	remote.apply_snapshot(m.snapshot())
	check(remote.state.pings[0].label == "防空" and remote.state.team_feed[0].text.contains("P2"), "marker owner and cooperation feed synchronized")
	m.state.time = 3
	m.command("p2", "ping", {"pos": Vector2(20, 4), "label": "补位"}, "replace")
	check(m.state.pings.size() == 1 and m.state.pings[0].label == "补位", "each player replaces own marker")
	m.configure("confluence_courtyard", {"p1": "commander", "p2": "skirmisher"})
	check(m.wave_intel().contains("A 6 / B 6") and m.wave_intel().contains("步兵"), "wave preview counts configured entries")
	m.state.wave = 4
	check(not m.wave_intel().is_empty(), "later wave preview derives actual roster")
	m.command("p1", "build", {"node": "p1_03", "tower": "barracks"}, "build")
	check(not m.command("p2", "rally", {"node": "p1_03", "pos": Vector2(13,12)}, "other").accepted, "teammate cannot move rally")
	check(not m.command("p1", "rally", {"node": "p1_03", "pos": Vector2(30,20)}, "far").accepted, "distant rally rejected")
	var target := m._rally_position(Vector2(13,12))
	check(m.command("p1", "rally", {"node": "p1_03", "pos": target}, "rally").accepted, "own nearby road rally accepted")
	var before: Vector2 = m.state.soldiers[0].pos
	m._soldiers(0.05)
	check(m.state.soldiers[0].pos.distance_to(target) < before.distance_to(target), "soldiers walk towards new rally")
	m.command("p1", "transfer", {"amount": 50}, "aid")
	m.command("p1", "transfer", {"amount": 50}, "aid")
	check(m.state.cooperation.p1.aid == 45, "duplicate aid counted once")
	m.state.wave = 5
	var eid: int = m.spawn("flyer", "a")
	m.state.enemies[eid].s = m.cfg.route_length("air_a")
	m._resolve_deaths()
	check(m.debrief().contains("第5波 飞行兵 / P2") and m.state.notice.contains("防空"), "failure report includes wave type exit and counter")
	m.state.heroes.p2.hp = 0
	m.state.heroes.p2.revive_at = 100
	m.state.heroes.p1.pos = m.state.heroes.p2.pos
	m.state.heroes.p1.target = m.state.heroes.p1.pos
	m.state.heroes.p1.rescue = 100
	for i in range(61): m._move_heroes(0.05)
	check(m.state.cooperation.p1.rescues == 1 and m.state.heroes.p2.hp > 0, "completed rescue counted once")
	var prefs = Preferences.new()
	prefs.path = ProjectSettings.globalize_path("res://../.work/tests/preferences_test.json")
	check(prefs.bind("skill", KEY_R) and prefs.keys.ultimate == KEY_Q, "duplicate key swaps existing action")
	check(not prefs.bind("skill", KEY_ESCAPE), "escape remains reserved")
	prefs.volume = 0
	prefs.numbers = false
	check(prefs.write() == OK, "preferences writes isolated save")
	var loaded = Preferences.new()
	loaded.path = prefs.path
	loaded.read()
	check(loaded.volume == 0 and not loaded.numbers and loaded.keys.skill == KEY_R, "preferences reload volume display and keys")
	DirAccess.remove_absolute(prefs.path)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	game.persist_progress = false
	root.add_child(game)
	game._select_level("rift_citadel")
	game.mode_choice.select(1)
	game._start_practice()
	game.session.set_physics_process(false)
	game._process(0.05)
	check(game.session.match_model.state.challenge and game.wave_info.text.contains("下一波"), "UI launches challenge and displays wave intel")
	game.preferences.bind("skill", KEY_E)
	game.preferences.shake = false
	game.preferences.numbers = false
	game._apply_preferences()
	game._process(0.05)
	check(game.skill_buttons[0].text.begins_with("E ") and not game.field.shake_enabled and not game.field.damage_numbers, "HUD and rendering follow settings")
	game.settings_panel.show()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_SPACE
	game._unhandled_input(key)
	check(game.session.match_model.state.phase == "prepare", "open settings blocks gameplay shortcuts")
	game._close_settings()
	check(not game.settings_panel.visible, "settings closes in nonpersisting tests")
	await process_frame
	await process_frame
	check(game.settings_panel.size.y <= 570, "settings content fits viewport")
	check(game.start_button.get_global_rect().end.y <= 690, "ready button remains visible below scrolling tower controls")
	game.queue_free()
	await process_frame
	print("IMPROVEMENTS_TESTS ", count - failed, "/", count, " passed")
	quit(0 if failed == 0 else 1)

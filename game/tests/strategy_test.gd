extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
const Session = preload("res://scripts/network/session.gd")
var count := 0
var failures: Array[String] = []
var serial := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, name: String) -> void:
	count += 1
	if not ok:
		failures.append(name)
		printerr("FAIL ", name)

func command(m, owner: String, kind: String, data := {}) -> Dictionary:
	serial += 1
	return m.command(owner, kind, data, "strategy-" + str(serial))

func fresh():
	var m = Match.new()
	m.state.gold = {"p1": 40000, "p2": 40000}
	return m

func run() -> void:
	var m = fresh()
	check(m.cfg.towers.size() == 8 and m.cfg.enemies.size() == 11, "eight towers and eleven enemy types")
	check(m.cfg.tower_rules.base_towers.size() == 4, "four fixed base towers")
	for kind in m.cfg.towers:
		var base: String = kind
		for family in m.cfg.tower_rules.upgrade_routes:
			if kind in m.cfg.tower_rules.upgrade_routes[family]: base = family
		for option in m.cfg.towers[kind].branches:
			m = fresh()
			var initial_gold: int = m.state.gold.p1
			if kind not in m.cfg.tower_rules.base_towers:
				check(not command(m, "p1", "build", {"node": "shared_01", "tower": kind}).accepted and m.state.gold.p1 == initial_gold, "advanced tower cannot be built directly")
			check(command(m, "p1", "build", {"node": "shared_01", "tower": base}).accepted, base + " base build")
			var before: int = m.state.gold.p1
			check(not command(m, "p2", "upgrade", {"node": "shared_01"}).accepted and m.state.gold.p1 == before, "partner cannot upgrade or spend owner gold")
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted, "branch cannot skip base upgrades")
			command(m, "p1", "upgrade", {"node": "shared_01"})
			m.state.time = 3
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted, "level two cannot unlock branch")
			check(not command(m, "p1", "upgrade", {"node": "shared_01", "branch": option.id}).accepted, "upgrade does not pick a branch before level three")
			command(m, "p1", "upgrade", {"node": "shared_01"})
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted, "must finish level-three construction")
			m.state.time = 6
			before = m.state.gold.p1
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": "forged"}).accepted and m.state.gold.p1 == before, "invalid branch cannot spend gold")
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": "cannon" if base != "cannon" else "frost", "branch": "siege" if base != "cannon" else "deep"}).accepted, "cannot cross tower families")
			check(not command(m, "p2", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted, "partner cannot choose route")
			var price: int = m.branch_cost(m.state.towers.shared_01, kind)
			m.state.gold.p1 = price * 4 - 1 if price > 0 else before
			if price > 0: check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted and m.state.towers.shared_01.id == base, "unaffordable conversion is atomic")
			m.state.gold.p1 = before
			check(command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted and m.state.towers.shared_01.id == kind and m.state.towers.shared_01.branch == option.id and m.state.gold.p1 == before - price * 4, kind + " " + option.id + " transforms and spends exact price")
			m.state.time = 9
			check(not command(m, "p1", "specialize", {"node": "shared_01", "tower": kind, "branch": option.id}).accepted, "branch is a committed choice")
			var copy = Match.new()
			copy.apply_snapshot(m.snapshot())
			check(copy.state.towers.shared_01.id == kind and copy.state.towers.shared_01.base_id == base and copy.state.towers.shared_01.branch == option.id and copy.tower_mods(copy.state.towers.shared_01) == m.tower_mods(m.state.towers.shared_01), "route and behavior survive snapshot")
			if kind == "barracks": check(m.state.soldiers[0].max_hp > 160 if option.id == "guard" else m.state.soldiers[0].max_hp < 160, "barracks branch changes actual soldier health")
			if kind == "beacon": check(m.state.soldiers.is_empty(), "beacon conversion removes barracks soldiers")
			var refund: int = int(floor(m.state.towers.shared_01.spent * 0.7)) * 4
			before = m.state.gold.p1
			command(m, "p1", "sell", {"node": "shared_01"})
			check(not m.state.towers.has("shared_01") and m.state.soldiers.is_empty() and m.state.gold.p1 == before + refund, "sale includes conversion investment")
	m = fresh()
	command(m, "p1", "build", {"node": "shared_01", "tower": "archer"})
	m.state.towers.shared_01.id = "ballista"
	m.state.soldiers.clear() # Isolated combat fixture, not a purchase/economy result.
	m.spawn("heavy", "a")
	var heavy: Dictionary = m.state.enemies.values()[0]
	heavy.pos = m.state.towers.shared_01.pos + Vector2(1, 0)
	m._towers()
	m._projectiles(1)
	check(is_equal_approx(heavy.max_hp - heavy.hp, 62 * 0.75), "ballista physically penetrates armor")
	m = fresh()
	command(m, "p1", "build", {"node": "shared_01", "tower": "frost"})
	m.state.towers.shared_01.id = "storm"
	m.state.soldiers.clear() # Isolated combat fixture, not a purchase/economy result.
	for i in range(4):
		m.spawn("infantry", "a")
		m.state.enemies.values()[i].pos = m.state.towers.shared_01.pos + Vector2(1 + i * 0.3, 0)
	m._towers()
	m._projectiles(1)
	var hurt := 0
	for enemy in m.state.enemies.values():
		if enemy.hp < enemy.max_hp: hurt += 1
	check(hurt == 3, "storm tower chains to three distinct enemies")
	m = fresh()
	command(m, "p1", "build", {"node": "shared_01", "tower": "barracks"})
	m.state.towers.shared_01.id = "beacon"
	m.state.soldiers.clear() # Isolated combat fixture, not a purchase/economy result.
	m.state.heroes.p1.pos = m.state.towers.shared_01.pos
	m.state.heroes.p1.hp = 100
	m._support_towers(1)
	check(m.state.heroes.p1.hp == 108, "beacon heals alive allies")
	m.state.heroes.p1.hp = 0
	m._support_towers(1)
	check(m.state.heroes.p1.hp == 0, "support cannot revive a fallen hero")
	command(m, "p2", "build", {"node": "shared_02", "tower": "archer"})
	m.state.towers.shared_02.pos = m.state.towers.shared_01.pos
	check(m._beacon_aura(m.state.towers.shared_02) == 1.15, "beacon buffs a nearby partner tower")
	check(m._beacon_aura(m.state.towers.shared_01) == 1.0, "beacon aura requires a different owner")
	m.spawn("warden", "a")
	var warden: Dictionary = m.state.enemies.values()[0]
	var hp: float = warden.hp
	m._damage(warden, 100, "true", "p1", false)
	check(warden.shield == 0 and warden.hp == hp - 20, "warden shield absorbs actual damage")
	m.spawn("mender", "a")
	var healer: Dictionary = m.state.enemies.values()[1]
	healer.pos = warden.pos
	m._enemy_support(1)
	check(warden.hp == hp - 2, "healer restores nearby enemies")
	m.spawn("flyer", "a")
	var flyer: Dictionary = m.state.enemies.values()[2]
	flyer.pos = warden.pos
	check(m._pick(warden.pos, 3, ["ground", "air"], "air").id == flyer.id, "air priority picks flyers with ground fallback")
	check(m._pick(warden.pos, 3, ["ground", "air"], "armor").id == warden.id, "armor priority picks armored enemies")
	for stage in m.cfg.levels:
		m.configure(stage, {"p1": "commander", "p2": "skirmisher"})
		var event_spec: Dictionary = m.cfg.levels[stage].event
		m.state.phase = "battle"
		m.state.wave = event_spec.waves[0]
		m.state.time = event_spec.delay
		m._stage_events(0.05)
		var event: Dictionary = m.state.stage_event
		check(event.active_at > m.state.time and not m._event_active(event.kind), stage + " warns before hazard")
		m.state.heroes.p1.pos = event.beacons[0]
		m.state.heroes.p2.pos = event.beacons[0]
		m._stage_events(3)
		check(not event.solved, "same beacon cannot satisfy both players")
		m.state.heroes.p2.pos = event.beacons[1]
		m._stage_events(1)
		m.state.heroes.p2.pos = Vector2(31, 23)
		m._stage_events(0.1)
		check(event.progress == 0, "leaving beacon resets capture progress")
		m.state.heroes.p2.pos = event.beacons[1]
		m._stage_events(3)
		check(event.solved and m.state.event_wins == 1 and m.state.resonance == 25, stage + " distinct heroes solve event and earn resonance")
		m._stage_events(3)
		check(m.state.event_wins == 1, "event reward is not repeatable")
	# Check event effects separately from optional cooperative cancellation.
	for stage in ["frost_pass", "ember_ruins", "thornwood", "skywatch", "rift_citadel"]:
		m.configure(stage, {"p1": "commander", "p2": "skirmisher"})
		m.state.phase = "battle"
		m.state.wave = 4
		m.state.time = 8
		m._stage_events(0)
		var event: Dictionary = m.state.stage_event
		m.state.time = event.active_at
		m.state.heroes.p1.pos = event.hazard
		var old_hp: float = m.state.heroes.p1.hp
		m._stage_events(1)
		if stage == "frost_pass": check(m._terrain_factor(event.hazard, "tower") < 1, "snow changes tower firing rate")
		if stage == "ember_ruins": check(m.state.heroes.p1.hp < old_hp, "ember inflicts actual hero damage")
		if stage == "thornwood": check(m._terrain_factor(event.hazard, "hero") < 1, "thorns slow actual hero movement")
		if stage == "skywatch": check(m._event_active("wind"), "wind activates air speed modifier")
		if stage == "rift_citadel":
			check(m.state.enemies.size() == 2, "rift summons first pair of wardens")
			m.state.time += 8
			m._stage_events(0)
			check(m.state.enemies.size() == 4, "unsolved rift summons second pair")
	for stage in ["moonbrook", "sunken_temple", "glacier_keep", "eclipse_gate"]:
		m.configure(stage, {"p1": "commander", "p2": "skirmisher"})
		m.state.phase = "battle"
		m.state.wave = 4
		m.state.time = 8
		m._stage_events(0)
		var event: Dictionary = m.state.stage_event
		m.state.time = event.active_at
		if stage == "moonbrook":
			m.spawn("infantry", "a")
			var enemy: Dictionary = m.state.enemies.values()[0]
			m._move_enemies(1)
			check(is_equal_approx(enemy.s, 1.25), "moon tide changes actual ground enemy speed")
		if stage == "sunken_temple":
			check(m._terrain_factor(event.hazard,"tower") == 0.7 and m._terrain_factor(event.hazard,"soldier") == 0.6, "quicksand affects towers and rally travel")
		if stage == "glacier_keep":
			m.spawn("heavy","a")
			var enemy: Dictionary = m.state.enemies.values()[0]
			enemy.pos = event.hazard
			m._stage_events(0)
			check(enemy.shield == 40, "crystal pulse grants a shield to a real nearby enemy")
			m.state.time += 6
			m._stage_events(0)
			check(enemy.shield == 80, "crystal pulse repeats with an eighty-point cap")
		if stage == "eclipse_gate":
			m.state.heroes.p1.pos = event.hazard
			var before: float = m.state.heroes.p1.hp
			m._stage_events(0)
			check(m.state.heroes.p1.hp == before - 24, "starfall damages heroes on its periodic pulse")
			m._stage_events(0)
			check(m.state.heroes.p1.hp == before - 24, "starfall cannot pulse repeatedly in the same tick")
		event.solved = true
		check(not m._event_active(event.kind), "cooperative cancellation disables the extension hazard")
	m = fresh()
	check(command(m, "p1", "hero_talent", {"talent": "assault"}).accepted, "hero talent is selectable in preparation")
	var h: Dictionary = m.state.heroes.p1
	check(is_equal_approx(m.cfg.HeroRules.skill_damage(h), 150 * 1.25), "assault changes actual skill damage")
	m.state.phase = "battle"
	check(not command(m, "p1", "hero_talent", {"talent": "support"}).accepted, "talent cannot change mid battle")
	m.state.heroes.p1.pos = Vector2(16,12)
	m.state.heroes.p2.pos = Vector2(16,12)
	m.spawn("heavy", "a")
	var target: Dictionary = m.state.enemies.values()[0]
	target.pos = Vector2(16,12)
	target.hp = 2000
	target.max_hp = 2000
	command(m,"p1","skill",{"key":"q","pos":target.pos})
	m.state.time = 0.5
	m._resolve_casts()
	check(target.relay_owner == "p1" and target.relay_end > m.state.time, "manual skill opens a visible four-second relay window")
	command(m,"p2","skill",{"key":"q","pos":target.pos})
	m.state.time = 0.8
	m._resolve_casts()
	check(m.state.active_relays == 1 and target.relay_end == 0, "other hero skill consumes relay for bonus damage")
	check(m.debrief().contains("主动技能接力 1"), "debrief reports active cooperation")
	for ip in ["127.0.0.1", "192.168.1.10", "10.0.0.2"]:
		var code: String = Session.room_code(ip, 25980)
		var endpoint: Dictionary = Session.parse_invite(code)
		check(endpoint.address == ip and endpoint.port == 25980, "room code round trip with nondefault port")
	check(Session.parse_invite("127.0.0.1:25980").port == 25980, "direct invitation supports custom port")
	check(Session.parse_invite("TG-ZZZZZZZZ-FFFF").is_empty() and Session.parse_invite("TG-7F000001-0000").is_empty() and Session.parse_invite("127.0.0.1:99999").is_empty(), "malformed invitation rejected before leaving session")
	await _check_ui()
	print("STRATEGY_TESTS ", count - failures.size(), "/", count, " passed")
	quit(0 if failures.is_empty() else 1)

func _check_ui() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.persist_progress = false
	root.add_child(game)
	check(game.mode_choice.selected == 1, "fair challenge is the default recommended mode")
	game._start_practice()
	game.session.set_physics_process(false)
	for node in game.session.match_model.cfg.nodes:
		game.selected = node
		game.tower_menu.refresh(true)
		await process_frame
		game.tower_menu.refresh()
		var rect := Rect2(game.tower_menu.position,game.tower_menu.size)
		var anchor: Vector2 = game.field.screen(game.session.match_model.cfg.vector(game.session.match_model.cfg.nodes[node].position))
		check(Rect2(23,110,955,580).encloses(rect), node + " menu stays in battlefield")
		check(not rect.grow(16).has_point(anchor), node + " menu leaves selected tower visible")
	check(game.build_buttons.size() == 4, "only four base towers appear at empty nodes")
	game.selected = "shared_01"
	game.tower_menu.refresh(true)
	game.tower_menu._show_detail("storm")
	await process_frame
	game.tower_menu.refresh()
	check(game.tower_menu.details.visible and game.tower_menu.details.text.contains("电弧扩散"), "details expand on demand with branch descriptions")
	check(Rect2(23,110,955,580).encloses(Rect2(game.tower_menu.position,game.tower_menu.size)), "expanded details remain inside map")
	var model = game.session.match_model
	model.state.gold.p1 = 0
	game.tower_menu.refresh()
	check(game.build_buttons.all(func(button): return button.disabled), "affordability refresh disables choices without rebuilding menu")
	model.state.gold.p1 = 1200
	game.tower_menu.refresh()
	check(game.build_buttons.all(func(button): return not button.disabled), "restored gold re-enables choices")
	game.pending_map_action = "rally"
	game.tower_menu.refresh()
	check(not game.tower_menu.visible, "rally placement hides menu for map targeting")
	game.pending_map_action = ""
	model.state.resonance = 100
	model.state.ultimate_request = {"owner": "p2", "expires": model.state.time + 3}
	game._process(0.05)
	check(game.ultimate_button.text.contains("响应") and not game.ultimate_button.disabled, "partner ultimate request has a fixed visible response button")
	var previous_skill: Button = game.skill_buttons[0]
	game._send("move", {"pos": Vector2(20,10)})
	game._process(0.05)
	check(game.skill_buttons[0] == previous_skill, "hero movement does not rebuild the fixed HUD")
	game.tower_menu.refresh(true)
	game.tower_menu._show_detail("ballista", false)
	game._process(0.05)
	check(game.field.preview_kind == "ballista", "hovering choices previews the actual tower range before purchase")
	var net = game.session
	net.leave(false)
	net.mode = "client"
	net.reconnect_token = "isolated-test-token"
	net.last_address = "127.0.0.1"
	net._begin_auto_retry()
	net.auto_retry_end = Time.get_ticks_msec() / 1000.0 - 1
	net._physics_process(0.05)
	check(net.auto_retry_exhausted and net.auto_retry_end == 0, "automatic retry expires after its bounded deadline")
	net._begin_auto_retry()
	check(net.auto_retry_end == 0, "connection failure cannot restart an exhausted retry loop")
	net.leave()
	game.pending_map_action = ""
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	game._unhandled_input(escape)
	check(game.selected.is_empty() and not game.tower_menu.visible, "Escape dismisses tower menu")
	game.queue_free()
	await process_frame

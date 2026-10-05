extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
var failures: Array[String] = []
var count := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, name: String) -> void:
	count += 1
	if not condition:
		failures.append(name)
		printerr("FAIL: " + name)

func fresh():
	var model = Match.new()
	model.state.wave = 1
	return model

func shot(model, enemy: Dictionary) -> void:
	model.state.projectiles.append({"start": enemy.pos, "pos": enemy.pos, "end": enemy.pos, "target": enemy.id, "owner": "p2", "damage": 40.0, "aura": 1.0, "travel": 0.0, "duration": 0.1})
	model._projectiles(0.1)

func run() -> void:
	var m = fresh()
	check(m.cfg.errors.is_empty(), "all configuration loads")
	check(m.cfg.nodes.size() == 16 and m.cfg.waves.size() == 10, "map and wave counts")
	var events := 0
	for wave in m.cfg.waves:
		events += wave.events.size()
	check(events == 206, "206 configured enemies")
	var result: Dictionary = m.command("p1", "build", {"node": "shared_01", "tower": "frost"}, "buy")
	check(result.accepted and m.state.gold.p1 == 720, "atomic purchase")
	m.command("p1", "build", {"node": "shared_01", "tower": "frost"}, "buy")
	check(m.state.gold.p1 == 720, "duplicate purchase is idempotent")
	result = m.command("p2", "build", {"node": "shared_01", "tower": "cannon"}, "buy")
	check(not result.accepted and m.state.gold.p2 == 1200, "losing shared-node request costs nothing")
	result = m.command("p1", "build", {"node": "p2_01", "tower": "archer"}, "invalid")
	check(not result.accepted, "ownership rejects hostile node")
	m.command("p1", "upgrade", {"node": "shared_01"}, "upgrade")
	check(m.state.towers.shared_01.level == 2 and m.state.gold.p1 == 336, "upgrade cost and level")
	result = m.command("p1", "sell", {"node": "shared_01"}, "sell_early")
	check(not result.accepted and m.state.towers.has("shared_01"), "cannot sell mid-upgrade")
	m.state.time = 3.0
	m.command("p1", "sell", {"node": "shared_01"}, "sell")
	check(not m.state.towers.has("shared_01") and m.state.gold.p1 == 940, "sell cumulative 70 percent")
	m = fresh()
	m.command("p1", "transfer", {"amount": 50}, "gift")
	m.command("p1", "transfer", {"amount": 50}, "gift")
	check(m.state.gold.p1 == 1000 and m.state.gold.p2 == 1380, "gift duplicate and fee")
	check(not m.command("p1", "transfer", {"amount": 50}, "gift2").accepted, "gift cooldown")
	m = fresh()
	var id: int = m.spawn("heavy", "a")
	var enemy: Dictionary = m.state.enemies[id]
	enemy.hp = 1000.0
	enemy.pos = Vector2(16, 12)
	enemy.frost_end = 3.0
	enemy.frost_owner = "p1"
	var other_id: int = m.spawn("heavy", "a")
	var other: Dictionary = m.state.enemies[other_id]
	other.hp = 1000.0
	other.pos = Vector2(16.5, 12)
	shot(m, enemy)
	check(is_equal_approx(enemy.hp, 880), "shatter replaces primary hit with true damage")
	check(is_equal_approx(other.hp, 924), "splash has physical and shatter components once")
	check(enemy.frost_end == 0 and m.state.stats.combos == 1, "shatter consumes frost")
	enemy.frost_end = 3.0
	shot(m, enemy)
	check(is_equal_approx(enemy.hp, 864), "shatter cooldown prevents repeated true hit")
	m = fresh()
	id = m.spawn("infantry", "a")
	enemy = m.state.enemies[id]
	enemy.hp = 0.0
	enemy.contrib = {"p1": 0.0, "p2": 0.0}
	m._resolve_deaths()
	m._resolve_deaths()
	check(m.state.gold.p1 == 1215 and m.state.gold.p2 == 1215, "synergy fractional bounty and death dedupe")
	m = fresh()
	id = m.spawn("infantry", "a")
	enemy = m.state.enemies[id]
	enemy.hp = 100.0
	enemy.pos = Vector2(16, 12)
	m.state.zones = [{"kind": "fire", "owner": "p1", "dps": 40.0, "pos": enemy.pos, "radius": 2.0, "end": 4.0}, {"kind": "fire", "owner": "p2", "dps": 60.0, "pos": enemy.pos, "radius": 2.0, "end": 4.0}]
	m._zones(0.05)
	m._zones(0.05)
	check(is_equal_approx(enemy.hp, 70.0), "overlapping fires take strongest DPS only")
	m = fresh()
	m.command("p1", "gate", {"id": "gate_a"}, "gate")
	check(m.state.gold.p1 == 1200, "gate pending never deducts money")
	m.command("p2", "gate_reply", {"accept": true}, "agree")
	check(m.state.gold.p1 == 1000, "confirmed gate deducts once")
	id = m.spawn("infantry", "a")
	other_id = m.spawn("infantry", "a")
	m.state.enemies[other_id].s = 7.0
	var air_id: int = m.spawn("flyer", "a")
	m._move_enemies(0.05)
	check(m.state.enemies[id].route == "a_diverted", "pre-gate ground unit diverted")
	check(m.state.enemies[other_id].route == "a_default", "passed gate unit unchanged")
	check(m.state.enemies[air_id].route == "air_a", "flying unit ignores gate")
	m.state.time = 11.0
	m._move_enemies(0.05)
	check(m.state.enemies[id].route == "a_diverted", "closing gate preserves bound route")
	m = fresh()
	m.state.resonance = 100
	m.command("p1", "ultimate", {}, "r1")
	check(m.state.resonance == 100, "ultimate pending preserves meter")
	m.command("p2", "ultimate", {}, "r2")
	check(m.state.resonance == 0 and m.state.ultimate_end == 5, "two-person ultimate spends once")
	m = fresh()
	id = m.spawn("infantry", "a")
	m.state.enemies[id].s = 100.0
	m.state.enemies[id].hp = 0.0
	m._resolve_deaths()
	check(m.state.hp == 20, "last moment death is not a leak")
	m = fresh()
	m.state.phase = "battle"
	m.state.wave = 10
	m.state.spawn_index = m.cfg.waves[9].events.size()
	m.state.hp = 1
	id = m.spawn("infantry", "a")
	m.state.enemies[id].s = 100.0
	m.step(0.05)
	check(m.state.phase == "lost", "zero HP precedes final-wave victory")
	m.command("p1", "restart", {}, "restart")
	check(m.state.phase == "prepare" and m.state.hp == 20 and m.state.gold.p1 == 1200 and m.state.epoch == 2, "restart resets state and advances epoch")
	# Exercise every scheduled enemy, inter-wave transition and final victory.
	m = Match.new()
	for wave_no in range(1, 11):
		m.command("p1", "ready", {}, "ready1_" + str(wave_no))
		m.command("p2", "ready", {}, "ready2_" + str(wave_no))
		for tick in range(2200):
			for target in m.state.enemies.values():
				target.hp = 0.0
			m.step(0.05)
			if m.state.phase != "battle":
				break
	check(m.state.phase == "won" and m.state.stats.kills == 206, "all ten waves spawn and victory completes")
	# Meaningful stress: active combat with all four base types and 200 simultaneous units.
	m = fresh()
	for player in ["p1", "p2"]:
		m.state.gold[player] = 100000
	var kinds := ["archer", "frost", "cannon", "barracks", "cannon"]
	var index := 0
	for node in m.cfg.nodes.values():
		m.command("p2" if node.owner == "p2" else "p1", "build", {"node": node.id, "tower": kinds[index % 5]}, str(index))
		index += 1
	for i in range(200):
		id = m.spawn("heavy" if i % 2 == 0 else "infantry", "a" if i % 2 == 0 else "b")
		m.state.enemies[id].s = (i % 25) * 1.0
		m.state.enemies[id].pos = m.cfg.route_position(m.state.enemies[id].route, m.state.enemies[id].s)
	m.state.phase = "battle"
	m.state.spawn_index = m.cfg.waves[0].events.size()
	var started := Time.get_ticks_usec()
	for i in range(400):
		m.step(0.05)
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	check(m.state.tick == 400, "200-unit stress simulation survives 400 steps")
	print("STRESS total_ms=", ms, " average_step_ms=", ms / 400.0)
	print("CORE_TESTS ", count - failures.size(), "/", count, " passed")
	quit(0 if failures.is_empty() else 1)

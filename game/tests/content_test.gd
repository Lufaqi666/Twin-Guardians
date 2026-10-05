extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
const Rules = preload("res://scripts/core/hero_rules.gd")
var count := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func run() -> void:
	var model = Match.new()
	check(model.cfg.levels.size() == 10 and model.cfg.heroes.size() == 6, "ten levels and six heroes")
	var base_hash: String = model.cfg.config_hash
	for id in model.cfg.levels:
		model.configure(id, {"p1": "sentinel", "p2": "stormcaller"}, {"p1": {"xp": 560, "skill_level": 3}, "p2": {"xp": 200, "skill_level": 2}})
		check(model.state.level_id == id and model.cfg.map.id == id, id + " selects actual map")
		check(model.cfg.config_hash == base_hash, "campaign hash independent of current selection")
		check(model.cfg.nodes.size() == 16 and model.cfg.waves.size() == 10, id + " build nodes and waves")
		var content_valid := true
		for route_id in model.cfg.map.routes:
			var route: Array = model.cfg.map.routes[route_id]
			var previous_x := -1.0
			for point in route:
				content_valid = content_valid and point[0] > previous_x and point[0] >= 0 and point[0] < 32 and point[1] >= 0 and point[1] < 24
				previous_x = point[0]
			content_valid = content_valid and route.back() == model.cfg.map.exits[model.cfg.map.route_exits[route_id]]
		for wave in model.cfg.waves:
			var previous_time := -1.0
			for event in wave.events:
				content_valid = content_valid and model.cfg.enemies.has(event.enemy_id) and event.entry in ["a", "b"] and event.time >= previous_time
				previous_time = event.time
		check(content_valid, id + " all routes bounded and wave events ordered with valid references")
		for node in model.cfg.nodes.values():
			var distance := INF
			var pos: Vector2 = model.cfg.vector(node.position)
			for lane in ["a_default", "b_default"]:
				var points: Array = model.cfg.map.routes[lane]
				for i in range(points.size() - 1):
					var a: Vector2 = model.cfg.vector(points[i])
					var b: Vector2 = model.cfg.vector(points[i + 1])
					var nearest := a + (b - a) * clampf((pos - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
					distance = minf(distance, pos.distance_to(nearest))
			check(distance >= 0.75, id + " " + node.id + " does not sit on roadway")
		for lane in ["a", "b"]:
			var route: Array = model.cfg.map.routes[lane + "_default"]
			check(model.cfg.route_position(lane + "_default", 999) == model.cfg.vector(route.back()), "route reaches configured exit")
		var remote = Match.new()
		remote.apply_snapshot(model.snapshot())
		check(remote.cfg.level_id == id and remote.cfg.nodes.shared_01.position == model.cfg.nodes.shared_01.position, "snapshot selects geometry before rendering")
		check(remote.state.heroes.p2.skill.id == "thunderstorm" and remote.state.heroes.p2.level == 3, "fixed skill and growth survive snapshot")
		model.state.phase = "won"
		model.command("p1", "restart", {}, "restart")
		check(model.cfg.level_id == id and model.state.heroes.p1.kind == "sentinel" and model.state.heroes.p2.skill_level == 2, "restart retains stage roster and skill growth")
		# Resolve each wave through the production spawn / death path.
		var expected := 0
		for wave in model.cfg.waves:
			expected += wave.events.size()
		for wave in range(10):
			model.command("p1", "ready", {}, "p1-ready" + str(wave))
			model.command("p2", "ready", {}, "p2-ready" + str(wave))
			for tick in range(3000):
				model.step(0.05)
				for enemy in model.state.enemies.values():
					enemy.hp = 0
				if model.state.phase != "battle":
					break
		check(model.state.phase == "won" and model.state.stats.kills == model.state.spawned and model.state.spawned >= expected, id + " all scheduled waves and event reinforcements resolve before final victory")
	for kind in model.cfg.heroes:
		model.configure("confluence_courtyard", {"p1": kind, "p2": "commander"})
		var hero: Dictionary = model.state.heroes.p1
		hero.pos = Vector2(16, 12)
		hero.target = hero.pos
		model.spawn("infantry", "a")
		var enemy: Dictionary = model.state.enemies.values()[0]
		enemy.pos = hero.pos + Vector2(0.5, 0)
		enemy.hp = 1000
		enemy.max_hp = 1000
		var result: Dictionary = model.command("p1", "skill", {"key": "q", "pos": enemy.pos}, "cast")
		check(result.accepted and hero.q_at > model.state.time, kind + " fixed Q skill accepted with cooldown")
		check(enemy.hp == 1000 and not hero.cast.is_empty(), "windup precedes impact")
		model.state.time += 0.5
		model._resolve_casts()
		check(enemy.hp <= 865 and hero.cast.is_empty(), kind + " delivers a strong actual impact")
		check(not model.command("p1", "skill", {"key": "q", "pos": enemy.pos}, "recast").accepted, "cooldown rejects recast")
		check(not model.command("p1", "skill", {"key": "e", "pos": enemy.pos}, "second").accepted, "second active skill removed")
		model._gain_xp(hero, 200)
		var before: float = Rules.skill_damage(hero)
		check(model.command("p1", "hero_upgrade", {}, "upgrade").accepted and Rules.skill_damage(hero) > before, kind + " skill upgrade increases damage")
	print("CONTENT_TESTS ", count - failures.size(), "/", count, " passed")
	quit(0 if failures.is_empty() else 1)

extends SceneTree
const Match = preload("res://scripts/core/match_state.gd")
var m = Match.new()
var serial := 0
var profile := {}
var challenge := false
var formation := "classic"
var desired_towers := {}
var mechanism_orders := {}

func _initialize() -> void:
	call_deferred("run")

func order(owner: String, kind: String, payload: Dictionary) -> void:
	if kind == "build":
		var target: String = payload.tower
		desired_towers[payload.node] = target
		for base in m.cfg.tower_rules.upgrade_routes:
			if target in m.cfg.tower_rules.upgrade_routes[base]: payload.tower = base
	serial += 1
	m.command(owner, kind, payload, "bot-" + str(serial))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			m.configure(arg.trim_prefix("--level="), {"p1": "commander", "p2": "skirmisher"})
	for arg in OS.get_cmdline_user_args():
		if arg == "--max-level": profile = {"xp": 1400, "skill_level": 3}
		if arg == "--challenge": challenge = true
		if arg.begins_with("--formation="): formation = arg.trim_prefix("--formation=")
	m.configure(m.cfg.level_id, {"p1": "commander" if formation == "classic" else "ranger", "p2": "skirmisher" if formation == "classic" else "stormcaller"}, {"p1": profile, "p2": profile}, challenge)
	var air_stage: bool = m.cfg.level_id == "skywatch" or m.cfg.map.get("tactic", "") == "flank_air"
	var pair: Array = ["p1_02", "p2_02"] if air_stage else ["shared_01", "shared_02"]
	var center: Vector2 = (m.cfg.vector(m.cfg.map.routes.a_default[2]) + m.cfg.vector(m.cfg.map.routes.a_default[3])) / 2
	var secondary := "cannon" if formation == "classic" else ("ballista" if formation == "ranged" else "storm")
	for row in [["p1", "p1_01", "archer"], ["p1", pair[0], "frost"], ["p2", "p2_01", "archer"], ["p2", pair[1], "archer" if air_stage else secondary]]:
		order(row[0], "build", {"node": row[1], "tower": row[2]})
	var targets := {"p1": Vector2(16, 5) if air_stage else center, "p2": Vector2(16, 19) if air_stage else center + Vector2(-4, 0)}
	order("p1", "move", {"pos": targets.p1 + Vector2(-1, -1)})
	order("p2", "move", {"pos": targets.p2 + Vector2(0, 1)})
	for wave in range(1, 11):
		if m.state.phase in ["lost", "won"]:
			break
		for owner in ["p1", "p2"]:
			while m.state.heroes[owner].skill_points > 0:
				order(owner, "hero_upgrade", {})
		# Reserve conversion investment before expanding the formation.
		for node in m.state.towers:
			var current: Dictionary = m.state.towers[node]
			var desired: String = desired_towers.get(node, current.id)
			if desired in ["ballista", "storm"] and current.level < 3:
				order(current.owner, "upgrade", {"node": node})
			if current.level == 3 and current.branch.is_empty() and current.upgrade_end <= m.state.time:
				order(current.owner, "specialize", {"node": node, "tower": desired, "branch": m.cfg.towers[desired].branches[0].id})
		if air_stage and wave >= 2:
			for row in [["p1", "p1_05", "archer"], ["p2", "p2_05", "archer"]]:
				if not m.state.towers.has(row[1]): order(row[0], "build", {"node": row[1], "tower": row[2]})
		if wave >= 3:
			for node in pair:
				order(m.state.towers[node].owner, "upgrade", {"node": node})
		if formation != "classic":
			for owner in ["p1", "p2"]:
				order(owner, "hero_talent", {"talent": "assault" if owner == "p1" else "support"})
		if wave >= 4:
			for row in [["p1", "shared_03", "frost" if formation == "classic" else "beacon"], ["p2", "shared_04", secondary], ["p1", "p1_04", "archer"], ["p2", "p2_04", "archer"], ["p1", "p1_03", "barracks"], ["p2", "p2_03", "barracks"], ["p1", "p1_05", "archer"], ["p2", "p2_05", "archer"]]:
				if not m.state.towers.has(row[1]):
					order(row[0], "build", {"node": row[1], "tower": row[2]})
		if wave >= 6:
			for node in m.state.towers:
				if m.state.towers[node].id in ["archer", "frost"] or (formation != "classic" and m.state.towers[node].id in ["storm", "ballista", "barracks"]):
					order(m.state.towers[node].owner, "upgrade", {"node": node})
		for node in m.state.towers:
			var tower: Dictionary = m.state.towers[node]
			var target: String = desired_towers.get(node, tower.id)
			if target != tower.id and tower.level < 3: order(tower.owner, "upgrade", {"node": node})
			if tower.level == 3 and tower.branch.is_empty() and tower.upgrade_end <= m.state.time:
				order(tower.owner, "specialize", {"node": node, "tower": target, "branch": m.cfg.towers[target].branches[0].id})
		if formation=="skills" and wave>=5:
			for node in m.state.towers:
				var skilled:Dictionary=m.state.towers[node]
				if skilled.branch.is_empty() or skilled.upgrade_end>m.state.time:continue
				for ability in m.cfg.towers[skilled.id].skills:
					if skilled.get("skills",{}).get(ability.id,0)<1:order(skilled.owner,"tower_skill_upgrade",{"node":node,"skill":ability.id})
		order("p1", "ready", {})
		order("p2", "ready", {})
		var time_started: float = m.state.time
		for tick in range(5000):
			if formation=="skills" and tick%20==0:
				for node in m.state.towers:
					var skilled:Dictionary=m.state.towers[node]
					if skilled.id=="storm" and not skilled.branch.is_empty() and skilled.upgrade_end<=m.state.time and int(skilled.get("skills",{}).get("rod",0))==0 and wave>=5:
						order(skilled.owner,"tower_skill_upgrade",{"node":node,"skill":"rod"})
					for ability in m.cfg.towers[skilled.id].skills:
						if int(skilled.get("skills",{}).get(ability.id,0))>0:order(skilled.owner,"tower_skill",{"node":node,"skill":ability.id})
				var q:Dictionary=m.state.mechanism
				if q.kind=="escort" and q.get("cart_active",false) and not q.cart_done:
					order("p1","mechanism",{})
				elif q.kind in ["junction","lock"] and not mechanism_orders.has(wave):
					order("p1","move",{"pos":Vector2(16,12)})
					if m.state.heroes.p1.pos.distance_to(Vector2(16,12))<=3:
						var result:Dictionary=m.command("p1","mechanism",{},"mechanism-"+str(serial))
						serial+=1
						if result.accepted:mechanism_orders[wave]=true
			if tick % 100 == 0:
				if formation != "classic":
					var event: Dictionary = m.state.stage_event
					for index in range(2):
						var owner := "p1" if index == 0 else "p2"
						if not (formation=="skills" and owner=="p1" and m.state.mechanism.kind=="escort" and m.state.mechanism.get("cart_active",false) and not m.state.mechanism.cart_done):
							order(owner, "move", {"pos": event.beacons[index] if not event.is_empty() and not event.solved and event.end > m.state.time else targets[owner]})
				for owner in ["p1", "p2"]:
					var aim: Vector2 = targets[owner]
					if formation != "classic":
						var best := -INF
						for enemy in m.state.enemies.values():
							var distance: float = enemy.pos.distance_to(m.state.heroes[owner].pos)
							if enemy.hp <= 0 or distance > 7: continue
							var score: float = (100 if enemy.kind == "mender" else 0) + (50 if enemy.relay_end > m.state.time and enemy.relay_owner != owner else 0) - distance
							if score > best:
								best = score
								aim = enemy.pos
					order(owner, "skill", {"key": "q", "pos": aim})
			if m.state.resonance == 100:
				order("p1", "ultimate", {})
				order("p2", "ultimate", {})
			m.step(0.05)
			if m.state.phase != "battle":
				break
		print("WAVE ", wave, " hp=", m.state.hp, " phase=", m.state.phase, " seconds=", snapped(m.state.time - time_started, .1), " gold=", m.state.gold, " kills=", m.state.stats.kills, " towers=", m.state.towers.size())
	print("PLAYTHROUGH ", m.cfg.level_id, " ", m.state.phase, " hp=", m.state.hp, " combos=", m.state.stats.combos, " mode=", "challenge" if challenge else ("max" if not profile.is_empty() else "fresh"), " formation=", formation, " active_relays=", m.state.active_relays, " events_solved=", m.state.event_wins)
	var branch_towers: Array = m.state.towers.values().filter(func(t): return not t.branch.is_empty())
	var needed := "ballista" if formation == "ranged" else "storm"
	var used_route: bool = formation == "classic" or branch_towers.any(func(t): return t.id == needed)
	print("PROGRESSION_ROUTE ", m.cfg.level_id, " ", formation, " branched=", branch_towers.size(), " expected_route_used=", used_route)
	var used_skills:bool=formation!="skills" or int(m.state.advanced_stats.skills)>0
	print("ADVANCED_PLAY ",m.cfg.level_id," ",formation," skills=",m.state.advanced_stats.skills," escorts=",m.state.advanced_stats.escort_wins," seals=",m.state.advanced_stats.seal_breaks)
	quit(0 if m.state.phase == "won" and used_route and used_skills else 1)

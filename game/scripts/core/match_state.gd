extends RefCounted

const Catalog = preload("res://scripts/core/catalog.gd")
const Expansion = preload("res://scripts/core/strategy_expansion.gd")
var cfg = Catalog.new()
var state: Dictionary = {}
var random := RandomNumberGenerator.new()
var command_results: Dictionary = {}
var next_id := 1
var seed_value := 98761
var epoch := 0
var roster := {"p1": "commander", "p2": "skirmisher"}
var hero_profiles: Dictionary = {}
var challenge := false

func _init() -> void:
	reset()

func reset() -> void:
	epoch += 1
	random.seed = seed_value
	next_id = 1
	command_results.clear()
	state = {"time": 0.0, "tick": 0, "phase": "prepare", "wave": 0, "hp": 20, "gold": {"p1": 1200, "p2": 1200}, "towers": {}, "enemies": {}, "projectiles": [], "zones": [], "effects": [], "heroes": {}, "soldiers": [], "resonance": 0, "ultimate_end": 0.0, "ultimate_cd": 0.0, "ultimate_request": {}, "gate_request": {}, "gates": {}, "traps": {}, "spawn_index": 0, "wave_start": 0.0, "prepare_end": 60.0, "ready": {"p1": false, "p2": false}, "transfer_cd": {"p1": 0.0, "p2": 0.0}, "stats": {"kills": 0, "leaks": 0, "combos": 0, "synergies": 0}, "notice": "在入口部署弓箭塔，在中央搭配冰霜与火炮。", "paused": false}
	state.epoch = epoch
	state.level_id = cfg.level_id
	state.challenge = challenge
	state.pings = []
	state.ping_at = {"p1": 0.0, "p2": 0.0}
	state.team_feed = []
	state.cooperation = {"p1": {"combos": 0, "rescues": 0, "aid": 0}, "p2": {"combos": 0, "rescues": 0, "aid": 0}}
	state.leak_log = []
	state.effect_serial = 0
	state.stage_event = {}
	state.event_done = false
	state.event_wins = 0
	state.active_relays = 0
	state.tower_damage = {}
	state.build_history = []
	state.spawned = 0
	Expansion.initialize(self)
	for player in ["p1", "p2"]:
		var kind: String = roster[player]
		var spec: Dictionary = cfg.heroes[kind]
		var pos := cfg.vector(cfg.map.hero_spawns[player])
		state.heroes[player] = cfg.HeroRules.create(player, kind, spec, ({"xp": 360, "skill_level": 3} if challenge else hero_profiles.get(player, {})), pos)
	for gate in cfg.map.gates:
		state.gates[gate.id] = {"end": 0.0, "ready_at": 0.0}
	for trap in cfg.map.fire_traps:
		state.traps[trap.id] = {"ready_at": 0.0, "end": 0.0}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func apply_snapshot(value: Dictionary) -> void:
	cfg.select_level(value.get("level_id", "confluence_courtyard"))
	state = value
	challenge = bool(state.get("challenge", false))
	for owner in state.heroes:
		roster[owner] = state.heroes[owner].kind
		_remember_hero(state.heroes[owner])

func configure(level: String, choices: Dictionary, profiles: Dictionary = {}, fixed_challenge := false) -> void:
	challenge = fixed_challenge
	cfg.select_level(level)
	for owner in ["p1", "p2"]:
		if cfg.heroes.has(choices.get(owner, "")):
			roster[owner] = choices[owner]
		hero_profiles[owner] = cfg.HeroRules.normalize(profiles.get(owner, {}))
	reset()

func set_hero(owner: String, kind: String, profile: Dictionary = {}) -> void:
	if not cfg.heroes.has(kind):
		return
	roster[owner] = kind
	hero_profiles[owner] = cfg.HeroRules.normalize(profile)
	state.heroes[owner] = cfg.HeroRules.create(owner, kind, cfg.heroes[kind], ({"xp": 360, "skill_level": 3} if challenge else hero_profiles[owner]), cfg.vector(cfg.map.hero_spawns[owner]))

func _remember_hero(hero: Dictionary) -> void:
	if challenge:
		return
	hero_profiles[hero.owner] = {"xp": hero.xp, "skill_level": hero.skill_level}

func _team(text: String) -> void:
	state.team_feed.append({"text": text, "end": state.time + 5})
	if state.team_feed.size() > 4:
		state.team_feed.pop_front()

func wave_intel() -> String:
	if state.wave >= cfg.waves.size():
		return "战役已完成"
	var wave: Dictionary = cfg.waves[state.wave]
	var counts := {}
	var lanes := {"a": 0, "b": 0}
	for event in wave.events:
		counts[event.enemy_id] = int(counts.get(event.enemy_id, 0)) + 1
		lanes[event.entry] += 1
	var parts: Array[String] = []
	for kind in counts:
		parts.append("%s×%d" % [cfg.enemies[kind].name, counts[kind]])
	var tips: Array[String] = []
	if counts.has("flyer"): tips.append("补足对空火力")
	if counts.has("heavy"): tips.append("魔法处理重甲")
	if counts.has("assassin"): tips.append("阻挡疾行刺客")
	if counts.has("boss"): tips.append("保留共鸣应对巨像")
	if counts.has("warden"): tips.append("弩炮穿甲并优先破盾")
	if counts.has("mender"): tips.append("优先击杀治疗者")
	if counts.has("saboteur"):tips.append("拆塔者蓄力1.5秒：击杀或眩晕打断；雷柱可净化干扰")
	if counts.has("splitter"):tips.append("分裂怪死亡产生两个步兵，预留范围技能")
	if counts.has("rift_lord"):tips.append("双方3秒内交替命中破印，离开紫色震荡圈")
	var stage: Dictionary = cfg.levels[cfg.level_id].get("event", {})
	if stage.get("waves", []).any(func(wave): return int(wave) == state.wave + 1): tips.append(stage.name + "：" + stage.description)
	return "下一波 %d · A %d / B %d\n%s\n%s" % [state.wave + 1, lanes.a, lanes.b, " · ".join(parts), " / ".join(tips) if not tips.is_empty() else "入口部署火力，英雄支援交汇区"]

func debrief() -> String:
	var lines: Array[String] = ["协同击杀 %d · 元素连锁 %d" % [state.stats.synergies, state.stats.combos]]
	for owner in ["p1", "p2"]:
		var c: Dictionary = state.cooperation[owner]
		lines.append("%s 连锁参与 %d · 救援 %d · 援助 %dg" % [owner.to_upper(), c.combos, c.rescues, c.aid])
	var totals := {}
	for leak in state.leak_log:
		var key: String = "第%d波 %s / %s" % [leak.wave, cfg.enemies[leak.kind].name, leak.exit.replace("exit_", "").to_upper()]
		totals[key] = int(totals.get(key, 0)) + 1
	for key in totals:
		lines.append("%s 漏过 %d" % [key, totals[key]])
	if totals.is_empty(): lines.append("没有敌人突破出口")
	lines.append("主动技能接力 %d · 双信标协作 %d" % [state.active_relays, state.event_wins])
	lines.append("塔技能施放 %d · 护送完成 %d · 双人破印 %d"%[state.advanced_stats.skills,state.advanced_stats.escort_wins,state.advanced_stats.seal_breaks])
	var counters := {"flyer": "在突破出口前布置弓箭/弩炮，切换飞行优先", "assassin": "在出口前放兵营并调整集结点，英雄补位", "heavy": "增加魔法火力或贯甲弩炮", "warden": "用集中火力先破盾，再接技能爆发", "mender": "用英雄技能优先消灭治疗者", "boss": "保留共鸣，避开冲击并集中输出", "elite": "用兵营与灯塔稳住前排，再集中火力", "infantry": "增补范围火力与阻挡，检查闲置塔是否覆盖道路"}
	var explained := {}
	counters.merge({"saboteur":"眩晕打断干扰蓄力或用雷柱净化","splitter":"保留范围伤害清理分裂出的步兵","rift_lord":"双方交替命中破印，分散躲避震荡并清理召唤物"})
	for leak in state.leak_log:
		if explained.has(leak.kind): continue
		explained[leak.kind] = true
		lines.append("改进：%s — %s" % [cfg.enemies[leak.kind].name, counters[leak.kind]])
	var used := {}
	for item in state.build_history: used[item.tower] = true
	lines.append("本局使用 %d/%d 种塔，可尝试不同专精重战" % [used.size(), cfg.towers.size()])
	return "\n".join(lines)

func _notice(text: String) -> void:
	state.notice = text

func _effect(kind: String, pos: Vector2, owner := "", end := 0.7, extra: Dictionary = {}) -> void:
	state.effect_serial += 1
	var event := {"id": state.effect_serial, "kind": kind, "pos": pos, "owner": owner, "end": state.time + end, "start": state.time}
	event.merge(extra)
	state.effects.append(event)
	if state.effects.size() > 512:
		state.effects.pop_front()

func command(player: String, kind: String, payload: Dictionary, command_id: String) -> Dictionary:
	var cache_key := player + ":" + command_id
	if command_results.has(cache_key):
		return command_results[cache_key]
	var reason := _execute(player, kind, payload)
	var result := {"accepted": reason.is_empty(), "reason": reason, "id": command_id}
	command_results[cache_key] = result
	if not reason.is_empty():
		_notice(reason)
	return result

func _execute(player: String, kind: String, payload: Dictionary) -> String:
	if not player in ["p1", "p2"]:
		return "无效玩家"
	if kind == "restart":
		if state.phase not in ["won", "lost"]:
			return "战斗尚未结束"
		reset()
		return ""
	if state.paused or state.phase in ["won", "lost"]:
		return "当前对局已暂停或结束"
	if kind in ["tower_skill_upgrade", "tower_skill", "tower_control", "mechanism"]:
		return Expansion.command(self, player, kind, payload)
	var now: float = state.time
	match kind:
		"ping":
			var pos = payload.get("pos", Vector2.ZERO)
			var label := str(payload.get("label", "补位"))
			if not pos is Vector2 or not pos.is_finite() or pos.x < 1 or pos.x > 31 or pos.y < 1 or pos.y > 23 or label not in ["防空", "补位", "集火"]:
				return "无效战术标记"
			if state.ping_at[player] > now: return "标记冷却中"
			state.ping_at[player] = now + 2
			state.pings = state.pings.filter(func(item): return item.owner != player and item.end > now)
			state.pings.append({"owner": player, "pos": pos, "label": label, "end": now + 6})
			_team(player.to_upper() + " 请求" + label)
		"rally":
			var node_id := str(payload.get("node", ""))
			var pos = payload.get("pos", Vector2.ZERO)
			if not state.towers.has(node_id) or not Expansion.allowed(state.towers[node_id],player) or state.towers[node_id].id != "barracks":
				return "只能设置自己的兵营集结点"
			if not pos is Vector2 or not pos.is_finite(): return "无效集结位置"
			var tower: Dictionary = state.towers[node_id]
			var rally := _rally_position(pos)
			if rally.distance_to(tower.pos) > 5 or rally.distance_to(pos) > 1:
				return "集结点须位于兵营五格内的道路上"
			tower.rally = rally
			_notice("士兵正前往新的集结点")
		"build":
			var node_id := str(payload.get("node", ""))
			var tower_id := str(payload.get("tower", ""))
			if not cfg.nodes.has(node_id) or not cfg.towers.has(tower_id):
				return "无效建造节点或塔型"
			if tower_id not in cfg.tower_rules.base_towers:
				return "高级塔须由基础塔升至三级后选择分支"
			if cfg.nodes[node_id].owner not in [player, "shared"]:
				return "这是队友的专属节点"
			if state.towers.has(node_id):
				return "节点已被占用"
			if Expansion.node_locked(self,node_id): return "塔基被晶核封锁，先解封或等待恢复"
			var price := int(cfg.towers[tower_id].cost)
			if int(state.gold[player]) < price * 4:
				return "金币不足"
			state.gold[player] -= price * 4
			state.towers[node_id] = {"id": tower_id, "base_id": tower_id, "owner": player, "level": 1, "spent": price, "attack_at": now, "upgrade_end": 0.0, "strategy": "first", "pos": cfg.vector(cfg.nodes[node_id].position), "branch": ""}
			state.towers[node_id].rally = _rally_position(state.towers[node_id].pos)
			if tower_id == "barracks":
				for i in range(3):
					state.soldiers.append({"tower": node_id, "owner": player, "pos": _rally_position(state.towers[node_id].pos), "hp": 80.0, "max_hp": 80.0, "revive_at": 0.0, "attack_at": now, "target": -1})
			state.build_history.append({"wave": state.wave, "owner": player, "tower": tower_id, "node": node_id})
			_notice(player.to_upper() + " 建造了" + cfg.towers[tower_id].name)
		"upgrade", "specialize", "sell", "strategy":
			var node_id := str(payload.get("node", ""))
			if not state.towers.has(node_id) or not Expansion.allowed(state.towers[node_id],player) or (kind == "sell" and state.towers[node_id].owner != player):
				return "只能操作自己的塔"
			var tower: Dictionary = state.towers[node_id]
			if tower.upgrade_end > now:
				return "升级进行中"
			if kind == "sell":
				state.gold[player] += int(floor(tower.spent * 0.7)) * 4
				state.towers.erase(node_id)
				state.soldiers = state.soldiers.filter(func(s): return s.tower != node_id)
			elif kind == "strategy":
				var strategies := ["first", "strong", "air", "fast", "armor"]
				var choice := str(payload.get("strategy", strategies[(strategies.find(tower.strategy) + 1) % strategies.size()]))
				if choice not in strategies: return "无效索敌策略"
				tower.strategy = choice
			elif kind == "specialize":
				if tower.level != 3 or not tower.get("branch", "").is_empty(): return "只有未分支的三级塔可以选择路线"
				var target := str(payload.get("tower", tower.id))
				var base := str(tower.get("base_id", tower.id))
				if target not in cfg.tower_rules.upgrade_routes.get(base, []) or not _valid_branch(target, str(payload.get("branch", ""))): return "请选择本塔系有效分支"
				var price := branch_cost(tower, target)
				if int(state.gold[player]) < price * 4: return "金币不足"
				state.gold[player] -= price * 4
				tower.spent += price
				tower.id = target
				tower.branch = str(payload.branch)
				tower.upgrade_end = now + 2
				if target != "barracks": state.soldiers = state.soldiers.filter(func(s): return s.tower != node_id)
				_update_soldier_stats(node_id)
				_notice("已选择分支：" + cfg.towers[target].name)
			else:
				if tower.level >= 3:
					return "已达到最高等级"
				var price := int(ceil(float(cfg.towers[tower.id].cost) * float(cfg.tower_rules.upgrade_cost_ratio[tower.level - 1])))
				if int(state.gold[player]) < price * 4:
					return "金币不足"
				var branch := str(payload.get("branch", ""))
				if not branch.is_empty(): return "先升至三级，再选择分支路线"
				state.gold[player] -= price * 4
				tower.branch = branch
				tower.spent += price
				tower.level += 1
				tower.upgrade_end = now + 2
				_update_soldier_stats(node_id)
		"ready":
			if state.phase != "prepare":
				return "当前正在战斗"
			state.ready[player] = true
			if state.ready.p1 and state.ready.p2:
				_start_wave()
		"move":
			var pos = payload.get("pos", Vector2.ZERO)
			if not pos is Vector2 or not pos.is_finite():
				return "无效位置"
			state.heroes[player].target = Vector2(clampf(pos.x, 1, 31), clampf(pos.y, 1, 23))
			state.heroes[player].rescue = 0.0
		"skill":
			return _skill(player, str(payload.get("key", "q")), payload.get("pos", state.heroes[player].pos))
		"hero_upgrade":
			var hero: Dictionary = state.heroes[player]
			if hero.skill_points <= 0 or hero.skill_level >= 3:
				return "技能强化点不足，英雄2级与4级各获得1点"
			hero.skill_level += 1
			hero.skill_points -= 1
			_remember_hero(hero)
			_effect("level_up", hero.pos, player, 1.0)
			_notice(hero.skill.name + " 已强化至 " + str(hero.skill_level) + " 级")
		"hero_talent":
			var hero: Dictionary = state.heroes[player]
			var talent := str(payload.get("talent", ""))
			if talent not in ["support", "assault"]: return "无效英雄专精"
			if state.phase != "prepare" or not hero.cast.is_empty() or hero.q_at > now: return "只能在备战且技能冷却结束时更换专精"
			hero.talent = talent
			_notice("本局英雄专精已选择，可在下次备战调整")
		"transfer":
			var amount := int(payload.get("amount", 50))
			if amount < 1 or amount > 10000 or int(state.gold[player]) < amount * 4:
				return "转账金额无效或金币不足"
			if float(state.transfer_cd[player]) > now:
				return "转账正在冷却"
			state.gold[player] -= amount * 4
			state.gold[_other(player)] += int(floor(amount * 0.9)) * 4
			state.transfer_cd[player] = now + 30
			state.cooperation[player].aid += int(floor(amount * 0.9))
			_team("%s → %s 援助 %dg" % [player.to_upper(), _other(player).to_upper(), int(floor(amount * 0.9))])
			_notice("援助已送达：" + str(int(floor(amount * 0.9))) + " 金币")
		"gate":
			var id := str(payload.get("id", ""))
			if not state.gates.has(id):
				return "无效闸门"
			if not state.gate_request.is_empty():
				return "已有分流请求等待确认"
			for gate in state.gates.values():
				if gate.end > now:
					return "另一个闸门正在分流"
			if state.gates[id].ready_at > now:
				return "闸门正在冷却"
			if int(state.gold[player]) < 200:
				return "金币不足"
			state.gate_request = {"id": id, "owner": player, "expires": now + 3}
			_notice(player.to_upper() + " 请求闸门分流，队友点击同意或拒绝")
		"gate_reply":
			if state.gate_request.is_empty() or state.gate_request.owner == player:
				return "没有需要你确认的请求"
			var req: Dictionary = state.gate_request
			state.gate_request = {}
			if payload.get("accept", false) and req.expires > now and int(state.gold[req.owner]) >= 200:
				state.gold[req.owner] -= 200
				state.gates[req.id].end = now + 10
				state.gates[req.id].ready_at = now + 40
				_notice("分流闸门已开启，持续 10 秒")
			else:
				_notice("分流取消，未扣金币")
		"trap":
			var id := str(payload.get("id", ""))
			if not state.traps.has(id) or state.traps[id].ready_at > now:
				return "机关不可用或冷却中"
			if int(state.gold[player]) < 300:
				return "金币不足"
			state.gold[player] -= 300
			state.traps[id] = {"end": now + 5, "ready_at": now + 40}
			for trap in cfg.map.fire_traps:
				if trap.id == id:
					var pos := cfg.vector(trap.position)
					state.zones.append({"kind": "fire", "pos": pos, "radius": 2.0, "owner": player, "dps": 30.0, "end": now + 5, "next": now})
					_ignite(pos, player)
		"ultimate":
			if state.resonance < 100 or state.ultimate_cd > now:
				return "共鸣尚未充满或大招正在冷却"
			for hero in state.heroes.values():
				if hero.hp <= 0:
					return "英雄倒地时不能启动共鸣"
			if state.ultimate_request.is_empty():
				state.ultimate_request = {"owner": player, "expires": now + 3}
				_notice("共鸣准备！队友在 3 秒内使用共鸣响应")
			elif state.ultimate_request.owner != player and state.ultimate_request.expires > now:
				state.resonance = 0
				state.ultimate_end = now + 5
				state.ultimate_cd = now + 60
				for enemy in state.enemies.values():
					enemy.stun_end = now + (2 if is_boss(enemy.kind) else 5)
				state.ultimate_request = {}
				_team("P1 + P2 共鸣成功！")
				_effect("ultimate", Vector2(16, 12), "", 5)
				_notice("时空停滞！守住水晶！")
		"rescue":
			state.heroes[player].rescue = now + 0.2 if payload.get("active", false) else 0.0
		_:
			return "未知指令"
	return ""

func _other(player: String) -> String:
	return "p2" if player == "p1" else "p1"

func _start_wave() -> void:
	state.phase = "battle"
	state.wave += 1
	state.wave_start = state.time
	state.spawn_index = 0
	state.ready = {"p1": false, "p2": false}
	state.stage_event = {}
	state.event_done = false
	_notice("第 %d 波来袭！" % state.wave)
	Expansion.wave_start(self)

func spawn(kind: String, lane: String) -> int:
	state.spawned += 1
	var spec: Dictionary = cfg.enemies[kind]
	var route := "air_" + lane if spec.movement_type == "air" else lane + "_default"
	route = Expansion.route(self,lane,route)
	var hp := float(round(float(spec.base_hp) * (1 + 0.08 * (state.wave - 1)))) if spec.wave_hp_scaling else float(spec.base_hp)
	var id := next_id
	next_id += 1
	state.enemies[id] = {"id": id, "kind": kind, "route": route, "lane": lane, "s": 0.0, "pos": cfg.route_position(route, 0), "hp": hp, "max_hp": hp, "previous_hp": hp, "hit_until": 0.0, "attack_until": 0.0, "hit_dir": Vector2.RIGHT, "blocker": "", "frost_end": 0.0, "frost_owner": "", "mark_end": 0.0, "mark_owner": "", "shatter_end": 0.0, "combo_at": 0.0, "stun_end": 0.0, "attack_at": 0.0, "fire_at": 0.0, "contrib": {}, "diverted": false, "blocked": false, "boss_stage": 0, "boss_cast": 0.0, "shield": 80.0 if kind == "warden" else 0.0, "heal_at": 0.0, "relay_owner": "", "relay_end": 0.0, "deep_end": 0.0, "frost_slow": 0.4}
	return id

func step(delta: float) -> void:
	if state.paused or state.phase in ["won", "lost"]:
		return
	state.time += delta
	state.tick += 1
	var now: float = state.time
	state.effects = state.effects.filter(func(e): return e.end > now)
	state.zones = state.zones.filter(func(z): return z.end > now)
	if not state.gate_request.is_empty() and state.gate_request.expires <= now:
		state.gate_request = {}
		_notice("闸门请求超时，未扣金币")
	if not state.ultimate_request.is_empty() and state.ultimate_request.expires <= now:
		state.ultimate_request = {}
		_notice("共鸣响应超时，能量保留")
	if state.phase == "prepare":
		if now >= state.prepare_end:
			_start_wave()
		_move_heroes(delta)
		_resolve_casts()
		return
	var wave: Dictionary = cfg.waves[state.wave - 1]
	while state.spawn_index < wave.events.size() and float(wave.events[state.spawn_index].time) <= now - float(state.wave_start):
		var event: Dictionary = wave.events[state.spawn_index]
		spawn(event.enemy_id, event.entry)
		state.spawn_index += 1
	_stage_events(delta)
	Expansion.update(self,delta)
	_enemy_support(delta)
	_support_towers(delta)
	_move_heroes(delta)
	_resolve_casts()
	_soldiers(delta)
	_hero_blocks()
	_move_enemies(delta)
	_towers()
	_heroes_attack()
	_projectiles(delta)
	_zones(delta)
	_resolve_deaths()
	if state.hp <= 0:
		state.phase = "lost"
		_notice("水晶失守。调整阵地，再战一次。")
	elif state.spawn_index == wave.events.size() and state.enemies.is_empty():
		for player in ["p1", "p2"]:
			state.gold[player] += int(wave.reward_per_player) * 4
		if state.wave == cfg.waves.size():
			state.phase = "won"
			_notice("胜利！双子水晶守住了！")
		else:
			state.phase = "prepare"
			state.stage_event = {}
			state.prepare_end = now + 25
			_notice("本波结束，升级中央火力并检查下一波兵种。")

func _move_heroes(delta: float) -> void:
	for player in state.heroes:
		var hero: Dictionary = state.heroes[player]
		if hero.hp <= 0:
			if state.time >= hero.revive_at:
				hero.hp = hero.max_hp
				hero.pos = cfg.vector(cfg.map.hero_spawns[player])
				hero.target = hero.pos
			continue
		var target: Vector2 = hero.target
		if state.time - hero.last_hurt > 6:
			hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.012 * delta)
		if hero.pos.distance_to(target) > 0.05:
			hero.rescue = 0.0
			hero.facing = (target - hero.pos).normalized()
		hero.pos = hero.pos.move_toward(target, float(cfg.heroes[hero.kind].speed) * delta * _terrain_factor(hero.pos, "hero"))
		var friend: Dictionary = state.heroes[_other(player)]
		if friend.hp <= 0 and hero.rescue > state.time and hero.pos.distance_to(friend.pos) < 1:
			friend.rescue_progress += delta
			if friend.rescue_progress >= 3:
				state.cooperation[player].rescues += 1
				_team(player.to_upper() + " 救起了 " + _other(player).to_upper())
				friend.hp = friend.max_hp * 0.5
				friend.target = friend.pos
				friend.rescue_progress = 0.0
		else:
			friend.rescue_progress = 0.0

func _move_enemies(delta: float) -> void:
	for enemy in state.enemies.values():
		if enemy.hp <= 0:
			continue
		var spec: Dictionary = cfg.enemies[enemy.kind]
		var now: float = state.time
		for gate_spec in cfg.map.gates:
			if enemy.lane == gate_spec.id.right(1) and enemy.route == gate_spec.from_route and enemy.s < 6 and state.gates[gate_spec.id].end > now and not is_boss(enemy.kind):
				enemy.route = gate_spec.to_route
				enemy.diverted = true
		var slow := float(enemy.get("frost_slow", 0.4)) if enemy.frost_end > now else 0.0
		for zone in state.zones:
			if zone.kind=="ice" and enemy.pos.distance_to(zone.pos)<=zone.radius:slow=maxf(slow,.45)
			if zone.kind == "oil" and spec.movement_type == "ground" and enemy.pos.distance_to(zone.pos) <= zone.radius:
				slow = maxf(slow, float(zone.get("slow", 0.3)))
				enemy.contrib[zone.owner] = now
		if is_boss(enemy.kind): slow = minf(slow, 0.2)
		if enemy.kind == "boss":
			var threshold := 0.7 if enemy.boss_stage == 0 else 0.35
			if enemy.boss_stage < 2 and enemy.hp / enemy.max_hp < threshold:
				enemy.boss_stage += 1
				enemy.boss_cast = now + 2
				_effect("warning", enemy.pos, "", 2)
			if enemy.boss_cast > 0 and now >= enemy.boss_cast:
				for soldier in state.soldiers:
					if soldier.pos.distance_to(enemy.pos) < 2:
						soldier.hp -= 40
				for hero in state.heroes.values():
					if hero.pos.distance_to(enemy.pos) < 2:
						hero.pos += (hero.pos - enemy.pos).normalized() * 1.5
				enemy.boss_cast = 0.0
				_effect("blast", enemy.pos)
		if not enemy.blocked and enemy.stun_end <= now and enemy.boss_cast <= now:
			var event_speed := 1.3 if _event_active("wind") and spec.movement_type == "air" else (1.25 if _event_active("tide") and spec.movement_type == "ground" else 1.0)
			enemy.s += float(spec.speed) * (1 - slow) * delta * event_speed
			enemy.pos = cfg.route_position(enemy.route, enemy.s)
		if spec.attack_heroes and not enemy.blocked and enemy.attack_at <= now and enemy.stun_end <= now:
			for hero in state.heroes.values():
				if hero.hp > 0 and hero.pos.distance_to(enemy.pos) <= 1.5:
					_hurt_hero(hero, enemy, float(spec.attack_damage))
					enemy.attack_at = now + 2
					break

func _rally_position(pos: Vector2) -> Vector2:
	var best := Vector2(16, 12)
	var distance := INF
	for route_id in ["a_default", "b_default"]:
		for i in range(75):
			var candidate := cfg.route_position(route_id, i * 0.5)
			if candidate.distance_to(pos) < distance:
				distance = candidate.distance_to(pos)
				best = candidate
	return best

func _soldiers(delta: float) -> void:
	for enemy in state.enemies.values():
		enemy.previous_blocker = enemy.get("blocker", "")
		enemy.blocked = false
		enemy.blocker = ""
	var claimed := {}
	var boss_reserved := {}
	for soldier in state.soldiers:
		if not Expansion.active(self,state.towers[soldier.tower]): continue
		if boss_reserved.has(soldier.tower):
			continue
		if soldier.hp <= 0:
			if soldier.revive_at <= 0:
				soldier.revive_at = state.time + 10
			if state.time < soldier.revive_at:
				continue
			soldier.hp = soldier.max_hp
			soldier.revive_at = 0.0
		var rally: Vector2 = state.towers[soldier.tower].get("rally", soldier.pos)
		if soldier.pos.distance_to(rally) > 0.1:
			soldier.pos = soldier.pos.move_toward(rally, delta * 4 * float(tower_mods(state.towers[soldier.tower]).get("move", 1)) * _terrain_factor(soldier.pos, "soldier"))
			soldier.target = -1
			continue
		var enemy: Dictionary = {}
		for candidate in state.enemies.values():
			if candidate.hp > 0 and cfg.enemies[candidate.kind].movement_type == "ground" and candidate.pos.distance_to(soldier.pos) < 1.2 and not claimed.has(candidate.id):
				if is_boss(candidate.kind):
					var live := 0
					for ally in state.soldiers:
						if ally.tower == soldier.tower and ally.hp > 0:
							live += 1
					if live < 3:
						continue
				enemy = candidate
				break
		if enemy.is_empty():
			continue
		claimed[enemy.id] = true
		if is_boss(enemy.kind):
			boss_reserved[soldier.tower] = true
		enemy.blocked = true
		enemy.blocker = "soldier_" + str(soldier.tower)
		enemy.contrib[soldier.owner] = state.time
		if soldier.attack_at <= state.time:
			var level: int = state.towers[soldier.tower].level
			_damage(enemy, 8 * (3 if is_boss(enemy.kind) else 1) * float(cfg.tower_rules.damage_multiplier_by_level[level - 1]) * float(tower_mods(state.towers[soldier.tower]).get("damage", 1)), "physical", soldier.owner, false)
			soldier.attack_at = state.time + 1
			_effect("slash", enemy.pos, soldier.owner, 0.18, {"from": soldier.pos})
		if enemy.attack_at <= state.time and enemy.stun_end <= state.time:
			soldier.hp -= float(cfg.enemies[enemy.kind].attack_damage) * (.5 if float(soldier.get("skill_guard_end",0))>state.time else 1.0)
			enemy.attack_until = state.time + 0.22
			_effect("hit", soldier.pos, "", 0.15)
			enemy.attack_at = state.time + 2

func _pick(pos: Vector2, radius: float, targets: Array, strategy := "first") -> Dictionary:
	var best: Dictionary = {}
	var score := -INF
	for enemy in state.enemies.values():
		if enemy.hp <= 0 or cfg.enemies[enemy.kind].movement_type not in targets or pos.distance_to(enemy.pos) > radius:
			continue
		var current: float = enemy.hp if strategy == "strong" else -(cfg.route_length(enemy.route) - float(enemy.s))
		if strategy == "air": current += 10000 if cfg.enemies[enemy.kind].movement_type == "air" else 0
		if strategy == "fast": current = float(cfg.enemies[enemy.kind].speed) * 1000 - (cfg.route_length(enemy.route) - float(enemy.s))
		if strategy == "armor": current = float(cfg.enemies[enemy.kind].physical_resistance) * 1000 - (cfg.route_length(enemy.route) - float(enemy.s))
		if current > score:
			score = current
			best = enemy
	return best

func _towers() -> void:
	for tower in state.towers.values():
		if tower.id in ["barracks", "beacon"] or tower.attack_at > state.time or not Expansion.active(self,tower):
			continue
		var spec: Dictionary = cfg.towers[tower.id]
		var aura := 1.0
		for hero in state.heroes.values():
			if hero.kind == "commander" and hero.owner != tower.owner and hero.hp > 0 and hero.pos.distance_to(tower.pos) <= 3:
				aura = 1.2
		var mods := tower_mods(tower)
		aura = maxf(aura, _beacon_aura(tower))
		var radius := tower_range(tower)
		var enemy := _pick(tower.pos, radius, spec.targets, tower.strategy)
		if enemy.is_empty():
			continue
		tower.attack_at = state.time + float(spec.interval) * float(mods.get("interval", 1)) / _terrain_factor(tower.pos, "tower")
		var damage := float(spec.damage) * float(cfg.tower_rules.damage_multiplier_by_level[tower.level - 1]) * float(mods.get("damage", 1))
		if float(tower.get("skill_damage_end",0))>state.time: damage*=float(tower.get("skill_damage_boost",1))
		damage *= float(mods.get("air_damage", 1)) if cfg.enemies[enemy.kind].movement_type == "air" else float(mods.get("ground_damage", 1))
		if tower.id == "alchemy":
			state.zones.append({"kind": "oil", "pos": enemy.pos, "radius": float(mods.get("oil_radius", 1.5)), "slow": float(mods.get("oil_slow", 0.3)), "fire": float(mods.get("fire", 1)), "owner": tower.owner, "level": tower.level, "end": state.time + 3 + tower.level + float(mods.get("oil_duration", 0))})
		elif tower.id == "cannon":
			state.projectiles.append({"start": tower.pos, "pos": tower.pos, "end": enemy.pos, "target": enemy.id, "owner": tower.owner, "damage": damage, "aura": aura, "mods": mods, "tower": _tower_node(tower), "travel": 0.0, "duration": maxf(0.1, tower.pos.distance_to(enemy.pos) / 8)})
		else:
			state.projectiles.append({"kind": tower.id, "start": tower.pos, "pos": tower.pos, "end": enemy.pos, "target": enemy.id, "owner": tower.owner, "damage": damage * aura, "damage_type": spec.damage_type, "mods": mods, "tower": _tower_node(tower), "travel": 0.0, "duration": maxf(0.08, tower.pos.distance_to(enemy.pos) / 20)})

func _damage(enemy: Dictionary, value: float, type: String, owner: String, crit := true, pierce := 0.0) -> float:
	if enemy.hp <= 0:
		return 0.0
	value *= Expansion.damage_factor(self,enemy,owner)
	if crit and enemy.mark_end > state.time and enemy.mark_owner != owner and random.randf() < 0.5:
		value *= 2
		_effect("crit", enemy.pos, owner, 0.5)
	var resistance := float(cfg.enemies[enemy.kind].get(type + "_resistance", 0)) if type != "true" else 0.0
	if type != "true" and enemy.blocked:
		for soldier in state.soldiers:
			if soldier.hp > 0 and soldier.owner != owner and soldier.pos.distance_to(enemy.pos) < 1.2:
				value *= 1.15
				break
	resistance = maxf(0, resistance - pierce)
	if float(enemy.get("breach_end",0))>state.time and type=="physical":resistance=maxf(0,resistance-.25)
	var actual := value * (1 - resistance)
	if float(enemy.get("shield", 0)) > 0:
		var absorbed := minf(actual, float(enemy.shield))
		enemy.shield -= absorbed
		actual -= absorbed
	var dealt := minf(actual, enemy.hp)
	enemy.previous_hp = enemy.hp
	enemy.hp -= actual
	if actual > 0:
		enemy.contrib[owner] = state.time
		enemy.hit_until = state.time + 0.14
		enemy.hit_dir = (enemy.pos - state.heroes[owner].pos).normalized() if state.heroes.has(owner) else Vector2.RIGHT
		_effect("hit", enemy.pos, owner, 0.16, {"victim": enemy.id, "amount": int(round(dealt)), "type": type})
		var merged := false
		for event in state.effects:
			if event.kind == "damage" and event.get("victim", -1) == enemy.id and state.time - event.start < 0.15:
				event.amount += int(round(dealt))
				merged = true
				break
		if not merged:
			_effect("damage", enemy.pos, owner, 0.65, {"victim": enemy.id, "amount": int(round(dealt)), "type": type})
	return dealt

func _combo(enemy: Dictionary, partner: String) -> void:
	enemy.contrib[partner] = state.time
	state.stats.combos += 1
	for owner in ["p1", "p2"]:
		state.cooperation[owner].combos += 1
	if enemy.combo_at <= state.time:
		state.resonance = mini(100, state.resonance + 3)
		enemy.combo_at = state.time + (4 if is_boss(enemy.kind) else 2)

func _projectiles(delta: float) -> void:
	var remaining := []
	for shot in state.projectiles:
		if shot.get("kind", "cannon") != "cannon" and state.enemies.has(shot.target):
			shot.end = state.enemies[shot.target].pos
		shot.travel += delta
		shot.pos = shot.start.lerp(shot.end, clampf(shot.travel / shot.duration, 0, 1))
		if shot.travel < shot.duration:
			remaining.append(shot)
			continue
		var primary: Dictionary = state.enemies.get(shot.target, {})
		if shot.get("kind", "cannon") != "cannon":
			if not primary.is_empty() and primary.hp > 0:
				if shot.kind == "hero":
					_hero_hit(state.heroes[shot.owner], primary, shot)
				else:
					_tower_hit(shot, primary, float(shot.damage), shot.damage_type)
					if shot.kind == "storm":
						var chained := [primary.id]
						var previous: Dictionary = primary
						for jump in range(1, int(shot.get("mods", {}).get("jumps", 3))):
							var nearest: Dictionary = {}
							var distance := 2.0
							for candidate in state.enemies.values():
								if candidate.hp > 0 and candidate.id not in chained and previous.pos.distance_to(candidate.pos) < distance:
									distance = previous.pos.distance_to(candidate.pos)
									nearest = candidate
							if nearest.is_empty(): break
							_tower_hit(shot, nearest, float(shot.damage) * pow(0.75, jump), "magic")
							_effect("lightning", nearest.pos, shot.owner, 0.3, {"from": previous.pos})
							chained.append(nearest.id)
							previous = nearest
					if shot.kind == "frost" and primary.hp > 0:
						primary.frost_end = state.time + float(shot.get("mods", {}).get("frost_duration", 3))
						primary.deep_end = primary.frost_end if shot.get("mods", {}).get("deep", false) else 0
						primary.frost_owner = shot.owner
					if shot.kind == "archer" and primary.hp > 0 and random.randf() < 0.15:
						primary.mark_end = state.time + 5
						primary.mark_owner = shot.owner
			continue
		var shatter := false
		var shatter_damage := float(shot.damage) * 3 * float(shot.get("mods", {}).get("shatter", 1))
		if not primary.is_empty() and primary.hp > 0 and primary.pos.distance_to(shot.end) <= 1.2 and primary.frost_end > state.time and primary.frost_owner != shot.owner and primary.shatter_end <= state.time:
			shatter = true
			if primary.kind == "boss":
				shatter_damage = float(shot.damage) * 1.5 * float(shot.get("mods", {}).get("shatter", 1))
			shatter_damage *= 1.25 if primary.get("deep_end", 0) > state.time else 1.0
			_damage(primary, shatter_damage, "true", shot.owner, false)
			_team("%s 冰霜 → %s 碎冰" % [primary.frost_owner.to_upper(), shot.owner.to_upper()])
			_combo(primary, primary.frost_owner)
			primary.frost_end = 0.0
			primary.shatter_end = state.time + (4 if primary.kind == "boss" else 2)
			_effect("shatter", primary.pos, shot.owner)
		for enemy in state.enemies.values():
			if enemy.hp <= 0 or cfg.enemies[enemy.kind].movement_type == "air":
				continue
			var distance: float = enemy.pos.distance_to(shot.end)
			if distance <= float(shot.get("mods", {}).get("splash", 1.2)) and (not shatter or enemy.id != shot.target):
				_tower_hit(shot, enemy, float(shot.damage) * float(shot.aura), "physical")
			if shatter and enemy.id != shot.target and distance <= 2:
				_damage(enemy, shatter_damage * 0.5, "true", shot.owner, false)
				if not primary.is_empty():
					enemy.contrib[primary.frost_owner] = state.time
		_ignite(shot.end, shot.owner)
		_effect("blast", shot.end, shot.owner)
	state.projectiles = remaining

func _ignite(pos: Vector2, owner: String) -> void:
	for zone in state.zones.duplicate():
		if zone.kind != "oil" or zone.pos.distance_to(pos) > zone.radius:
			continue
		var cross: bool = zone.owner != owner
		zone.kind = "fire"
		zone.dps = float(cfg.towers.alchemy.fire_dps_by_level[zone.level - 1]) * (1 if cross else 0.5) * float(zone.get("fire", 1))
		zone.partner = zone.owner if cross else ""
		zone.owner = owner
		zone.end = state.time + 4
		zone.next = state.time
		_effect("fire", zone.pos, owner)
		if cross:
			_team("%s 油污 → %s 点燃" % [zone.partner.to_upper(), owner.to_upper()])
			for enemy in state.enemies.values():
				if enemy.hp > 0 and enemy.pos.distance_to(zone.pos) <= zone.radius:
					_combo(enemy, zone.partner)

func _zones(_delta: float) -> void:
	for enemy in state.enemies.values():
		if enemy.hp <= 0 or enemy.fire_at > state.time:
			continue
		var strongest: Dictionary = {}
		for zone in state.zones:
			if zone.kind in ["fire","ice"] and (zone.kind=="ice" or cfg.enemies[enemy.kind].movement_type!="air") and zone.end > state.time and enemy.pos.distance_to(zone.pos) <= zone.radius and (strongest.is_empty() or zone.dps > strongest.dps):
				strongest = zone
		if not strongest.is_empty():
			enemy.fire_at = state.time + 0.5
			_damage(enemy, float(strongest.dps) * 0.5, "magic", strongest.owner, false)
			if strongest.get("partner", "") != "":
				enemy.contrib[strongest.partner] = state.time

func _hero_blocks() -> void:
	for hero in state.heroes.values():
		hero.blocked_ids = []
		if hero.hp <= 0 or hero.pos.distance_to(hero.target) > 0.15:
			continue
		var spec: Dictionary = cfg.heroes[hero.kind]
		var capacity := int(spec.block_capacity) + (1 if hero.kind == "sentinel" and hero.level >= 6 else 0)
		var used := 0
		for enemy in state.enemies.values():
			if enemy.hp <= 0 or enemy.blocked or cfg.enemies[enemy.kind].movement_type == "air" or hero.pos.distance_to(enemy.pos) > 1.0:
				continue
			var cost := 3 if is_boss(enemy.kind) else 1
			if is_boss(enemy.kind) and (hero.kind != "sentinel" or hero.level < 5):
				continue
			if used + cost > capacity:
				continue
			used += cost
			enemy.blocked = true
			enemy.blocker = "hero_" + hero.owner
			enemy.contrib[hero.owner] = state.time
			hero.blocked_ids.append(enemy.id)
			if enemy.get("previous_blocker", "") != enemy.blocker:
				_effect("block", enemy.pos, hero.owner, 0.25)
			if enemy.attack_at <= state.time and enemy.stun_end <= state.time:
				_hurt_hero(hero, enemy, float(cfg.enemies[enemy.kind].attack_damage) * (1.5 if is_boss(enemy.kind) else 1.0))
				enemy.attack_at = state.time + float(cfg.enemies[enemy.kind].attack_interval)
			if hero.hp <= 0:
				for id in hero.blocked_ids:
					state.enemies[id].blocked = false
					state.enemies[id].blocker = ""
				hero.blocked_ids = []
				break

func _hurt_hero(hero: Dictionary, enemy: Dictionary, amount: float) -> void:
	if hero.hp <= 0:
		return
	var reduction := 0.0
	if hero.kind == "sentinel":
		reduction = 0.4 if hero.level >= 6 else (0.3 if hero.level >= 3 else 0.2)
	if hero.ward_end > state.time:
		reduction = 1 - (1 - reduction) * 0.5
	if float(hero.get("skill_guard_end",0))>state.time: reduction=1-(1-reduction)*.5
	hero.previous_hp = hero.hp
	hero.hp -= amount * (1 - reduction)
	hero.last_hurt = state.time
	hero.hit_until = state.time + 0.16
	hero.rescue = 0.0
	enemy.attack_until = state.time + 0.22
	_effect("hit", hero.pos, hero.owner, 0.18, {"amount": int(amount * (1 - reduction)), "hero_hit": true})
	if hero.kind == "sentinel" and hero.level >= 3:
		_damage(enemy, amount * 0.2, "true", hero.owner, false)
	if hero.hp <= 0:
		hero.revive_at = state.time + 12
		hero.cast = {}
		_effect("hero_down", hero.pos, hero.owner, 1.0)

func _gain_xp(hero: Dictionary, amount: int) -> void:
	if challenge:
		return
	var old_level: int = hero.level
	hero.xp = mini(1400, hero.xp + amount)
	hero.level = cfg.HeroRules.level_for(hero.xp)
	if hero.level > old_level:
		var old_max: float = hero.max_hp
		var spec: Dictionary = cfg.heroes[hero.kind]
		hero.max_hp = float(spec.hp) * (1 + 0.12 * (hero.level - 1))
		hero.damage = float(spec.damage) * (1 + 0.1 * (hero.level - 1))
		if hero.hp > 0:
			hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp - old_max)
		hero.skill_points = cfg.HeroRules.rank_cap(hero.level) - hero.skill_level
		_effect("level_up", hero.pos, hero.owner, 1.0, {"level": hero.level})
		_notice(cfg.heroes[hero.kind].name + " 升至 " + str(hero.level) + " 级！")
	_remember_hero(hero)

func _heroes_attack() -> void:
	for hero in state.heroes.values():
		if hero.hp <= 0 or hero.attack_at > state.time or not hero.cast.is_empty():
			continue
		var spec: Dictionary = cfg.heroes[hero.kind]
		var enemy := _pick(hero.pos, float(spec.range), spec.targets)
		if not hero.blocked_ids.is_empty():
			enemy = state.enemies.get(hero.blocked_ids[0], enemy)
		if enemy.is_empty() or enemy.hp <= 0:
			continue
		hero.attack_count += 1
		hero.attack_at = state.time + float(spec.interval)
		hero.attack_until = state.time + 0.24
		hero.facing = (enemy.pos - hero.pos).normalized()
		var shot := {"kind": "hero", "start": hero.pos, "pos": hero.pos, "end": enemy.pos, "target": enemy.id, "owner": hero.owner, "damage": hero.damage, "damage_type": spec.damage_type, "nth": hero.attack_count, "travel": 0.0, "duration": maxf(0.08, hero.pos.distance_to(enemy.pos) / 20)}
		if float(spec.range) > 2:
			state.projectiles.append(shot)
		else:
			_hero_hit(hero, enemy, shot)
			_effect("slash", enemy.pos, hero.owner, 0.22, {"from": hero.pos})

func _hero_hit(hero: Dictionary, enemy: Dictionary, shot: Dictionary) -> void:
	var damage: float = shot.damage
	var enhanced: bool = int(shot.nth) % 3 == 0
	if hero.kind == "ranger" and enhanced:
		damage *= 2
		_effect("crit", enemy.pos, hero.owner, 0.6)
	var dealt := _damage(enemy, damage, shot.damage_type, hero.owner)
	match hero.kind:
		"commander":
			if enhanced and enemy.hp > 0:
				enemy.frost_end = state.time + (2.5 if hero.level >= 6 else 1.5)
				enemy.frost_owner = hero.owner
		"skirmisher":
			if hero.hp > 0:
				hero.hp = minf(hero.max_hp, hero.hp + dealt * (0.45 if hero.level >= 6 else 0.25))
			if enhanced:
				_damage(enemy, damage * 0.6, "true", hero.owner, false)
		"ranger":
			if hero.level >= 6 and enemy.hp > 0:
				enemy.mark_end = state.time + 5
				enemy.mark_owner = hero.owner
		"pyromancer":
			state.zones.append({"kind": "fire", "pos": enemy.pos, "radius": 1.1 if hero.level >= 6 else 0.55, "owner": hero.owner, "dps": 10.0 + hero.level, "end": state.time + 3})
			_ignite(enemy.pos, hero.owner)
		"stormcaller":
			if enhanced:
				var jumps := 0
				for other in state.enemies.values():
					if other.id != enemy.id and other.hp > 0 and other.pos.distance_to(enemy.pos) <= 2:
						_damage(other, damage * 0.5, "magic", hero.owner, false)
						other.stun_end = state.time + (0.5 if hero.level >= 6 else 0.25)
						_effect("lightning", other.pos, hero.owner, 0.25, {"from": enemy.pos})
						jumps += 1
						if jumps >= (3 if hero.level >= 6 else 2):
							break

func _skill(player: String, key: String, pos: Variant) -> String:
	if key != "q" or not pos is Vector2 or not pos.is_finite():
		return "每位英雄只有一个固定技能，按 Q 施放"
	var hero: Dictionary = state.heroes[player]
	if hero.hp <= 0:
		return "英雄倒地，等待复活"
	if hero.q_at > state.time or not hero.cast.is_empty():
		return "技能正在冷却"
	var center: Vector2 = Vector2(clampf(pos.x, 1, 31), clampf(pos.y, 1, 23))
	center = hero.pos + (center - hero.pos).limit_length(7)
	if hero.skill.id in ["frost_nova", "earthbreaker"]:
		center = hero.pos
	if hero.skill.id == "flame_rush":
		center = hero.pos + (center - hero.pos).limit_length(3)
	hero.q_at = state.time + cfg.HeroRules.skill_cooldown(hero)
	hero.cast_until = state.time + float(hero.skill.windup)
	hero.cast = {"center": center, "damage": cfg.HeroRules.skill_damage(hero), "rank": hero.skill_level}
	hero.facing = (center - hero.pos).normalized() if center != hero.pos else hero.facing
	_effect("cast", hero.pos, player, float(hero.skill.windup), {"skill": hero.skill.id, "to": center})
	_effect("telegraph", center, player, float(hero.skill.windup), {"radius": float(hero.skill.radius), "skill": hero.skill.id})
	return ""

func _resolve_casts() -> void:
	for hero in state.heroes.values():
		if hero.cast.is_empty() or hero.cast_until > state.time:
			continue
		if hero.hp <= 0:
			hero.cast = {}
			continue
		var cast: Dictionary = hero.cast
		hero.cast = {}
		var center: Vector2 = cast.center
		var skill: Dictionary = hero.skill
		var radius := float(skill.radius) * (1 + 0.08 * (int(cast.rank) - 1)) * (1.25 if hero.get("talent", "") == "support" else (0.85 if hero.get("talent", "") == "assault" else 1.0))
		if skill.id == "flame_rush":
			_effect("dash", hero.pos, hero.owner, 0.4, {"to": center})
			hero.pos = center
			hero.target = center
			hero.ward_end = state.time + 1.5
		var targets := []
		for enemy in state.enemies.values():
			if enemy.hp > 0 and enemy.pos.distance_to(center) <= radius:
				if skill.id in ["earthbreaker", "flame_rush"] and cfg.enemies[enemy.kind].movement_type == "air":
					continue
				targets.append(enemy)
		if skill.id == "thunderstorm":
			targets.sort_custom(func(a, b): return a.pos.distance_to(center) < b.pos.distance_to(center))
		for i in range(targets.size()):
			var enemy: Dictionary = targets[i]
			if skill.id == "thunderstorm" and i >= 6:
				break
			var relay: bool = enemy.get("relay_end", 0) > state.time and enemy.get("relay_owner", "") != hero.owner
			if relay:
				state.active_relays += 1
				_damage(enemy, float(cast.damage) * 0.35, "true", hero.owner, false)
				_combo(enemy, str(enemy.relay_owner))
				_effect("shatter", enemy.pos, hero.owner)
				_team("主动接力！队友弱点 → " + hero.owner.to_upper() + " 技能爆发")
				enemy.relay_end = 0.0
			else:
				enemy.relay_owner = hero.owner
				enemy.relay_end = state.time + 4
			_damage(enemy, float(cast.damage) * (pow(0.9, i) if skill.id == "thunderstorm" else 1.0), skill.damage_type, hero.owner, false)
			if skill.id == "frost_nova":
				enemy.frost_end = state.time + 3 + int(cast.rank) * 0.5
				enemy.frost_owner = hero.owner
			if skill.id == "arrow_storm":
				enemy.mark_end = state.time + 5
				enemy.mark_owner = hero.owner
			if skill.id in ["earthbreaker", "thunderstorm", "flame_rush"]:
				enemy.stun_end = state.time + (0.5 if is_boss(enemy.kind) else 1.2 + int(cast.rank) * 0.3)
				if skill.id == "earthbreaker" and not is_boss(enemy.kind):
					enemy.s = maxf(0, enemy.s - 0.65)
					enemy.pos = cfg.route_position(enemy.route, enemy.s)
		if skill.id == "meteor":
			state.zones.append({"kind": "fire", "pos": center, "radius": radius, "owner": hero.owner, "dps": 25.0 * (1 + 0.35 * (int(cast.rank) - 1)), "end": state.time + 5})
		if skill.id in ["meteor", "flame_rush"]:
			_ignite(center, hero.owner)
		if skill.id in ["frost_nova", "earthbreaker"] or hero.get("talent", "") == "support":
			for ally in state.heroes.values():
				if ally.hp > 0 and ally.pos.distance_to(center) <= radius:
					ally.hp = minf(ally.max_hp, ally.hp + 20 * int(cast.rank))
					if skill.id == "earthbreaker" or hero.get("talent", "") == "support":
						ally.ward_end = state.time + 3
		_effect("hero_skill", center, hero.owner, 0.9, {"skill": skill.id, "radius": radius, "amount": int(cast.damage)})
		_notice(cfg.heroes[hero.kind].name + " · " + skill.name)

func _resolve_deaths() -> void:
	for id in state.enemies.keys():
		var enemy: Dictionary = state.enemies[id]
		if enemy.hp <= 0:
			var contributors := {}
			for player in enemy.contrib:
				if state.time - float(enemy.contrib[player]) <= 3:
					contributors[player] = true
			if enemy.frost_end > state.time:
				contributors[enemy.frost_owner] = true
			if enemy.mark_end > state.time:
				contributors[enemy.mark_owner] = true
			var synergy: bool = contributors.has("p1") and contributors.has("p2")
			var bounty := int(cfg.enemies[enemy.kind].bounty)
			for player in ["p1", "p2"]:
				state.gold[player] += bounty * (3 if synergy else 2)
			if synergy:
				state.resonance = mini(100, state.resonance + 2)
				state.stats.synergies += 1
			state.stats.kills += 1
			if enemy.kind=="splitter":
				for offset in [-.25,.25]:
					var child_id:=spawn("infantry",enemy.lane)
					var child:Dictionary=state.enemies[child_id]
					child.route=enemy.route
					child.s=maxf(0,enemy.s+offset)
					child.pos=cfg.route_position(child.route,child.s)
			var xp: int = {"infantry": 6, "heavy": 12, "assassin": 8, "flyer": 8, "elite": 20, "boss": 80, "warden": 14, "mender": 12,"saboteur":16,"splitter":14,"rift_lord":100}[enemy.kind]
			for hero in state.heroes.values():
				_gain_xp(hero, xp)
			_effect("death", enemy.pos, "", 0.85, {"enemy": enemy.kind})
			state.enemies.erase(id)
		elif enemy.s >= cfg.route_length(enemy.route):
			state.hp = maxi(0, state.hp - int(cfg.enemies[enemy.kind].leak_damage))
			state.stats.leaks += 1
			state.leak_log.append({"wave": state.wave, "kind": enemy.kind, "exit": cfg.map.route_exits[enemy.route]})
			_effect("leak", enemy.pos)
			state.enemies.erase(id)
			_notice("%s 突破 %s 出口！补充%s。" % [cfg.enemies[enemy.kind].name, cfg.map.route_exits[enemy.route].replace("exit_", "").to_upper(), "防空" if enemy.kind == "flyer" else "阻挡与火力"])

func _valid_branch(kind: String, branch: String) -> bool:
	for option in cfg.towers[kind].get("branches", []):
		if option.id == branch: return true
	return false

func branch_cost(tower: Dictionary, target: String) -> int:
	# The full Lv.3 investment is 1 + 0.8 + 1.2 = 3 base costs.
	return maxi(0, int(cfg.towers[target].cost) * 3 - int(tower.spent))

func tower_mods(tower: Dictionary) -> Dictionary:
	var result := {}
	var spec: Dictionary = cfg.towers[tower.id]
	for key in ["pierce", "jumps"]:
		if spec.has(key): result[key] = spec[key]
	for option in spec.get("branches", []):
		if option.id == tower.get("branch", ""): result.merge(option.modifiers, true)
	return result

func tower_range(tower: Dictionary) -> float:
	var radius := float(cfg.towers[tower.id].get("range", 5)) * float(tower_mods(tower).get("range", 1))
	if tower.id in ["barracks", "beacon"]: return radius
	for hero in state.heroes.values():
		if hero.kind == "commander" and hero.owner != tower.owner and hero.hp > 0 and hero.pos.distance_to(tower.pos) <= 3: return radius * 1.15
	return radius

func _tower_node(tower: Dictionary) -> String:
	for key in state.towers:
		if state.towers[key] == tower: return str(key)
	return ""

func _tower_hit(shot: Dictionary, enemy: Dictionary, damage: float, type: String) -> void:
	var dealt := _damage(enemy, damage, type, shot.owner, true, float(shot.get("mods", {}).get("pierce", 0)))
	var node := str(shot.get("tower", ""))
	state.tower_damage[node] = float(state.tower_damage.get(node, 0)) + dealt

func _update_soldier_stats(node: String) -> void:
	var tower: Dictionary = state.towers[node]
	for soldier in state.soldiers:
		if soldier.tower == node:
			soldier.max_hp = 80 * float(cfg.tower_rules.damage_multiplier_by_level[tower.level - 1]) * float(tower_mods(tower).get("soldier_hp", 1))
			soldier.hp = minf(soldier.hp + 40, soldier.max_hp)

func _beacon_aura(tower: Dictionary) -> float:
	var aura := 1.0
	for beacon in state.towers.values():
		if beacon.id == "beacon" and beacon.owner != tower.owner and Expansion.active(self,beacon):
			var mods := tower_mods(beacon)
			if beacon.pos.distance_to(tower.pos) <= float(cfg.towers.beacon.range) * float(mods.get("range", 1)):
				aura = maxf(aura, float(mods.get("aura", 1.15)))
	return aura

func _support_towers(delta: float) -> void:
	# Take the strongest nearby source so stacking support towers is not optimal.
	var allies: Array = state.heroes.values() + state.soldiers
	for ally in allies:
		if ally.hp <= 0: continue
		var healing := 0.0
		for tower in state.towers.values():
			if tower.id != "beacon" or not Expansion.active(self,tower): continue
			var mods := tower_mods(tower)
			if tower.pos.distance_to(ally.pos) <= float(cfg.towers.beacon.range) * float(mods.get("range", 1)):
				healing = maxf(healing, (4 + 4 * tower.level) * float(mods.get("heal", 1)))
		ally.hp = minf(ally.max_hp, ally.hp + healing * delta)

func _enemy_support(delta: float) -> void:
	for healer in state.enemies.values():
		if healer.kind != "mender" or healer.hp <= 0 or healer.stun_end > state.time or healer.heal_at > state.time: continue
		healer.heal_at = state.time + 3
		for enemy in state.enemies.values():
			if enemy.id != healer.id and enemy.hp > 0 and enemy.pos.distance_to(healer.pos) < 2:
				enemy.hp = minf(enemy.max_hp, enemy.hp + 18)
		_effect("heal", healer.pos, "", 0.6)

func _event_active(kind: String) -> bool:
	var event: Dictionary = state.stage_event
	return not event.is_empty() and event.kind == kind and event.active_at <= state.time and event.end > state.time and not event.solved

func _terrain_factor(pos: Vector2, unit: String) -> float:
	var event: Dictionary = state.stage_event
	if event.is_empty() or event.solved or event.active_at > state.time or event.end <= state.time: return 1.0
	if pos.distance_to(event.hazard) > 3: return 1.0
	if event.kind == "snow": return 0.65 if unit == "hero" else 0.75
	if event.kind == "sand": return 0.6 if unit in ["hero", "soldier"] else 0.7
	if event.kind == "thorn" and unit == "hero": return 0.7
	return 1.0

func _stage_events(delta: float) -> void:
	var spec: Dictionary = cfg.levels[cfg.level_id].get("event", {})
	if spec.is_empty(): return
	if not state.event_done and spec.waves.any(func(wave): return int(wave) == int(state.wave)) and state.time - state.wave_start >= float(spec.delay):
		state.event_done = true
		var a := cfg.route_position("a_default", cfg.route_length("a_default") * 0.4)
		var b := cfg.route_position("b_default", cfg.route_length("b_default") * 0.65)
		state.stage_event = {"kind": spec.kind, "name": spec.name, "description": spec.description, "active_at": state.time + float(spec.warning), "end": state.time + float(spec.warning) + float(spec.duration), "beacons": [a, b], "hazard": cfg.route_position("a_default" if state.wave == 4 else "b_default", cfg.route_length("a_default" if state.wave == 4 else "b_default") * 0.5), "progress": 0.0, "solved": false, "spawned": false, "reinforce_at": state.time + float(spec.warning) + 8}
		_notice(spec.name + " 即将发生！分头守住两个信标3秒可化解并获得共鸣")
	var event: Dictionary = state.stage_event
	if event.is_empty() or event.solved or event.end <= state.time: return
	# Both heroes must be alive and each cover a distinct beacon, either assignment.
	var h1: Dictionary = state.heroes.p1
	var h2: Dictionary = state.heroes.p2
	var paired: bool = h1.hp > 0 and h2.hp > 0 and ((h1.pos.distance_to(event.beacons[0]) < 1.5 and h2.pos.distance_to(event.beacons[1]) < 1.5) or (h2.pos.distance_to(event.beacons[0]) < 1.5 and h1.pos.distance_to(event.beacons[1]) < 1.5))
	event.progress = event.progress + delta if paired else 0.0
	if event.progress >= 3:
		event.solved = true
		state.event_wins += 1
		state.resonance = mini(100, state.resonance + 25)
		_team("双信标协作！" + event.name + " 已化解，共鸣 +25")
		return
	if event.active_at > state.time: return
	if event.kind in ["icefall", "eclipse"] and float(event.get("pulse_at", event.active_at)) <= state.time:
		event.pulse_at = state.time + (6 if event.kind == "icefall" else 5)
		if event.kind == "icefall":
			for enemy in state.enemies.values():
				if enemy.hp > 0 and enemy.pos.distance_to(event.hazard) < 3:
					enemy.shield = minf(80, float(enemy.get("shield", 0)) + 40)
			_effect("frost_ring", event.hazard, "", 0.9)
		else:
			for hero in state.heroes.values():
				if hero.hp > 0 and hero.pos.distance_to(event.hazard) < 3:
					hero.hp = maxf(1, hero.hp - 24)
					hero.last_hurt = state.time
			for soldier in state.soldiers:
				if soldier.hp > 0 and soldier.pos.distance_to(event.hazard) < 3: soldier.hp -= 30
			_effect("blast", event.hazard, "", 0.7)
	if event.kind == "rift" and (not event.spawned or state.time >= event.reinforce_at):
		spawn("warden", "a")
		spawn("warden", "b")
		if event.spawned: event.reinforce_at = event.end + 1
		event.spawned = true
	if event.kind in ["ember", "thorn"]:
		for soldier in state.soldiers:
			if soldier.hp > 0 and soldier.pos.distance_to(event.hazard) < 3: soldier.hp -= 7 * delta
		if event.kind == "ember":
			for hero in state.heroes.values():
				if hero.hp > 0 and hero.pos.distance_to(event.hazard) < 3:
					hero.hp = maxf(1, hero.hp - 9 * delta)
					hero.last_hurt = state.time


func is_boss(kind: String) -> bool:
	return kind == "boss" or bool(cfg.enemies[kind].get("boss",false))

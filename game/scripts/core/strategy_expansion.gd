extends RefCounted

static func initialize(m) -> void:
	m.state.mechanism = {"kind": str(m.cfg.levels[m.cfg.level_id].get("mechanism", {}).get("kind", "")), "flipped": false, "ready_at": 0.0, "wave": 0, "lock_at": 0.0, "lock_end": 0.0, "unsealed": false, "nodes": ["shared_03", "shared_04"], "cart_s": 12.0, "cart_hp": 100.0, "cart_done": false}
	m.state.advanced_stats = {"skills": 0, "escort_wins": 0, "seal_breaks": 0}

static func allowed(tower: Dictionary, player: String) -> bool:
	return tower.owner == player or bool(tower.get("shared_control", false))

static func active(m, tower: Dictionary, ignore_jam := false) -> bool:
	return tower.upgrade_end <= m.state.time and (ignore_jam or float(tower.get("jam_end", 0)) <= m.state.time) and not node_locked(m,m._tower_node(tower))

static func node_locked(m, node: String) -> bool:
	var q: Dictionary = m.state.get("mechanism", {})
	return q.get("kind", "") == "lock" and not q.get("unsealed", false) and q.lock_at > 0 and m.state.time >= q.lock_at and m.state.time < q.lock_end and node in q.nodes

static func skill_spec(m, tower: Dictionary, id: String) -> Dictionary:
	for skill in m.cfg.towers[tower.id].get("skills", []):
		if skill.id == id: return skill
	return {}

static func command(m, player: String, kind: String, payload: Dictionary) -> String:
	if kind == "mechanism": return operate(m, player)
	var node := str(payload.get("node", ""))
	if not m.state.towers.has(node): return "请选择已建造的塔"
	var tower: Dictionary = m.state.towers[node]
	if kind == "tower_control":
		if tower.owner != player: return "只有塔主可以授权队友"
		tower.shared_control = not bool(tower.get("shared_control", false))
		return ""
	if not allowed(tower, player): return "塔主尚未授权队友操作"
	if tower.level != 3 or str(tower.get("branch", "")).is_empty(): return "先选择三级分支，再学习塔技能"
	if tower.upgrade_end > m.state.time: return "分支施工中"
	var id := str(payload.get("skill", ""))
	var spec := skill_spec(m,tower,id)
	if spec.is_empty(): return "无效塔技能"
	var ranks: Dictionary = tower.get("skills", {})
	var rank: int = int(ranks.get(id,0))
	if kind == "tower_skill_upgrade":
		if rank >= int(spec.max_rank): return "技能已满级"
		var cost: int = int(spec.costs[rank])
		if m.state.gold[player] < cost * 4: return "金币不足"
		m.state.gold[player] -= cost * 4
		tower.spent += cost
		ranks[id] = rank + 1
		tower.skills = ranks
		m._notice(spec.name + " 已强化至 " + str(rank + 1) + " 级")
		return ""
	if rank == 0: return "请先学习技能"
	var cooldowns: Dictionary = tower.get("skill_at", {})
	if float(cooldowns.get(id,0)) > m.state.time: return "技能冷却中"
	if not active(m,tower,id == "rod"): return "塔被封锁或干扰，技能无法施放"
	var origin: Vector2 = tower.get("rally", tower.pos) if tower.id == "barracks" else tower.pos
	var enemy: Dictionary = m._pick(tower.pos,m.tower_range(tower),m.cfg.towers[tower.id].targets,tower.strategy)
	if enemy.is_empty() and id not in ["wall","charge","rod","heal","banner"]: return "射程内没有目标"
	var center: Vector2 = enemy.pos if not enemy.is_empty() else origin
	var power: float = 1.0 + (rank - 1) * 0.5
	match id:
		"wall":
			for ally in m.state.heroes.values() + m.state.soldiers:
				if ally.hp > 0 and ally.pos.distance_to(origin) <= 4: ally.skill_guard_end = m.state.time + 5 + rank
		"heal":
			for ally in m.state.heroes.values() + m.state.soldiers:
				if ally.hp > 0 and ally.pos.distance_to(origin) <= m.tower_range(tower): ally.hp = minf(ally.max_hp,ally.hp+70*power)
		"banner":
			for target in m.state.towers.values():
				if target.owner != player and target.pos.distance_to(origin) <= m.tower_range(tower):
					target.skill_damage_end = m.state.time + 5
					target.skill_damage_boost = 1.3 + rank * 0.1
		"ignite", "blizzard":
			m.state.zones.append({"kind":"ice" if id=="blizzard" else "fire","pos":center,"radius":2.0+rank*.2,"dps":22*power,"owner":player,"end":m.state.time+5})
		"mire":
			m.state.zones.append({"kind":"oil","pos":center,"radius":2.8,"slow":0.65,"fire":1.0,"owner":player,"level":3,"end":m.state.time+7})
			area(m,center,2.8,55*power,"magic",player)
		"volley", "surge":
			var hits := 0
			for target in m.state.enemies.values():
				if target.hp > 0 and target.pos.distance_to(center)<=2.5 and hits < (5 if id=="volley" else 6):
					m._damage(target,65*power,"physical" if id=="volley" else "magic",player,false)
					hits += 1
		"line":
			var direction: Vector2 = (center-origin).normalized()
			for target in m.state.enemies.values():
				var offset: Vector2 = target.pos-origin
				if offset.dot(direction)>=0 and offset.dot(direction)<=m.tower_range(tower)+2 and absf(offset.cross(direction))<=.7:
					m._damage(target,100*power,"true",player,false)
		"execute": m._damage(enemy,(90+180*(1-enemy.hp/enemy.max_hp))*power,"physical",player,false,.6)
		"charge":
			area(m,origin,2.3,70*power,"physical",player)
			for soldier in m.state.soldiers:
				if soldier.tower==node: soldier.attack_at=m.state.time
		"barrage": area(m,center,2.5,100*power,"physical",player)
		"rod":
			for target in m.state.towers.values():
				if target.pos.distance_to(origin)<=4: target.jam_end=0.0
			for target in m.state.enemies.values():
				if target.pos.distance_to(origin)<=3: target.stun_end=maxf(target.stun_end,m.state.time+1+rank*.5)
		"snare", "freeze", "breach":
			for target in m.state.enemies.values():
				if target.hp <= 0 or target.pos.distance_to(center)>2.2: continue
				if id=="breach":
					target.breach_end=m.state.time+6
					m._damage(target,60*power,"physical",player,false)
				elif id=="freeze": target.stun_end=maxf(target.stun_end,m.state.time+(.5 if m.is_boss(target.kind) else 1.5+rank*.5))
				else:
					target.frost_end=m.state.time+4+rank
					target.frost_slow=.65
					target.frost_owner=player
	cooldowns[id]=m.state.time+float(spec.cooldown)
	tower.skill_at=cooldowns
	m.state.advanced_stats.skills+=1
	m._effect("heal" if id in ["heal","banner","wall"] else ("frost_ring" if id in ["freeze","snare","blizzard"] else "blast"),origin if id in ["wall","charge","rod","heal","banner"] else center,player,.8,{"tower_kind":tower.id,"tower_skill":id,"branch":tower.branch,"from":origin,"radius":2.3})
	return ""

static func area(m, center: Vector2, radius: float, damage: float, type: String, player: String) -> void:
	for target in m.state.enemies.values():
		if target.hp > 0 and target.pos.distance_to(center)<=radius: m._damage(target,damage,type,player,false)

static func wave_start(m) -> void:
	var q: Dictionary = m.state.mechanism
	q.wave=m.state.wave
	if q.kind=="junction" and m.state.wave in [3,6,9]:
		q.flipped=not q.flipped
		m._notice("荆棘岔路换线：新到敌军改走"+("交叉出口" if q.flipped else "原始出口"))
	if q.kind=="lock" and m.state.wave in [4,7,10]:
		q.lock_at=m.state.time+8
		q.lock_end=q.lock_at+12
		q.unsealed=false
		m._notice("晶核8秒后封锁两座共享塔基，英雄靠近晶核可提前解封")
	if q.kind=="escort" and m.state.wave in [4,8]:
		q.cart_s=12.0
		q.cart_hp=100.0
		q.cart_done=false
		q.cart_active=true
		m._notice("补给车到达：一人护送、一人清路；成功获得金币与共鸣")

static func route(m, lane: String, original: String) -> String:
	return lane+"_diverted" if m.state.mechanism.kind=="junction" and m.state.mechanism.flipped and original==lane+"_default" else original

static func operate(m, player: String) -> String:
	var q: Dictionary = m.state.mechanism
	if q.kind.is_empty(): return "本关没有可操作机关"
	var hero: Dictionary = m.state.heroes[player]
	var point: Vector2 = m.cfg.vector(m.cfg.levels[m.cfg.level_id].mechanism.position)
	if q.kind=="escort":
		if not q.get("cart_active",false) or q.cart_done: return "补给车尚未到达或护送已结束"
		hero.target=m.cfg.route_position("a_default",q.cart_s)
		return ""
	if hero.hp<=0 or hero.pos.distance_to(point)>3: return "英雄须存活并靠近地图机关三格内"
	if q.ready_at>m.state.time: return "机关冷却中"
	if q.kind=="lock" and (q.lock_end<=m.state.time or q.unsealed): return "当前没有封锁"
	var cost:=30 if q.kind=="junction" else 50
	if m.state.gold[player]<cost*4: return "金币不足"
	m.state.gold[player]-=cost*4
	q.ready_at=m.state.time+4
	if q.kind=="junction": q.flipped=not q.flipped
	else: q.unsealed=true
	m._notice("岔路已切换，新到敌军换线" if q.kind=="junction" else "晶核封锁已解除")
	return ""

static func update(m, delta: float) -> void:
	var q: Dictionary=m.state.mechanism
	if q.kind=="escort" and q.get("cart_active",false) and not q.cart_done:
		var point: Vector2=m.cfg.route_position("a_default",q.cart_s)
		var near:=0
		for hero in m.state.heroes.values():
			if hero.hp>0 and hero.pos.distance_to(point)<3: near+=1
		if near>0:q.cart_s+=delta*(1.4 if near==1 else 2.0)
		for enemy in m.state.enemies.values():
			if enemy.hp>0 and enemy.pos.distance_to(point)<2.2: q.cart_hp-=delta*3
		if q.cart_hp<=0:
			q.cart_done=true
			m._notice("补给车被毁，本次护送奖励失去")
		elif q.cart_s>=24:
			q.cart_done=true
			m.state.advanced_stats.escort_wins+=1
			m.state.resonance=mini(100,m.state.resonance+30)
			for player in ["p1","p2"]:m.state.gold[player]+=160
			m._notice("护送成功！双方各获40金币和30共鸣")
	for enemy in m.state.enemies.values():
		if enemy.hp<=0:continue
		if enemy.kind=="saboteur":
			if float(enemy.get("jam_cast",0))>0 and m.state.time>=enemy.jam_cast:
				if enemy.stun_end<=m.state.time and m.state.towers.has(enemy.jam_node): m.state.towers[enemy.jam_node].jam_end=m.state.time+3
				enemy.jam_cast=0.0
			if float(enemy.get("jam_at",0))<=m.state.time and enemy.stun_end<=m.state.time:
				for node in m.state.towers:
					if m.state.towers[node].pos.distance_to(enemy.pos)<=3:
						enemy.jam_node=node
						enemy.jam_cast=m.state.time+1.5
						enemy.jam_at=m.state.time+9
						m._effect("warning",m.state.towers[node].pos,"",1.5)
						break
		if enemy.kind=="rift_lord": boss(m,enemy)

static func boss(m, enemy: Dictionary) -> void:
	var stage:int=int(enemy.get("rift_stage",0))
	if stage<2 and enemy.hp/enemy.max_hp < (.65 if stage==0 else .3):
		enemy.rift_stage=stage+1
		for offset in [-.5,.5]:
			var id:int=m.spawn("splitter",enemy.lane)
			var child:Dictionary=m.state.enemies[id]
			child.route=enemy.route
			child.s=maxf(0,enemy.s+offset)
			child.pos=m.cfg.route_position(child.route,child.s)
		m._notice("裂隙领主召唤孢囊，先处理分裂怪！")
	if float(enemy.get("pulse_at",0))<=m.state.time and float(enemy.get("pulse_cast",0))<=0:
		enemy.pulse_cast=m.state.time+2
		enemy.pulse_pos=enemy.pos
		enemy.pulse_at=m.state.time+12
		m._effect("warning",enemy.pos,"",2)
	if float(enemy.get("pulse_cast",0))>0 and m.state.time>=enemy.pulse_cast:
		for hero in m.state.heroes.values():
			if hero.hp>0 and hero.pos.distance_to(enemy.pulse_pos)<2.3:m._hurt_hero(hero,enemy,40)
		for tower in m.state.towers.values():
			if tower.pos.distance_to(enemy.pulse_pos)<2.3:tower.jam_end=m.state.time+3
		enemy.pulse_cast=0.0
		m._effect("blast",enemy.pulse_pos,"",.7)

static func damage_factor(m, enemy: Dictionary, owner: String) -> float:
	if enemy.kind!="rift_lord":return 1.0
	if float(enemy.get("seal_open",0))>m.state.time:return 1.25
	if str(enemy.get("seal_owner",""))!=owner and float(enemy.get("seal_at",-10))+3>=m.state.time and not str(enemy.get("seal_owner","")).is_empty():
		enemy.seal_open=m.state.time+4
		m.state.advanced_stats.seal_breaks+=1
		m._team("双方交替破印！裂隙领主暴露弱点4秒")
		m._effect("crit",enemy.pos,owner,.7)
		return 1.25
	enemy.seal_owner=owner
	enemy.seal_at=m.state.time
	return .4

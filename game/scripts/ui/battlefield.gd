extends Node2D

const HeroArt = preload("res://scripts/ui/hero_art.gd")

const Materials = preload("res://scripts/ui/art_materials.gd")
const TowerArt = preload("res://scripts/ui/tower_art.gd")
const TowerFX = preload("res://scripts/ui/tower_fx.gd")
signal combat_event(event: Dictionary)
var fx_epoch := -1
var last_fx := 0
var shake_enabled := true
var damage_numbers := true
var effect_quality := 2
var menu_rect := Rect2()
var preview_kind := ""
var preview_branch := ""
var shake := 0.0
var impact_stop := 0.0
var session: Node
var selected := ""
var hover := ""
var clock := 0.0
const ORIGIN = Vector2(35, 130)
const SCALE = Vector2(29, 22)
const INK = Color("342d28")
const P1 = Color("65b9e6")
const P2 = Color("e7835e")
const SHARED = Color("ba94d5")
var font := SystemFont.new()
var display_positions: Dictionary = {}
var damage_rects: Array[Rect2] = []
var terrain_details: Array = []
var detail_level := ""

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])

func screen(pos: Vector2) -> Vector2:
	return ORIGIN + pos * SCALE

func logic(pos: Vector2) -> Vector2:
	return (pos - position - ORIGIN) / SCALE

func closest_node(pos: Vector2) -> String:
	if not session:
		return ""
	pos -= position
	for node in session.match_model.cfg.nodes.values():
		if screen(session.match_model.cfg.vector(node.position)).distance_to(pos) < 24:
			return node.id
	return ""

func _process(delta: float) -> void:
	impact_stop = maxf(0, impact_stop - delta)
	if impact_stop <= 0:
		clock += delta
	shake = maxf(0, shake - delta * 25)
	position = Vector2(sin(clock * 91), cos(clock * 73)) * shake if shake_enabled else Vector2.ZERO
	if not shake_enabled: impact_stop = 0
	if session:
		var state: Dictionary = session.match_model.state
		if fx_epoch != int(state.epoch):
			fx_epoch = int(state.epoch)
			last_fx = 0
			display_positions.clear()
		if session.mode != "menu":
			for event in state.effects:
				if int(event.get("id", 0)) <= last_fx:
					continue
				last_fx = int(event.id)
				combat_event.emit(event)
				if shake_enabled and event.kind in ["hero_skill", "shatter", "blast"]:
					shake = maxf(shake, 4.5 if event.kind == "hero_skill" else 2.0)
					impact_stop = 0.045 if event.kind == "hero_skill" else 0.018
		var active := {}
		for enemy in session.match_model.state.enemies.values():
			active[enemy.id] = true
			var target: Vector2 = enemy.pos
			var previous: Vector2 = display_positions.get(enemy.id, target)
			display_positions[enemy.id] = previous if impact_stop > 0 else previous.lerp(target, 1 - exp(-delta * 22))
		for id in display_positions.keys():
			if not active.has(id):
				display_positions.erase(id)
	queue_redraw()

func _outline_circle(pos: Vector2, radius: float, fill: Color, border := INK, width := 2.0) -> void:
	draw_circle(pos, radius + width, border)
	draw_circle(pos, radius, fill)

func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, INK, 2, true)

func _tree(pos: Vector2, size: float, variation: float) -> void:
	var theme: String = session.match_model.cfg.map.get("theme", "forest")
	if theme != "forest":
		draw_set_transform(pos, 0, Vector2.ONE * size)
		_ellipse(Vector2(6, 14), Vector2(22, 8), Color(0.12,0.17,0.15,0.22))
		if theme == "snow":
			draw_rect(Rect2(-4, -1, 8, 19), Color("6c6050"))
			for i in range(3):
				var y := 7-i*15
				var width := 25-i*5
				_poly(PackedVector2Array([Vector2(-width,y),Vector2(0,y-36),Vector2(width,y)]), Color("466d64"))
				_poly(PackedVector2Array([Vector2(2,y-30),Vector2(width,y),Vector2(4,y-3)]), Color("31594f"))
				_poly(PackedVector2Array([Vector2(-width*.68,y-7),Vector2(0,y-36),Vector2(width*.68,y-7),Vector2(4,y-12),Vector2(-7,y-9)]), Color("e7ede0"))
				draw_line(Vector2(-width*.45,y-12),Vector2(-3,y-29),Color("ffffff"),1.7,true)
		else:
			draw_line(Vector2(0,17),Vector2(5,-26),Color("82623d"),7,true)
			draw_line(Vector2(-1,16),Vector2(3,-25),Color("c7a372"),2,true)
			for ring in range(5):
				draw_line(Vector2(-2,12-ring*7),Vector2(5,10-ring*7),Color("775237"),1.5,true)
			for i in range(6):
				var v := Vector2.from_angle(i*TAU/6)*Vector2(31,15)
				_poly(PackedVector2Array([Vector2(5,-27),Vector2(5,-27)+v*.7+Vector2(0,-8),Vector2(5,-27)+v+Vector2(0,5)]),Color("638459"))
				draw_line(Vector2(5,-27),Vector2(5,-27)+v*.85,Color("95ab65"),1.5,true)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(pos, 0, Vector2.ONE * size)
	for layer in range(3):
		_ellipse(Vector2(8, 16), Vector2(31 + layer * 3, 10 + layer * 2), Color(0.06, 0.13, 0.08, 0.12 - layer * 0.025))
	_poly(PackedVector2Array([Vector2(-7,18),Vector2(-4,-17),Vector2(5,-16),Vector2(8,17),Vector2(17,21),Vector2(-15,21)]), Color("795535"))
	draw_line(Vector2(-3, 15), Vector2(-1, -15), Color("b1834d"), 3, true)
	for lobe in [[Vector2(-18,-9),21.0],[Vector2(19,-12),23.0],[Vector2(1,-31),27.0]]:
		var center: Vector2 = lobe[0]
		var radius: float = lobe[1]
		var points := PackedVector2Array()
		for j in range(32):
			var angle := j * TAU / 32
			points.append(center + Vector2.from_angle(angle) * radius * (1 + sin(j * 2.3 + variation * 40) * 0.065))
		_poly(points, Color("355437"))
		_ellipse(center + Vector2(-3,-5), Vector2(radius * 0.88, radius * 0.73), Color("587a3e").lightened(variation))
		_ellipse(center + Vector2(-7,-9), Vector2(radius * 0.62, radius * 0.49), Color("83a24d").lightened(variation))
		for leaf in range(5):
			var pp := center + Vector2(-12 + leaf * 5, -8 + sin(leaf * 2) * 6)
			draw_arc(pp, 5, PI * 1.1, PI * 1.8, 8, Color("abc268"), 1.8, true)
	draw_set_transform(Vector2.ZERO)

func _ellipse(pos: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24
		points.append(pos + Vector2(cos(a), sin(a)) * radii)
	draw_colored_polygon(points, color)

func _label(pos: Vector2, text: String, size := 13, color := Color("f5e5bd")) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color("332c27"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if not session:
		return
	var cfg = session.match_model.cfg
	var state: Dictionary = session.match_model.state
	draw_rect(Rect2(0, 0, 1280, 800), Color("293c32"))
	draw_rect(Rect2(18, 105, 965, 590), INK)
	var theme: String = cfg.map.get("theme", "forest")
	var terrain: Color = {"forest": Color("748e55"), "snow": Color("b6c8c6"), "desert": Color("c69d65")}[theme]
	draw_texture_rect(Materials.ground(theme), Rect2(23, 110, 955, 580), false)
	_draw_landmark(str(cfg.map.get("landmark", "")))
	if detail_level != cfg.level_id:
		detail_level = cfg.level_id
		terrain_details.clear()
		for i in range(175):
			var candidate := Vector2(48 + fmod(i * 107.3, 905), 143 + fmod(i * 73.7, 510))
			var logical := logic(candidate)
			if session.match_model._rally_position(logical).distance_to(logical) >= 1.4:
				terrain_details.append({"pos": candidate, "index": i})
	# Fine painted tufts stay away from gameplay roads and build pads.
	for tuft in terrain_details:
		var pos: Vector2 = tuft.pos
		var i: int = tuft.index
		var tint := terrain.darkened(0.19)
		for blade in range(3):
			var p := pos + Vector2(blade * 3, sin(i + blade) * 2)
			draw_line(p, p + Vector2(-2 + blade, -4 - i % 3), tint, 1.3, true)
		if i % 7 == 0:
			draw_circle(pos + Vector2(0,-5), 1.8, Color("ead793") if theme == "forest" else terrain.lightened(0.2))
	# Small original woodland clusters away from paths and selectable nodes.
	for cluster in [Vector2(4, 11), Vector2(4, 14), Vector2(18, 3), Vector2(18, 21), Vector2(28, 11), Vector2(28, 14)]:
		for j in range(3):
			_tree(screen(cluster) + Vector2((j - 1) * 19, (j % 2) * 10), 0.62 + j * 0.08, j * 0.02)
	for i in range(12):
		var pos := screen(Vector2(3 + fmod(i * 7.0, 25), 2 + fmod(i * 5.0, 20)))
		_poly(PackedVector2Array([pos + Vector2(-6, 2), pos + Vector2(-4, -5), pos + Vector2(5, -7), pos + Vector2(8, 1)]), Color("9ba18c"))
	if theme == "desert":
		for pos in [Vector2(10, 2), Vector2(10, 22), Vector2(29, 12)]:
			draw_set_transform(screen(pos), 0, Vector2.ONE * 0.8)
			TowerArt.ellipse(self, Vector2(5, 8), Vector2(40, 10), Color(0.2, 0.12, 0.07, 0.2))
			TowerArt.wall(self, -28, -12, 34, 18, Color("b3956b"))
			for x in [-31, 14]:
				TowerArt.block(self, x, -43 if x < 0 else -32, 10, 45 if x < 0 else 34, Color("c6ad80"))
				TowerArt.block(self, x - 3, -47 if x < 0 else -36, 16, 6, Color("dbc496"))
			draw_set_transform(Vector2.ZERO)
	for id in ["a_default", "b_default"]:
		var points := PackedVector2Array()
		for pos in cfg.map.routes[id]:
			points.append(screen(cfg.vector(pos)))
		var dirt := Color("cbb17b") if theme == "forest" else (Color("c3c9bf") if theme == "snow" else Color("e1bd84"))
		draw_polyline(points, Color(0.13,0.15,0.08,0.22), 47, true)
		draw_polyline(points, dirt.darkened(0.36), 39, true)
		draw_polyline(points, dirt.lightened(0.18), 34, true)
		draw_polyline(points, dirt, 28, true)
		for segment in range(points.size() - 1):
			var direction := (points[segment + 1] - points[segment]).normalized()
			var normal := direction.orthogonal()
			for rut in [-7.0, 7.0]:
				draw_line(points[segment] + normal * rut, points[segment + 1] + normal * rut, Color(dirt.darkened(0.13), 0.45), 1.7, true)
		for j in range(0, 72, 3):
			var pos := screen(cfg.route_position(id, j * 0.5))
			var ahead := screen(cfg.route_position(id, j * 0.5 + 0.1))
			var normal := (ahead - pos).normalized().orthogonal()
			for side in [-1, 1]:
				var pebble: Vector2 = pos + normal * (side * (18 + j % 3))
				_ellipse(pebble + Vector2(1,1), Vector2(3.5,2.0), Color(0.16,0.14,0.09,0.22))
				_ellipse(pebble, Vector2(2.8,1.5), dirt.lightened(0.17))
			draw_line(pos + Vector2(-2,3), pos + Vector2(3,3), Color(dirt.darkened(0.15),0.5), 1, true)
	for lane in ["a", "b"]:
		if state.phase == "prepare":
			var air: Array = cfg.map.routes["air_" + lane]
			for segment in range(air.size() - 1):
				var start := screen(cfg.vector(air[segment]))
				var finish := screen(cfg.vector(air[segment + 1]))
				var length := start.distance_to(finish)
				for distance in range(0, int(length), 18):
					draw_line(start.lerp(finish, distance / length), start.lerp(finish, minf(1, (distance + 8) / length)), Color(0.65, 0.85, 1.0, 0.5), 2, true)
		var pos: Vector2 = cfg.vector(cfg.map.routes[lane + "_default"][0])
		var p := screen(pos)
		_poly(PackedVector2Array([p + Vector2(-25, 10), p + Vector2(-25, -30), p + Vector2(24, -30), p + Vector2(24, 10)]), Color("7b745f"))
		draw_circle(p + Vector2(0, -3), 18, INK)
		draw_rect(Rect2(p + Vector2(-18, -4), Vector2(36, 17)), INK)
		_label(p + Vector2(-25, -39), lane.to_upper() + " 入侵")
	for owner in ["p1", "p2"]:
		var p := screen(cfg.vector(cfg.map.exits["exit_" + owner]))
		_poly(PackedVector2Array([p + Vector2(-22, 10), p + Vector2(-22, -27), p + Vector2(22, -27), p + Vector2(22, 10)]), Color("a1a090"))
		_poly(PackedVector2Array([p + Vector2(-28, -25), p + Vector2(0, -46), p + Vector2(28, -25)]), P1 if owner == "p1" else P2)
		_poly(PackedVector2Array([p + Vector2(0, -18), p + Vector2(-9, -2), p + Vector2(0, 13), p + Vector2(9, -2)]), Color("acedef"))
		_label(p + Vector2(-24, -54), owner.to_upper() + " 出口")
	for zone in state.zones:
		var p := screen(zone.pos)
		var scale: float = zone.radius
		_ellipse(p, Vector2(29, 22) * scale, Color(0.2, 0.16, 0.09, 0.5) if zone.kind == "oil" else Color(1, 0.4, 0.05, 0.28))
		if zone.kind == "fire":
			for i in range(5):
				var fp := p + Vector2(cos(i * 2.4), sin(i * 2.4)) * scale * 13
				_poly(PackedVector2Array([fp + Vector2(-6, 3), fp + Vector2(-4, -12), fp + Vector2(1, -20 - sin(clock * 8 + i) * 4), fp + Vector2(7, 3)]), Color("efad3f"))
	if selected != "" and cfg.nodes.has(selected):
		var p := screen(cfg.vector(cfg.nodes[selected].position))
		var radius := 4.0
		if state.towers.has(selected) and preview_branch.is_empty():
			radius = session.match_model.tower_range(state.towers[selected])
		elif cfg.towers.has(preview_kind):
			radius = float(cfg.towers[preview_kind].get("range", 5))
			if state.towers.has(selected):
				var preview: Dictionary = state.towers[selected].duplicate(true)
				preview.id = preview_kind
				preview.branch = preview_branch
				radius = session.match_model.tower_range(preview)
		_ellipse(p, SCALE * radius, Color(0.94, 0.94, 0.72, 0.12))
		var points := PackedVector2Array()
		for i in range(65):
			var a := TAU * i / 64
			points.append(p + Vector2(cos(a), sin(a)) * SCALE * radius)
		draw_polyline(points, Color("f0e4aa"), 1.5, true)
	for node in cfg.nodes.values():
		var p := screen(cfg.vector(node.position))
		var color := P1 if node.owner == "p1" else (P2 if node.owner == "p2" else SHARED)
		_ellipse(p + Vector2(0, 6), Vector2(24, 11), Color(0.16, 0.2, 0.1, 0.35))
		_ellipse(p, Vector2(25, 15), Color("564d35"))
		_ellipse(p + Vector2(0,-2), Vector2(22, 12), Color("b6a779"))
		_ellipse(p + Vector2(-2,-3), Vector2(18, 9), Color("d1c295"))
		draw_arc(p + Vector2(0,-2), 16, 0, TAU, 28, Color(color,0.55), 1.5, true)
		if not state.towers.has(node.id):
			_label(p + Vector2(-5, 5), "+", 19, INK)
		else:
			_tower(p, state.towers[node.id])
		if node.id == selected or node.id == hover:
			draw_arc(p, 25, 0, TAU, 32, Color("f5e7b8"), 2, true)
	for soldier in state.soldiers:
		if soldier.hp > 0:
			_person(screen(soldier.pos) + Vector2(0, sin(clock * 4) * 1), Color("adb4bb"), soldier.owner, false)
	# Sort by depth so moving units overlap predictably.
	var units := []
	_draw_mechanism()
	for enemy in state.enemies.values():
		units.append({"type": "enemy", "unit": enemy, "y": enemy.pos.y})
	for hero in state.heroes.values():
		units.append({"type": "hero", "unit": hero, "y": hero.pos.y})
	units.sort_custom(func(a, b): return a.y < b.y)
	for entry in units:
		if entry.type == "enemy":
			_enemy(entry.unit)
		else:
			_hero(entry.unit)
	for shot in state.projectiles:
		var progress := clampf(float(shot.travel) / float(shot.duration), 0, 1)
		var kind: String = shot.get("kind", "cannon")
		var p := screen(shot.pos) + Vector2(0, -lerpf(45, 12, progress) - (sin(progress * PI) * 35 if kind == "cannon" else 0.0))
		var source: Dictionary = state.towers.get(shot.get("tower", ""), {})
		if effect_quality>0 and not source.is_empty() and not str(source.get("branch", "")).is_empty():
			TowerFX.trail(self,p,(screen(shot.end)-screen(shot.start)).normalized(),source.id,source.branch,clock)
		if kind == "cannon":
			_ellipse(p + Vector2(3, 2), Vector2(8, 5), Color(0.7,0.62,0.45,0.25))
			_outline_circle(p, 5, Color("55514b"))
			draw_circle(p + Vector2(-2,-2), 1.8, Color("a5a9a0"))
		elif kind in ["archer", "ballista"] or (kind == "hero" and shot.damage_type == "physical"):
			var direction: Vector2 = (screen(shot.end) - screen(shot.start)).normalized()
			draw_line(p - direction * 15, p, Color("e9d5a0"), 2, true)
			var normal := direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([p+direction*3,p-direction*4+normal*3,p-direction*4-normal*3]), Color("d9e2da"))
		else:
			var color := Color("83dfff") if kind == "frost" else (Color("c4a2ef") if kind == "storm" else Color(cfg.heroes[state.heroes[shot.owner].kind].color))
			for i in range(3):
				draw_circle(p, 5+i*3, Color(color, 0.12-float(i)*0.03))
			draw_circle(p, 4, color.lightened(0.45))
	for gate in cfg.map.gates:
		var p := screen(cfg.vector(gate.position))
		draw_line(p + Vector2(-9, -18), p + Vector2(-9, 15), INK, 7)
		draw_line(p + Vector2(10, -18), p + Vector2(10, 15), INK, 7)
		draw_line(p + Vector2(-10, -18), p + Vector2(11, -18), Color("ac8b52"), 7)
		if state.gates[gate.id].end > state.time:
			_label(p + Vector2(14, -5), "分流", 12, Color("f5e7b8"))
	for trap in cfg.map.fire_traps:
		var p := screen(cfg.vector(trap.position))
		draw_rect(Rect2(p - Vector2(8, 6), Vector2(16, 12)), INK)
		draw_circle(p, 5, Color("dc8240"))
	for ping in state.get("pings", []):
		if ping.end <= state.time: continue
		var pp := screen(ping.pos)
		var tint := P1 if ping.owner == "p1" else P2
		draw_arc(pp, 18 + sin(clock * 5) * 3, 0, TAU, 32, tint, 3, true)
		_label(pp + Vector2(-30, -30), ping.owner.to_upper() + " " + ping.label, 15, tint.lightened(0.35))
	for tower in state.towers.values():
		if tower.id != "barracks": continue
		var rp := screen(tower.get("rally", tower.pos))
		draw_line(rp, rp + Vector2(0, -24), INK, 3)
		draw_colored_polygon(PackedVector2Array([rp + Vector2(0,-24),rp + Vector2(14,-18),rp + Vector2(0,-13)]), P1 if tower.owner == "p1" else P2)
	damage_rects.clear()
	# Reserve heroes and their status labels before placing floating numbers.
	for hero in state.heroes.values(): damage_rects.append(Rect2(screen(hero.pos) + Vector2(-30, -77), Vector2(60, 90)))
	for effect in state.effects:
		_effect(effect, float(state.time))
	for hero in state.heroes.values():
		var hp := screen(hero.pos)
		var tint := P1 if hero.owner == "p1" else P2
		draw_arc(hp, 22 if hero.owner == session.player else 17, 0, TAU, 32, tint, 3, true)
		if hero.hp <= 0:
			_label(hp + Vector2(-40, -55), hero.owner.to_upper() + " 倒地 · 请求救援", 14, Color("ffe0a0"))
		else:
			_label(hp + Vector2(-12, -67), hero.owner.to_upper(), 14, tint.lightened(0.35))
			if hero.get("talent", "") == "support": draw_line(hp + Vector2(-3, 12), hp + Vector2(3, 12), Color("95ead2"), 3)
	_draw_stage_event(state)
	for i in range(19):
		_tree(Vector2(40 + i * 50, 112), 0.75 + (i % 3) * 0.08, (i % 2) * 0.06)
	for i in range(18):
		_tree(Vector2(45 + i * 51, 685), 0.65 + (i % 3) * 0.09, 0)
	if state.ultimate_end > state.time:
		draw_rect(Rect2(23, 110, 955, 580), Color(0.38, 0.66, 0.92, 0.14))

func _tower(p: Vector2, tower: Dictionary) -> void:
	TowerArt.paint(self, p, tower.id, int(tower.level), P1 if tower.owner == "p1" else P2, clock)
	var model = session.match_model
	var pulse := 0.0
	var fx_interval := float(model.cfg.towers[tower.id].get("interval",1))
	var elapsed := fx_interval - (float(tower.attack_at) - float(model.state.time))
	if tower.attack_at>0 and elapsed>=0 and elapsed<.35:pulse=1-elapsed/.35
	for ability in model.cfg.towers[tower.id].get("skills",[]):
		var cast_at := float(tower.get("skill_at",{}).get(ability.id,0))-float(ability.cooldown)
		if cast_at>0 and model.state.time>=cast_at and model.state.time-cast_at<.7:
			pulse=maxf(pulse,1-(model.state.time-cast_at)/.7)
	if effect_quality>0:
		TowerFX.idle(self,p,tower,clock,model.Expansion.active(model,tower),pulse if effect_quality==2 else 0.0)
	if not session.match_model.Expansion.active(session.match_model,tower) and tower.upgrade_end<=session.match_model.state.time:
		draw_arc(p+Vector2(0,-24),30,0,TAU,32,Color("ce82df"),3,true)
		_label(p+Vector2(-26,-80),"封锁 / 干扰",12,Color("edb0ff"))
	if tower.get("shared_control",false):_label(p+Vector2(-14,31),"协作",11,Color("b9e2ff"))
	if not tower.get("branch", "").is_empty():
		draw_colored_polygon(PackedVector2Array([p+Vector2(-7,15),p+Vector2(0,8),p+Vector2(7,15),p+Vector2(0,22)]), Color("f2d87e"))
	var spec: Dictionary = session.match_model.cfg.towers[tower.id]
	var interval := float(spec.get("interval", 1))
	var since_attack: float = interval - (tower.attack_at - session.match_model.state.time)
	if tower.id == "cannon" and since_attack >= 0 and since_attack < 0.16 and tower.attack_at > 0:
		_ellipse(p + Vector2(-13, -57), Vector2(8, 5), Color("ffe2a0"))
		_ellipse(p + Vector2(-15, -62), Vector2(11, 7), Color(0.82, 0.8, 0.7, 0.45))
	if tower.upgrade_end > session.match_model.state.time:
		_label(p + Vector2(-20, -93), "升级中", 12)

func _person(p: Vector2, color: Color, owner: String, hero: bool, attack := 0.0, facing := Vector2.RIGHT) -> void:
	_ellipse(p + Vector2(0, 3), Vector2(10, 4), Color(0.1, 0.15, 0.09, 0.3))
	draw_line(p + Vector2(-4, -5), p + Vector2(-4, 2), INK, 4)
	draw_line(p + Vector2(4, -5), p + Vector2(4, 2), INK, 4)
	_poly(PackedVector2Array([p + Vector2(-8, -15), p + Vector2(8, -15), p + Vector2(7, -3), p + Vector2(-7, -3)]), color)
	_poly(PackedVector2Array([p + Vector2(-6,-14),p + Vector2(-2,-14),p + Vector2(-2,-5),p + Vector2(-6,-5)]), color.lightened(0.22))
	_poly(PackedVector2Array([p + Vector2(3,-13),p + Vector2(7,-14),p + Vector2(7,-4),p + Vector2(3,-5)]), color.darkened(0.28))
	draw_line(p + Vector2(-7,-5),p + Vector2(7,-5), Color("604632"), 2.5, true)
	draw_circle(p + Vector2(0,-5), 1.6, Color("e2c077"))
	_outline_circle(p + Vector2(0, -21), 7.5, Color("b9895a"))
	draw_circle(p + Vector2(-2,-23), 5.7, Color("e9c58f"))
	draw_line(p + Vector2(-4,-22),p + Vector2(-1,-22), INK, 1.5, true)
	draw_line(p + Vector2(2,-22),p + Vector2(4,-22), INK, 1.5, true)
	draw_arc(p + Vector2(0, -21), 7, PI, TAU, 12, INK, 3)
	if hero:
		var cape := P1 if owner == "p1" else P2
		_poly(PackedVector2Array([p + Vector2(-8, -14), p + Vector2(-13, -2), p + Vector2(-2, -4)]), cape)
	var hand := p + Vector2(8 if facing.x >= 0 else -8, -12)
	var blade := Vector2.from_angle(facing.angle() - 1.2 + attack * 2.4) * 19 if attack > 0 else Vector2(2,-15)
	draw_line(hand, hand + blade, INK, 5, true)
	draw_line(hand, hand + blade, Color("dce4d5"), 2.5, true)
	if attack > 0:
		draw_arc(hand, 18, facing.angle()-1.1, facing.angle()+attack*1.7, 18, Color(1,0.91,0.7,0.5),3,true)

func _hero(hero: Dictionary) -> void:
	var p := screen(hero.pos)
	if hero.hp <= 0:
		draw_line(p + Vector2(-10, -2), p + Vector2(9, -2), P1 if hero.owner == "p1" else P2, 8)
		_label(p + Vector2(-15, -15), "倒地", 12)
		return
	var bob := sin(clock * 6) * 1.5 if hero.pos.distance_to(hero.target) > 0.1 else 0.0
	var spec: Dictionary = session.match_model.cfg.heroes[hero.kind]
	var hurt: bool = hero.hit_until > session.match_model.state.time
	var attack := maxf(0, (hero.attack_until - session.match_model.state.time) / 0.24)
	HeroArt.paint(self, p, hero.kind, Color(spec.color).lightened(0.65) if hurt else Color(spec.color), clock, hero.pos.distance_to(hero.target) > 0.1, attack, hero.facing, 0.92)
	if not hero.cast.is_empty():
		_ellipse(p, Vector2(22,12),Color(spec.color,0.23))
		draw_arc(p + Vector2(0,-10), 20, clock*4, clock*4+PI*1.5,28,Color(spec.color).lightened(0.3),2,true)
	if not hero.blocked_ids.is_empty():
		_ellipse(p+Vector2(0,3), Vector2(17,8),Color(0.9,0.78,0.4,0.18))
		for id in hero.blocked_ids:
			if session.match_model.state.enemies.has(id):
				draw_line(p+Vector2(0,-9),screen(session.match_model.state.enemies[id].pos)+Vector2(0,-9),Color(0.92,0.78,0.48,0.35),1.5,true)
	if hero.get("ward_end", 0) > session.match_model.state.time:
		draw_arc(p + Vector2(0,-10), 20, 0, TAU, 32, Color("cde6ac"), 2, true)
	_label(p + Vector2(-10, -34), "", 11, Color("fff1c3"))
	_health(p + Vector2(-15, -52), 30, float(hero.hp / hero.max_hp), Color("74c2b2"), float(hero.previous_hp / hero.max_hp) if hero.hit_until + 0.3 > session.match_model.state.time else -1.0)
	if hero.owner == session.player:
		draw_arc(p + Vector2(0, 2), 14, 0, TAU, 24, Color("f8e6a6"), 2)

func _enemy(enemy: Dictionary) -> void:
	var p := screen(display_positions.get(enemy.id, enemy.pos))
	var spec: Dictionary = session.match_model.cfg.enemies[enemy.kind]
	var frozen: bool = enemy.frost_end > session.match_model.state.time
	var hurt: bool = enemy.hit_until > session.match_model.state.time
	if hurt:
		p += enemy.hit_dir * sin((enemy.hit_until - session.match_model.state.time) / 0.14 * PI) * 4
	var bob := 0.0 if enemy.blocked or enemy.stun_end > session.match_model.state.time else sin(clock * 8 + int(enemy.id)) * 2
	if enemy.kind == "flyer":
		_ellipse(p + Vector2(0, 5), Vector2(12, 4), Color(0.1, 0.15, 0.08, 0.25))
		p.y -= 18 + sin(clock * 6) * 3
		_poly(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(-22, -13 - bob), p + Vector2(-17, 2)]), Color("886d92"))
		_poly(PackedVector2Array([p + Vector2(4, -4), p + Vector2(22, -13 - bob), p + Vector2(17, 2)]), Color("886d92"))
		_outline_circle(p + Vector2(0, -2), 8, Color("646d57"))
	elif session.match_model.is_boss(enemy.kind):
		_ellipse(p + Vector2(0, 5), Vector2(23, 7), Color(0.1, 0.15, 0.08, 0.3))
		_poly(PackedVector2Array([p + Vector2(-20, -29), p + Vector2(20, -29), p + Vector2(15, 1), p + Vector2(-15, 1)]), Color("d4d7cf") if hurt else Color("706c65"))
		_outline_circle(p + Vector2(0, -36), 13, Color("9d9380"))
		draw_line(p + Vector2(-7, -39), p + Vector2(-2, -39), Color("f29c62"), 3)
		draw_line(p + Vector2(2, -39), p + Vector2(7, -39), Color("f29c62"), 3)
		draw_line(p + Vector2(-15, -15), p + Vector2(-25, -1), INK, 9)
		if enemy.kind=="rift_lord":
			_poly(PackedVector2Array([p+Vector2(-18,-25),p+Vector2(-12,3),p+Vector2(0,-3),p+Vector2(12,3),p+Vector2(18,-25),p+Vector2(0,-12)]),Color("6d4b86"))
			draw_line(p+Vector2(26,-5),p+Vector2(26,-57),Color("bca48a"),4,true)
			_outline_circle(p+Vector2(26,-61),7,Color("b787e1"))
			_poly(PackedVector2Array([p+Vector2(-15,-43),p+Vector2(-19,-64),p+Vector2(-7,-53),p+Vector2(0,-69),p+Vector2(8,-53),p+Vector2(20,-64),p+Vector2(15,-43)]),Color("9272bc"))
			draw_arc(p+Vector2(0,-17),29,0,TAU,32,Color("d7bfff") if enemy.get("seal_open",0)<=session.match_model.state.time else Color("ffe083"),3,true)
			_label(p+Vector2(-45,-78),"破印弱点" if enemy.get("seal_open",0)>session.match_model.state.time else "双方交替破印",12,Color("ead8ff"))
			_label(p+Vector2(-34,-97),"裂隙领主",14,Color("e1baff"))
	else:
		p.y += bob
		var color := Color("798c5b")
		if enemy.kind == "heavy":
			color = Color("92958c")
		elif enemy.kind == "assassin":
			color = Color("aa6c6a")
		elif enemy.kind == "mender":
			color = Color("77b98f")
		elif enemy.kind == "warden":
			color = Color("b49c5f")
		elif enemy.kind == "elite":
			color = Color("87758f")
		elif enemy.kind=="saboteur":color=Color("ab794f")
		elif enemy.kind=="splitter":color=Color("549d7e")
		_person(p, color.lightened(0.7) if hurt else color, "", false, maxf(0,(enemy.attack_until-session.match_model.state.time)/0.22), Vector2.LEFT)
		if enemy.kind == "assassin":
			_poly(PackedVector2Array([p+Vector2(-10,-22),p+Vector2(0,-34),p+Vector2(10,-22),p+Vector2(6,-26),p+Vector2(-5,-27)]), Color("824c50"))
			_poly(PackedVector2Array([p+Vector2(-6,-19),p+Vector2(6,-19),p+Vector2(4,-15),p+Vector2(-4,-15)]), Color("4b363a"))
		elif enemy.kind == "infantry":
			draw_arc(p+Vector2(0,-24),8,PI,TAU,16,Color("515f45"),4,true)
		elif enemy.kind=="saboteur":
			draw_line(p+Vector2(9,-5),p+Vector2(18,-31),Color("d6b76e"),4,true)
			draw_arc(p+Vector2(18,-32),6,0,PI,12,Color("dbc8ac"),4,true)
			if enemy.get("jam_cast",0)>session.match_model.state.time:_label(p+Vector2(-28,-43),"干扰蓄力",11,Color("ffc686"))
		elif enemy.kind=="splitter":
			_ellipse(p+Vector2(0,-16),Vector2(14,15),Color("69ab87"))
			for i in range(4):draw_circle(p+Vector2(-8+i*5,-13-(i%2)*9),3,Color("c5dd80"))
		elif enemy.kind == "elite":
			draw_line(p+Vector2(-6,-29),p+Vector2(-10,-37), Color("d9c798"),3,true)
			draw_line(p+Vector2(6,-29),p+Vector2(10,-37), Color("d9c798"),3,true)
		if enemy.kind in ["heavy", "elite"]:
			_poly(PackedVector2Array([p + Vector2(-11, -18), p + Vector2(-3, -18), p + Vector2(-4, -7), p + Vector2(-9, -3)]), Color("b9ae8b"))
			_outline_circle(p + Vector2(0, -21), 7, color)
	if enemy.stun_end > session.match_model.state.time:
		for i in range(3):
			draw_circle(p + Vector2(cos(clock*4+i*TAU/3)*11, -36+sin(clock*4+i*TAU/3)*3),2,Color("f8d577"))
	if frozen:
		draw_arc(p + Vector2(0, -12), 17 if enemy.kind != "boss" else 30, 0, TAU, 20, Color("97def1"), 2)
	if enemy.get("shield", 0) > 0:
		draw_arc(p + Vector2(0, -12), 21, 0, TAU, 28, Color("e6ca79"), 3, true)
	if enemy.get("relay_end", 0) > session.match_model.state.time:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0,-48), p + Vector2(-7,-40), p + Vector2(0,-32), p + Vector2(7,-40)]), Color("f4df78"))
	if enemy.mark_end > session.match_model.state.time:
		draw_line(p + Vector2(-4, -37), p + Vector2(4, -29), Color("ffdc73"), 2)
		draw_line(p + Vector2(4, -37), p + Vector2(-4, -29), Color("ffdc73"), 2)
	if enemy.boss_cast > session.match_model.state.time:
		_ellipse(p, SCALE * 2, Color(1, 0.2, 0.1, 0.18))
		draw_arc(p, 38, 0, TAU, 32, Color("ff7055"), 3, true)
		_label(p + Vector2(-42, -69), "巨像蓄力 %.1fs" % (enemy.boss_cast - session.match_model.state.time), 14, Color("ffe0a0"))
	if enemy.kind in ["flyer", "assassin"] and session.match_model.cfg.route_length(enemy.route) - enemy.s < 6:
		draw_arc(p, 19, 0, TAU, 24, Color("ff7055"), 2, true)
		_label(p + Vector2(-12, -45), "危险", 12, Color("ffe0a0"))
	if enemy.kind=="rift_lord" and enemy.get("pulse_cast",0)>session.match_model.state.time:
		_ellipse(screen(enemy.pulse_pos),SCALE*2.3,Color(.9,.2,.7,.2))
		_label(screen(enemy.pulse_pos)+Vector2(-35,30),"震荡：离开圈内",12,Color("ff9ade"))
	var health_y := -55 if session.match_model.is_boss(enemy.kind) else -30
	_health(p + Vector2(-12, health_y), 24, float(enemy.hp / enemy.max_hp), Color("bc6751"), float(enemy.previous_hp / enemy.max_hp) if enemy.hit_until + 0.3 > session.match_model.state.time else -1.0)

func _draw_mechanism() -> void:
	var m=session.match_model
	var q:Dictionary=m.state.get("mechanism",{})
	var kind:String=q.get("kind","")
	if kind.is_empty():return
	var p:Vector2=screen(m.cfg.vector(m.cfg.levels[m.cfg.level_id].mechanism.position))
	if kind=="escort":
		if not q.get("cart_active",false) or q.cart_done:return
		p=screen(m.cfg.route_position("a_default",q.cart_s))
		draw_rect(Rect2(p+Vector2(-15,-20),Vector2(30,20)),Color("b8894c"))
		draw_line(p+Vector2(-15,-10),p+Vector2(15,-10),INK,2)
		for x in [-12,12]:_outline_circle(p+Vector2(x,3),6,Color("dfc68e"))
		_health(p+Vector2(-18,-32),36,q.cart_hp/100,Color("78c98d"))
		_label(p+Vector2(-35,30),"靠近护送",12,Color("e4edb9"))
	else:
		_outline_circle(p,17,Color("80dbe9") if kind=="lock" else Color("cda768"))
		_poly(PackedVector2Array([p+Vector2(0,-18),p+Vector2(-10,0),p+Vector2(0,12),p+Vector2(10,0)]),Color("72afc8") if kind=="lock" else Color("947046"))
		_label(p+Vector2(-24,34),"晶核" if kind=="lock" else "岔路道闸",12)
		if kind=="lock" and q.lock_end>m.state.time and not q.unsealed:
			for node in q.nodes:
				var point:Vector2=screen(m.cfg.vector(m.cfg.nodes[node].position))
				draw_arc(point,29,0,TAU,28,Color("d5a4ec"),2,true)
				_label(point+Vector2(-30,38),"封锁" if m.state.time>=q.lock_at else "封锁预警",12,Color("ecbcff"))

func _health(pos: Vector2, width: float, value: float, color: Color, previous := -1.0) -> void:
	draw_rect(Rect2(pos - Vector2.ONE, Vector2(width + 2, 5)), INK)
	if previous >= 0:
		draw_rect(Rect2(pos, Vector2(width * clampf(previous, 0, 1), 3)), Color("dfbc74"))
	draw_rect(Rect2(pos, Vector2(width * clampf(value, 0, 1), 3)), color)

func _effect(effect: Dictionary, now: float) -> void:
	var p := screen(effect.pos)
	var life := clampf((now - float(effect.start)) / maxf(0.01, float(effect.end) - float(effect.start)), 0, 1)
	var fade := 1 - life
	if effect.has("tower_kind"):
		TowerFX.cast(self,p,screen(effect.from),effect,life,SCALE,effect_quality)
		return
	var color := Color("f4c169")
	if effect.kind in ["shatter", "frost_ring", "frost_hit"]:
		color = Color("b3f2fa")
	color.a = fade
	match effect.kind:
		"ultimate": return
		"heal":
			draw_line(p+Vector2(-6,-36),p+Vector2(6,-36),Color(.6,1,.7,fade),3,true)
			draw_line(p+Vector2(0,-42),p+Vector2(0,-30),Color(.6,1,.7,fade),3,true)
		"damage":
			if not damage_numbers or damage_rects.size() >= 10 or int(effect.amount) < 35: return
			var text := str(effect.amount)
			var text_pos := p + Vector2(-10, -34 - life * 23)
			var tint := Color("b6e6fa") if effect.get("type", "") == "magic" else (Color("fff2a7") if effect.get("type", "") == "true" else Color("fff1cf"))
			var size := 14 if int(effect.amount) >= 80 else 11
			var origin := text_pos
			var placed := false
			var bounds := Rect2(text_pos - Vector2(2, size), Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 4, size + 5))
			for attempt in range(25):
				var column: int = [0, -1, 1, -2, 2][attempt % 5]
				text_pos = origin + Vector2(column * 40, -floori(attempt / 5.0) * 27)
				bounds.position = text_pos - Vector2(2, size)
				var overlap := false
				for previous in damage_rects:
					if bounds.intersects(previous) or (menu_rect.has_area() and bounds.intersects(menu_rect)):
						overlap = true
						break
				if not overlap and Rect2(24, 112, 954, 576).encloses(bounds):
					placed = true
					break
			if not placed: return
			damage_rects.append(bounds)
			draw_string_outline(font,text_pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,2,Color(0.12,0.12,0.1,fade))
			draw_string(font,text_pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(tint,fade * 0.72))
		"hit", "block":
			for i in range(6):
				var direction := Vector2.from_angle(i*TAU/6 + float(effect.get("id",0))*0.7)
				draw_line(p + Vector2(0,-12) + direction*4,p+Vector2(0,-12)+direction*(7+life*12),Color("f8edcf")*Color(1,1,1,fade),1.8,true)
		"slash":
			var center := screen(effect.get("from", effect.pos)) + Vector2(0,-12)
			var angle := (p-center).angle()
			draw_arc(center,24+life*8,angle-1.2,angle+0.9,24,Color(1,.91,.68,fade),4,true)
		"cast", "telegraph":
			var radius := float(effect.get("radius", 0.7))
			var tint := Color("8edbff") if effect.get("skill", "") == "frost_nova" else Color("f1b26a")
			_ellipse(p,SCALE*radius,Color(tint,0.1+life*0.1))
			var points := PackedVector2Array()
			for i in range(65):
				points.append(p+Vector2.from_angle(i*TAU/64)*SCALE*radius*(0.7+life*.3))
			draw_polyline(points,Color(tint,.8),2,true)
			if effect.kind == "cast":
				draw_line(p+Vector2(0,3),p+Vector2(0,-30-life*18),Color(tint,.5),5,true)
			elif effect.get("skill", "") == "meteor":
				var meteor := p + Vector2(-42, -175) * (1 - life)
				draw_line(meteor + Vector2(-19, -65), meteor, Color(1, .45, .12, .4), 13, true)
				draw_line(meteor + Vector2(-10, -40), meteor, Color(1, .76, .25, .8), 7, true)
				draw_circle(meteor, 12, Color(1, .4, .12, .3))
				draw_circle(meteor, 7, Color("ffcf75"))
				draw_circle(meteor, 4, Color("fff7d3"))
		"hero_skill":
			var skill: String = effect.skill
			var radius := float(effect.radius)
			var tint := Color("9fe8ff") if skill == "frost_nova" else (Color("bdacff") if skill == "thunderstorm" else Color("ffc770"))
			_ellipse(p,SCALE*radius*(.5+life),Color(tint,.18*fade))
			for ring in range(2):
				var points := PackedVector2Array()
				for i in range(65):
					points.append(p+Vector2.from_angle(i*TAU/64)*SCALE*radius*(.2+life*.9+ring*.15))
				draw_polyline(points,Color(tint,fade),3-ring,true)
			for i in range(12):
				var direction := Vector2.from_angle(i*TAU/12)
				var ep := p + direction * SCALE * radius * (.3 + life*.7)
				if skill == "frost_nova":
					draw_colored_polygon(PackedVector2Array([ep+Vector2(-4,5),ep+Vector2(0,-18*fade),ep+Vector2(6,4)]),Color(tint,fade * 0.72))
				elif skill == "arrow_storm":
					draw_line(ep+Vector2(8,-40*fade),ep+Vector2(0,-3),Color("f6e1aa")*Color(1,1,1,fade),2,true)
				elif skill == "thunderstorm":
					if i%2==0:
						draw_polyline(PackedVector2Array([ep+Vector2(-10,-85*fade),ep+Vector2(8,-51*fade),ep+Vector2(-6,-32*fade),ep]),Color(tint,fade),3,true)
				else:
					draw_circle(ep+Vector2(0,-sin(life*PI)*14),3+fade*2,Color(tint,fade * 0.72))
			if skill == "meteor":
				_ellipse(p + Vector2(0, -8), Vector2(30, 19) * (1 + life), Color(1, .51, .15, fade * .35))
				for i in range(4):
					_ellipse(p+Vector2((i-2)*13,-12-life*30),Vector2(17+life*14,11+life*7),Color(.38,.31,.22,fade*.35))
			if life < .12:
				_ellipse(p+Vector2(0,-10),Vector2(20,14),Color(1,1,.88,fade*.7))
		"dash":
			draw_line(p+Vector2(0,-12),screen(effect.to)+Vector2(0,-12),Color(1,.63,.22,fade),10*fade,true)
		"death", "hero_down":
			_ellipse(p+Vector2(2,3),Vector2(12,5),Color(.12,.13,.09,fade*.3))
			draw_line(p+Vector2(-10,-3),p+Vector2(8,-1),Color(.47,.44,.34,fade),7*fade,true)
			for i in range(5):
				var ep := p+Vector2.from_angle(i*TAU/5)*life*18
				draw_circle(ep,2.5*fade,Color(.82,.75,.55,fade))
		"level_up":
			draw_arc(p,14+life*24,0,TAU,32,Color(.98,.86,.43,fade),3,true)
			for i in range(6):
				var ep := p+Vector2((i-3)*6,-15-life*40)
				draw_line(ep,ep+Vector2(0,-7),Color(1,.94,.61,fade),2,true)
			_label(p+Vector2(-18,-43-life*20),"升级!",16,Color(1,.94,.61,fade))
		"shatter":
			for i in range(8):
				var direction := Vector2.from_angle(i*TAU/8)
				draw_line(p+direction*5,p+direction*(10+life*38),color,3,true)
			_label(p+Vector2(-20,-40-life*12),"冰碎!",16,color)
		"crit": _label(p+Vector2(-12,-38-life*15),"暴击!",14,color)
		"lightning":
			draw_polyline(PackedVector2Array([p+Vector2(-3,-58),p+Vector2(7,-36),p+Vector2(-5,-24),p+Vector2(3,-5)]),Color(.84,.8,1,fade),3,true)
		_:
			draw_arc(p,8+life*(45 if effect.kind in ["frost_ring","warning","blast"] else 20),0,TAU,24,color,3,true)
			if effect.kind == "blast":
				for i in range(7):
					draw_circle(p+Vector2.from_angle(i*TAU/7)*life*25,3*fade,Color("f1bf68")*Color(1,1,1,fade))

func _draw_stage_event(state: Dictionary) -> void:
	var event: Dictionary = state.get("stage_event", {})
	if event.is_empty() or event.end <= state.time: return
	var active: bool = event.active_at <= state.time
	var tint := Color("79d3dc") if event.kind in ["snow", "relay", "tide", "icefall"] else (Color("c6a0ee") if event.kind == "eclipse" else Color("efaa69"))
	if not event.solved and event.kind in ["snow", "ember", "thorn", "sand", "icefall", "eclipse"]:
		var p := screen(event.hazard)
		_ellipse(p, SCALE * 3, Color(tint, 0.18 if active else 0.08))
		draw_arc(p, 60, 0, TAU, 40, tint, 2, true)
		_label(p + Vector2(-40, -68), event.name + (" !" if active else " · 预警"), 13, tint.lightened(0.25))
	if event.solved: return
	for i in range(event.beacons.size()):
		var p := screen(event.beacons[i])
		draw_arc(p, 27, 0, TAU, 32, Color("8bd8c1"), 2, true)
		draw_arc(p, 31, -PI/2, -PI/2 + TAU * minf(1, float(event.progress)/3), 32, Color("fff0b4"), 4, true)
		_label(p + Vector2(-23, 43), "信标 " + str(i + 1), 12, Color("dbf2d9"))
	if menu_rect.has_area():
		var p := screen(session.match_model.cfg.vector(session.match_model.cfg.nodes[selected].position)) if not selected.is_empty() else Vector2.ZERO
		if p != Vector2.ZERO: draw_line(p, Vector2(menu_rect.position.x if menu_rect.position.x > p.x else menu_rect.end.x, clampf(p.y, menu_rect.position.y, menu_rect.end.y)), Color("e1c68d"), 2, true)

func _draw_landmark(kind: String) -> void:
	if kind.is_empty(): return
	if kind in ["moon", "stars"]:
		draw_rect(Rect2(23,110,955,580),Color(.08,.12,.25,.17 if kind == "moon" else .28))
	if kind == "moon":
		for center in [Vector2(14,3),Vector2(16,21)]:
			var p := screen(center)
			_ellipse(p,Vector2(71,24),Color("3c657b"))
			_ellipse(p+Vector2(-3,-2),Vector2(63,19),Color("6897a9"))
			for i in range(4): draw_arc(p+Vector2(i*13-20,0),18,0.2,2.9,20,Color(.8,.92,1,.35),1.2,true)
	elif kind == "temple":
		for point in [Vector2(15,3),Vector2(17,21)]:
			var p := screen(point)
			_ellipse(p+Vector2(0,11),Vector2(57,17),Color(0.3,0.2,0.1,0.18))
			_poly(PackedVector2Array([p+Vector2(-46,5),p+Vector2(0,-47),p+Vector2(46,5)]),Color("ae986c"))
			_poly(PackedVector2Array([p+Vector2(0,-47),p+Vector2(46,5),p+Vector2(0,5)]),Color("8b7354"))
			for i in range(3): draw_line(p+Vector2(-29+i*8,-i*10),p+Vector2(28-i*8,-i*10),Color("ddc68f"),2,true)
			draw_rect(Rect2(p+Vector2(-8,-12),Vector2(16,19)),Color("54483b"))
	elif kind == "crystal":
		for point in [Vector2(15,3),Vector2(17,21)]:
			var p := screen(point)
			for i in range(3):
				var q := p+Vector2((i-1)*19,abs(i-1)*8)
				_poly(PackedVector2Array([q+Vector2(0,-49),q+Vector2(-10,-22),q+Vector2(-8,6),q+Vector2(9,4),q+Vector2(13,-18)]),Color("86d3db"))
				_poly(PackedVector2Array([q+Vector2(0,-49),q+Vector2(-10,-22),q+Vector2(-8,6),q+Vector2(0,-7)]),Color("d5f6f2"))
	elif kind == "stars":
		for point in [Vector2(15,3),Vector2(17,21)]:
			var p := screen(point)
			draw_arc(p,39,0,TAU,48,Color("b19acb"),3,true)
			draw_arc(p,33,0,TAU,48,Color("e4ceef"),1.5,true)
			for i in range(6):
				var q := p+Vector2.from_angle(i*TAU/6)*30
				_poly(PackedVector2Array([q+Vector2(0,-5),q+Vector2(-4,1),q+Vector2(0,4),q+Vector2(4,1)]),Color("bde4ef"))

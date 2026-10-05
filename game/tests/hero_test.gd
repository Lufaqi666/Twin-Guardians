extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
const Rules = preload("res://scripts/core/hero_rules.gd")
const Career = preload("res://scripts/core/career.gd")
var count := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	count += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func setup(kind: String, xp := 0):
	var m = Match.new()
	m.set_hero("p1", kind, {"xp": xp})
	m.state.heroes.p2.pos = Vector2(30, 20)
	m.state.heroes.p2.target = Vector2(30, 20)
	m.state.heroes.p1.pos = Vector2(16, 12)
	m.state.heroes.p1.target = Vector2(16, 12)
	return m

func enemy(m, kind := "infantry", offset := Vector2.ZERO) -> Dictionary:
	var id: int = m.spawn(kind, "a")
	var e: Dictionary = m.state.enemies[id]
	e.pos = Vector2(16, 12) + offset
	e.hp = 10000.0
	e.attack_at = 100.0
	return e

func hit(m, e: Dictionary, nth := 3) -> void:
	m._hero_hit(m.state.heroes.p1, e, {"damage": 100.0, "damage_type": "true", "nth": nth})

func run() -> void:
	var m = setup("commander")
	var h: Dictionary = m.state.heroes.p1
	var base_hp: float = h.max_hp
	m._gain_xp(h, 80)
	check(h.level == 2 and h.skill_points == 1 and h.max_hp > base_hp, "XP grows stats and grants point at level 2")
	var before: float = Rules.skill_damage(h)
	check(m.command("p1", "hero_upgrade", {}, "rank-one").accepted, "upgrade consumes earned point")
	m.command("p1", "hero_upgrade", {}, "rank-one")
	check(h.skill_level == 2 and h.skill_points == 0 and Rules.skill_damage(h) > before, "duplicate upgrade is idempotent")
	check(Rules.skill_cooldown(h) < h.skill.cooldown, "upgrade shortens cooldown")
	m._gain_xp(h, 280)
	check(h.level == 4 and h.skill_points == 1, "level 4 grants final skill point")
	check(m.command("p1", "hero_upgrade", {}, "rank-two").accepted and h.skill_level == 3, "skill reaches rank 3")
	check(not m.command("p1", "hero_upgrade", {}, "rank-three").accepted, "rank 3 cap enforced")
	h.hp = 0
	m._gain_xp(h, 2000)
	check(h.level == 8 and h.xp == 1400 and h.hp == 0, "XP cap and no level-up revival")
	check(Rules.normalize({"xp": -10, "skill_level": 99}) == {"xp": 0, "skill_level": 1}, "invalid profile normalized")
	m.reset()
	check(m.state.heroes.p1.level == 8 and m.state.heroes.p1.skill_level == 3, "restart retains progress")
	m = setup("skirmisher")
	h = m.state.heroes.p1
	var e := enemy(m)
	var hp: float = h.hp
	e.attack_at = 0
	m._soldiers(0.05)
	m._hero_blocks()
	check(e.blocked and e.blocker == "hero_p1" and h.hp < hp, "ground enemy blocked and retaliates against hero")
	var s: float = e.s
	m._move_enemies(0.1)
	check(e.s == s, "blocked enemy cannot advance")
	h.target += Vector2(3, 0)
	m._soldiers(0.05)
	m._hero_blocks()
	check(not e.blocked and h.blocked_ids.is_empty(), "moving hero releases enemies")
	for kind in ["commander", "skirmisher", "sentinel"]:
		m = setup(kind)
		for i in range(5):
			enemy(m, "infantry", Vector2(i * 0.05, 0))
		m._soldiers(0.05)
		m._hero_blocks()
		check(m.state.heroes.p1.blocked_ids.size() == int(m.cfg.heroes[kind].block_capacity), kind + " block capacity")
	m = setup("sentinel", 800)
	for i in range(5):
		enemy(m)
	m._soldiers(0.05)
	m._hero_blocks()
	check(m.state.heroes.p1.blocked_ids.size() == 4, "level 6 sentinel extra blocking slot")
	m = setup("sentinel")
	e = enemy(m, "flyer")
	var boss := enemy(m, "boss")
	m._soldiers(0.05)
	m._hero_blocks()
	check(not e.blocked and not boss.blocked, "air bypasses hero and low level cannot block boss")
	m._gain_xp(m.state.heroes.p1, 560)
	m._soldiers(0.05)
	m._hero_blocks()
	check(boss.blocked and not e.blocked, "level 5 sentinel can block boss")
	m.state.heroes.p1.hp = 1
	boss.attack_at = 0
	m._soldiers(0.05)
	m._hero_blocks()
	check(m.state.heroes.p1.hp <= 0 and not boss.blocked, "death releases blocked enemies immediately")
	m = setup("commander")
	e = enemy(m)
	hit(m, e)
	check(e.frost_end > m.state.time, "commander third strike freezes")
	m = setup("skirmisher")
	e = enemy(m)
	m.state.heroes.p1.hp -= 100
	hp = m.state.heroes.p1.hp
	hit(m, e)
	check(m.state.heroes.p1.hp > hp and e.hp <= 9840, "skirmisher lifesteal and true damage third strike")
	m = setup("sentinel", 200)
	e = enemy(m)
	hp = m.state.heroes.p1.hp
	m._hurt_hero(m.state.heroes.p1, e, 100)
	check(is_equal_approx(hp - m.state.heroes.p1.hp, 70) and is_equal_approx(e.hp, 9980), "sentinel armor and reflection")
	m = setup("ranger", 800)
	e = enemy(m)
	hit(m, e)
	check(is_equal_approx(e.hp, 9800) and e.mark_end > 0, "ranger double shot and high level mark")
	m = setup("pyromancer")
	e = enemy(m)
	hit(m, e)
	check(m.state.zones.size() == 1 and m.state.zones[0].radius == 0.55, "pyromancer attacks leave burn zone")
	m = setup("stormcaller")
	e = enemy(m)
	var nearby: Array = []
	for i in range(3):
		nearby.append(enemy(m, "infantry", Vector2(0.2 + i * 0.2, 0)))
	hit(m, e)
	check(nearby[0].hp < 10000 and nearby[1].hp < 10000 and nearby[2].hp == 10000, "stormcaller arcs to exactly two enemies")
	m = setup("ranger")
	e = enemy(m, "infantry", Vector2(2, 0))
	m._heroes_attack()
	check(e.hp == 10000 and m.state.projectiles.size() == 1, "ranged damage waits for projectile")
	m._projectiles(0.5)
	check(e.hp < 10000 and m.state.projectiles.is_empty(), "projectile deals damage on arrival")
	m = setup("pyromancer")
	e = enemy(m)
	m.command("p1", "skill", {"key": "q", "pos": e.pos}, "cast")
	m._hurt_hero(m.state.heroes.p1, e, 10000)
	m.state.time += 1
	m._resolve_casts()
	check(e.hp == 10000 and m.state.heroes.p1.cast.is_empty(), "death cancels pending skill")
	m = setup("commander")
	e = enemy(m)
	e.hp = 0
	m._resolve_deaths()
	var xp: int = m.state.heroes.p1.xp
	m._resolve_deaths()
	check(xp == 6 and m.state.heroes.p1.xp == xp and m.state.heroes.p2.xp == xp, "kill XP shared once between both heroes")
	var career = Career.new()
	career.path = ProjectSettings.globalize_path("res://../.work/tests/hero_growth_test.json")
	DirAccess.remove_absolute(career.path)
	career.record("p1", {"kind": "ranger", "xp": 200, "skill_level": 2})
	check(career.write() == OK, "career writes first save")
	career.record("p1", {"kind": "ranger", "xp": 360, "skill_level": 3})
	check(career.write() == OK, "career atomically replaces existing save")
	var loaded = Career.new()
	loaded.path = career.path
	loaded.read()
	check(loaded.profile("p1", "ranger") == {"xp": 360, "skill_level": 3}, "career reload retains XP and skill rank")
	check(loaded.profile("p2", "ranger").xp == 0, "player careers remain independent")
	loaded.record("p1", {"kind": "ranger", "xp": 0, "skill_level": 1})
	check(loaded.profile("p1", "ranger").xp == 360, "older match cannot roll back progress")
	DirAccess.remove_absolute(career.path)
	print("HERO: %d/%d passed" % [count - failures.size(), count])
	quit(0 if failures.is_empty() else 1)

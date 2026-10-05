extends RefCounted

const XP = [0, 80, 200, 360, 560, 800, 1080, 1400]

static func level_for(xp: int) -> int:
	var level := 1
	for threshold in XP:
		if xp >= threshold:
			level += 1
	return mini(8, level - 1)

static func rank_cap(level: int) -> int:
	return 1 + (1 if level >= 2 else 0) + (1 if level >= 4 else 0)

static func normalize(profile: Dictionary) -> Dictionary:
	var xp := clampi(int(profile.get("xp", 0)), 0, 1400)
	var rank := clampi(int(profile.get("skill_level", 1)), 1, rank_cap(level_for(xp)))
	return {"xp": xp, "skill_level": rank}

static func create(owner: String, kind: String, spec: Dictionary, profile: Dictionary, pos: Vector2) -> Dictionary:
	var progress := normalize(profile)
	var level := level_for(progress.xp)
	var hp := float(spec.hp) * (1 + 0.12 * (level - 1))
	return {"kind": kind, "owner": owner, "pos": pos, "target": pos, "hp": hp, "max_hp": hp, "damage": float(spec.damage) * (1 + 0.1 * (level - 1)), "xp": progress.xp, "level": level, "skill_level": progress.skill_level, "skill_points": rank_cap(level) - progress.skill_level, "skill": spec.skill.duplicate(true), "attack_at": 0.0, "q_at": 0.0, "revive_at": 0.0, "rescue": 0.0, "rescue_progress": 0.0, "ward_end": 0.0, "hit_until": 0.0, "attack_until": 0.0, "last_hurt": -10.0, "cast": {}, "cast_until": 0.0, "attack_count": 0, "facing": Vector2.RIGHT, "blocked_ids": [], "previous_hp": hp, "talent": ""}

static func skill_damage(hero: Dictionary) -> float:
	return float(hero.skill.damage) * (1 + 0.35 * (int(hero.skill_level) - 1)) * (1 + 0.08 * (int(hero.level) - 1)) * (1.25 if hero.get("talent", "") == "assault" else (0.85 if hero.get("talent", "") == "support" else 1.0))

static func skill_cooldown(hero: Dictionary) -> float:
	return float(hero.skill.cooldown) * (1 - 0.08 * (int(hero.skill_level) - 1)) * (1.1 if hero.get("talent", "") == "assault" else 1.0)

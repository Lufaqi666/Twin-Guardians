extends RefCounted

var map: Dictionary
var rules: Dictionary
var tower_rules: Dictionary
var towers: Dictionary = {}
var enemies: Dictionary = {}
var heroes: Dictionary = {}
var nodes: Dictionary = {}
var waves: Array = []
var config_hash := ""
var errors: Array[String] = []
var levels: Dictionary = {}
var level_id := "confluence_courtyard"
var maps: Dictionary = {}
var wave_sets: Dictionary = {}
const HeroRules = preload("res://scripts/core/hero_rules.gd")

func _init() -> void:
	var files := ["maps/confluence_courtyard.json", "rules.json", "towers.json", "enemies.json", "heroes.json", "waves/courtyard_normal.json"]
	var data := {}
	var content := ""
	for file in files:
		var text := FileAccess.get_file_as_string("res://data/" + file)
		var json := JSON.new()
		if json.parse(text) != OK or not json.data is Dictionary:
			errors.append(file + ": invalid JSON")
			continue
		data[file] = json.data
		content += file + text
		if int(json.data.get("schema_version", 0)) != 1:
			errors.append(file + ": unsupported schema")
	config_hash = content.sha256_text()
	if not errors.is_empty():
		return
	map = data[files[0]]
	rules = data[files[1]]
	tower_rules = data[files[2]]
	for row in tower_rules.towers:
		_add_unique(towers, row, "tower")
	for row in data[files[3]].enemies:
		_add_unique(enemies, row, "enemy")
	for row in data[files[4]].heroes:
		_add_unique(heroes, row, "hero")
	for row in map.nodes:
		_add_unique(nodes, row, "node")
	waves = data[files[5]].waves
	for wave in waves:
		for event in wave.events:
			if not enemies.has(event.enemy_id) or not event.entry in ["a", "b"] or float(event.time) < 0:
				errors.append("Invalid wave reference")
	for key in map.routes:
		var previous_x := -1.0
		for pos in map.routes[key]:
			if float(pos[0]) <= previous_x:
				errors.append("Route loops: " + key)
			previous_x = float(pos[0])
	var campaign_text := FileAccess.get_file_as_string("res://data/levels.json")
	var campaign = JSON.parse_string(campaign_text)
	content += campaign_text
	for level in campaign.levels:
		levels[level.id] = level
		var map_text := FileAccess.get_file_as_string("res://data/" + level.map)
		var waves_text := FileAccess.get_file_as_string("res://data/" + level.waves)
		maps[level.id] = JSON.parse_string(map_text)
		wave_sets[level.id] = JSON.parse_string(waves_text).waves
		content += map_text + waves_text
	content += FileAccess.get_file_as_string("res://scripts/core/hero_rules.gd")
	content += FileAccess.get_file_as_string("res://scripts/core/match_state.gd")
	content += FileAccess.get_file_as_string("res://scripts/core/strategy_expansion.gd")
	config_hash = content.sha256_text()
	select_level(level_id)

func select_level(id: String) -> bool:
	if not levels.has(id):
		return false
	level_id = id
	map = maps[id]
	waves = wave_sets[id]
	nodes.clear()
	for row in map.nodes:
		nodes[row.id] = row
	return true

func _add_unique(index: Dictionary, row: Dictionary, kind: String) -> void:
	if index.has(row.id):
		errors.append("Duplicate " + kind + ": " + row.id)
	index[row.id] = row

func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func route_length(id: String) -> float:
	var route: Array = map.routes[id]
	var distance := 0.0
	for i in range(1, route.size()):
		distance += vector(route[i - 1]).distance_to(vector(route[i]))
	return distance

func route_position(id: String, distance: float) -> Vector2:
	var route: Array = map.routes[id]
	for i in range(1, route.size()):
		var a := vector(route[i - 1])
		var b := vector(route[i])
		var segment := a.distance_to(b)
		if distance <= segment:
			return a.lerp(b, clampf(distance / segment, 0, 1))
		distance -= segment
	return vector(route.back())

extends RefCounted

const Rules = preload("res://scripts/core/hero_rules.gd")
var path := "user://hero_progress_v1.json"
var records: Dictionary = {}
var stage_stars: Dictionary = {}
var dirty := false
var recovered := false

func _valid_data(file_path:String) -> Dictionary:
	if not FileAccess.file_exists(file_path):return {}
	var json:=JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path))!=OK:return {}
	var data=json.data
	return data if data is Dictionary and int(data.get("version",0))==1 and data.get("heroes") is Dictionary else {}

func read() -> void:
	recovered=false
	var data:Dictionary=_valid_data(path)
	if data.is_empty():
		data=_valid_data(path+".bak")
		recovered=not data.is_empty()
		if recovered:dirty=true
	if data is Dictionary and int(data.get("version", 0)) == 1 and data.get("heroes") is Dictionary:
		for key in data.heroes:
			if data.heroes[key] is Dictionary:
				records[key] = Rules.normalize(data.heroes[key])
		var saved_stars = data.get("stage_stars", {})
		if saved_stars is Dictionary:
			for level in saved_stars:
				if saved_stars[level] is int or saved_stars[level] is float:
					stage_stars[level] = clampi(int(saved_stars[level]), 0, 3)

static func stars_for(phase: String, hp: int) -> int:
	if phase != "won" or hp <= 0: return 0
	return 3 if hp >= 18 else (2 if hp >= 10 else 1)

func record_stage(level: String, phase: String, hp: int) -> int:
	var earned := stars_for(phase, hp)
	if earned > int(stage_stars.get(level, 0)):
		stage_stars[level] = earned
		dirty = true
	return earned

func profile(owner: String, kind: String) -> Dictionary:
	return records.get(owner + ":" + kind, {"xp": 0, "skill_level": 1}).duplicate(true)

func record(owner: String, hero: Dictionary) -> void:
	var old := profile(owner, hero.kind)
	var progress := Rules.normalize({"xp": maxi(old.xp, hero.xp), "skill_level": maxi(old.skill_level, hero.skill_level)})
	if old != progress:
		records[owner + ":" + hero.kind] = progress
		dirty = true

func write() -> Error:
	if not dirty:
		return OK
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "heroes": records, "stage_stars": stage_stars}))
	file.close()
	if not _valid_data(path).is_empty():
		var backup_error:=DirAccess.copy_absolute(path,path+".bak.tmp")
		if backup_error!=OK:return backup_error
		backup_error=DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if backup_error!=OK:return backup_error
	var result := DirAccess.rename_absolute(temporary, path)
	if result == OK:
		dirty = false
	return result

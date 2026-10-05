extends RefCounted

const DEFAULT_KEYS = {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "skill": KEY_Q, "upgrade": KEY_U, "ultimate": KEY_R, "rescue": KEY_F, "ready": KEY_SPACE, "switch": KEY_TAB, "ping": KEY_G, "accept": KEY_Y, "reject": KEY_N,"tower_one":KEY_1,"tower_two":KEY_2,"tower_next":KEY_C}
const NAMES = {"up": "向上移动", "down": "向下移动", "left": "向左移动", "right": "向右移动", "skill": "英雄技能", "upgrade": "强化技能", "ultimate": "团队共鸣", "rescue": "救援队友", "ready": "准备下一波", "switch": "本机换人", "ping": "补位标记", "accept": "同意分流", "reject": "拒绝分流","tower_one":"塔技能一","tower_two":"塔技能二","tower_next":"下一座就绪塔"}
var keys: Dictionary = DEFAULT_KEYS.duplicate()
var volume := 0.7
var shake := true
var numbers := true
var tutorial := true
var effects := 2
var playtest := false
var persist := true
var path := "user://preferences_v1.json"

func read() -> void:
	if not persist or not FileAccess.file_exists(path): return
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return
	volume = clampf(float(value.get("volume", 0.7)), 0, 1)
	shake = bool(value.get("shake", true))
	numbers = bool(value.get("numbers", true))
	tutorial = bool(value.get("tutorial", true))
	effects = clampi(int(value.get("effects",2)),0,2)
	playtest = bool(value.get("playtest",false))
	var saved = value.get("keys", {})
	if not saved is Dictionary: return
	var candidate := {}
	var used := {}
	# Reserve saved bindings first; add new actions using a free key when needed.
	for action in DEFAULT_KEYS:
		if not saved.has(action):continue
		var code := int(saved.get(action, DEFAULT_KEYS[action]))
		if code <= 0 or code == KEY_ESCAPE or used.has(code): return
		candidate[action] = code
		used[code] = true
	for action in DEFAULT_KEYS:
		if candidate.has(action):continue
		var code:int=DEFAULT_KEYS[action]
		if used.has(code):
			for fallback in [KEY_1,KEY_2,KEY_C,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_J,KEY_K,KEY_L,KEY_O,KEY_P,KEY_B,KEY_H,KEY_V,KEY_X,KEY_Z]:
				if not used.has(fallback):code=fallback;break
		candidate[action]=code;used[code]=true
	keys = candidate

func bind(action: String, code: int) -> bool:
	if not keys.has(action) or code <= 0 or code == KEY_ESCAPE: return false
	var previous: int = keys[action]
	for other in keys:
		if keys[other] == code: keys[other] = previous
	keys[action] = code
	return true

func label(action: String) -> String:
	return OS.get_keycode_string(int(keys[action]))

func action_for(code: int) -> String:
	for action in keys:
		if int(keys[action]) == code: return action
	return ""

func write() -> Error:
	if not persist: return OK
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"volume": volume, "shake": shake, "numbers": numbers, "tutorial": tutorial,"effects":effects,"playtest":playtest, "keys": keys}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

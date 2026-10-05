extends SceneTree

const Session = preload("res://scripts/network/session.gd")
var session: Node
var challenge := false
var role := "host"
var started := 0.0
var stage := 0
var connected_count := 0
var reconnect_at := 0.0
var saw_pause := false

func _initialize() -> void:
	challenge = "--challenge" in OS.get_cmdline_user_args()
	role = "client" if "--client" in OS.get_cmdline_user_args() else "host"
	call_deferred("start")

func start() -> void:
	started = Time.get_ticks_msec() / 1000.0
	session = Session.new()
	session.name = "Session"
	session.persist_progress = false
	root.add_child(session)
	session.entered_game.connect(_connected)
	session.message.connect(func(text): print(role, ": ", text))
	if role == "host":
		if session.host("commander", 25980, "skywatch" if challenge else "frost_pass", {"xp": 200, "skill_level": 2}, challenge) != OK:
			quit(1)
			return
		session.match_model.command("p1", "build", {"node": "shared_01", "tower": "frost"}, "host-build")
	else:
		session.join("127.0.0.1", "stormcaller", 25980, {"xp": 80, "skill_level": 2})

func _connected() -> void:
	connected_count += 1
	if role == "client" and connected_count == 1:
		if session.match_model.cfg.level_id != ("skywatch" if challenge else "frost_pass") or session.match_model.state.challenge != challenge or session.match_model.state.heroes.p2.kind != "stormcaller" or session.match_model.state.heroes.p1.skill.id != "frost_nova" or session.match_model.state.heroes.p2.skill.id != "thunderstorm" or session.match_model.state.heroes.p2.level != (4 if challenge else 2) or session.match_model.state.heroes.p2.skill_level != (3 if challenge else 2):
			printerr("CLIENT map or fixed hero growth handshake mismatch")
			quit(1)
			return
		print("CLIENT verified selected level, independent heroes and fixed skill and hero growth baseline")
		session.submit("build", {"node": "shared_02", "tower": "cannon"})
		session._request.rpc_id(1, "build", {"node": "shared_02", "tower": "cannon"}, "1")
		session.submit("build", {"node": "shared_01", "tower": "archer"})
		session.submit("transfer", {"amount": 50})
		session.submit("ping", {"pos": Vector2(24, 4), "label": "防空"})
	elif role == "client" and connected_count == 2:
		if session.match_model.state.heroes.p2.kind != "stormcaller" or session.match_model.state.heroes.p2.skill_level != (3 if challenge else 2):
			printerr("CLIENT reconnect changed original hero progression")
			quit(1)
			return
		# Sequence must continue, otherwise the new transaction hits an old cache entry.
		session.submit("build", {"node": "p2_01", "tower": "archer"})

func _process(_delta: float) -> bool:
	if not session:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - started > 20:
		printerr("NETWORK_TEST timed out: ", role, " stage ", stage)
		quit(1)
		return false
	var value: Dictionary = session.match_model.state
	if role == "host":
		if value.paused:
			saw_pause = true
		if stage == 0 and value.towers.has("shared_02") and value.gold.p2 == 500 and value.gold.p1 == 900:
			print("HOST verified atomic shared purchase, duplicate and transfer")
			stage = 1
		if stage == 1 and value.towers.has("p2_01"):
			if not saw_pause or value.gold.p2 != 100:
				printerr("HOST invalid reconnect outcome")
				quit(1)
				return false
			print("HOST verified pause, reconnect baseline, sequence continuity")
			stage = 2
			session.match_model.command("p1", "ready", {}, "host-ready")
		if stage == 2 and value.phase == "battle" and value.enemies.size() > 0:
			stage = 3
			reconnect_at = now + 1.5
		if stage == 3 and now >= reconnect_at:
			print("NETWORK_HOST_PASS")
			session.leave()
			quit(0)
	else:
		if stage == 0 and value.towers.has("shared_02") and value.gold.p2 == 500 and value.gold.p1 == 900:
			if value.pings.is_empty() or value.pings[0].label != "防空" or value.cooperation.p2.aid != 45:
				return false
			print("CLIENT verified authoritative snapshot")
			session.leave(false)
			reconnect_at = now + 0.5
			stage = 1
		if stage == 1 and now > reconnect_at:
			session.join("127.0.0.1", "skirmisher", 25980)
			stage = 2
		if stage == 2 and session.authenticated and value.towers.has("p2_01") and value.gold.p2 == 100:
			stage = 3
			session.submit("ready")
		if stage == 3 and value.phase == "battle" and value.enemies.size() > 0:
			print("NETWORK_CLIENT_PASS")
			stage = 4
		if stage == 4 and not session.authenticated:
			quit(0)
	return false

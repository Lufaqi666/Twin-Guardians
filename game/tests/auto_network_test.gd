extends SceneTree

const Session = preload("res://scripts/network/session.gd")
var session: Node
var role := "host"
var stage := 0
var connections := 0
var started := 0.0
var saw_pause := false
var finish_at := 0.0

func _initialize() -> void:
	role = "client" if "--client" in OS.get_cmdline_user_args() else "host"
	call_deferred("start")

func start() -> void:
	started = Time.get_ticks_msec() / 1000.0
	session = Session.new()
	session.name = "Session"
	session.persist_progress = false
	root.add_child(session)
	session.entered_game.connect(connected)
	session.message.connect(func(value): print(role, ": ", value))
	if role == "host":
		if session.host("commander", 25982, "ember_ruins", {}, true) != OK: quit(1)
		# Isolated network transaction fixture, not a playthrough economy result.
		session.match_model.state.gold.p2 = 10000
	else:
		session.join(Session.room_code("127.0.0.1", 25982), "stormcaller")

func connected() -> void:
	connections += 1
	if role == "client" and connections == 1:
		session.submit("build", {"node": "shared_01", "tower": "frost"})
		session.submit("hero_talent", {"talent": "support"})
	elif role == "client" and connections == 2:
		var s: Dictionary = session.match_model.state
		if s.towers.shared_01.branch != "chain" or s.towers.shared_01.id != "storm" or s.towers.shared_01.base_id != "frost" or s.heroes.p2.talent != "support" or s.level_id != "ember_ruins":
			printerr("Automatic reconnect lost tower specialization or hero choice")
			quit(1)
			return
		stage = 4

func _process(_delta: float) -> bool:
	if not session: return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - started > 22:
		printerr("AUTO_NETWORK_TIMEOUT ", role, " stage ", stage)
		quit(1)
		return false
	var s: Dictionary = session.match_model.state
	if role == "host":
		if s.paused: saw_pause = true
		if stage == 0 and s.towers.has("shared_01") and s.towers.shared_01.branch == "chain": stage = 1
		if stage == 1 and saw_pause and not s.paused and s.towers.shared_01.strategy == "air" and s.towers.shared_01.get("shared_control",false):
			session.submit("tower_skill_upgrade", {"node":"shared_01","skill":"surge"})
			var target_id:int=session.match_model.spawn("heavy","a")
			s.enemies[target_id].pos=s.towers.shared_01.pos+Vector2(1,0)
			session.submit("tower_skill", {"node":"shared_01","skill":"surge"})
			if int(s.towers.shared_01.get("skills",{}).get("surge",0))!=2 or float(s.towers.shared_01.get("skill_at",{}).get("surge",0))<=s.time:
				printerr("Delegated skill purchase/cast failed")
				quit(1)
				return false
			print("AUTO_NETWORK_HOST_PASS authoritative tower, talent, reconnect, delegated skill rank and cast")
			stage = 2
			finish_at = now + 1
		if stage == 2 and now > finish_at:
			session.leave()
			quit(0)
	else:
		if stage == 0 and s.towers.has("shared_01"):
			session.submit("upgrade", {"node": "shared_01"})
			stage = 1
		if stage == 1 and s.towers.shared_01.level == 2 and s.towers.shared_01.upgrade_end <= s.time:
			session.submit("upgrade", {"node": "shared_01"})
			stage = 2
		if stage == 2 and s.towers.shared_01.level == 3 and s.towers.shared_01.upgrade_end <= s.time:
			session.submit("specialize", {"node": "shared_01", "tower": "storm", "branch": "chain"})
			stage = 6
		if stage == 6 and s.towers.shared_01.branch == "chain":
			# Drop the transport and fire its disconnect handler. Do not call join again.
			session.multiplayer.multiplayer_peer.close()
			session._server_gone()
			stage = 3
		if stage == 4 and session.authenticated and s.towers.shared_01.upgrade_end <= s.time:
			session.submit("strategy", {"node": "shared_01", "strategy": "air"})
			stage = 5
		if stage == 5 and session.authenticated and s.towers.shared_01.strategy == "air":
			session.submit("tower_skill_upgrade", {"node":"shared_01","skill":"surge"})
			session.submit("tower_control", {"node":"shared_01"})
			stage=7
		if stage==7 and s.towers.shared_01.get("skills",{}).get("surge",0)==2 and float(s.towers.shared_01.get("skill_at",{}).get("surge",0))>s.time:
			print("AUTO_NETWORK_CLIENT_PASS room code, branch, automatic reconnect and delegated skill RPC")
			session.leave()
			quit(0)
	return false

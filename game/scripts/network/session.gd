extends Node

signal entered_game
signal message(text: String)
signal state_changed

const Match = preload("res://scripts/core/match_state.gd")
const Career = preload("res://scripts/core/career.gd")
var career = Career.new()
var persist_progress := true
var save_at := 0.0
var last_save_error := OK
var result_epoch_sent := -1
var match_model = Match.new()
var mode := "menu"
var player := "p1"
var client_peer := 0
var authenticated := false
var sequence := 0
var reconnect_token := ""
var accepted_token := ""
var last_heartbeat := 0.0
var disconnected_at := 0.0
var reconnect_deadline := 0.0
var selected_hero := "skirmisher"
var selected_profile: Dictionary = {}
var port := 24820
var discover := PacketPeerUDP.new()
var broadcaster := PacketPeerUDP.new()
var discovered_rooms: Dictionary = {}
var broadcast_at := 0.0
var heartbeat_at := 0.0
var snapshot_chunks: Dictionary = {}
var last_address := ""
var last_port := 24820
var auto_retry_at := 0.0
var auto_retry_end := 0.0
var retry_count := 0
var auto_retry_exhausted := false
var initial_join_deadline := 0.0

func _ready() -> void:
	if persist_progress:
		career.read()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_gone)
	broadcaster.set_broadcast_enabled(true)
	discover.bind(24821, "0.0.0.0")

func practice(level := "confluence_courtyard", p1 := "commander", p2 := "skirmisher", challenge := false) -> void:
	leave()
	mode = "practice"
	player = "p1"
	match_model.configure(level, {"p1": p1, "p2": p2}, {"p1": career.profile("p1", p1), "p2": career.profile("p2", p2)}, challenge)
	entered_game.emit()

func host(hero := "commander", game_port := 24820, level := "confluence_courtyard", profile: Dictionary = {}, challenge := false) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(game_port, 1, 3)
	if error != OK:
		message.emit("房间创建失败，端口可能被占用。")
		return error
	multiplayer.multiplayer_peer = peer
	mode = "host"
	player = "p1"
	port = game_port
	match_model.configure(level, {"p1": hero, "p2": "skirmisher"}, {"p1": career.profile("p1", hero) if profile.is_empty() else profile}, challenge)
	message.emit("房间已创建，等待队友加入。游戏端口 %d" % port)
	return OK

func join(address: String, hero := "skirmisher", game_port := 24820, profile: Dictionary = {}) -> Error:
	var endpoint := parse_invite(address, game_port)
	if endpoint.is_empty():
		message.emit("邀请无效，请输入房间码或 IP:端口")
		return ERR_INVALID_PARAMETER
	address = endpoint.address
	game_port = endpoint.port
	# A reconnect token belongs to exactly one host endpoint.
	if address != last_address or game_port != last_port: reconnect_token = ""
	leave(false)
	last_address = address
	last_port = game_port
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, game_port, 3)
	if error != OK:
		message.emit("连接地址无效。")
		return error
	multiplayer.multiplayer_peer = peer
	mode = "client"
	player = "p2"
	selected_hero = hero
	selected_profile = career.profile("p2", hero) if profile.is_empty() else profile
	port = game_port
	message.emit("正在连接 " + address + "…")
	initial_join_deadline=Time.get_ticks_msec()/1000.0+12
	return OK

func leave(clear_token := true) -> void:
	persist_now()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = "menu"
	initial_join_deadline=0.0
	result_epoch_sent = -1
	client_peer = 0
	authenticated = false
	snapshot_chunks.clear()
	auto_retry_end = 0.0
	auto_retry_at = 0.0
	retry_count = 0
	auto_retry_exhausted = false
	if clear_token:
		sequence = 0
	disconnected_at = 0.0
	accepted_token = ""
	if clear_token:
		reconnect_token = ""

func _peer_connected(id: int) -> void:
	if mode == "host":
		client_peer = id

func _connected() -> void:
	_hello.rpc_id(1, match_model.cfg.config_hash, reconnect_token, selected_hero, selected_profile)

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(hash_value: String, token: String, hero: String, profile: Dictionary = {}) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != client_peer:
		return
	if hash_value != match_model.cfg.config_hash:
		_reject.rpc_id(client_peer, "游戏配置版本不一致，请使用同一份游戏。")
		return
	if not accepted_token.is_empty() and token != accepted_token:
		_reject.rpc_id(client_peer, "此对局席位仅允许原队友重连。")
		return
	var reconnecting := not accepted_token.is_empty()
	if not reconnecting:
		accepted_token = str(Time.get_ticks_usec()) + "-" + str(randi())
		_set_hero("p2", hero, profile)
	authenticated = true
	last_heartbeat = Time.get_ticks_msec() / 1000.0
	disconnected_at = 0.0
	match_model.state.paused = false
	_welcome.rpc_id(client_peer, accepted_token, match_model.snapshot())
	if not reconnecting:
		entered_game.emit()
	message.emit("队友已重连。" if reconnecting else "队友已加入，双方部署后确认出发。")

@rpc("authority", "call_remote", "reliable", 2)
func _welcome(token: String, value: Dictionary) -> void:
	if mode != "client":
		return
	reconnect_token = token
	initial_join_deadline=0.0
	auto_retry_end = 0.0
	auto_retry_at = 0.0
	retry_count = 0
	authenticated = true
	match_model.apply_snapshot(value)
	last_heartbeat = Time.get_ticks_msec() / 1000.0
	entered_game.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _reject(text: String) -> void:
	authenticated = false
	message.emit(text)
	leave(false)

func _set_hero(owner: String, kind: String, profile: Dictionary = {}) -> void:
	match_model.set_hero(owner, kind, profile)

func persist_now() -> void:
	if mode == "menu":
		return
	if mode == "client" and not authenticated:
		return
	var s: Dictionary = match_model.state
	career.record_stage(str(s.level_id), str(s.phase), int(s.hp))
	if not persist_progress: return
	if not s.get("challenge", false):
		for owner in s.heroes:
			if mode == "practice" or owner == player:
				career.record(owner, s.heroes[owner])
	var error: Error = career.write()
	if error != OK and error != last_save_error:
		message.emit("游戏进度保存失败：" + error_string(error))
	last_save_error = error

func _exit_tree() -> void:
	persist_now()
	discover.close()
	broadcaster.close()

func submit(kind: String, payload: Dictionary = {}) -> Dictionary:
	sequence += 1
	var id := str(sequence)
	if mode == "practice" or mode == "host":
		var result: Dictionary = match_model.command(player, kind, payload, id)
		if not result.accepted:
			message.emit(result.reason)
		return result
	if mode == "client" and authenticated:
		_request.rpc_id(1, kind, payload, id)
		return {"accepted": true, "pending": true}
	return {"accepted": false, "reason": "尚未连接房间"}

@rpc("any_peer", "call_remote", "reliable", 0)
func _request(kind: String, payload: Dictionary, id: String) -> void:
	if mode != "host" or not authenticated or multiplayer.get_remote_sender_id() != client_peer:
		return
	last_heartbeat = Time.get_ticks_msec() / 1000.0
	var result: Dictionary = match_model.command("p2", kind, payload, accepted_token + ":" + id)
	_ack.rpc_id(client_peer, result)

@rpc("authority", "call_remote", "reliable", 0)
func _ack(result: Dictionary) -> void:
	if not result.accepted:
		message.emit(result.reason)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot_chunk(epoch: int, tick: int, index: int, total: int, bytes: PackedByteArray) -> void:
	if mode != "client" or not authenticated or total < 1 or total > 256 or index < 0 or index >= total or bytes.size() > 1000:
		return
	if epoch < int(match_model.state.epoch) or (epoch == int(match_model.state.epoch) and tick < int(match_model.state.tick)):
		return
	var key := str(epoch) + ":" + str(tick)
	if not snapshot_chunks.has(key):
		if snapshot_chunks.size() >= 3:
			snapshot_chunks.erase(snapshot_chunks.keys()[0])
		snapshot_chunks[key] = {"total": total, "parts": {}}
	var packet: Dictionary = snapshot_chunks[key]
	if packet.total != total:
		return
	packet.parts[index] = bytes
	if packet.parts.size() != total:
		return
	var compressed := PackedByteArray()
	for i in range(total):
		compressed.append_array(packet.parts[i])
	snapshot_chunks.erase(key)
	var decoded := compressed.decompress_dynamic(4194304, FileAccess.COMPRESSION_DEFLATE)
	var value = bytes_to_var(decoded)
	if value is Dictionary and value.epoch == epoch and value.tick == tick:
		match_model.apply_snapshot(value)
		last_heartbeat = Time.get_ticks_msec() / 1000.0
		state_changed.emit()

func _send_snapshot() -> void:
	var value: Dictionary = match_model.snapshot()
	var bytes := var_to_bytes(value).compress(FileAccess.COMPRESSION_DEFLATE)
	var total := int(ceil(bytes.size() / 1000.0))
	for i in range(total):
		_snapshot_chunk.rpc_id(client_peer, int(value.epoch), int(value.tick), i, total, bytes.slice(i * 1000, mini(bytes.size(), (i + 1) * 1000)))

@rpc("authority", "call_remote", "reliable", 2)
func _final_result(value: Dictionary) -> void:
	if mode != "client" or not authenticated or value.get("phase", "") not in ["won", "lost"]: return
	if int(value.get("epoch", -1)) < int(match_model.state.epoch): return
	if int(value.get("epoch", -1)) == int(match_model.state.epoch) and int(value.get("tick", -1)) < int(match_model.state.tick): return
	match_model.apply_snapshot(value)
	last_heartbeat = Time.get_ticks_msec() / 1000.0
	persist_now()
	state_changed.emit()

@rpc("any_peer", "call_remote", "unreliable", 0)
func _heartbeat() -> void:
	if mode == "host" and multiplayer.get_remote_sender_id() == client_peer and authenticated:
		last_heartbeat = Time.get_ticks_msec() / 1000.0

func _peer_disconnected(id: int) -> void:
	if mode == "host" and id == client_peer and not accepted_token.is_empty():
		if match_model.state.phase in ["won", "lost"]:
			authenticated = false
			return
		_pause_for_reconnect()

func _pause_for_reconnect() -> void:
	if disconnected_at > 0:
		return
	authenticated = false
	match_model.state.paused = true
	disconnected_at = Time.get_ticks_msec() / 1000.0
	reconnect_deadline = disconnected_at + 60
	message.emit("队友掉线，暂停战斗并等待 60 秒重连。")

func _server_gone() -> void:
	if mode == "client":
		if match_model.state.phase in ["won", "lost"]:
			leave()
			return
		persist_now()
		authenticated = false
		match_model.state.paused = true
		_begin_auto_retry()

func _physics_process(delta: float) -> void:
	if mode == "practice" or (mode == "host" and (authenticated or disconnected_at > 0)):
		match_model.step(delta)
		if mode == "host" and authenticated and match_model.state.phase in ["won", "lost"] and result_epoch_sent != int(match_model.state.epoch):
			result_epoch_sent = int(match_model.state.epoch)
			_final_result.rpc_id(client_peer, match_model.snapshot())
		if mode == "host" and authenticated and int(match_model.state.tick) % 2 == 0:
			_send_snapshot()
	var now := Time.get_ticks_msec() / 1000.0
	if mode=="client" and not authenticated and initial_join_deadline>0 and now>=initial_join_deadline:
		initial_join_deadline=0.0
		if reconnect_token.is_empty():
			leave(false)
			message.emit("连接超时：确认房主已建房、双方版本相同、UDP端口可达；跨网络需要可直连地址，房间码没有中继。")
		else:_begin_auto_retry()
	if now >= save_at:
		persist_now()
		save_at = now + 1
	if mode == "host" and authenticated and now - last_heartbeat > 3:
		_pause_for_reconnect()
	if mode == "host" and disconnected_at > 0 and now >= reconnect_deadline:
		match_model.state.phase = "lost"
		match_model.state.notice = "重连超时，本局结束。"
		match_model.state.paused = false
		disconnected_at = 0.0
	if mode == "client" and authenticated and now > heartbeat_at:
		_heartbeat.rpc_id(1)
		heartbeat_at = now + 0.5
	if mode == "client" and authenticated and now - last_heartbeat > 3:
		authenticated = false
		match_model.state.paused = true
		_begin_auto_retry()
	if mode == "client" and auto_retry_end > 0:
		if now >= auto_retry_end:
			auto_retry_end = 0.0
			auto_retry_exhausted = true
			message.emit("自动重连超时，可返回大厅使用原房间码手动重连。")
		elif now >= auto_retry_at:
			auto_retry_at = now + 4
			retry_count += 1
			if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
			var retry_peer := ENetMultiplayerPeer.new()
			var error := retry_peer.create_client(last_address, last_port, 3)
			if error == OK: multiplayer.multiplayer_peer = retry_peer
	if mode == "host" and not authenticated and accepted_token.is_empty() and now > broadcast_at:
		broadcaster.set_dest_address("255.255.255.255", 24821)
		broadcaster.put_packet(JSON.stringify({"game": "TwinGuardians", "port": port}).to_utf8_buffer())
		broadcast_at = now + 1
	while discover.get_available_packet_count() > 0:
		var packet := discover.get_packet()
		var ip := discover.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data is Dictionary and data.get("game", "") == "TwinGuardians":
			discovered_rooms[ip] = {"port": int(data.port), "seen": now}


func _begin_auto_retry() -> void:
	if reconnect_token.is_empty() or last_address.is_empty() or auto_retry_end > 0 or auto_retry_exhausted: return
	var now := Time.get_ticks_msec() / 1000.0
	auto_retry_end = now + 60
	auto_retry_at = now + 2
	message.emit("连接中断，战斗暂停，正在自动重连（最多60秒）。")

func _connection_failed() -> void:
	if mode == "client" and not reconnect_token.is_empty():
		_begin_auto_retry()
	else:
		message.emit("无法连接房间。请确认房主已创建、地址可达且双方版本相同。")

static func room_code(ip: String, game_port := 24820) -> String:
	var pieces := ip.split(".")
	if pieces.size() != 4 or game_port < 1 or game_port > 65535: return ip + ":" + str(game_port)
	var encoded := ""
	for piece in pieces:
		if not piece.is_valid_int() or int(piece) < 0 or int(piece) > 255: return ip + ":" + str(game_port)
		encoded += "%02X" % int(piece)
	return "TG-" + encoded + "-%04X" % game_port

static func parse_invite(value: String, default_port := 24820) -> Dictionary:
	value = value.strip_edges()
	if value.to_upper().begins_with("TG-"):
		var parts := value.to_upper().split("-")
		if parts.size() != 3 or parts[1].length() != 8 or parts[2].length() != 4: return {}
		if not parts[1].is_valid_hex_number(false) or not parts[2].is_valid_hex_number(false): return {}
		var octets: Array[String] = []
		for i in range(4): octets.append(str(parts[1].substr(i * 2, 2).hex_to_int()))
		var decoded_port := parts[2].hex_to_int()
		return {"address": ".".join(octets), "port": decoded_port} if decoded_port > 0 else {}
	if value.is_empty() or value.contains(" ") or value.contains("/"): return {}
	var host := value
	var parsed_port := default_port
	if value.count(":") == 1:
		var parts := value.split(":")
		if not parts[1].is_valid_int(): return {}
		host = parts[0]
		parsed_port = int(parts[1])
	elif value.begins_with("["):
		var closing := value.find("]")
		if closing <= 1: return {}
		host = value.substr(1, closing - 1)
		var suffix := value.substr(closing + 1)
		if not suffix.is_empty():
			if not suffix.begins_with(":") or not suffix.substr(1).is_valid_int(): return {}
			parsed_port = int(suffix.substr(1))
	if host.is_empty() or parsed_port < 1 or parsed_port > 65535: return {}
	return {"address": host, "port": parsed_port}

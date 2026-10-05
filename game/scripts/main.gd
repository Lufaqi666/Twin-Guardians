extends Node2D

const Materials = preload("res://scripts/ui/art_materials.gd")
const Preferences = preload("res://scripts/core/preferences.gd")
const ReleaseGuide = preload("res://scripts/core/release_guide.gd")
const PlaytestReport = preload("res://scripts/core/playtest_report.gd")
var playtest_report = PlaytestReport.new()
var playtest_epoch := -1
var feedback_dialog: AcceptDialog
var feedback_notes: TextEdit
var feedback_difficulty: OptionButton
const Session = preload("res://scripts/network/session.gd")
const Campaign = preload("res://scripts/ui/campaign_map.gd")
const Portrait = preload("res://scripts/ui/hero_portrait.gd")
const HeroRules = preload("res://scripts/core/hero_rules.gd")
const CombatAudio = preload("res://scripts/ui/combat_audio.gd")
const TowerIcon = preload("res://scripts/ui/tower_icon.gd")
const TowerMenu = preload("res://scripts/ui/tower_menu.gd")
var tower_menu: PanelContainer
var ally_info: Label
var event_info: Label
var talent_buttons: Array[Button] = []
var tactical_tools: VBoxContainer
var tools_button: Button
var tools_expanded := false
var ultimate_button: Button
const Field = preload("res://scripts/ui/battlefield.gd")
var preferences = Preferences.new()
var settings_panel: PanelContainer
var mode_choice: OptionButton
var binding_choice: OptionButton
var binding_button: Button
var awaiting_binding := ""
var settings_status: Label
var wave_info: Label
var team_info: Label
var help_info: Label
var pending_map_action := ""
var tutorial_dismissed := false
var session: Node
var field: Node2D
var ui: CanvasLayer
var menu: Control
var game_ui: Control
var footer: VBoxContainer
var sidebar: VBoxContainer
var header: Label
var notice: Label
var lobby_notice: Label
var hero_info: Label
var skill_buttons: Array[Button] = []
var address: LineEdit
var hero_choice: OptionButton
var hero2_choice: OptionButton
var hero_cards: Dictionary = {}
var persist_progress := true
var combat_audio: Node
var skill_upgrade: Button
var xp_bar: ProgressBar
var passive_info: Label
var selected_level := "confluence_courtyard"
var campaign: Node2D
var invitation: PanelContainer
var mission_info: Label
var mission_title: Label
var stage_buttons: Dictionary = {}
var selected := ""
var last_panel := ""
var command_count := 0
var elapsed := 0.0
var last_move := Vector2(-100, -100)
var move_at := 0.0
var ui_font := SystemFont.new()
var build_buttons: Array[Button] = []
var start_button: Button
var practice_button: Button
var gate_accept: Button
var gate_reject: Button
var player_button: Button
var effect_sound := AudioStreamPlayer.new()
var last_combo := 0
var volume := 0.22
var toast := ""
var toast_until := 0.0
var victory_panel: PanelContainer
var victory_grade: Label
var victory_detail: Label
var victory_countdown: Label
var victory_return_at := 0.0
var victory_epoch := -1

func _ready() -> void:
	preferences.persist = persist_progress and not "--demo" in OS.get_cmdline_user_args()
	preferences.read()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
	get_window().title = "双子守护者 v0.10  Twin Guardians"
	session = Session.new()
	session.name = "Session"
	session.persist_progress = persist_progress and not "--demo" in OS.get_cmdline_user_args()
	add_child(session)
	session.entered_game.connect(_enter_game)
	session.message.connect(_message)
	field = Field.new()
	field.session = session
	combat_audio = CombatAudio.new()
	combat_audio.enabled = not "--silent-preview" in OS.get_cmdline_user_args()
	add_child(combat_audio)
	field.combat_event.connect(combat_audio.on_event)
	add_child(field)
	ui = CanvasLayer.new()
	add_child(ui)
	_build_menu()
	_build_game_ui()
	_build_victory_panel()
	_build_settings()
	_build_feedback()
	_apply_preferences()
	add_child(effect_sound)
	if "--demo" in OS.get_cmdline_user_args():
		_demo()
	if "--invite-preview" in OS.get_cmdline_user_args():
		invitation.show()
	if "--release-audit" in OS.get_cmdline_user_args():
		var valid:bool=not OS.has_feature("editor") and session.match_model.cfg.errors.is_empty() and session.match_model.cfg.levels.size()==10 and session.match_model.cfg.towers.size()==8 and not FileAccess.file_exists("res://tests/core_test.gd")
		print("RELEASE_AUDIT ","PASS" if valid else "FAIL"," config_hash=",session.match_model.cfg.config_hash)
		get_tree().quit(0 if valid else 1)

func _style(bg: String, border := "574335", padding := 10) -> StyleBox:
	if padding == 0:
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color(bg)
		bar.set_corner_radius_all(3)
		return bar
	return Materials.panel(bg, border, padding)

func _label(text: String, size := 16, color := "3c3329") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(color))
	return label

func _button(text: String, action: Callable, width := 0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 37)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("f7e8bc"))
	button.add_theme_color_override("font_hover_color", Color("fff4ce"))
	button.add_theme_color_override("font_disabled_color", Color("b4aa8e"))
	button.add_theme_stylebox_override("normal", _style("425c50", "876843", 6))
	button.add_theme_stylebox_override("hover", _style("5b7962", "d3ad65", 6))
	button.add_theme_stylebox_override("pressed", _style("2d493e", "cfbb82", 6))
	button.add_theme_stylebox_override("disabled", _style("777363", "716149", 6))
	button.pressed.connect(action)
	return button

func _panel(rect: Rect2, parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style("eadbb5", "725334"))
	parent.add_child(panel)
	return panel

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color("182a28")
	shade.size = Vector2(1280, 800)
	menu.add_child(shade)
	campaign = Campaign.new()
	campaign.stage_stars = session.career.stage_stars
	campaign.levels = session.match_model.cfg.levels
	menu.add_child(campaign)
	var title := _label("双 子 守 护 者", 34, "eddbad")
	title.position = Vector2(450, 20)
	menu.add_child(title)
	var subtitle := _label("T W I N  G U A R D I A N S   /   战役远征", 13, "bfae83")
	subtitle.position = Vector2(452, 70)
	menu.add_child(subtitle)
	var invite_button := _button("＋ 邀请队友 / 加入房间", func(): invitation.visible = not invitation.visible, 260)
	invite_button.position = Vector2(18, 23)
	menu.add_child(invite_button)
	var exit_button := _button("退出", func(): get_tree().quit(), 95)
	exit_button.position = Vector2(1167, 23)
	menu.add_child(exit_button)
	var settings_button := _button("设置", func(): settings_panel.show(), 95)
	settings_button.position = Vector2(1055, 23)
	menu.add_child(settings_button)
	var cfg = session.match_model.cfg
	for id in cfg.levels:
		var level: Dictionary = cfg.levels[id]
		var marker := Button.new()
		marker.position = cfg.vector(level.position) - Vector2(37, 37)
		marker.size = Vector2(74, 74)
		marker.flat = true
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.tooltip_text = level.name + " · " + level.difficulty
		marker.pressed.connect(func(): _select_level(id))
		menu.add_child(marker)
		var caption := _label(level.name, 18, "fff1c8")
		caption.position = cfg.vector(level.position) + Vector2(-68, 48)
		caption.size.x = 136
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(caption)
		stage_buttons[id] = marker
	var mission := _panel(Rect2(850, 110, 412, 465), menu)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	mission.add_child(list)
	list.add_child(_label("战 役  /  关卡详情", 14, "846240"))
	mission_title = _label("", 26)
	list.add_child(mission_title)
	mission_info = _label("", 14)
	mission_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_info.custom_minimum_size.x = 364
	mission_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mission_scroll:=ScrollContainer.new()
	mission_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	mission_scroll.custom_minimum_size.y=160
	mission_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	mission_scroll.add_child(mission_info)
	list.add_child(mission_scroll)
	mode_choice = OptionButton.new()
	mode_choice.add_theme_font_override("font", ui_font)
	mode_choice.add_theme_font_size_override("font_size", 15)
	mode_choice.custom_minimum_size.y = 30
	mode_choice.item_selected.connect(func(_index):
		for owner in hero_cards: _refresh_hero_card(owner)
	)
	mode_choice.add_item("成长战役 · 使用已保存的英雄等级")
	mode_choice.add_item("公平挑战 · 双方固定四级 / 三阶技能")
	mode_choice.select(1)
	mode_choice.set_item_text(1, "公平挑战 · 推荐合作 · 双方固定四级")
	mode_choice.tooltip_text = "挑战模式不获得英雄经验，关卡星数照常保存；关卡与选择由房主决定。"
	list.add_child(mode_choice)
	practice_button = _button("出征 · 本机双人练习", _start_practice)
	list.add_child(practice_button)
	list.add_child(_button("创建合作房间 · 邀请 P2", _host_selected))
	for owner in ["p1", "p2"]:
		var panel := _panel(Rect2(18 if owner == "p1" else 650, 595, 612, 187), menu)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var portrait := Portrait.new()
		portrait.custom_minimum_size = Vector2(112, 146)
		row.add_child(portrait)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 5)
		row.add_child(column)
		var heading := HBoxContainer.new()
		heading.add_child(_label(owner.to_upper() + " · 出战英雄", 16, "48627a" if owner == "p1" else "9b583a"))
		heading.add_child(_label("固定绝技 · 成长保留", 12, "886b44"))
		column.add_child(heading)
		var choice := OptionButton.new()
		choice.custom_minimum_size.y = 32
		choice.add_theme_font_override("font", ui_font)
		choice.add_theme_font_size_override("font_size", 17)
		choice.add_theme_color_override("font_color", Color("f5e8bb"))
		choice.add_theme_stylebox_override("normal", _style("45594c", "8e9a70", 4))
		for kind in cfg.heroes:
			choice.add_item(cfg.heroes[kind].name)
			choice.set_item_metadata(choice.item_count - 1, kind)
		choice.selected = 0 if owner == "p1" else 1
		choice.item_selected.connect(func(_index): _refresh_hero_card(owner))
		column.add_child(choice)
		var description := _label("", 12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(description)
		hero_cards[owner] = {"portrait": portrait, "choice": choice, "description": description}
		if owner == "p1":
			hero_choice = choice
		else:
			hero2_choice = choice
		_refresh_hero_card(owner)
	# The invitation panel is deliberately located in the upper-left corner.
	invitation = _panel(Rect2(18, 76, 386, 420), menu)
	invitation.visible = false
	var invite := VBoxContainer.new()
	invite.add_theme_constant_override("separation", 10)
	invitation.add_child(invite)
	invite.add_child(_label("邀请好友 · 局域网合作", 23))
	invite.add_child(_label("房主使用 P1 英雄；加入者使用 P2 英雄。", 13))
	invite.add_child(_button("创建所选关卡房间", _host_selected))
	invite.add_child(_button("复制房间码", _copy_invite))
	address = LineEdit.new()
	address.placeholder_text = "粘贴 TG-房间码，或 IP:端口"
	address.text = "127.0.0.1"
	address.custom_minimum_size.y = 38
	address.add_theme_font_override("font", ui_font)
	invite.add_child(address)
	invite.add_child(_button("加入 / 原席位重连", func(): session.join(address.text.strip_edges(), _chosen_hero("p2"), 24820)))
	invite.add_child(_button("搜索附近房间并加入", _join_discovered))
	lobby_notice = _label("创建房间后复制房间码给队友。支持局域网或可直连的 IP:端口；房间码不提供公网中继。断线后自动重连60秒。", 13)
	lobby_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_notice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	invite.add_child(lobby_notice)
	var close_row := HBoxContainer.new()
	close_row.add_child(_button("取消房间 / 连接", func(): session.leave(false); _message("房间已取消，可以重新选择关卡和英雄。"), 185))
	close_row.add_child(_button("收起面板", func(): invitation.hide(), 165))
	invite.add_child(close_row)
	_select_level(selected_level)

func _select_level(id: String) -> void:
	selected_level = id
	campaign.selected = id
	var cfg = session.match_model.cfg
	var level: Dictionary = cfg.levels[id]
	mission_title.text = level.name
	var count := 0
	for wave in cfg.wave_sets[id]:
		count += wave.events.size()
	mission_info.text = "%s\n\n难度：%s   ·   %d 波 / %d 敌人\n\n%s\n\n四种基础塔 · 三级解锁八条路线 · 主动接力" % [level.subtitle, level.difficulty, cfg.wave_sets[id].size(), count, level.description + "\n推荐英雄等级：" + str(int(level.get("recommended_level", 1)))]
	var best: int = int(session.career.stage_stars.get(id, 0))
	mission_info.text += "\n\n最高评价：" + "★".repeat(best) + "☆".repeat(3-best) + "\n三星扣血0–2 · 二星3–10 · 通关至少一星"
	mission_info.tooltip_text = level.get("mechanism",{}).get("description","")
	if level.has("mechanism"):mission_info.text+="\n\n本关机关："+level.mechanism.name+"\n"+level.mechanism.description

func _chosen_hero(owner := "p1") -> String:
	var choice: OptionButton = hero_cards[owner].choice
	return str(choice.get_item_metadata(choice.selected))

func _refresh_hero_card(owner: String) -> void:
	var kind := _chosen_hero(owner)
	var spec: Dictionary = session.match_model.cfg.heroes[kind]
	var card: Dictionary = hero_cards[owner]
	card.portrait.kind = kind
	card.portrait.accent = Color(spec.color)
	card.portrait.queue_redraw()
	var profile: Dictionary = {"xp": 360, "skill_level": 3} if is_instance_valid(mode_choice) and mode_choice.selected == 1 else session.career.profile(owner, kind)
	var level := HeroRules.level_for(profile.xp)
	var hero := HeroRules.create(owner, kind, spec, profile, Vector2.ZERO)
	card.description.text = "Lv.%d · 阻挡 %d · Q %s Lv.%d · %.0f 伤害 / %.1fs\n%s\n被动：%s — %s" % [level, spec.block_capacity, spec.skill.name, profile.skill_level, HeroRules.skill_damage(hero), HeroRules.skill_cooldown(hero), spec.skill.description, spec.passive_name, spec.passive_description]

func _start_practice() -> void:
	session.practice(selected_level, _chosen_hero("p1"), _chosen_hero("p2"), mode_choice.selected == 1)

func _host_selected() -> void:
	invitation.show()
	session.host(_chosen_hero("p1"), 24820, selected_level, {}, mode_choice.selected == 1)

func _copy_invite() -> void:
	if session.mode not in ["host", "client"]:
		_message("先创建房间，再复制房间码邀请队友。")
		return
	var addresses := []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			addresses.append(ip)
	var ip: String = addresses[0] if not addresses.is_empty() else "127.0.0.1"
	if session.mode == "client": ip = session.last_address
	var code: String = Session.room_code(ip, session.port)
	DisplayServer.clipboard_set(code)
	_message("已复制房间码 " + code + "，适用于同一局域网或可直连网络。")

func _join_discovered() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for ip in session.discovered_rooms:
		if now - float(session.discovered_rooms[ip].seen) < 4:
			address.text = ip
			session.join(ip, _chosen_hero("p2"), int(session.discovered_rooms[ip].port))
			return
	_message("暂未发现房间。请让队友创建房间，或直接输入 IP。")

func _build_game_ui() -> void:
	game_ui = Control.new()
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.size = Vector2(1280, 800)
	game_ui.visible = false
	ui.add_child(game_ui)
	var top := _panel(Rect2(18, 12, 1244, 83), game_ui)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top.add_child(row)
	var branding := VBoxContainer.new()
	branding.add_child(_label("双子守护者", 21))
	var combat_invite := _button("＋ 邀请 · 复制地址", _copy_invite, 145)
	combat_invite.custom_minimum_size.y = 25
	branding.add_child(combat_invite)
	row.add_child(branding)
	header = _label("", 17)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header)
	var controls := VBoxContainer.new()
	player_button = _button("P1  ⇄  P2", _switch_player, 130)
	player_button.custom_minimum_size.y = 23
	controls.add_child(player_button)
	var navigation := HBoxContainer.new()
	var settings := _button("设置", func(): settings_panel.show(), 62)
	settings.custom_minimum_size.y = 23
	navigation.add_child(settings)
	var back := _button("大厅", _return_menu, 62)
	back.custom_minimum_size.y = 23
	navigation.add_child(back)
	controls.add_child(navigation)
	row.add_child(controls)
	var side := _panel(Rect2(995, 106, 267, 590), game_ui)
	var shell := VBoxContainer.new()
	side.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 6)
	scroll.add_child(sidebar)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 5)
	shell.add_child(footer)
	var bottom := _panel(Rect2(18, 705, 1244, 82), game_ui)
	var vbox := VBoxContainer.new()
	bottom.add_child(vbox)
	notice = _label("", 16)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(notice)
	help_info = _label("", 12, "745c3d")
	vbox.add_child(help_info)
	tower_menu = TowerMenu.new()
	game_ui.add_child(tower_menu)
	tower_menu.initialize(self)
	_rebuild_sidebar()

func _enter_game() -> void:
	if playtest_epoch!=int(session.match_model.state.epoch):
		playtest_report.begin()
		playtest_epoch=int(session.match_model.state.epoch)
	victory_epoch = -1
	victory_return_at = 0.0
	victory_panel.hide()
	menu.visible = false
	game_ui.visible = true
	selected = ""
	sell_confirm = ""
	pending_map_action = ""
	tutorial_dismissed = false
	last_combo = 0
	last_panel = ""
	_rebuild_sidebar()

func _return_menu() -> void:
	if game_ui.visible:
		playtest_report.finish(session.match_model.state,session.match_model.cfg,session.mode)
		if preferences.playtest and preferences.persist:
			var saved:Dictionary=playtest_report.save()
			if saved.error!=OK:_message("试玩记录保存失败："+error_string(saved.error))
	playtest_epoch=-1
	victory_return_at = 0.0
	victory_epoch = -1
	victory_panel.hide()
	if session.mode == "client" and not session.authenticated:
		session.leave(false)
	else:
		session.leave()
	menu.visible = true
	game_ui.visible = false
	campaign.stage_stars = session.career.stage_stars
	_select_level(selected_level)
	for owner in hero_cards:
		_refresh_hero_card(owner)
	_message("已返回大厅。")

func _build_victory_panel() -> void:
	victory_panel = _panel(Rect2(282, 234, 580, 258), game_ui)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	victory_panel.add_child(box)
	var title := _label("守护成功 · 关卡评价", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	victory_grade = _label("", 56, "b27b20")
	victory_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(victory_grade)
	victory_detail = _label("", 18)
	victory_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(victory_detail)
	victory_countdown = _label("", 16, "745c3d")
	victory_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(victory_countdown)
	victory_panel.hide()

func _update_victory(state: Dictionary) -> bool:
	if state.phase != "won":
		victory_panel.hide()
		victory_epoch = -1
		victory_return_at = 0.0
		return false
	var stars: int = session.career.stars_for(str(state.phase), int(state.hp))
	if victory_epoch != int(state.epoch):
		victory_epoch = int(state.epoch)
		victory_return_at = elapsed + 3.0
		session.persist_now()
		victory_grade.text = "★".repeat(stars) + "☆".repeat(3 - stars)
		victory_detail.text = "水晶 %d / 20 · 扣血 %d · 本关最高 %d 星" % [state.hp, maxi(0, 20 - int(state.hp)), int(session.career.stage_stars.get(state.level_id, stars))]
	victory_panel.show()
	victory_countdown.text = "%d 秒后自动返回主界面" % maxi(0, int(ceil(victory_return_at - elapsed)))
	if elapsed >= victory_return_at:
		selected_level = str(state.level_id)
		var stage_name: String = session.match_model.cfg.levels[state.level_id].name
		_return_menu()
		_message("%s 通关 · %s · 扣血 %d，已保存最高星数。" % [stage_name, "★".repeat(stars) + "☆".repeat(3-stars), maxi(0,20-int(state.hp))])
		return true
	return false

func _switch_player() -> void:
	if session.mode == "practice":
		session.player = "p2" if session.player == "p1" else "p1"
		last_panel = ""
		_rebuild_sidebar()

func _send(kind: String, payload: Dictionary = {}) -> void:
	var result: Dictionary = session.submit(kind, payload)
	playtest_report.command(kind,result)
	if result.accepted and kind in ["build", "upgrade", "sell", "ready", "hero_upgrade"]:
		_tone(440 if kind == "build" else 320, 0.055)

func _message(text: String) -> void:
	toast = text
	toast_until = elapsed + 3.5
	if is_instance_valid(lobby_notice):
		lobby_notice.text = text
	if is_instance_valid(notice):
		notice.text = text

func _ready_wave() -> void:
	_send("ready")
	if session.mode == "practice":
		var previous: String = session.player
		session.player = "p2" if previous == "p1" else "p1"
		_send("ready")
		session.player = previous

func _rebuild_sidebar() -> void:
	if not sidebar:
		return
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()
	skill_buttons.clear()
	talent_buttons.clear()
	var state: Dictionary = session.match_model.state
	var cfg = session.match_model.cfg
	var player: String = session.player
	sidebar.add_child(_label(player.to_upper() + " 的指挥台", 21))
	if state.phase == "prepare":
		wave_info = _label(session.match_model.wave_intel(), 12)
		wave_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sidebar.add_child(wave_info)
	elif state.phase in ["won", "lost"]:
		var report := _label(session.match_model.debrief(), 13)
		report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sidebar.add_child(report)
	var help := _label("点击地基，在塔旁选择建造与升级。\n详细说明可展开；Esc 收起菜单。", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(help)
	event_info = _label("", 13, "8a4938")
	event_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(event_info)
	ally_info = _label("", 13, "48627a")
	ally_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(ally_info)
	var markers := HBoxContainer.new()
	for label in ["防空", "补位", "集火"]:
		markers.add_child(_button(label, func(): pending_map_action = label; _message("点击地图发送「" + label + "」标记"), 70))
	footer.add_child(markers)
	team_info = _label("", 12, "48627a")
	team_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(team_info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	var hero_row := HBoxContainer.new()
	var avatar := Portrait.new()
	avatar.kind = state.heroes[player].kind
	avatar.accent = Color(cfg.heroes[avatar.kind].color)
	avatar.custom_minimum_size = Vector2(48, 58)
	hero_row.add_child(avatar)
	hero_info = _label("", 13)
	hero_row.add_child(hero_info)
	footer.add_child(hero_row)
	var hero: Dictionary = state.heroes[player]
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size.y = 7
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _style("584d3a", "584d3a", 0))
	xp_bar.add_theme_stylebox_override("fill", _style("b9bf6d", "b9bf6d", 0))
	footer.add_child(xp_bar)
	passive_info = _label("被动：" + cfg.heroes[hero.kind].passive_name, 12, "6b6940")
	passive_info.tooltip_text = cfg.heroes[hero.kind].passive_description
	footer.add_child(passive_info)
	var skills := HBoxContainer.new()
	var active := _button("Q " + hero.skill.name, func(): _cast_button("q"), 155)
	active.tooltip_text = hero.skill.description + "。键盘 " + preferences.label("skill") + " 指定鼠标目标；按钮自动瞄准附近敌人。"
	skills.add_child(active)
	skill_buttons.append(active)
	ultimate_button = _button(preferences.label("ultimate") + " 共鸣", func(): _send("ultimate"), 75)
	skills.add_child(ultimate_button)
	footer.add_child(skills)
	skill_upgrade = _button("", func(): _send("hero_upgrade"))
	skill_upgrade.add_theme_font_size_override("font_size", 13)
	skill_upgrade.custom_minimum_size.y = 30
	footer.add_child(skill_upgrade)
	var talent_row := HBoxContainer.new()
	for option in cfg.heroes[hero.kind].talents:
		var choice := _button(option.name, func(): _send("hero_talent", {"talent": option.id}), 115)
		choice.tooltip_text = option.description + " 仅本局生效，备战且技能冷却完成后可更换。"
		choice.add_theme_font_size_override("font_size", 12)
		choice.custom_minimum_size.y = 28
		talent_row.add_child(choice)
		talent_buttons.append(choice)
	footer.add_child(talent_row)
	tools_button = _button("▸ 战术工具 · 分流 / 喷火 / 援助", func(): tools_expanded = not tools_expanded; tactical_tools.visible = tools_expanded; tools_button.text = ("▾ 收起战术工具" if tools_expanded else "▸ 战术工具 · 分流 / 喷火 / 援助"))
	tools_button.add_theme_font_size_override("font_size", 12)
	tools_button.custom_minimum_size.y = 28
	footer.add_child(tools_button)
	tactical_tools = VBoxContainer.new()
	tactical_tools.visible = tools_expanded
	footer.add_child(tactical_tools)
	var machinery := HBoxContainer.new()
	machinery.add_child(_button("分流 50g", func(): _send("gate", {"id": "gate_a" if player == "p1" else "gate_b"}), 115))
	machinery.add_child(_button("喷火 75g", func(): _send("trap", {"id": "fire_" + player}), 115))
	tactical_tools.add_child(machinery)
	var reply := HBoxContainer.new()
	gate_accept = _button(preferences.label("accept") + " 同意", func(): _send("gate_reply", {"accept": true}), 115)
	gate_reject = _button(preferences.label("reject") + " 拒绝", func(): _send("gate_reply", {"accept": false}), 115)
	reply.add_child(gate_accept)
	reply.add_child(gate_reject)
	gate_accept.visible = not state.gate_request.is_empty() and state.gate_request.owner != player
	gate_reject.visible = gate_accept.visible
	footer.add_child(reply)
	tactical_tools.add_child(_button("援助队友 50g  ·  到账 45g", func(): _send("transfer", {"amount": 50})))
	var mechanism:Dictionary=session.match_model.cfg.levels[state.level_id].get("mechanism",{})
	if not mechanism.is_empty():
		var operation:=_button(mechanism.name+(" · 跟随护送" if mechanism.kind=="escort" else (" · 换线30g" if mechanism.kind=="junction" else " · 解封50g")),func():_send("mechanism"))
		operation.tooltip_text=mechanism.description
		tactical_tools.add_child(operation)
	if state.phase in ["won", "lost"]:
		start_button = _button("重新守护水晶", func(): _send("restart"))
		start_button.disabled = state.phase == "won"
	else:
		start_button = _button("开始下一波" if session.mode == "practice" else "我已准备", _ready_wave)
		start_button.disabled = state.phase != "prepare" or state.paused
	footer.add_child(start_button)
	if is_instance_valid(tower_menu): tower_menu.refresh()

var sell_confirm := ""
func _cast_button(key: String) -> void:
	var state: Dictionary = session.match_model.state
	var hero: Dictionary = state.heroes[session.player]
	var target: Vector2 = hero.pos + Vector2(2, 0)
	var distance := 7.0
	for enemy in state.enemies.values():
		if enemy.hp > 0 and hero.pos.distance_to(enemy.pos) < distance:
			distance = hero.pos.distance_to(enemy.pos)
			target = enemy.pos
	_send("skill", {"key": key, "pos": target})

func _confirm_sell() -> void:
	if sell_confirm == selected:
		_send("sell", {"node": selected})
		sell_confirm = ""
	else:
		sell_confirm = selected
		_message("确认出售？再次点击出售按钮。")

func _process(delta: float) -> void:
	elapsed += delta
	if not game_ui.visible:
		var locked: bool = session.mode in ["host", "client"]
		mode_choice.disabled = locked
		for card in hero_cards.values():
			card.choice.disabled = locked
		for button in stage_buttons.values():
			button.disabled = locked
		return
	var state: Dictionary = session.match_model.state
	if _update_victory(state): return
	playtest_report.sample(state)
	var player: String = session.player
	var phase_text := "%s · 第 %d / %d 波" % [session.match_model.cfg.map.name, state.wave, session.match_model.cfg.waves.size()]
	if state.phase == "prepare":
		phase_text = "第 %d 波准备  %ds" % [state.wave + 1, maxi(0, int(ceil(state.prepare_end - state.time)))]
	elif state.phase == "won":
		phase_text = "守护成功！"
	elif state.phase == "lost":
		phase_text = "水晶失守"
	if state.paused:
		phase_text = "断线暂停 · 等待重连"
	header.text = "水晶 %d / 20    P1 %dg    P2 %dg\n%s    共鸣 %d%%    击杀 %d" % [state.hp, int(state.gold.p1) / 4, int(state.gold.p2) / 4, phase_text, state.resonance, state.stats.kills]
	header.text += "  · " + ("固定四级挑战" if state.challenge else "成长战役")
	player_button.text = player.to_upper() + ("  ⇄ " + preferences.label("switch") if session.mode == "practice" else " 联机")
	player_button.disabled = session.mode != "practice"
	var signature: String = player + str(state.heroes[player].kind) + str(state.phase) + str(state.gate_request) + str(state.paused) + str(state.wave)
	if signature != last_panel:
		last_panel = signature
		_rebuild_sidebar()
	if is_instance_valid(tower_menu): tower_menu.refresh()
	var event: Dictionary = state.get("stage_event", {})
	if is_instance_valid(event_info):
		event_info.text = ""
		if not event.is_empty() and event.end > state.time:
			var countdown := maxi(0, int(ceil(event.active_at - state.time)))
			event_info.text = event.name + (" · 已化解" if event.solved else (" · %ds 后发生" % countdown if countdown > 0 else " · 正在发生"))
			if not event.solved: event_info.text += "\n分头守住信标：%.1f / 3秒\n%s" % [event.progress, event.description]
		var q:Dictionary=state.get("mechanism",{})
		if q.get("kind","")=="junction":event_info.text+="\n岔路："+("交叉出口" if q.flipped else "原始出口")+" · 战术工具可换线"
		elif q.get("kind","")=="lock" and q.lock_end>state.time and not q.unsealed:event_info.text+="\n晶核："+("%ds后封锁"%int(ceil(q.lock_at-state.time)) if state.time<q.lock_at else "塔基封锁剩余%ds"%int(ceil(q.lock_end-state.time)))+" · 靠近晶核解封"
		elif q.get("kind","")=="escort" and q.get("cart_active",false):event_info.text+="\n护送车："+("已结束" if q.cart_done else "%d生命 · 英雄靠近才前进"%int(q.cart_hp))
	var friend: Dictionary = state.heroes["p2" if player == "p1" else "p1"]
	if is_instance_valid(ally_info):
		ally_info.text = "队友 %s · %d/%d HP\n%s" % [friend.owner.to_upper(), maxi(0, int(friend.hp)), int(friend.max_hp), "倒地！靠近按住 " + preferences.label("rescue") + " 救援" if friend.hp <= 0 else ("技能就绪 · 可接力" if friend.q_at <= state.time else "技能冷却 %ds" % int(ceil(friend.q_at - state.time)))]
	var hero: Dictionary = state.heroes[player]
	for i in range(talent_buttons.size()):
		var option: Dictionary = session.match_model.cfg.heroes[hero.kind].talents[i]
		talent_buttons[i].disabled = state.phase != "prepare" or hero.q_at > state.time or state.paused
		talent_buttons[i].text = ("✓ " if hero.get("talent", "") == option.id else "") + option.name
	var cooldown := maxi(0, int(ceil(hero.q_at - state.time)))
	var ultimate_cd := maxi(0, int(ceil(state.ultimate_cd - state.time)))
	var requested: bool = not state.ultimate_request.is_empty() and state.ultimate_request.owner != player
	ultimate_button.text = preferences.label("ultimate") + (" 响应!" if requested else (" %ds" % ultimate_cd if ultimate_cd > 0 else " 共鸣"))
	ultimate_button.disabled = state.resonance < 100 or ultimate_cd > 0 or hero.hp <= 0 or state.paused or state.phase in ["won", "lost"]
	ultimate_button.tooltip_text = "队友请求共鸣！三秒内响应。" if requested else "需要100%共鸣，双方确认；英雄均须存活。"
	if not skill_buttons.is_empty():
		skill_buttons[0].disabled = cooldown > 0 or hero.hp <= 0 or state.paused or state.phase in ["won", "lost"]
		skill_buttons[0].text = preferences.label("skill") + " " + (str(cooldown) + "s" if cooldown > 0 else hero.skill.name) + " ·" + str(hero.skill_level)
	if is_instance_valid(hero_info):
		var capacity := int(session.match_model.cfg.heroes[hero.kind].block_capacity) + (1 if hero.kind == "sentinel" and hero.level >= 6 else 0)
		hero_info.text = "%s Lv.%d\nHP %d / %d\n阻挡 %d / %d" % [session.match_model.cfg.heroes[hero.kind].name, hero.level, maxi(0, int(hero.hp)), int(hero.max_hp), hero.blocked_ids.size(), capacity]
		xp_bar.max_value = 1 if hero.level == 8 else HeroRules.XP[hero.level] - HeroRules.XP[hero.level - 1]
		xp_bar.value = 1 if hero.level == 8 else hero.xp - HeroRules.XP[hero.level - 1]
		xp_bar.tooltip_text = "经验 MAX" if hero.level == 8 else "经验 %d / %d；2级、4级获得技能强化点" % [hero.xp, HeroRules.XP[hero.level]]
		skill_upgrade.text = "技能满级 Lv.3" if hero.skill_level == 3 else "%s 技能强化 Lv.%d → %d · %d 点" % [preferences.label("upgrade"), hero.skill_level, hero.skill_level + 1, hero.skill_points]
		skill_upgrade.disabled = hero.skill_points <= 0 or hero.skill_level >= 3 or state.paused or state.phase in ["won", "lost"]
		skill_upgrade.tooltip_text = "每级强化提高技能伤害35%%，扩大范围并缩短冷却。当前伤害 %.0f" % HeroRules.skill_damage(hero)
		passive_info.text = "被动：" + session.match_model.cfg.heroes[hero.kind].passive_name + (" · 已强化" if hero.level >= 6 else " · Lv6强化")
	if not state.paused:
		notice.text = toast if elapsed < toast_until else state.notice
	else:
		notice.text = "战斗已暂停。队友可从大厅使用原地址重连；房主离开会结束本局。"
	if state.stats.combos > last_combo:
		last_combo = state.stats.combos
		_tone(780, 0.1)
	var feed: Array[String] = []
	for item in state.team_feed:
		if item.end > state.time: feed.append(item.text)
	if is_instance_valid(team_info): team_info.text = "\n".join(feed.slice(-2))
	if not feed.is_empty() and elapsed >= toast_until and not state.paused and not state.notice.contains("突破") and state.phase not in ["won", "lost"]:
		notice.text = feed.back()
	help_info.text = tutorial_text() if preferences.tutorial and not tutorial_dismissed else "左键建塔 · 右键移动 · %s 技能 · %s 共鸣 · %s 救援 · %s 标记 · %s 准备" % [preferences.label("skill"), preferences.label("ultimate"), preferences.label("rescue"), preferences.label("ping"), preferences.label("ready")]
	if settings_panel.visible or feedback_dialog.visible: return
	var direction := Vector2(float(Input.is_physical_key_pressed(preferences.keys.right)) - float(Input.is_physical_key_pressed(preferences.keys.left)), float(Input.is_physical_key_pressed(preferences.keys.down)) - float(Input.is_physical_key_pressed(preferences.keys.up)))
	if not direction.is_zero_approx() and elapsed > move_at and not state.paused:
		_send("move", {"pos": hero.pos + direction.normalized() * 1.2})
		move_at = elapsed + 0.08
	if Input.is_physical_key_pressed(preferences.keys.rescue) and elapsed > move_at:
		_send("rescue", {"active": true})
		move_at = elapsed + 0.1
	field.selected = selected
	field.preview_kind = tower_menu.detail_kind if tower_menu.visible else ""
	field.preview_branch = tower_menu.preview_branch if tower_menu.visible else ""
	field.menu_rect = Rect2(tower_menu.position, tower_menu.size) if tower_menu.visible else Rect2()
	field.hover = field.closest_node(get_global_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if feedback_dialog.visible:return
	if settings_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if not awaiting_binding.is_empty():
				if event.physical_keycode != KEY_ESCAPE: preferences.bind(awaiting_binding, event.physical_keycode)
				awaiting_binding = ""
				_refresh_binding()
			elif event.physical_keycode == KEY_ESCAPE:
				_close_settings()
		return
	if not game_ui.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not pending_map_action.is_empty() and Rect2(23, 110, 955, 580).has_point(event.position):
				if pending_map_action == "rally":
					_send("rally", {"node": selected, "pos": field.logic(event.position)})
				else:
					_send("ping", {"label": pending_map_action, "pos": field.logic(event.position)})
				pending_map_action = ""
				return
			selected = field.closest_node(event.position)
			sell_confirm = ""
			tower_menu.refresh(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.position.x < 985 and event.position.y > 105 and event.position.y < 695:
			_send("move", {"pos": field.logic(event.position)})
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pending_map_action = ""
			selected = ""
			tower_menu.hide()
			return
		match preferences.action_for(event.physical_keycode):
			"switch":
				_switch_player()
			"ready":
				_ready_wave()
			"skill":
				_send("skill", {"key": "q", "pos": field.logic(get_global_mouse_position())})
			"upgrade":
				_send("hero_upgrade")
			"ultimate":
				_send("ultimate")
			"accept":
				_send("gate_reply", {"accept": true})
			"reject":
				_send("gate_reply", {"accept": false})
			"ping":
				_send("ping", {"label": "补位", "pos": field.logic(get_global_mouse_position())})
			"tower_one":_cast_tower_skill(0)
			"tower_two":_cast_tower_skill(1)
			"tower_next":_next_ready_tower()

func _cast_tower_skill(index:int) -> void:
	var m=session.match_model
	var tower:Dictionary=m.state.towers.get(selected,{})
	if tower.is_empty():_message("先选中一座高级塔，或按 "+preferences.label("tower_next")+" 找就绪塔。");return
	if not m.Expansion.allowed(tower,session.player):_message("塔主尚未授权队友操作。");return
	var skills:Array=m.cfg.towers[tower.id].get("skills",[])
	if index>=skills.size():return
	_send("tower_skill",{"node":selected,"skill":skills[index].id})

func _next_ready_tower() -> void:
	var m=session.match_model
	var choices:Array[String]=[]
	for node in m.state.towers:
		var tower:Dictionary=m.state.towers[node]
		if str(tower.get("branch","")).is_empty() or not m.Expansion.allowed(tower,session.player):continue
		for skill in m.cfg.towers[tower.id].skills:
			if int(tower.get("skills",{}).get(skill.id,0))>0 and float(tower.get("skill_at",{}).get(skill.id,0))<=m.state.time and m.Expansion.active(m,tower,skill.id=="rod"):
				choices.append(node);break
	choices.sort()
	if choices.is_empty():_message("没有已学习且冷却完成的可操作塔技能。");return
	selected=choices[(choices.find(selected)+1)%choices.size()]
	pending_map_action="";sell_confirm="";tower_menu.refresh(true)
	_message("已选择就绪塔 · "+m.cfg.towers[m.state.towers[selected].id].name+" · "+preferences.label("tower_one")+" / "+preferences.label("tower_two")+" 施放")

func tutorial_text() -> String:
	var state: Dictionary = session.match_model.state
	if not pending_map_action.is_empty(): return "点击地图完成标记 / 集结点；Esc 取消"
	return ReleaseGuide.text(state,session.match_model.cfg,preferences,selected)

func _apply_preferences() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, preferences.volume)))
	AudioServer.set_bus_mute(0, preferences.volume <= 0)
	field.shake_enabled = preferences.shake
	field.damage_numbers = preferences.numbers
	field.effect_quality = preferences.effects

func _build_settings() -> void:
	var shade := ColorRect.new()
	shade.size = Vector2(1280, 800)
	shade.color = Color(0.04, 0.07, 0.06, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.hide()
	ui.add_child(shade)
	settings_panel = _panel(Rect2(365, 110, 550, 570), ui)
	settings_panel.visibility_changed.connect(func(): shade.visible = settings_panel.visible)
	settings_panel.hide()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(510,520)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.add_child(_label("设置 · 声音 / 显示 / 操作", 24))
	column.add_child(_label("联机时设置面板不会暂停队友的战斗。", 13))
	column.add_child(_label("总音量", 16))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = preferences.volume
	slider.value_changed.connect(func(value): preferences.volume = value; _apply_preferences())
	column.add_child(slider)
	column.add_child(_label("特效强度 · 危险预警始终保留",16))
	var effects_choice:=OptionButton.new()
	for label in ["低：保留技能范围，关闭高级塔装饰","中：光环与简化技能","高：完整高级形态特效"]:effects_choice.add_item(label)
	effects_choice.select(preferences.effects)
	effects_choice.item_selected.connect(func(index):preferences.effects=index;_apply_preferences())
	column.add_child(effects_choice)
	for option in [["shake", "战斗震屏与短暂视觉停顿"], ["numbers", "显示伤害数字"], ["tutorial", "显示分阶段教学"],["playtest","自动保存本地试玩记录（不联网）"]]:
		var toggle := CheckBox.new()
		toggle.text = option[1]
		toggle.add_theme_font_override("font", ui_font)
		toggle.add_theme_font_size_override("font_size", 16)
		for style in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			toggle.add_theme_color_override(style, Color("3c3329"))
		toggle.button_pressed = bool(preferences.get(option[0]))
		var property: String = option[0]
		toggle.toggled.connect(func(value): preferences.set(property, value); tutorial_dismissed = false; _apply_preferences())
		column.add_child(toggle)
	var remap := HBoxContainer.new()
	binding_choice = OptionButton.new()
	binding_choice.add_theme_font_override("font", ui_font)
	binding_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for action in Preferences.NAMES:
		binding_choice.add_item(Preferences.NAMES[action])
		binding_choice.set_item_metadata(binding_choice.item_count - 1, action)
	binding_choice.item_selected.connect(func(_index): _refresh_binding())
	remap.add_child(binding_choice)
	binding_button = _button("", func(): awaiting_binding = str(binding_choice.get_item_metadata(binding_choice.selected)); binding_button.text = "请按新键 · Esc取消", 210)
	remap.add_child(binding_button)
	column.add_child(remap)
	column.add_child(_button("恢复默认按键", func(): preferences.keys = Preferences.DEFAULT_KEYS.duplicate(); awaiting_binding = ""; _refresh_binding()))
	settings_status = _label("重复按键会交换绑定；Esc 保留用于取消。", 13)
	column.add_child(settings_status)
	column.add_child(_button("跳过本局教学", func(): tutorial_dismissed = true; _close_settings()))
	column.add_child(_button("试玩反馈 / 导出本局记录",func():settings_panel.hide();feedback_dialog.popup_centered()))
	column.add_child(_button("复制联机诊断",_copy_network_diagnostic))
	column.add_child(_button("保存并关闭", _close_settings))
	_refresh_binding()

func _build_feedback() -> void:
	feedback_dialog=AcceptDialog.new()
	feedback_dialog.title="试玩反馈 · 仅保存到本机"
	feedback_dialog.size=Vector2i(580,410)
	feedback_dialog.ok_button_text="保存记录并复制路径"
	ui.add_child(feedback_dialog)
	var column:=VBoxContainer.new()
	feedback_dialog.add_child(column)
	column.add_child(_label("记录包含阵容、金币、漏怪和技能使用，不含房间地址。",14,"d9e9f6"))
	feedback_difficulty=OptionButton.new()
	for label in ["1 · 太简单","2 · 较简单","3 · 合适","4 · 较难","5 · 太难"]:feedback_difficulty.add_item(label)
	feedback_difficulty.select(2);column.add_child(feedback_difficulty)
	feedback_notes=TextEdit.new()
	feedback_notes.placeholder_text="哪里看不懂？哪一波最难？哪些塔或技能特别好用？"
	feedback_notes.custom_minimum_size=Vector2(530,220)
	column.add_child(feedback_notes)
	feedback_dialog.confirmed.connect(_save_feedback)

func _save_feedback() -> void:
	if game_ui.visible:playtest_report.finish(session.match_model.state,session.match_model.cfg,session.mode)
	var result:Dictionary=playtest_report.save(feedback_notes.text,feedback_difficulty.selected+1)
	if result.error!=OK:_message("反馈保存失败："+("请先开始一局游戏。" if result.error==ERR_UNCONFIGURED else error_string(result.error)));return
	DisplayServer.clipboard_set(result.path)
	feedback_notes.clear()
	_message("试玩记录已保存，文件路径已复制；没有自动发送。")

func _copy_network_diagnostic() -> void:
	var data:={"version":"0.10","mode":session.mode,"connected":session.authenticated,"retry_count":session.retry_count,"config_hash":session.match_model.cfg.config_hash,"platform":OS.get_name(),"engine":Engine.get_version_info().string}
	DisplayServer.clipboard_set(JSON.stringify(data,"\t"))
	settings_status.text="已复制诊断。双方需同构建；检查UDP端口与防火墙，房间码不提供公网中继。"

func _refresh_binding() -> void:
	var action := str(binding_choice.get_item_metadata(binding_choice.selected))
	binding_button.text = "当前 " + preferences.label(action) + " · 点击改键"

func _close_settings() -> void:
	awaiting_binding = ""
	_apply_preferences()
	var error: Error = preferences.write()
	if error != OK:
		settings_status.text = "设置保存失败：" + error_string(error)
		return
	settings_panel.hide()
	last_panel = ""

func _tone(frequency: float, duration: float) -> void:
	if effect_sound.playing:
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	var count := int(duration * 22050)
	data.resize(count * 2)
	for i in range(count):
		var sample := int(sin(TAU * frequency * i / 22050.0) * 8000 * (1.0 - float(i) / count))
		data.encode_s16(i * 2, sample)
	stream.data = data
	effect_sound.stream = stream
	effect_sound.volume_db = linear_to_db(volume)
	effect_sound.play()

func _exit_tree() -> void:
	preferences.write()
	effect_sound.stop()
	effect_sound.stream = null

func _demo() -> void:
	var preview_level := "confluence_courtyard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			preview_level = arg.trim_prefix("--level=")
	session.practice(preview_level)
	var model = session.match_model
	model.command("p1", "build", {"node": "p1_01", "tower": "archer"}, "demo1")
	model.command("p1", "build", {"node": "shared_01", "tower": "frost"}, "demo2")
	model.command("p2", "build", {"node": "p2_01", "tower": "archer"}, "demo3")
	model.command("p2", "build", {"node": "shared_02", "tower": "cannon"}, "demo4")
	model.command("p1", "move", {"pos": Vector2(15, 11)}, "demo5")
	model.command("p2", "move", {"pos": Vector2(16, 13)}, "demo6")
	model.command("p1", "ready", {}, "demo7")
	model.command("p2", "ready", {}, "demo8")
	for i in range(260):
		model.step(0.05)
	selected = "shared_01"
	if "--build-preview" in OS.get_cmdline_user_args():
		selected = "shared_03"
	if "--combat-preview" in OS.get_cmdline_user_args():
		model.state.enemies.clear()
		model.state.effects.clear()
		model.state.projectiles.clear()
		model.set_hero("p1", "pyromancer", {"xp": 360, "skill_level": 2})
		model.set_hero("p2", "sentinel", {"xp": 800, "skill_level": 3})
		for owner in ["p1", "p2"]:
			model.state.heroes[owner].pos = Vector2(15, 12) if owner == "p1" else Vector2(17, 12)
			model.state.heroes[owner].target = model.state.heroes[owner].pos
			model.state.heroes[owner].attack_at = model.state.time + 2
		for i in range(7):
			var id: int = model.spawn("heavy" if i % 2 == 0 else "infantry", "a")
			model.state.enemies[id].pos = Vector2(17 + (i % 3) * 0.5, 11.5 + floori(i / 3.0) * 0.5)
			model.state.enemies[id].attack_at = model.state.time + 2
			if i % 2 == 0:
				model.state.enemies[id].hp = 600
				model.state.enemies[id].max_hp = 600
		model._soldiers(0.05)
		model._hero_blocks()
		model.command("p1", "skill", {"key": "q", "pos": Vector2(17.5, 12)}, "preview-meteor")
		model.state.time += 0.55
		model._resolve_casts()
		model._resolve_deaths()
		model._soldiers(0.05)
		model._hero_blocks()
		model.state.notice = "战斗反馈预览 · 陨星命中 / 骑士阻挡 / 英雄成长"
		session.set_physics_process(false)
		selected = "shared_03" if "--build-preview" in OS.get_cmdline_user_args() else "shared_01"
	if "--gallery" in OS.get_cmdline_user_args():
		model.state.gold = {"p1": 40000, "p2": 40000}
		var kinds := ["archer", "frost", "cannon", "barracks", "alchemy"]
		var index := 0
		for id in model.cfg.nodes:
			var owner: String = model.cfg.nodes[id].owner
			if owner == "shared":
				owner = "p1" if index % 2 == 0 else "p2"
			if not model.state.towers.has(id):
				model.command(owner, "build", {"node": id, "tower": kinds[index % kinds.size()]}, "gallery" + id)
			model.state.towers[id].level = 1 + index % 3
			index += 1
		model.state.notice = "防御塔美术预览 · 展示五类塔的不同升级外观"
	_rebuild_sidebar()

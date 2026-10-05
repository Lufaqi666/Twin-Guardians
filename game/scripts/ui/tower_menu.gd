extends PanelContainer

# World-adjacent controls live in the UI layer, so clicks never become map commands.
var game: Node
var content: VBoxContainer
var detail_kind := ""
var expanded := false
var details: Label
var detail_toggle: Button
var tracked: Array[Dictionary] = []
var node_id := ""
var signature := ""
const STRATEGIES = {"first": "出口优先", "strong": "生命最高", "air": "飞行优先", "fast": "速度优先", "armor": "护甲优先"}
const TowerIcon = preload("res://scripts/ui/tower_icon.gd")
const BASE_NAMES = {"archer": "弓箭塔", "barracks": "兵营", "frost": "法师塔", "cannon": "火炮塔"}
var preview_branch := ""

func initialize(owner: Node) -> void:
	game = owner
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = 324
	add_theme_stylebox_override("panel", game._style("eadbb5", "725334", 10))
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	hide()

func _button(text: String, kind: String, payload: Dictionary, price := 0, blocked := false) -> Button:
	var button: Button = game._button(text, func(): game._send(kind, payload))
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size.y = 34
	tracked.append({"button": button, "price": price, "blocked": blocked})
	return button

func refresh(force := false) -> void:
	var state: Dictionary = game.session.match_model.state
	var cfg = game.session.match_model.cfg
	var selected: String = game.selected
	if selected.is_empty() or not cfg.nodes.has(selected) or not game.pending_map_action.is_empty() or state.phase in ["won", "lost"]:
		hide()
		return
	var tower: Dictionary = state.towers.get(selected, {})
	var next_signature: String = selected + game.session.player + str(tower.get("id", "")) + str(tower.get("level", 0)) + str(tower.get("branch", "")) + str(tower.get("strategy", "")) + str(tower.get("upgrade_end", 0) > state.time) + str(game.sell_confirm) + str(tower.get("skills",{})) + str(tower.get("shared_control",false))
	if selected != node_id:
		detail_kind = ""
		expanded = false
		node_id = selected
	if force or signature != next_signature:
		signature = next_signature
		_rebuild()
	show()
	for item in tracked:
		item.button.disabled = item.blocked or state.paused or int(state.gold[game.session.player]) < int(item.price) * 4
		if tower.is_empty() and game.session.match_model.Expansion.node_locked(game.session.match_model,selected):item.button.disabled=true
		if item.has("skill"):
			var remaining: int = maxi(0,int(ceil(float(tower.get("skill_at",{}).get(item.skill,0))-float(state.time))))
			item.button.text=item.skill_name+(" · %ds" % remaining if remaining>0 else " · 施放")
			item.button.disabled = remaining>0 or state.paused or not game.session.match_model.Expansion.active(game.session.match_model,tower,item.skill=="rod")
	var anchor: Vector2 = game.field.screen(cfg.vector(cfg.nodes[selected].position))
	var height := maxf(get_combined_minimum_size().y, 100)
	size = Vector2(324, height)
	# Choose the side with room and keep the selected node visible.
	var x := anchor.x + 42 if anchor.x + 42 + size.x <= 978 else anchor.x - 42 - size.x
	position = Vector2(clampf(x, 24, 978 - size.x), clampf(anchor.y - height * 0.45, 112, 690 - height))

func _rebuild() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	tracked.clear()
	preview_branch = ""
	game.build_buttons.clear()
	var state: Dictionary = game.session.match_model.state
	var cfg = game.session.match_model.cfg
	var player: String = game.session.player
	var node: Dictionary = cfg.nodes[node_id]
	var tower: Dictionary = state.towers.get(node_id, {})
	var heading := HBoxContainer.new()
	var tower_name: String = BASE_NAMES.get(tower.id, "") if not tower.is_empty() and tower.get("branch", "").is_empty() else (cfg.towers[tower.id].name if not tower.is_empty() else "")
	var title: Label = game._label("选择基础塔" if tower.is_empty() else tower_name + " · Lv." + str(tower.level), 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close: Button = game._button("×", func(): game.selected = ""; game.sell_confirm = ""; hide(), 28)
	close.custom_minimum_size.y = 26
	heading.add_child(close)
	content.add_child(heading)
	content.add_child(game._label("共享地基 · 先建先管理" if node.owner == "shared" else node.owner.to_upper() + " 专属地基", 12, "745c3d"))
	if tower.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		content.add_child(grid)
		for id in cfg.tower_rules.base_towers:
			var spec: Dictionary = cfg.towers[id]
			var build := _button(BASE_NAMES[id] + "\n%dg" % int(spec.cost), "build", {"node": node_id, "tower": id}, int(spec.cost), node.owner not in [player, "shared"])
			build.custom_minimum_size = Vector2(149, 49)
			build.add_theme_stylebox_override("normal", game._style("425c50", "876843", 6))
			var icon := TowerIcon.new()
			icon.kind = id
			icon.position = Vector2(4, 13)
			icon.scale = Vector2(0.72, 0.72)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			build.add_child(icon)
			build.add_theme_constant_override("outline_size", 0)
			build.tooltip_text = spec.description
			build.mouse_entered.connect(func(): _show_detail(id, false))
			grid.add_child(build)
			game.build_buttons.append(build)
		if detail_kind.is_empty(): detail_kind = "archer"
	else:
		detail_kind = tower.id
		var owned: bool = tower.owner == player or bool(tower.get("shared_control",false))
		content.add_child(game._label("由 " + tower.owner.to_upper() + " 管理", 12))
		if owned:
			var price := int(ceil(float(cfg.towers[tower.id].cost) * (0.8 if tower.level == 1 else 1.2)))
			if tower.level < 3:
				content.add_child(_button("升级至 Lv.%d · %dg" % [tower.level + 1, price], "upgrade", {"node": node_id}, price, tower.upgrade_end > state.time))
				content.add_child(game._label("升至三级后解锁两条路线，四种分支。", 12, "745c3d"))
			elif tower.get("branch", "").is_empty():
				content.add_child(game._label("三级路线 · 选择后固定，可出售重建", 13))
				var routes := HBoxContainer.new()
				routes.add_theme_constant_override("separation", 6)
				content.add_child(routes)
				for target in cfg.tower_rules.upgrade_routes[tower.get("base_id", tower.id)]:
					var column := VBoxContainer.new()
					column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					routes.add_child(column)
					column.add_child(game._label(cfg.towers[target].name, 12, "48627a"))
					var branch_price: int = game.session.match_model.branch_cost(tower, target)
					for option in cfg.towers[target].branches:
						var branch := _button(option.name + ("\n+%dg" % branch_price if branch_price > 0 else "\n已包含升级费用"), "specialize", {"node": node_id, "tower": target, "branch": option.id}, branch_price, tower.upgrade_end > state.time)
						branch.custom_minimum_size = Vector2(149, 49)
						branch.tooltip_text = option.description + ("；转换后士兵撤离" if tower.id == "barracks" and target == "beacon" else "")
						branch.mouse_entered.connect(func(): preview_branch = option.id; _show_detail(target, false))
						branch.mouse_exited.connect(func(): preview_branch = ""; detail_kind = tower.id; _update_details())
						column.add_child(branch)
				if tower.id == "barracks": content.add_child(game._label("转为灯塔会撤离士兵，改为治疗与增益。", 12))
			else:
				for option in cfg.towers[tower.id].branches:
					if option.id == tower.branch: content.add_child(game._label("分支：" + option.name + " · 已达最高级", 13, "48627a"))
				var grid := GridContainer.new()
				grid.columns=2
				content.add_child(grid)
				for skill in cfg.towers[tower.id].skills:
					var rank:int=int(tower.get("skills",{}).get(skill.id,0))
					var cost:int=int(skill.costs[rank]) if rank<2 else 0
					var buy:=_button(skill.name+" · 已满级" if rank==2 else ("学习 " if rank==0 else "强化 ")+skill.name+" · %dg"%cost,"tower_skill_upgrade",{"node":node_id,"skill":skill.id},cost,rank>=2 or tower.upgrade_end>state.time)
					buy.custom_minimum_size=Vector2(149,34)
					buy.add_theme_font_size_override("font_size",11)
					buy.tooltip_text=skill.description+" 两阶强化，上限Lv.2。"
					grid.add_child(buy)
					var cast:=_button(skill.name+" · 施放","tower_skill",{"node":node_id,"skill":skill.id},0,rank==0)
					cast.custom_minimum_size=Vector2(149,34)
					cast.add_theme_font_size_override("font_size",11)
					grid.add_child(cast)
					if rank>0:
						tracked[-1].skill=skill.id
						tracked[-1].skill_name="["+game.preferences.label("tower_one" if skill.id==cfg.towers[tower.id].skills[0].id else "tower_two")+"] "+skill.name+" Lv."+str(rank)
			if tower.owner==player:
				content.add_child(_button("队友操作："+("已授权" if tower.get("shared_control",false) else "未授权"),"tower_control",{"node":node_id}))
			else:content.add_child(game._label("队友已授权 · 升级使用你的金币",12))
			if tower.id != "beacon":
				content.add_child(_button("索敌：" + STRATEGIES.get(tower.strategy, "出口优先") + "  ↻", "strategy", {"node": node_id}, 0, tower.upgrade_end > state.time or tower.id == "barracks"))
			if tower.id == "barracks":
				content.add_child(game._button("设置集结点 · 点击道路", func(): game.pending_map_action = "rally"; hide(); game._message("点击兵营五格内的道路，Esc 取消")))
			var selling: bool = game.sell_confirm == node_id
			var sell: Button = game._button(("确认出售 · " if selling else "出售 · ") + "返还 %dg" % int(floor(tower.spent * 0.7)), game._confirm_sell)
			tracked.append({"button": sell, "price": 0, "blocked": tower.upgrade_end > state.time or tower.owner != player})
			content.add_child(sell)
		else:
			content.add_child(game._label("队友管理，可查看说明与射程。", 13))
	detail_toggle = game._button("", func(): expanded = not expanded; _update_details())
	detail_toggle.custom_minimum_size.y = 29
	detail_toggle.add_theme_font_size_override("font_size", 12)
	content.add_child(detail_toggle)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 88 if expanded else 0
	scroll.name = "DetailScroll"
	content.add_child(scroll)
	details = game._label("", 12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 292
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	_update_details()

func _show_detail(kind: String, open := true) -> void:
	detail_kind = kind
	if open: expanded = true
	_update_details()

func _update_details() -> void:
	if not is_instance_valid(details): return
	var cfg = game.session.match_model.cfg
	var spec: Dictionary = cfg.towers[detail_kind]
	detail_toggle.text = ("▾ 收起说明 · " if expanded else "▸ 详细说明 · ") + spec.name
	var target := "对地对空" if "air" in spec.targets else ("支援盟友" if detail_kind == "beacon" else "仅对地")
	details.text = "%s\n射程 %.1f格 · %s\n" % [spec.description, float(spec.get("range", 5)), target]
	if float(spec.get("damage", 0)) > 0:
		details.text += "基础伤害 %d · 间隔 %.1fs\n" % [int(spec.damage), float(spec.interval)]
	var tower: Dictionary = game.session.match_model.state.towers.get(node_id, {})
	if not tower.is_empty() and tower.id == detail_kind:
		var mods: Dictionary = game.session.match_model.tower_mods(tower)
		details.text += "当前射程 %.1f格\n" % game.session.match_model.tower_range(tower)
	if (tower.is_empty() and cfg.tower_rules.upgrade_routes.has(detail_kind)) or (not tower.is_empty() and tower.level < 3):
		details.text += "三级可选路线：\n"
		for target_kind in cfg.tower_rules.upgrade_routes.get(tower.get("base_id", tower.get("id", detail_kind)), []):
			for branch in cfg.towers[target_kind].branches: details.text += cfg.towers[target_kind].name + " / " + branch.name + "：" + branch.description + "\n"
	else:
		for branch in spec.branches: details.text += branch.name + "：" + branch.description + "\n"
		for skill in spec.get("skills",[]):details.text+=skill.name+"："+skill.description+" 冷却%d秒，学习70g／强化100g。\n"%int(skill.cooldown)
	var scroll: ScrollContainer = details.get_parent()
	scroll.visible = expanded
	scroll.custom_minimum_size.y = 88 if expanded else 0
	# Container minimum size is recomputed next frame; refresh then reclamps it.
	queue_sort()

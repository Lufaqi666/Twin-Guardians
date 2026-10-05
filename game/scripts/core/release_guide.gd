extends RefCounted

static func text(state: Dictionary, cfg, keys, selected: String) -> String:
	var own: Array = state.towers.values()
	var stage: String = state.level_id
	if stage=="confluence_courtyard":
		if own.is_empty():return "第1关 · 建造：左键点道路旁地基，再选基础塔；注意悬停射程是否覆盖道路。"
		if state.wave==0:return "第1关 · 出发：已建好防线，按 %s 准备；右键或移动键指挥英雄。"%keys.label("ready")
		return "第1关 · 守线：英雄停驻可阻挡地面敌人；%s 放技能，飞行敌人需要对空塔。"%keys.label("skill")
	if stage=="frost_pass":
		var final:=false
		var learned:=false
		for tower in own:
			final=final or not str(tower.get("branch","")).is_empty()
			learned=learned or not tower.get("skills",{}).is_empty()
		if not final:return "第2关 · 分支：塔先升二级、再升三级；完工后选择路线，选择会固定。魔法可应对重甲。"
		if not learned:return "第2关 · 学习：选中高级塔，在塔旁购买主动技能；每项两级，详细说明按需展开。"
		return "第2关 · 施放：选中高级塔，%s / %s 放塔技能；%s 跳到技能就绪的可操作塔。"%[keys.label("tower_one"),keys.label("tower_two"),keys.label("tower_next")]
	if stage=="ember_ruins":
		if state.active_relays==0:return "第3关 · 接力：队友技能留下4秒弱点，再接英雄技能爆发；靠近倒地队友按住 %s 救援。"%keys.label("rescue")
		return "第3关 · 分工：事件预警时分头守住两处信标3秒；塔旁可授权队友操作，队友投资扣自己的金币。"
	var mechanism: Dictionary=state.get("mechanism",{})
	if mechanism.get("kind","")=="escort" and mechanism.get("cart_active",false) and not mechanism.cart_done:
		return "护送教学：活着的英雄靠近车才会前进；一人护送、一人清路。成功双方获得奖励。"
	if mechanism.get("kind","")=="lock" and mechanism.get("lock_end",0)>state.time and not mechanism.get("unsealed",false):
		return "封锁教学：中央地基暂时停用；英雄靠近晶核后，在战术工具花50g提前解封。"
	if mechanism.get("kind","")=="junction":return "岔路教学：机关改变后续地面敌人的路线；英雄靠近中央，在战术工具花30g切换。"
	if not selected.is_empty():return "塔操作：%s / %s 放已学习技能，%s 跳到就绪塔；详细说明按需展开。"%[keys.label("tower_one"),keys.label("tower_two"),keys.label("tower_next")]
	return "合作：分守信标、技能接力与救援；裂隙领主需要不同玩家3秒内先后命中破印。"

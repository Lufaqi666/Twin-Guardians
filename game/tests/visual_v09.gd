extends SceneTree

var checks:=0
var failed:=false
var serial:=0
var suffix:="v09"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suffix="):suffix=arg.trim_prefix("--suffix=")
	call_deferred("run")
func verify(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed=true;printerr("FAIL ",label)
func order(game,kind:String,data:Dictionary) -> void:
	serial+=1
	verify(game.session.match_model.command("p1",kind,data,"visual09-"+str(serial)).accepted,"preview command "+kind)
func capture(game,name:String) -> void:
	game._process(.01)
	await process_frame
	await process_frame
	game._process(.01)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/"+name+"-"+suffix+".png"))
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.persist_progress=false
	root.add_child(game)
	game.combat_audio.enabled=false
	game._start_practice()
	game.session.set_physics_process(false)
	var m=game.session.match_model
	m.state.gold={"p1":40000,"p2":40000}
	# Every final tower, all sixteen anchors, expanded skill descriptions.
	for kind in m.cfg.towers:
		m.state.towers.clear();m.state.soldiers.clear()
		var base:String=kind
		for family in m.cfg.tower_rules.upgrade_routes:
			if kind in m.cfg.tower_rules.upgrade_routes[family]:base=family
		order(game,"build",{"node":"shared_01","tower":base})
		order(game,"upgrade",{"node":"shared_01"})
		m.state.time+=3
		order(game,"upgrade",{"node":"shared_01"})
		m.state.time+=3
		order(game,"specialize",{"node":"shared_01","tower":kind,"branch":m.cfg.towers[kind].branches[0].id})
		m.state.time+=3
		for ability in m.cfg.towers[kind].skills:
			order(game,"tower_skill_upgrade",{"node":"shared_01","skill":ability.id})
		var source:Dictionary=m.state.towers.shared_01.duplicate(true)
		game.selected="shared_01"
		game.tower_menu.refresh(true)
		game.tower_menu.expanded=true
		game.tower_menu._update_details()
		if kind=="storm":
			await capture(game,"tower-skills")
			var cast:Button
			for item in game.tower_menu.tracked:
				if item.get("skill","")=="rod":cast=item.button
			verify(is_instance_valid(cast),"skill button exists")
			cast.pressed.emit()
			game._process(.01)
			verify(cast.disabled and cast.text.contains("s"),"skill button reflects real cooldown")
			order(game,"tower_control",{"node":"shared_01"})
			await capture(game,"tower-cooperation")
		for node in m.cfg.nodes:
			var fixture:Dictionary=source.duplicate(true)
			fixture.pos=m.cfg.vector(m.cfg.nodes[node].position)
			m.state.towers[node]=fixture
			game.selected=node
			game.tower_menu.refresh(true)
			game.tower_menu.expanded=true
			game.tower_menu._update_details()
			await process_frame
			await process_frame
			game.tower_menu.refresh()
			var rect:=Rect2(game.tower_menu.position,game.tower_menu.size)
			verify(Rect2(23,110,955,580).encloses(rect),kind+" skills panel bounds "+node)
			verify(not rect.grow(16).has_point(game.field.screen(fixture.pos)),kind+" selected tower visible "+node)
	for stage in ["thornwood","moonbrook","glacier_keep","eclipse_gate"]:
		game.session.practice(stage,"ranger","stormcaller",true)
		game.session.set_physics_process(false)
		m=game.session.match_model
		m.state.gold={"p1":40000,"p2":40000}
		game.selected=""
		m.state.wave=3 if stage in ["moonbrook","glacier_keep"] else 2
		m._start_wave()
		m.state.spawn_index=m.cfg.waves[m.state.wave-1].events.size()
		if stage=="glacier_keep":
			order(game,"build",{"node":"shared_03","tower":"archer"})
			m.state.time=m.state.mechanism.lock_at+1
		if stage=="moonbrook":m.state.heroes.p1.pos=m.cfg.route_position("a_default",m.state.mechanism.cart_s)
		if stage=="eclipse_gate":
			var boss_id:int=m.spawn("rift_lord","a")
			var lord:Dictionary=m.state.enemies[boss_id]
			lord.s=15;lord.pos=m.cfg.route_position(lord.route,15)
			m.Expansion.update(m,.05)
			for kind in ["saboteur","splitter"]:
				var id:int=m.spawn(kind,"b")
				m.state.enemies[id].s=12 if kind=="saboteur" else 16
				m.state.enemies[id].pos=m.cfg.route_position(m.state.enemies[id].route,m.state.enemies[id].s)
		game.tools_expanded=true
		game.last_panel=""
		await capture(game,"mechanism-"+stage)
	game.queue_free()
	await process_frame
	print("VISUAL_V09 ",checks," checks ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

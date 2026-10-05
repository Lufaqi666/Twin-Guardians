extends SceneTree

var checks:=0
var failed:=false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed=true;printerr("FAIL ",label)
func capture(game,name:String) -> void:
	game._process(.016)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/"+name+"-v10.png"))
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.persist_progress=false;root.add_child(game);game.combat_audio.enabled=false
	game._start_practice();game.session.set_physics_process(false)
	await capture(game,"first-stage-guide")
	game.settings_panel.show()
	await capture(game,"release-settings")
	check(Rect2(0,0,1280,800).encloses(game.settings_panel.get_global_rect()),"settings panel fits viewport")
	var scroll:ScrollContainer=game.settings_panel.get_child(0)
	scroll.scroll_vertical=2000
	await capture(game,"release-settings-feedback")
	check(scroll.scroll_vertical>0,"new settings can scroll to feedback")
	game.settings_panel.hide();game.feedback_dialog.popup_centered()
	await capture(game,"local-feedback")
	check(game.feedback_dialog.visible and game.feedback_notes.size.y>=220,"feedback editable notes visible")
	game.feedback_dialog.hide()
	var m=game.session.match_model
	m.state.gold={"p1":50000,"p2":50000}
	for item in [{"kind":"build","data":{"node":"shared_01","tower":"frost"}},{"kind":"upgrade","data":{"node":"shared_01"}},{"kind":"upgrade","data":{"node":"shared_01"}},{"kind":"specialize","data":{"node":"shared_01","tower":"storm","branch":"overload"}},{"kind":"tower_skill_upgrade","data":{"node":"shared_01","skill":"rod"}}]:
		check(m.command("p1",item.kind,item.data,str(checks)).accepted,"fixture production progression")
		m.state.time+=3
	game.selected="shared_01"
	for quality in [0,1,2]:
		game.preferences.effects=quality;game._apply_preferences()
		m.state.towers.shared_01.skill_at={}
		check(m.command("p1","tower_skill",{"node":"shared_01","skill":"rod"},"cast-quality-"+str(quality)).accepted,"cast with effect quality "+str(quality))
		await capture(game,"effects-quality-"+str(quality))
		check(Rect2(23,110,955,580).encloses(Rect2(game.tower_menu.position,game.tower_menu.size)),"shortcut labels keep tower menu inside battlefield")
	game.queue_free();await process_frame
	print("VISUAL_RELEASE ",checks," checks ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

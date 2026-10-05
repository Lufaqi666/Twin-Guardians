extends SceneTree

var checks:=0
var failed:=false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed=true;printerr("FAIL ",label)
func key(game,code:int) -> void:
	var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=code
	game._unhandled_input(event)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	game.persist_progress=false;root.add_child(game)
	game.combat_audio.enabled=false
	game._start_practice();game.session.set_physics_process(false)
	var m=game.session.match_model
	check(game.tutorial_text().contains("建造"),"first stage starts with building")
	m.state.gold={"p1":50000,"p2":50000}
	check(m.command("p1","build",{"node":"shared_01","tower":"frost"},"rel1").accepted,"build tutorial progresses")
	check(game.tutorial_text().contains("出发"),"built tower prompts ready")
	game.session.practice("frost_pass","ranger","stormcaller",true)
	game.session.set_physics_process(false);m=game.session.match_model;m.state.gold={"p1":50000,"p2":50000}
	check(game.tutorial_text().contains("分支"),"second stage teaches branches")
	for item in [{"kind":"build","data":{"node":"shared_01","tower":"frost"}},{"kind":"upgrade","data":{"node":"shared_01"}},{"kind":"upgrade","data":{"node":"shared_01"}},{"kind":"specialize","data":{"node":"shared_01","tower":"storm","branch":"chain"}}]:
		check(m.command("p1",item.kind,item.data,str(checks)).accepted,"production tower progression "+item.kind)
		m.state.time+=3
	check(game.tutorial_text().contains("学习"),"branch teaches learning")
	check(m.command("p1","tower_skill_upgrade",{"node":"shared_01","skill":"rod"},"learn").accepted,"learn support skill")
	game.selected="";key(game,KEY_C)
	check(game.selected=="shared_01","ready cycle selects learned available tower")
	check(game.tutorial_text().contains("施放"),"learned skill teaches casting")
	key(game,KEY_2)
	check(m.state.towers.shared_01.skill_at.rod>m.state.time,"shortcut casts actual skill")
	var used:int=m.state.advanced_stats.skills
	key(game,KEY_2)
	check(m.state.advanced_stats.skills==used,"shortcut respects cooldown")
	m.state.time+=30;game.session.player="p2";key(game,KEY_2)
	check(m.state.advanced_stats.skills==used,"shortcut denies unauthorized teammate")
	m.state.towers.shared_01.shared_control=true;key(game,KEY_2)
	check(m.state.advanced_stats.skills==used+1,"authorized teammate can cast shortcut")
	game.preferences.effects=0;game._apply_preferences()
	check(game.field.effect_quality==0,"low effects applied")
	game.preferences.effects=2;game._apply_preferences()
	check(game.field.effect_quality==2,"high effects applied")
	game.playtest_report.directory=ProjectSettings.globalize_path("res://../.work/tests/playtest_reports")
	game.playtest_report.sample(m.state)
	game.playtest_report.finish(m.state,m.cfg,game.session.mode)
	var report:Dictionary=game.playtest_report.report
	check(report.towers.size()==1 and report.towers[0].kind=="storm","report captures final formation")
	check(report.advanced.skills==used+1 and not report.has("address"),"report captures skill use without endpoint")
	var saved:Dictionary=game.playtest_report.save("技能操作较方便",4)
	check(saved.error==OK,"feedback saved locally")
	var data=JSON.parse_string(FileAccess.get_file_as_string(saved.path))
	check(data.feedback.difficulty==4 and data.feedback.comment=="技能操作较方便","feedback roundtrip")
	DirAccess.remove_absolute(saved.path)
	var prefs=game.Preferences.new();prefs.path=ProjectSettings.globalize_path("res://../.work/tests/test_release_preferences.json")
	var legacy:Dictionary=game.Preferences.DEFAULT_KEYS.duplicate()
	legacy.erase("tower_one");legacy.erase("tower_two");legacy.erase("tower_next")
	legacy.skill=KEY_1
	var file:=FileAccess.open(prefs.path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"keys":legacy,"effects":9}));file.close()
	prefs.read()
	check(prefs.keys.skill==KEY_1,"legacy custom hero binding preserved")
	check(prefs.keys.tower_one!=KEY_1 and prefs.keys.values().size()==16,"new bindings avoid legacy collision")
	check(prefs.effects==2,"invalid effects value clamped")
	prefs.effects=0;prefs.playtest=true;prefs.write()
	var restored=game.Preferences.new();restored.path=prefs.path;restored.read()
	check(restored.effects==0 and restored.playtest,"new preferences persist")
	DirAccess.remove_absolute(prefs.path)
	var career=game.session.Career.new()
	career.path=ProjectSettings.globalize_path("res://../.work/tests/test_release_career.json")
	career.records={"p1:ranger":{"xp":100,"skill_level":1}}
	career.dirty=true;check(career.write()==OK,"initial career save")
	career.stage_stars.frost_pass=3;career.dirty=true
	check(career.write()==OK and FileAccess.file_exists(career.path+".bak"),"valid previous save backed up")
	file=FileAccess.open(career.path,FileAccess.WRITE);file.store_string("broken save");file.close()
	var recovered=game.session.Career.new();recovered.path=career.path;recovered.read()
	check(recovered.recovered and recovered.profile("p1","ranger").xp==100,"corrupt primary recovers last valid backup")
	check(recovered.write()==OK,"recovered save restored atomically")
	var reread=game.session.Career.new();reread.path=career.path;reread.read()
	check(not reread.recovered and reread.profile("p1","ranger").xp==100,"restored primary readable")
	for suffix in ["",".bak"]:DirAccess.remove_absolute(career.path+suffix)
	var audio_keys:Dictionary={}
	for kind in ["archer","barracks","frost","cannon","alchemy","ballista","storm","beacon"]:
		var stream:AudioStreamWAV=game.combat_audio.sounds["tower_"+kind]
		audio_keys[stream.data.hex_encode().sha256_text()]=true
	check(audio_keys.size()==8 and game.combat_audio.sounds.has("warning"),"eight distinct tower cues and danger warning")
	game.session.practice("ember_ruins","ranger","stormcaller",true);game.session.set_physics_process(false)
	check(game.tutorial_text().contains("接力"),"third stage teaches cooperation")
	game.session.match_model.state.active_relays=1
	check(game.tutorial_text().contains("分工"),"cooperation tutorial advances after real relay")
	game._return_menu()
	game.session.mode="client";game.session.authenticated=false;game.session.initial_join_deadline=.001;game.session.reconnect_token=""
	game.session._physics_process(0)
	check(game.session.mode=="menu" and game.toast.contains("连接超时"),"initial timeout releases blocked lobby")
	game.queue_free();await process_frame
	print("RELEASE_TESTS ",checks," checks ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

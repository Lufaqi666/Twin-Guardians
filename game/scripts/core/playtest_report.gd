extends RefCounted

var attempts: Dictionary={}
var report: Dictionary={}
var started_ms:=0
var samples: Array=[]
var sample_at:=0.0
var directory:="user://playtest_reports"

func begin() -> void:
	attempts.clear();report.clear();samples.clear();sample_at=0;started_ms=Time.get_ticks_msec()

func command(kind:String,result:Dictionary) -> void:
	if kind=="move":return
	var counts:Dictionary=attempts.get(kind,{"accepted":0,"rejected":0,"pending":0})
	var key:="pending" if result.get("pending",false) else ("accepted" if result.get("accepted",false) else "rejected")
	counts[key]+=1;attempts[kind]=counts

func sample(state:Dictionary) -> void:
	if float(state.time)<sample_at:return
	sample_at=float(state.time)+10
	if samples.size()<600:samples.append({"time":snappedf(state.time,.1),"wave":state.wave,"hp":state.hp,"gold_p1":int(state.gold.p1)/4,"gold_p2":int(state.gold.p2)/4,"towers":state.towers.size()})

func finish(state:Dictionary,cfg,mode:String) -> Dictionary:
	var towers: Array=[]
	for node in state.towers:
		var tower:Dictionary=state.towers[node]
		towers.append({"node":node,"kind":tower.id,"owner":tower.owner,"level":tower.level,"branch":tower.get("branch",""),"skills":tower.get("skills",{}).duplicate(true),"spent":tower.spent})
	report={"version":"0.10","level":state.level_id,"mode":mode,"challenge":state.challenge,"result":state.phase,"wave":state.wave,"hp":state.hp,"simulation_seconds":snappedf(state.time,.1),"wall_seconds":(Time.get_ticks_msec()-started_ms)/1000.0,"config_hash":cfg.config_hash,"commands":attempts.duplicate(true),"samples":samples.duplicate(true),"towers":towers,"damage_by_tower":state.get("tower_damage",{}).duplicate(true),"leaks":state.leak_log.duplicate(true),"advanced":state.advanced_stats.duplicate(true)}
	return report

func save(comment:String="",difficulty:int=3) -> Dictionary:
	if report.is_empty():return {"error":ERR_UNCONFIGURED,"path":""}
	var error:=DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK:return {"error":error,"path":""}
	var path:=directory+"/playtest-"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(Time.get_ticks_usec())+".json"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return {"error":FileAccess.get_open_error(),"path":""}
	var data:=report.duplicate(true)
	data.feedback={"difficulty":clampi(difficulty,1,5),"comment":comment.left(4000)}
	file.store_string(JSON.stringify(data,"\t"));file.close()
	return {"error":OK,"path":ProjectSettings.globalize_path(path)}

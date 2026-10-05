extends SceneTree

const Match = preload("res://scripts/core/match_state.gd")
var count := 0
var errors: Array[String] = []
var serial := 0

func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	count+=1
	if not ok:errors.append(text);printerr("FAIL ",text)
func cmd(m, player: String, kind: String, data: Dictionary = {}) -> Dictionary:
	serial+=1
	return m.command(player,kind,data,"expansion-"+str(serial))
func fresh(level := "confluence_courtyard"):
	var m=Match.new()
	m.configure(level,{"p1":"commander","p2":"skirmisher"})
	m.state.gold={"p1":40000,"p2":40000}
	return m
func tower(m, kind: String, node := "shared_01") -> Dictionary:
	var base:=kind
	for family in m.cfg.tower_rules.upgrade_routes:
		if kind in m.cfg.tower_rules.upgrade_routes[family]:base=family
	check(cmd(m,"p1","build",{"node":node,"tower":base}).accepted,"base purchase "+kind)
	cmd(m,"p1","upgrade",{"node":node})
	m.state.time+=3
	cmd(m,"p1","upgrade",{"node":node})
	m.state.time+=3
	cmd(m,"p1","specialize",{"node":node,"tower":kind,"branch":m.cfg.towers[kind].branches[0].id})
	m.state.time+=3
	return m.state.towers[node]

func run() -> void:
	for kind in Match.new().cfg.towers:
		for skill in Match.new().cfg.towers[kind].skills:
			var m=fresh()
			var t:Dictionary=tower(m,kind)
			var node:="shared_01"
			var before:int=m.state.gold.p1
			check(not cmd(m,"p2","tower_skill_upgrade",{"node":node,"skill":skill.id}).accepted,"unauthorized learning "+skill.id)
			check(not cmd(m,"p1","tower_skill_upgrade",{"node":node,"skill":"forged"}).accepted and m.state.gold.p1==before,"invalid skill is atomic")
			m.state.gold.p1=279
			check(not cmd(m,"p1","tower_skill_upgrade",{"node":node,"skill":skill.id}).accepted and m.state.gold.p1==279,"insufficient skill gold")
			m.state.gold.p1=before
			check(cmd(m,"p1","tower_skill_upgrade",{"node":node,"skill":skill.id}).accepted and m.state.gold.p1==before-280,"first rank exact payment "+skill.id)
			before=m.state.gold.p1
			check(cmd(m,"p1","tower_skill_upgrade",{"node":node,"skill":skill.id}).accepted and m.state.gold.p1==before-400,"second rank exact payment")
			before=m.state.gold.p1
			check(not cmd(m,"p1","tower_skill_upgrade",{"node":node,"skill":skill.id}).accepted and m.state.gold.p1==before,"rank cap cannot spend")
			var origin:Vector2=t.rally if kind=="barracks" else t.pos
			m.state.heroes.p1.pos=origin
			m.state.heroes.p1.hp=80
			cmd(m,"p2","build",{"node":"shared_02","tower":"archer"})
			var friend:Dictionary=m.state.towers.shared_02
			friend.pos=origin
			if skill.id=="rod":friend.jam_end=m.state.time+10;t.jam_end=m.state.time+10
			var id:int=m.spawn("heavy","a")
			var e:Dictionary=m.state.enemies[id]
			e.pos=origin+Vector2(1,0)
			e.hp=2000.0;e.max_hp=3000.0
			check(cmd(m,"p1","tower_skill",{"node":node,"skill":skill.id}).accepted,"actual cast "+skill.id)
			match skill.id:
				"wall":
					m._hurt_hero(m.state.heroes.p1,e,40)
					check(m.state.heroes.p1.hp==60,"wall reduces real damage")
				"heal":check(m.state.heroes.p1.hp>80,"heal restores real health")
				"banner":check(friend.skill_damage_boost>1.4 and friend.skill_damage_end>m.state.time,"banner buffs partner only")
				"rod":check(friend.jam_end==0 and t.jam_end==0 and e.stun_end>m.state.time,"rod cleanses jams and stuns")
				"freeze":check(e.stun_end>m.state.time,"freeze applies actual stun")
				"snare":check(e.frost_end>m.state.time and e.frost_slow==.65,"snare applies actual slow")
				"ignite","blizzard":
					m._zones(.5)
					check(e.hp<2000 and m.state.zones[0].kind==("ice" if skill.id=="blizzard" else "fire"),"persistent field damages "+skill.id)
				_:check(e.hp<2000,"skill changes enemy health "+skill.id)
			check(not cmd(m,"p1","tower_skill",{"node":node,"skill":skill.id}).accepted and m.state.advanced_stats.skills==1,"cooldown prevents repeat cast")
			var copy=Match.new();copy.apply_snapshot(m.snapshot())
			check(copy.state.towers[node].skills[skill.id]==2 and copy.state.towers[node].skill_at[skill.id]>copy.state.time,"rank and cooldown survive snapshot")
			m.state.time+=float(skill.cooldown)+1
			check(cmd(m,"p1","tower_skill",{"node":node,"skill":skill.id}).accepted,"cooldown expires "+skill.id)
	var m=fresh()
	var t:Dictionary=tower(m,"archer")
	check(not cmd(m,"p2","tower_control",{"node":"shared_01"}).accepted,"partner cannot grant permission")
	cmd(m,"p1","tower_control",{"node":"shared_01"})
	var p1_gold:int=m.state.gold.p1
	var p2_gold:int=m.state.gold.p2
	check(cmd(m,"p2","tower_skill_upgrade",{"node":"shared_01","skill":"volley"}).accepted and m.state.gold.p1==p1_gold and m.state.gold.p2==p2_gold-280,"delegation uses actor gold")
	check(not cmd(m,"p2","sell",{"node":"shared_01"}).accepted,"delegation never grants sale")
	cmd(m,"p1","tower_control",{"node":"shared_01"})
	check(not cmd(m,"p2","strategy",{"node":"shared_01"}).accepted,"revocation is immediate")
	var spent:int=t.spent
	var before:int=m.state.gold.p1
	cmd(m,"p1","sell",{"node":"shared_01"})
	check(m.state.gold.p1==before+int(floor(spent*.7))*4,"skill investment included in refund")
	m=fresh("thornwood")
	m.state.wave=2;m._start_wave()
	var id:int=m.spawn("infantry","a")
	check(m.state.enemies[id].route=="a_diverted","junction changes actual incoming route")
	id=m.spawn("flyer","a")
	check(m.state.enemies[id].route=="air_a","junction leaves air route intact")
	check(not cmd(m,"p1","mechanism").accepted,"junction operator must be nearby")
	m.state.heroes.p1.pos=Vector2(16,12)
	before=m.state.gold.p1
	check(cmd(m,"p1","mechanism").accepted and m.state.gold.p1==before-120,"junction charges once")
	id=m.spawn("infantry","a")
	check(m.state.enemies[id].route=="a_default" and not cmd(m,"p1","mechanism").accepted,"manual switch and operation cooldown")
	m=fresh("glacier_keep")
	t=tower(m,"storm","shared_03")
	cmd(m,"p1","tower_skill_upgrade",{"node":"shared_03","skill":"rod"})
	m.state.wave=3;m._start_wave()
	m.state.time=m.state.mechanism.lock_at+1
	before=m.state.gold.p1
	check(not cmd(m,"p1","build",{"node":"shared_04","tower":"archer"}).accepted and m.state.gold.p1==before,"locked empty foundation cannot spend")
	check(not m.Expansion.active(m,t) and not cmd(m,"p1","tower_skill",{"node":"shared_03","skill":"rod"}).accepted,"lock disables built tower and its skill")
	m.state.heroes.p1.pos=Vector2(16,12)
	check(cmd(m,"p1","mechanism").accepted and m.Expansion.active(m,t),"operator actually restores tower")
	m=fresh("moonbrook")
	m.state.wave=3;m._start_wave()
	var q:Dictionary=m.state.mechanism
	var start:float=q.cart_s
	m.Expansion.update(m,1)
	check(q.cart_s==start,"unescorted cart waits")
	for i in range(12):
		m.state.heroes.p1.pos=m.cfg.route_position("a_default",q.cart_s)
		m.Expansion.update(m,1)
	check(q.cart_done and m.state.advanced_stats.escort_wins==1,"living hero actually escorts to destination")
	before=m.state.gold.p1
	m.Expansion.update(m,1)
	check(m.state.gold.p1==before and m.state.resonance==30,"escort reward cannot repeat")
	m=fresh()
	t=tower(m,"archer")
	id=m.spawn("saboteur","a")
	var e:Dictionary=m.state.enemies[id]
	e.pos=t.pos
	m.Expansion.update(m,.1)
	check(e.jam_cast>m.state.time and m.Expansion.active(m,t),"saboteur warns before jam")
	m.state.time+=1.6;m.Expansion.update(m,.1)
	check(not m.Expansion.active(m,t),"saboteur actually disables tower")
	m.state.time+=4
	check(m.Expansion.active(m,t),"jam naturally expires")
	m=fresh();id=m.spawn("splitter","a");e=m.state.enemies[id];e.s=8;e.hp=0
	m._resolve_deaths()
	check(m.state.enemies.size()==2 and m.state.spawned==3,"splitter spawns exactly two living children")
	m._resolve_deaths()
	check(m.state.enemies.size()==2,"split corpse cannot spawn twice")
	m=fresh();id=m.spawn("rift_lord","a");e=m.state.enemies[id]
	check(m._damage(e,100,"true","p1",false)==40 and m._damage(e,100,"true","p1",false)==40,"single owner cannot break lord seal")
	check(m._damage(e,100,"true","p2",false)==125 and m.state.advanced_stats.seal_breaks==1,"partner breaks seal and exposes damage window")
	m.state.time+=5
	check(m._damage(e,100,"true","p2",false)==40,"seal reseals after window")
	e.hp=e.max_hp*.6
	m.Expansion.update(m,.1)
	check(m.state.enemies.size()==3 and e.rift_stage==1,"lord summons at first phase")
	var point:Vector2=e.pulse_pos
	m.state.heroes.p1.pos=point;m.state.heroes.p1.hp=200
	m.state.heroes.p2.pos=point+Vector2(4,0);m.state.heroes.p2.hp=200
	m.state.time=e.pulse_cast+.1;m.Expansion.update(m,.1)
	check(m.state.heroes.p1.hp<200 and m.state.heroes.p2.hp==200,"warning pulse damages only heroes who remain inside")
	print("EXPANSION_TESTS ",count-errors.size(),"/",count," passed")
	quit(0 if errors.is_empty() else 1)

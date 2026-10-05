extends SceneTree

const Art = preload("res://scripts/ui/tower_art.gd")
const FX = preload("res://scripts/ui/tower_fx.gd")
class Gallery extends Node2D:
	var configs: Dictionary
	var clock := 0.0
	var casts := false
	var font := SystemFont.new()
	func _ready() -> void:font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,900),Color("172331"))
		draw_string(font,Vector2(36,42),"高级塔 · 动态特效" if not casts else "高级塔 · 主动技能特效",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("ffe3a0"))
		var index := 0
		for kind in configs:
			for variant in range(2):
				var x := 35+(index%4)*310
				var y := 68+(index/4)*175
				draw_style_box(panel(),Rect2(x,y,294,166))
				var branch:Dictionary=configs[kind].branches[variant]
				var p := Vector2(x+145,y+115)
				var tower := {"id":kind,"level":3,"branch":branch.id,"pos":Vector2(index,2)}
				Art.paint(self,p,kind,3,Color("65b9e6"),clock)
				FX.idle(self,p,tower,clock,true,.7)
				if casts:
					var ability:Dictionary=configs[kind].skills[variant]
					FX.cast(self,p+Vector2(48,0),p,{"tower_kind":kind,"tower_skill":ability.id,"branch":branch.id,"radius":1.4},.35,Vector2(29,22))
				draw_string(font,Vector2(x+12,y+24),configs[kind].name+" · "+branch.name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d9e9f6"))
				if casts:draw_string(font,Vector2(x+12,y+154),configs[kind].skills[variant].name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a9d9ec"))
				index+=1
	func panel() -> StyleBoxFlat:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("263747")
		style.set_corner_radius_all(10)
		return style

func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,900)
	var catalog=load("res://scripts/core/catalog.gd").new()
	var gallery:=Gallery.new()
	gallery.configs=catalog.towers
	root.add_child(gallery)
	for mode in [false,true]:
		gallery.casts=mode
		for phase in [.2,1.4,2.7]:
			gallery.clock=phase
			gallery.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/advanced-tower-"+("skills" if mode else "auras")+".png"))
	gallery.queue_free()
	await process_frame
	var game=load("res://scenes/main.tscn").instantiate()
	game.persist_progress=false
	root.add_child(game)
	game.combat_audio.enabled=false
	game._start_practice()
	game.session.set_physics_process(false)
	var m=game.session.match_model
	var index:=0
	for kind in m.cfg.towers:
		var node:String=m.cfg.nodes.keys()[index]
		m.state.towers[node]={"id":kind,"level":3,"branch":m.cfg.towers[kind].branches[0].id,"pos":m.cfg.vector(m.cfg.nodes[node].position),"owner":"p1","upgrade_end":0.0,"attack_at":m.state.time+.1,"strategy":"exit","spent":300,"skills":{},"skill_at":{}}
		index+=1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/design/advanced-tower-battlefield.png"))
	game.queue_free()
	await process_frame
	print("TOWER_FX_VISUAL_PASS: sixteen branches, sixteen skills, three animation phases and battlefield integration")
	quit()

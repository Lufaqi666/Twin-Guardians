extends Node

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_sound: Dictionary = {}
var master_at := 0.0

func _ready() -> void:
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -19
		add_child(voice)
		voices.append(voice)
	for kind in ["hit", "slash", "blast", "hero_skill", "cast", "lightning", "block", "death", "level_up", "hero_down"]:
		sounds[kind] = _synthesize(kind)
	for kind in ["archer","barracks","frost","cannon","alchemy","ballista","storm","beacon"]:
		sounds["tower_"+kind]=_synthesize("tower_"+kind)
	sounds.warning=_synthesize("warning")

func on_event(event: Dictionary) -> void:
	var kind:String="tower_"+str(event.tower_kind) if event.has("tower_kind") else str(event.kind)
	if not enabled or not sounds.has(kind):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var strong: bool = kind in ["hero_skill", "level_up", "hero_down","warning"] or kind.begins_with("tower_")
	if now < float(next_sound.get(kind,0)) or (not strong and now<master_at):
		return
	# Important cues can replace a quiet impact when all six voices are occupied.
	if strong and voices.all(func(voice):return voice.playing):voices[0].stop()
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[kind]
			voice.volume_db = -13 if strong else -20
			voice.play()
			next_sound[kind] = now + (0.09 if kind == "hit" else .3 if strong else 0.15)
			master_at = now + 0.035
			return

func _synthesize(kind: String) -> AudioStreamWAV:
	var duration: float = {"hit": 0.08, "slash": 0.14, "blast": 0.32, "hero_skill": 0.45, "cast": 0.22, "lightning": 0.18, "block": 0.12, "death": 0.16, "level_up": 0.5, "hero_down": 0.3}.get(kind,.3)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(kind)
	var phase := 0.0
	var filtered := 0.0
	for i in range(count):
		var progress := float(i) / count
		var t := float(i) / 22050
		var noise := random.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, 0.18)
		var frequency := 1200.0
		var sample := 0.0
		var envelope := pow(1 - progress, 2.0)
		if kind.begins_with("tower_"):
			var base:float={"tower_archer":740,"tower_barracks":220,"tower_frost":960,"tower_cannon":75,"tower_alchemy":340,"tower_ballista":540,"tower_storm":140,"tower_beacon":660}[kind]
			frequency=base*(1+progress*.35)
			sample=sin(phase)*.4+sin(phase*1.5)*.15
			if kind in ["tower_cannon","tower_storm"]:sample+=filtered*.8
		elif kind=="warning":
			frequency=880 if progress<.5 else 660
			sample=sin(phase)*.5
		match kind:
			"blast", "hero_skill", "hero_down":
				frequency = lerpf(110, 36, progress)
				sample = filtered * 2 + sin(phase) * 0.55
			"slash", "death":
				frequency = lerpf(900, 120, progress)
				sample = noise * 0.55 + sin(phase) * 0.15
			"lightning":
				frequency = 80
				sample = noise * 0.6 + sin(phase) * 0.2
			"cast":
				frequency = lerpf(300, 1200, progress)
				sample = sin(phase) * 0.35 + sin(phase * 1.5) * 0.15
				envelope = sin(PI * progress)
			"level_up":
				frequency = [261.6, 329.6, 392.0, 523.2][mini(3, int(progress * 4))]
				sample = sin(phase) * 0.4 + sin(phase * 2) * 0.1
				envelope = sin(PI * fmod(progress * 4, 1)) * (1 - progress * 0.4)
			_:
				if not kind.begins_with("tower_") and kind!="warning":
					frequency = 1600 if kind == "block" else 2100
					sample = sin(phase) * 0.45 + sin(phase * 1.47) * 0.2 + noise * 0.3
		phase += TAU * frequency / 22050
		var attack := minf(1, t / 0.003)
		data.encode_s16(i * 2, int(clampf(sample * envelope * attack, -1, 1) * 23000))
	stream.data = data
	return stream

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()

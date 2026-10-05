extends RefCounted

# Original procedural painted materials; cached once and shared by UI/terrain.
static var panels: Dictionary = {}
static var grounds: Dictionary = {}

static func panel(bg: String, border: String, padding: int) -> StyleBoxTexture:
	var key := bg + border
	if not panels.has(key):
		var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
		var base := Color(bg)
		var edge := Color(border)
		var paper: bool = base.get_luminance() > 0.45
		for y in range(96):
			for x in range(96):
				var rim := float(mini(mini(x, 95 - x), mini(y, 95 - y)))
				var corner := Vector2(maxf(0, 8 - x) + maxf(0, x - 87), maxf(0, 8 - y) + maxf(0, y - 87))
				if corner.x > 0 and corner.y > 0: rim = 8 - corner.length()
				if rim < 0:
					image.set_pixel(x, y, Color.TRANSPARENT)
					continue
				var grain := sin(x * 1.73 + y * 7.17) * sin(x * 9.41 - y * 2.3)
				var wash := sin(x * 0.05 + y * 0.027) * 0.015
				var color := base.lightened(maxf(0, grain * 0.024 + wash)) if grain > 0 else base.darkened(-grain * 0.018)
				if rim < 2:
					color = edge.darkened(0.28)
				elif rim < 5:
					var light: bool = y < 5 or x < 5
					color = edge.lightened(0.26 if light else 0.04)
					color = color.lightened(grain * 0.035)
				elif rim < 6:
					color = base.darkened(0.24)
				elif rim < 7:
					color = base.lightened(0.13)
				elif not paper:
					color = color.lightened((1 - float(y) / 96) * 0.1)
				color.a = clampf(rim + 0.5, 0, 1)
				image.set_pixel(x, y, color)
		panels[key] = ImageTexture.create_from_image(image)
	var box := StyleBoxTexture.new()
	box.texture = panels[key]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 12)
		box.set_content_margin(side, padding)
	return box

static func ground(theme: String) -> Texture2D:
	if grounds.has(theme): return grounds[theme]
	var image := Image.create(480, 290, false, Image.FORMAT_RGB8)
	var broad := FastNoiseLite.new()
	broad.seed = 8723
	broad.frequency = 0.016
	broad.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = 317
	detail.frequency = 0.38
	var palette: Array = {"forest": [Color("637745"), Color("839653"), Color("a2ad66")], "snow": [Color("9bb3af"), Color("c3d3cc"), Color("e8eadb")], "desert": [Color("bb8c59"), Color("ccaa70"), Color("e9cb90")]}[theme]
	for y in range(290):
		for x in range(480):
			var wash := clampf(broad.get_noise_2d(x, y) * 0.6 + 0.5, 0, 1)
			var color: Color = palette[0].lerp(palette[1], wash * 1.6) if wash < 0.625 else palette[1].lerp(palette[2], (wash - 0.625) * 2.0)
			var brush := detail.get_noise_2d(x * 0.7, y * 1.8) * 0.025
			color = color.lightened(maxf(0, brush)) if brush >= 0 else color.darkened(-brush)
			var edge := pow(maxf(absf(float(x) / 480 - 0.5) * 2, absf(float(y) / 290 - 0.5) * 2), 3) * 0.1
			image.set_pixel(x, y, color.darkened(edge))
	grounds[theme] = ImageTexture.create_from_image(image)
	return grounds[theme]

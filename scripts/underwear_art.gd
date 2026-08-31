class_name UnderwearArt
extends RefCounted

## 按条目唯一 id 烘焙内裤贴图。同一 id 永远得到同一张图，替换库存色块占位。

static var _cache: Dictionary = {}


static func texture_for(item: Dictionary) -> Texture2D:
	var item_id: int = int(item.get("id", 0))
	if item_id <= 0:
		item_id = 1 + absi(int(item.get("quality", 0)) * 4099 + String(item.get("wear", "")).hash())
	if _cache.has(item_id):
		return _cache[item_id] as Texture2D
	var image: Image = _bake(
		item_id,
		int(item.get("quality", 0)),
		String(item.get("wear", item.get("wear_modifier", "")))
	)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[item_id] = texture
	return texture


static func _bake(item_id: int, quality: int, wear: String) -> Image:
	var width: int = 72
	var height: int = 80
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = item_id
	var base: Color = GameData.QUALITY_COLORS.get(quality, Color(0.75, 0.55, 0.85))
	var wear_dim: float = _wear_dim(wear)
	var cloth: Color = Color(base.r * wear_dim, base.g * wear_dim, base.b * wear_dim, 1.0)
	var band: Color = cloth.lightened(0.22)
	var stitch: Color = cloth.darkened(0.28)
	var pattern: int = rng.randi_range(0, 4)
	var cx: float = float(width) * 0.5
	for y: int in range(height):
		for x: int in range(width):
			if not _inside_brief(x, y, width, height):
				continue
			var color: Color = band if y < 16 else cloth
			color = _apply_pattern(color, x, y, pattern, rng, stitch)
			if y >= 16 and y <= 18:
				color = stitch
			image.set_pixel(x, y, color)
	_stamp_id_dots(image, item_id, cx)
	return image


static func _inside_brief(x: int, y: int, width: int, height: int) -> bool:
	var nx: float = (float(x) / float(width)) * 2.0 - 1.0
	var ny: float = float(y) / float(height)
	if ny < 0.06 or ny > 0.94:
		return false
	if ny < 0.20:
		return absf(nx) < 0.78
	var body: float = 0.74 - (ny - 0.20) * 0.18
	if ny > 0.62:
		var hole_x: float = 0.34
		var hole_y: float = (ny - 0.70) / 0.24
		var left: float = nx + hole_x
		var right: float = nx - hole_x
		if hole_y > 0.0 and (left * left + hole_y * hole_y < 0.085 or right * right + hole_y * hole_y < 0.085):
			return false
		body -= (ny - 0.62) * 0.35
	return absf(nx) < body


static func _apply_pattern(
	color: Color, x: int, y: int, pattern: int, rng: RandomNumberGenerator, stitch: Color
) -> Color:
	match pattern:
		0:
			if (x / 5 + y / 5) % 2 == 0:
				return color.lightened(0.08)
		1:
			if (x + y * 2) % 7 == 0:
				return stitch
		2:
			if (x % 8 < 3) and y > 16:
				return color.darkened(0.12)
		3:
			if ((x - 36) * (x - 36) + (y - 40) * (y - 40)) % 47 < 6:
				return color.lightened(0.16)
		_:
			if rng.randf() < 0.03 and y > 18:
				return stitch
	return color


static func _wear_dim(wear: String) -> float:
	if wear.contains("臭") or wear.contains("开裂") or wear.contains("破洞"):
		return 0.72
	if wear.contains("二手") or wear.contains("瑕疵"):
		return 0.84
	return 0.96


static func _stamp_id_dots(image: Image, item_id: int, cx: float) -> void:
	var n: int = 3 + (absi(item_id) % 5)
	var y: int = 28
	for i: int in range(n):
		var x: int = int(cx) - n + i * 2
		if x >= 0 and x < image.get_width() and y < image.get_height():
			var current: Color = image.get_pixel(x, y)
			if current.a > 0.1:
				image.set_pixel(x, y, current.lightened(0.35))

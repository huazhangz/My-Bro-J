class_name UnderwearArt
extends RefCounted

## 库存内裤贴图：优先用 boxers.png / boxers1.png 抠绿后的 5×5 切片，
## 否则用仓库内 `assets/images/underwear/01.png` … `50.png`。

static var _cache: Dictionary = {}
static var _ingested: bool = false


static func texture_for(item: Dictionary) -> Texture2D:
	_ingest_sheets_if_needed()
	var art_index: int = GameData.item_art_index(item)
	if _cache.has(art_index):
		return _cache[art_index] as Texture2D
	var texture: Texture2D = _load_cutout(art_index)
	if texture == null:
		texture = _fallback_bake(item, art_index)
	_cache[art_index] = texture
	return texture


static func _ingest_sheets_if_needed() -> void:
	if _ingested:
		return
	_ingested = true
	var sheet_a: String = GameData.first_existing_named(GameData.USER_BOXERS_SHEET_A)
	var sheet_b: String = GameData.first_existing_named(GameData.USER_BOXERS_SHEET_B)
	if sheet_a.is_empty() and sheet_b.is_empty():
		return
	print("[Steve/Underwear] slice sheets a=%s b=%s" % [sheet_a, sheet_b])
	if not sheet_a.is_empty():
		_slice_sheet(sheet_a, 0)
	if not sheet_b.is_empty():
		_slice_sheet(sheet_b, GameData.UNDERWEAR_SHEET_CELLS)
	_cache.clear()


static func _slice_sheet(path: String, start_index: int) -> void:
	var image: Image = Image.new()
	if image.load(path) != OK:
		print("[Steve/Underwear] failed to load sheet %s" % path)
		return
	_chroma_key_image(image)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < 10 or height < 10:
		return
	var cols: int = GameData.UNDERWEAR_SHEET_COLUMNS
	var rows: int = GameData.UNDERWEAR_SHEET_ROWS
	var cell_w: int = width / cols
	var cell_h: int = height / rows
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameData.UNDERWEAR_USER_DIR))
	for row: int in range(rows):
		for col: int in range(cols):
			var art_index: int = start_index + row * cols + col
			var cell: Image = image.get_region(Rect2i(col * cell_w, row * cell_h, cell_w, cell_h))
			_chroma_key_image(cell)
			var trimmed: Image = _trim_and_fit(cell, GameData.UNDERWEAR_ART_SIZE)
			var dest: String = GameData.underwear_user_path(art_index)
			trimmed.save_png(dest)
			var res_path: String = GameData.underwear_res_path(art_index)
			trimmed.save_png(res_path)


static func _chroma_key_image(image: Image) -> void:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < 4 or height < 4:
		return
	var corners: Array[Color] = [
		image.get_pixel(2, 2),
		image.get_pixel(width - 3, 2),
		image.get_pixel(2, height - 3),
		image.get_pixel(width - 3, height - 3),
	]
	var green_hits: int = 0
	for color: Color in corners:
		if color.g > 0.55 and color.g > color.r + 0.16 and color.g > color.b + 0.16:
			green_hits += 1
	var use_green: bool = green_hits >= 2
	for y: int in range(height):
		for x: int in range(width):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			if use_green and color.g > 0.35 and color.g > color.r + 0.11 and color.g > color.b + 0.11:
				var spill: float = color.g - maxf(color.r, color.b)
				color.a = clampf(1.0 - spill * 1.8, 0.0, 1.0)
				if color.g > 0.58 and color.r < 0.55 and color.b < 0.55:
					color.a = 0.0
				image.set_pixel(x, y, color)
				continue
			if not use_green:
				var luma: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
				if luma > 0.91 and absf(color.r - color.g) < 0.07 and absf(color.g - color.b) < 0.07:
					color.a = 0.0
					image.set_pixel(x, y, color)


static func _trim_and_fit(source: Image, size: int) -> Image:
	var used: Rect2i = source.get_used_rect()
	if used.size.x < 2 or used.size.y < 2:
		used = Rect2i(0, 0, source.get_width(), source.get_height())
	var cropped: Image = source.get_region(used)
	var fitted: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	fitted.fill(Color(0.0, 0.0, 0.0, 0.0))
	var scale: float = minf(float(size) / float(cropped.get_width()), float(size) / float(cropped.get_height())) * 0.92
	var new_w: int = maxi(1, int(round(float(cropped.get_width()) * scale)))
	var new_h: int = maxi(1, int(round(float(cropped.get_height()) * scale)))
	cropped.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	fitted.blit_rect(cropped, Rect2i(0, 0, new_w, new_h), Vector2i((size - new_w) / 2, (size - new_h) / 2))
	return fitted


static func _load_cutout(art_index: int) -> Texture2D:
	var paths: PackedStringArray = PackedStringArray([
		GameData.underwear_user_path(art_index),
		GameData.underwear_res_path(art_index),
	])
	for path: String in paths:
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		if path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
			var loaded: Resource = ResourceLoader.load(path, "Texture2D")
			var as_tex: Texture2D = loaded as Texture2D
			if as_tex != null:
				return as_tex
		var image: Image = Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


static func _fallback_bake(item: Dictionary, art_index: int) -> Texture2D:
	var item_id: int = int(item.get("id", art_index + 1))
	var image: Image = Image.create(GameData.UNDERWEAR_ART_SIZE, GameData.UNDERWEAR_ART_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = art_index * 9973 + item_id
	var base: Color = GameData.QUALITY_COLORS.get(int(item.get("quality", 0)), Color(0.75, 0.55, 0.85))
	var width: int = image.get_width()
	var height: int = image.get_height()
	for y: int in range(height):
		for x: int in range(width):
			var nx: float = (float(x) / float(width)) * 2.0 - 1.0
			var ny: float = float(y) / float(height)
			if ny < 0.08 or ny > 0.94:
				continue
			var inside: bool = absf(nx) < (0.78 if ny < 0.22 else 0.74 - (ny - 0.22) * 0.18)
			if ny > 0.62:
				var hole_y: float = (ny - 0.70) / 0.24
				if hole_y > 0.0:
					var left: float = nx + 0.34
					var right: float = nx - 0.34
					if left * left + hole_y * hole_y < 0.08 or right * right + hole_y * hole_y < 0.08:
						inside = false
			if not inside:
				continue
			var color: Color = base.lightened(0.22) if y < 28 else base
			image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
	return ImageTexture.create_from_image(image)

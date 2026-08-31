class_name UnderwearArt
extends RefCounted

## 库存内裤贴图：优先用 boxers.png / boxers1.png 按格内缩后从边角 flood-fill 抠底，
## 否则用仓库内 `assets/images/underwear/01.png` … `50.png`。
## 不使用 Steve 立绘的全局色度键参数。

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
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < 10 or height < 10:
		return
	var cols: int = GameData.UNDERWEAR_SHEET_COLUMNS
	var rows: int = GameData.UNDERWEAR_SHEET_ROWS
	var cell_w: int = width / cols
	var cell_h: int = height / rows
	var inset_x: int = maxi(int(round(float(cell_w) * GameData.UNDERWEAR_CELL_INSET_X_RATIO)), 4)
	var inset_top: int = maxi(int(round(float(cell_h) * GameData.UNDERWEAR_CELL_INSET_TOP_RATIO)), 4)
	var inset_bottom: int = maxi(int(round(float(cell_h) * GameData.UNDERWEAR_CELL_INSET_BOTTOM_RATIO)), 6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameData.UNDERWEAR_USER_DIR))
	for row: int in range(rows):
		for col: int in range(cols):
			var art_index: int = start_index + row * cols + col
			var left: int = col * cell_w + inset_x
			var top: int = row * cell_h + inset_top
			var right: int = (col + 1) * cell_w - inset_x
			var bottom: int = (row + 1) * cell_h - inset_bottom
			var region_w: int = maxi(right - left, 8)
			var region_h: int = maxi(bottom - top, 8)
			var cell: Image = image.get_region(Rect2i(left, top, region_w, region_h))
			_flood_key_from_edges(cell)
			var trimmed: Image = _trim_and_fit(cell, GameData.UNDERWEAR_ART_SIZE)
			var dest: String = GameData.underwear_user_path(art_index)
			trimmed.save_png(dest)
			var res_path: String = GameData.underwear_res_path(art_index)
			trimmed.save_png(res_path)


static func _corner_is_backdrop(color: Color) -> bool:
	if color.a < 0.08:
		return true
	var luma: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	if luma > 0.90 and absf(color.r - color.g) < 0.08 and absf(color.g - color.b) < 0.08:
		return true
	if color.g > 0.50 and color.g > color.r + 0.18 and color.g > color.b + 0.18:
		return true
	return false


static func _matches_backdrop(color: Color, key: Color) -> bool:
	if color.a < 0.08:
		return true
	var dr: float = color.r - key.r
	var dg: float = color.g - key.g
	var db: float = color.b - key.b
	var dist: float = sqrt(dr * dr + dg * dg + db * db)
	if dist <= 0.22:
		return true
	if key.g > 0.45 and color.g > 0.48 and color.g > color.r + 0.20 and color.g > color.b + 0.20:
		return dist <= 0.38
	var luma: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var key_luma: float = key.r * 0.299 + key.g * 0.587 + key.b * 0.114
	if key_luma > 0.88 and luma > 0.88 and absf(color.r - color.g) < 0.08 and absf(color.g - color.b) < 0.08:
		return true
	return false


static func _flood_key_from_edges(image: Image) -> void:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < 4 or height < 4:
		return
	var corners: Array[Color] = [
		image.get_pixel(1, 1),
		image.get_pixel(width - 2, 1),
		image.get_pixel(1, height - 2),
		image.get_pixel(width - 2, height - 2),
	]
	var key: Color = Color(0.0, 0.0, 0.0, 0.0)
	var hits: int = 0
	for color: Color in corners:
		if _corner_is_backdrop(color):
			key = color
			hits += 1
	if hits < 2:
		return
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width * height)
	var qx: PackedInt32Array = PackedInt32Array()
	var qy: PackedInt32Array = PackedInt32Array()
	for x: int in range(width):
		_try_seed(image, x, 0, key, qx, qy, visited, width)
		_try_seed(image, x, height - 1, key, qx, qy, visited, width)
	for y: int in range(height):
		_try_seed(image, 0, y, key, qx, qy, visited, width)
		_try_seed(image, width - 1, y, key, qx, qy, visited, width)
	var i: int = 0
	while i < qx.size():
		var x: int = qx[i]
		var y: int = qy[i]
		i += 1
		image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		if x > 0:
			_try_seed(image, x - 1, y, key, qx, qy, visited, width)
		if x + 1 < width:
			_try_seed(image, x + 1, y, key, qx, qy, visited, width)
		if y > 0:
			_try_seed(image, x, y - 1, key, qx, qy, visited, width)
		if y + 1 < height:
			_try_seed(image, x, y + 1, key, qx, qy, visited, width)


static func _try_seed(
	image: Image,
	x: int,
	y: int,
	key: Color,
	qx: PackedInt32Array,
	qy: PackedInt32Array,
	visited: PackedByteArray,
	width: int
) -> void:
	var idx: int = y * width + x
	if visited[idx] != 0:
		return
	if not _matches_backdrop(image.get_pixel(x, y), key):
		return
	visited[idx] = 1
	qx.append(x)
	qy.append(y)


static func _trim_and_fit(source: Image, size: int) -> Image:
	var used: Rect2i = source.get_used_rect()
	if used.size.x < 2 or used.size.y < 2:
		used = Rect2i(0, 0, source.get_width(), source.get_height())
	var cropped: Image = source.get_region(used)
	var fitted: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	fitted.fill(Color(0.0, 0.0, 0.0, 0.0))
	var scale: float = minf(float(size) / float(cropped.get_width()), float(size) / float(cropped.get_height())) * 0.90
	var new_w: int = maxi(1, int(round(float(cropped.get_width()) * scale)))
	var new_h: int = maxi(1, int(round(float(cropped.get_height()) * scale)))
	cropped.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	fitted.blit_rect(
		cropped,
		Rect2i(0, 0, new_w, new_h),
		Vector2i((size - new_w) / 2, (size - new_h) / 2)
	)
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


static func _in_round_rect(x: float, y: float, left: float, top: float, right: float, bottom: float, radius: float) -> bool:
	if x < left or x > right or y < top or y > bottom:
		return false
	var cx: float = clampf(x, left + radius, right - radius)
	var cy: float = clampf(y, top + radius, bottom - radius)
	if absf(x - cx) <= 0.001 or absf(y - cy) <= 0.001:
		return true
	var dx: float = (x - cx) / radius
	var dy: float = (y - cy) / radius
	return dx * dx + dy * dy <= 1.0


static func _in_ellipse(x: float, y: float, left: float, top: float, right: float, bottom: float) -> bool:
	var rx: float = (right - left) * 0.5
	var ry: float = (bottom - top) * 0.5
	if rx <= 0.0 or ry <= 0.0:
		return false
	var dx: float = (x - (left + right) * 0.5) / rx
	var dy: float = (y - (top + bottom) * 0.5) / ry
	return dx * dx + dy * dy <= 1.0


static func _brief_inside(px: float, py: float) -> bool:
	if _in_ellipse(px, py, 24.0, 90.0, 60.0, 140.0) or _in_ellipse(px, py, 68.0, 90.0, 104.0, 140.0):
		return false
	if _in_round_rect(px, py, 18.0, 10.0, 110.0, 70.0, 10.0):
		return true
	if _in_round_rect(px, py, 18.0, 48.0, 60.0, 116.0, 16.0):
		return true
	if _in_round_rect(px, py, 68.0, 48.0, 110.0, 116.0, 16.0):
		return true
	# crotch bridge
	if py >= 58.0 and py <= 94.0:
		var t: float = (py - 58.0) / 36.0
		var left: float = 40.0 + (48.0 - 40.0) * t
		var right: float = 88.0 + (80.0 - 88.0) * t
		if px >= left and px <= right:
			return true
	return false


static func _fallback_bake(item: Dictionary, art_index: int) -> Texture2D:
	var item_id: int = int(item.get("id", art_index + 1))
	var size: int = GameData.UNDERWEAR_ART_SIZE
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = art_index * 9973 + item_id
	var base: Color = GameData.QUALITY_COLORS.get(int(item.get("quality", 0)), Color(0.75, 0.55, 0.85))
	var scale: float = 128.0 / float(size)
	for y: int in range(size):
		for x: int in range(size):
			var px: float = float(x) * scale
			var py: float = float(y) * scale
			if not _brief_inside(px, py):
				continue
			var color: Color = base.lightened(0.22) if py < 32.0 else base
			image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
	return ImageTexture.create_from_image(image)

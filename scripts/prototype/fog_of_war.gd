class_name FogOfWar
extends RefCounted

var map_rect := Rect2(-2304.0, -1296.0, 4608.0, 2592.0)
var grid_size := Vector2i(256, 144)
var edge_softness := 54.0
var fog_color := Color(0.015, 0.02, 0.035, 0.96)
var sources: Array[Dictionary] = []
var texture: ImageTexture
var last_rebuild_milliseconds := 0.0
var native_simulation


func _init(native_backend = null, profile: BalanceProfile = null) -> void:
	native_simulation = native_backend
	if profile != null:
		map_rect = profile.map_rect()
		grid_size = Vector2i(int(profile.value("fog/grid_width", 256)), int(profile.value("fog/grid_height", 144)))
		edge_softness = float(profile.value("fog/edge_softness", 54.0))
		fog_color = Color8(
			int(profile.value("fog/dark_red", 4)), int(profile.value("fog/dark_green", 5)),
			int(profile.value("fog/dark_blue", 9)), int(round(float(profile.value("fog/maximum_alpha", 0.96)) * 255.0))
		)


func rebuild(new_sources: Array[Dictionary]) -> void:
	var started := Time.get_ticks_usec()
	sources = new_sources.duplicate(true)
	var image: Image
	if native_simulation != null:
		var pixels: PackedByteArray = native_simulation.build_visibility_mask(
			sources, map_rect, grid_size, edge_softness
		)
		if pixels.size() == grid_size.x * grid_size.y * 4:
			image = Image.create_from_data(
				grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8, pixels
			)
	if image == null:
		image = _build_gdscript_fallback()
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	last_rebuild_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0


func _build_gdscript_fallback() -> Image:
	var image := Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	for y in grid_size.y:
		for x in grid_size.x:
			var world_position := Vector2(
				map_rect.position.x + (float(x) + 0.5) / float(grid_size.x) * map_rect.size.x,
				map_rect.position.y + (float(y) + 0.5) / float(grid_size.y) * map_rect.size.y
			)
			var visibility := _visibility_at(world_position)
			image.set_pixel(x, y, Color(fog_color, fog_color.a * (1.0 - visibility)))
	return image


func is_lit(world_position: Vector2) -> bool:
	for source: Dictionary in sources:
		var position: Vector2 = source.get("position", Vector2.ZERO)
		var radius := float(source.get("radius", 0.0))
		if world_position.distance_squared_to(position) <= radius * radius:
			return true
	return false


func _visibility_at(world_position: Vector2) -> float:
	var best := 0.0
	for source: Dictionary in sources:
		var position: Vector2 = source.get("position", Vector2.ZERO)
		var radius := float(source.get("radius", 0.0))
		var distance := world_position.distance_to(position)
		if distance <= radius - edge_softness:
			return 1.0
		if distance < radius:
			best = maxf(best, smoothstep(radius, radius - edge_softness, distance))
	return best

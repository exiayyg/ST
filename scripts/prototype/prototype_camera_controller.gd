class_name PrototypeCameraController
extends RefCounted

var camera: Camera2D
var map_rect: Rect2
var viewport: Viewport
var pan_speed := 760.0
var min_zoom := 0.5
var max_zoom := 1.5
var zoom_step_base := 1.12


func _init(camera_node: Camera2D, world_rect: Rect2, owner_viewport: Viewport, profile: BalanceProfile = null) -> void:
	camera = camera_node
	map_rect = world_rect
	viewport = owner_viewport
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	if profile != null:
		pan_speed = float(profile.value("map_camera/pan_speed", pan_speed))
		min_zoom = float(profile.value("map_camera/min_zoom", min_zoom))
		max_zoom = float(profile.value("map_camera/max_zoom", max_zoom))
		zoom_step_base = float(profile.value("map_camera/zoom_step_base", zoom_step_base))


func update(delta: float, direction := Vector2.ZERO) -> void:
	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * pan_speed * delta / camera.zoom.x
	clamp_to_map()


func pan_by_screen_delta(relative: Vector2) -> void:
	camera.position -= relative / camera.zoom.x
	clamp_to_map()


func zoom_by_steps(steps: float) -> void:
	var zoom_value := clampf(camera.zoom.x * pow(zoom_step_base, steps), min_zoom, max_zoom)
	camera.zoom = Vector2(zoom_value, zoom_value)
	clamp_to_map()


func visible_world_rect() -> Rect2:
	var world_size := Vector2(viewport.get_visible_rect().size) / camera.zoom
	return Rect2(camera.position - world_size * 0.5, world_size)


func clamp_to_map() -> void:
	var half_view := Vector2(viewport.get_visible_rect().size) * 0.5 / camera.zoom
	var minimum := map_rect.position + half_view
	var maximum := map_rect.end - half_view
	if minimum.x > maximum.x:
		minimum.x = map_rect.get_center().x
		maximum.x = minimum.x
	if minimum.y > maximum.y:
		minimum.y = map_rect.get_center().y
		maximum.y = minimum.y
	camera.position = Vector2(
		clampf(camera.position.x, minimum.x, maximum.x),
		clampf(camera.position.y, minimum.y, maximum.y)
	)

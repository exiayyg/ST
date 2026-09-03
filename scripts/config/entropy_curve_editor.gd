@tool
class_name EntropyCurveEditor
extends Control

signal curve_changed(points: Array)

var points: Array = []
var _drag_index := -1


func _init() -> void:
	custom_minimum_size = Vector2(340.0, 180.0)
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func set_points(new_points: Array) -> void:
	points = new_points.duplicate(true)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111827"), true)
	for index in range(1, 4):
		var ratio := float(index) / 4.0
		draw_line(Vector2(size.x * ratio, 0.0), Vector2(size.x * ratio, size.y), Color("273449"), 1.0)
		draw_line(Vector2(0.0, size.y * ratio), Vector2(size.x, size.y * ratio), Color("273449"), 1.0)
	if points.size() < 2:
		return
	for index in range(points.size() - 1):
		draw_line(_to_screen(points[index]), _to_screen(points[index + 1]), Color("5ee6a8"), 3.0, true)
	for index in points.size():
		var color := Color.WHITE if index == _drag_index else Color("77d9ff")
		draw_circle(_to_screen(points[index]), 6.0, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_drag_index = _pick_point(event.position)
			if _drag_index < 0 and event.double_click:
				_add_point(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _drag_index >= 0:
				curve_changed.emit(points.duplicate(true))
			_drag_index = -1
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var picked := _pick_point(event.position)
			if picked > 0 and picked < points.size() - 1:
				points.remove_at(picked)
				curve_changed.emit(points.duplicate(true))
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag_index > 0 and _drag_index < points.size() - 1:
		var normalized := _from_screen(event.position)
		var previous: Dictionary = points[_drag_index - 1]
		var following: Dictionary = points[_drag_index + 1]
		normalized.x = clampf(normalized.x, float(previous.x) + 0.001, float(following.x) - 0.001)
		normalized.y = clampf(normalized.y, float(previous.y), float(following.y))
		points[_drag_index] = {"x": normalized.x, "y": normalized.y}
		queue_redraw()
		accept_event()


func _add_point(screen_position: Vector2) -> void:
	var normalized := _from_screen(screen_position)
	var insert_index := 1
	while insert_index < points.size() and float((points[insert_index] as Dictionary).x) < normalized.x:
		insert_index += 1
	var previous: Dictionary = points[insert_index - 1]
	var following: Dictionary = points[insert_index]
	normalized.y = clampf(normalized.y, float(previous.y), float(following.y))
	points.insert(insert_index, {"x": normalized.x, "y": normalized.y})
	curve_changed.emit(points.duplicate(true))
	queue_redraw()


func _pick_point(screen_position: Vector2) -> int:
	var best := -1
	var distance := 12.0
	for index in points.size():
		var current := screen_position.distance_to(_to_screen(points[index]))
		if current < distance:
			distance = current
			best = index
	return best


func _to_screen(point_value) -> Vector2:
	var point: Dictionary = point_value
	return Vector2(float(point.x) * size.x, (1.0 - float(point.y)) * size.y)


func _from_screen(screen_position: Vector2) -> Vector2:
	return Vector2(clampf(screen_position.x / maxf(size.x, 1.0), 0.0, 1.0),
		clampf(1.0 - screen_position.y / maxf(size.y, 1.0), 0.0, 1.0))

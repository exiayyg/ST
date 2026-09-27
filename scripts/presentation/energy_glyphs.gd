class_name EnergyGlyphs
extends RefCounted

# Normalized vector artwork. Fractions and segment counts below describe shape topology,
# not collision geometry or a second set of balance defaults.
static func polygon(canvas: CanvasItem, center: Vector2, radius: float, sides: int, rotation: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in sides + 1:
		points.append(center + Vector2.RIGHT.rotated(rotation + TAU * float(index) / sides) * radius)
	canvas.draw_polyline(points, color, width, true)

static func arrow(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(start, finish, color, width, true)
	var direction := (finish - start).normalized()
	var wing := (finish - start).length() * 0.25
	canvas.draw_line(finish, finish - direction.rotated(PI * 0.25) * wing, color, width, true)
	canvas.draw_line(finish, finish - direction.rotated(-PI * 0.25) * wing, color, width, true)

static func draw(canvas: CanvasItem, kind: StringName, center: Vector2, radius: float, angle: float, color: Color, width: float, phase := 0.0) -> void:
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	match kind:
		&"bounce_plate":
			canvas.draw_line(center - forward * radius, center + forward * radius, color, width, true)
			for sign_value in [-1.0, 1.0]:
				canvas.draw_line(center + forward * radius * sign_value, center + forward * radius * sign_value + side * radius * 0.3, color, width, true)
		&"speed_increaser":
			for fraction in [-0.55, 0.15, 0.8]:
				var tip: Vector2 = center + forward * radius * fraction
				canvas.draw_polyline(PackedVector2Array([tip - forward * radius * 0.45 - side * radius * 0.65, tip, tip - forward * radius * 0.45 + side * radius * 0.65]), color, width, true)
		&"mass_increaser":
			polygon(canvas, center, radius, 6, angle, color, width)
			polygon(canvas, center, radius * 0.65, 6, angle, Color(color, color.a * 0.6), width)
			canvas.draw_circle(center, radius * 0.28, color)
		&"splitter":
			for sign_value in [-1.0, 1.0]:
				var exit: Vector2 = center + side * radius * sign_value
				canvas.draw_line(center - forward * radius, exit - forward * radius * 0.2, color, width, true)
				arrow(canvas, exit - forward * radius * 0.2, exit + forward * radius * 0.7, color, width)
		&"diode", &"diode_exit":
			var exit := kind == &"diode_exit"
			canvas.draw_arc(center, radius, angle + PI * 0.2, angle + TAU - PI * 0.2, 32, color, width, true)
			canvas.draw_arc(center, radius * 0.7, angle + PI * 0.4, angle + TAU - PI * 0.4, 28, Color(color, color.a * 0.55), width, true)
			arrow(canvas, center - forward * radius * (0.2 if exit else 1.35), center + forward * radius * (1.35 if exit else 0.2), color, width)
		&"electric_field":
			polygon(canvas, center, radius, 4, angle + PI * 0.25, color, width)
			for fraction in [-0.5, 0.0, 0.5]:
				arrow(canvas, center + side * radius * fraction - forward * radius * 0.55, center + side * radius * fraction + forward * radius * 0.55, color, width)
		&"magnetic_field":
			for index in 3:
				var start := angle + TAU * float(index) / 3.0 + phase
				canvas.draw_arc(center, radius, start, start + PI * 0.48, 14, color, width, true)
				var end := center + Vector2.RIGHT.rotated(start + PI * 0.48) * radius
				canvas.draw_circle(end, width, color)
			canvas.draw_circle(center, radius * 0.18, color)
		&"wave_converter":
			canvas.draw_arc(center, radius, angle - PI * 0.25, angle + PI * 0.25, 20, color, width, true)
			canvas.draw_arc(center, radius * 0.6, angle - PI * 0.25, angle + PI * 0.25, 16, color, width, true)
			for sign_value in [-1.0, 1.0]:
				canvas.draw_line(center - forward * radius * 0.55, center + forward.rotated(sign_value * PI * 0.25) * radius, color, width, true)
		&"accumulator":
			polygon(canvas, center, radius, 6, angle + PI * 0.5, color, width)
			canvas.draw_line(center - side * radius * 0.55 - forward * radius * 0.4, center + side * radius * 0.55 - forward * radius * 0.4, color, width, true)
			canvas.draw_line(center - side * radius * 0.55 + forward * radius * 0.4, center + side * radius * 0.55 + forward * radius * 0.4, color, width, true)
			arrow(canvas, center, center + forward * radius * 1.25, color, width)

static func enemy(canvas: CanvasItem, center: Vector2, radius: float, ranged: bool, color: Color, width: float) -> void:
	if ranged:
		polygon(canvas, center, radius, 6, PI * 0.5, color, width)
		canvas.draw_arc(center, radius * 0.55, 0.0, TAU, 24, color, width, true)
	else:
		# Direction points toward the center tower, a visual cue only.
		var angle := (-center).angle()
		polygon(canvas, center, radius, 3, angle, color, width)
		canvas.draw_line(center - Vector2.RIGHT.rotated(angle) * radius * 0.3, center + Vector2.RIGHT.rotated(angle) * radius * 0.6, color, width, true)

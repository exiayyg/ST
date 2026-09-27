class_name SpawnRegion
extends Resource
## Immutable spawn geometry. Distribution remains a function of stable enemy ID,
## never of device placement. Full-edge uses the exact legacy lerp operands.

var _mode := "full_edge"
var _center_ratio := 0.0
var _half_width := 0.0

static func from_spec(spec: Dictionary) -> SpawnRegion:
	var fields := ["mode", "center_ratio", "half_width"]
	if spec.size() != fields.size() or not spec.has_all(fields):
		return null
	if spec.mode is not String or spec.mode not in ["full_edge", "segment"]:
		return null
	for field in ["center_ratio", "half_width"]:
		if spec[field] is not float and spec[field] is not int:
			return null
		if not is_finite(float(spec[field])):
			return null
	if float(spec.center_ratio) < 0.0 or float(spec.center_ratio) > 1.0 or float(spec.half_width) < 0.0:
		return null
	if spec.mode == "segment" and float(spec.half_width) <= 0.0:
		return null
	var region := SpawnRegion.new()
	region._mode = spec.mode
	region._center_ratio = float(spec.center_ratio)
	region._half_width = float(spec.half_width)
	return region

func fits(rect: Rect2, inset: float, direction: StringName) -> bool:
	if direction not in [&"east", &"south", &"west", &"north"] or not rect.is_finite() or not is_finite(inset):
		return false
	var usable := rect.grow(-inset)
	if inset < 0.0 or usable.size.x <= 0.0 or usable.size.y <= 0.0:
		return false
	var length := usable.size.x if direction in [&"north", &"south"] else usable.size.y
	return _mode == "full_edge" or (_half_width <= length * _center_ratio and _half_width <= length * (1.0 - _center_ratio))

func position(rect: Rect2, inset: float, direction: StringName, ratio: float) -> Vector2:
	if not fits(rect, inset, direction) or not is_finite(ratio) or ratio < 0.0 or ratio > 1.0:
		return Vector2.INF
	var horizontal := direction in [&"north", &"south"]
	var lower := rect.position.x + inset if horizontal else rect.position.y + inset
	var upper := rect.end.x - inset if horizontal else rect.end.y - inset
	if _mode == "segment":
		var center := lerpf(lower, upper, _center_ratio)
		lower = center - _half_width
		upper = center + _half_width
	var along := lerpf(lower, upper, ratio)
	match direction:
		&"north": return Vector2(along, rect.position.y + inset)
		&"south": return Vector2(along, rect.end.y - inset)
		&"west": return Vector2(rect.position.x + inset, along)
		_: return Vector2(rect.end.x - inset, along)

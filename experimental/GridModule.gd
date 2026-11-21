@tool
extends Control
class_name Griddy

@export var color : Color
@export var cell_size = 64
@export var thickness = 4
@export var offset := Vector2.ZERO  ## Where on the screen to draw the origin of the grid.

func _draw() -> void:
	var polyline : Array = []
	var span : int = 0
	#draw_line(Vector2(span, 0), Vector2(span, size.y), color, thickness)
	while span < size.x:
		polyline += [
			Vector2(span, 0) + offset,
			Vector2(span, size.y) + offset
				]
		span += cell_size
	span = 0
	while span < size.y:
		polyline += [
			Vector2(0, span) + offset,
			Vector2(size.x, span) + offset
				]
	
	draw_multiline(polyline, color, thickness)

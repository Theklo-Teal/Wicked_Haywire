@tool
extends Resource
class_name Cluster

@export var coord : Vector2i : 
	set(val):
		coord = val
		emit_changed()
@export var limit := Vector2i(2,1) : 
	set(val):
		limit = val
		emit_changed()
@export var spread : bool :  ## Sockets are placed as far apart as [code]limit[/code] allows
	set(val):
		spread = val
		emit_changed()
@export var perpendicular : bool : 
	set(val):
		perpendicular = val
		emit_changed()
@export var mirror_x : bool :  ## Whether to reverse the order of the sockets.
	set(val):
		mirror_x = val
		emit_changed()
@export var mirror_y : bool :  ## Whether to reverse the order of the sockets.
	set(val):
		mirror_y = val
		emit_changed()

func transform_coord(from:Vector2i, constraint:Callable) -> Vector2i:
	var to = from
	if mirror_x: to.x = -to.x
	if mirror_y: to.y = -to.y
	if perpendicular: to = Vector2i(-to.y, to.x)
	return to + constraint.call(coord)

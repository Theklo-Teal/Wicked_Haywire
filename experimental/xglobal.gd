extends Node

## Singleton for any experimental prototype.

#region Wire Drawing
const CELL_DIA = 20  ## Size of row cells.
var CELL_RAD = CELL_DIA / 2.0
const VIA_RAD = 7  ## Hole size inside sockets
var WIRE_THICK = 8  ## The maximum thickness of a wire.
const CLEARANCE = 4  ## Minimum distance between wires or sockets, so they don't touch.
var CELL_SPACING = CELL_RAD + CLEARANCE + (WIRE_THICK / 2.0)

var layer : int = 0  ## Which layer is visible.
var sel_joint : xJoint
var coord_joint : Vector3i  ## Grid coordinate of sel_joint at time of selecting it.
var sel_wire : xWire
var info_wire : Dictionary  ## Information about the sel_wire at the time of selecting it.

## Returns the actual space position snapped to the grid from a grid coordinate.
func from_grid(coord:Vector2i) -> Vector2:
	var pos := Vector2.ZERO
	pos.x = 2 * CELL_SPACING * coord.x
	pos.y = CELL_SPACING * coord.y
	if coord.y % 2 == 0:  # Make cell position staggered between rows.
		pos.x += CELL_SPACING
	return pos

## Returns [code]coord[/code] on the grid and the actual space [code]position[/code]
## snapped to that cell. It produces interleaved square grids, where the corner of
## one square is the center of another, allowing for staggered connections.
func to_grid(point:Vector2) -> Dictionary:
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, CELL_SPACING * 2, point.x)),
		roundi(inverse_lerp(0, CELL_SPACING, point.y))
		)
	if coord.y % 2 == 0:
		var offset = point.x - CELL_SPACING
		coord.x = roundi(inverse_lerp(0, CELL_SPACING * 2, offset))
	return {"position" = from_grid(coord), "coord" = coord}
#endregion

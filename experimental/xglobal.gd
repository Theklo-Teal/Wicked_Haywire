extends Node

## Singleton for any experimental prototype.

const CELL_DIA = 20  ## Size of row cells.
var CELL_RAD = CELL_DIA / 2.0
var ROW_HEI = tan(deg_to_rad(60)) * CELL_RAD
const VIA_RAD = 3  ## Hole size inside sockets
const CLEARANCE = 1.5  ## Minimum distance between wires or sockets, so they don't touch.

## Returns [code]cell_coord[/code] on the grid and the actual space [code]cell_position[/code]
## of that cell.
func to_grid(point:Vector2) -> Dictionary:
	var pos = point.snapped(Vector2(X.CELL_DIA, X.ROW_HEI))
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, X.CELL_DIA, point.x)),
		roundi(inverse_lerp(0, X.ROW_HEI, point.y))
		)
	if coord.y % 2 == 0: # Make cell position staggered between rows.
		pos.x += X.CELL_RAD
	return {"cell_position" = pos, "cell_coord" = coord}

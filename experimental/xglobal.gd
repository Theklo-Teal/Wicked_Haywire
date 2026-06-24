extends Node

## Singleton for any experimental prototype.

#region Wire Drawing
const CELL_DIA = 20  ## Size of row cells.
var CELL_RAD = CELL_DIA / 2.0
const VIA_RAD = 7  ## Hole size inside sockets
const CLEARANCE = 4  ## Minimum distance between wires or sockets, so they don't touch.

## Returns [code]cell_coord[/code] on the grid and the actual space [code]cell_position[/code]
## of that cell.
func to_grid(point:Vector2) -> Dictionary:
	return to_grid_rhombus(point)

func to_grid_square(point:Vector2) -> Dictionary:
	var pos = point.snappedf(CELL_DIA)
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, CELL_DIA, point.x)),
		roundi(inverse_lerp(0, CELL_DIA, point.y))
		)
	return {"position" = pos, "coord" = coord}

func to_grid_isometric_horiz(point:Vector2) -> Dictionary:
	var ROW_HEI = tan(deg_to_rad(60)) * CELL_RAD
	var pos = point.snapped(Vector2(CELL_DIA, ROW_HEI))
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, CELL_DIA, point.x)),
		roundi(inverse_lerp(0, ROW_HEI, point.y))
		)
	if coord.y % 2 == 0: # Make cell position staggered between rows.
		var offset = point.x - CELL_RAD
		pos.x = snapped(offset, CELL_DIA) + CELL_RAD
		coord.x = roundi(inverse_lerp(0, CELL_DIA, offset))
	return {"position" = pos, "coord" = coord}

func to_grid_isometric_verti(point:Vector2) -> Dictionary:
	var COL_WID = tan(deg_to_rad(60)) * CELL_RAD
	var pos = point.snapped(Vector2(COL_WID, CELL_DIA))
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, COL_WID, point.x)),
		roundi(inverse_lerp(0, CELL_DIA, point.y))
		)
	if coord.x % 2 == 0: # Make cell position staggered between rows.
		var offset = point.y - CELL_RAD
		pos.y = snapped(offset, CELL_DIA) + CELL_RAD
		coord.y = roundi(inverse_lerp(0, CELL_DIA, offset))
	return {"position" = pos, "coord" = coord}

func to_grid_rhombus(point:Vector2) -> Dictionary:
	var SPACING = CELL_RAD + CLEARANCE
	var pos = point.snapped(Vector2(SPACING * 2, SPACING))
	var coord := Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, SPACING * 2, point.x)),
		roundi(inverse_lerp(0, SPACING, point.y))
		)
	if coord.y % 2 == 0:  # Make cell position staggered between rows.
		var offset = point.x - SPACING
		pos.x = snapped(offset, SPACING * 2) + SPACING
		coord.x = roundi(inverse_lerp(0, SPACING * 2, offset))
	return {"position" = pos, "coord" = coord}
#endregion

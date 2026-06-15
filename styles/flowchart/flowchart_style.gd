extends Resource
class_name FlowchartStyle

@export_range(1, 200, 1, "or_greater") var cell_size : int = 50 :   ## The nominal size for the background pattern.
	set(val):
		cell_size = val
		emit_changed()
@export var min_cell_size : int = 8 :  ## As you zoom out and cells become smaller, how small until we just don't bother rendering?
	set(val):
		min_cell_size = clamp(val, 1, cell_size)
		emit_changed()
@export var grid_thick : int = 2 :  ## Width of the lines for drawing background pattern.
	set(val):
		grid_thick = clamp(val, -1, min_cell_size)
		emit_changed()
@export var orig_thick : int = 4 :  ## Width of the lines for drawing the origin indicator.
	set(val):
		orig_thick = clamp(val, -1, min_cell_size)
		emit_changed()
@export_color_no_alpha var grid_color := Color.BLACK :  ## Color of background pattern lines.
	set(val):
		grid_color = val
		emit_changed()
@export_color_no_alpha var orig_color := Color.RED :   ## Color of the lines for the origin indicator.
	set(val):
		orig_color = val
		emit_changed()
@export_color_no_alpha var color := Color.WEB_GRAY :   ## Background Color
	set(val):
		color = val
		emit_changed()

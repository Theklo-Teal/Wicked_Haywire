@tool
extends Node

var chart : Flowchart
var appearance : FlowchartStyle = load("res://styles/flowchart/Blueprint.tres") : 
	set(val):
		appearance = val
		if chart != null:
			if not appearance.changed.is_connected(chart._on_appearance_changed):
				appearance.changed.connect(chart._on_appearance_changed)
var layer : int = 0
var wire_from := Vector2.INF

var grid_changed := true
var snap : int = 12 :  ## Size of grid snapping  cells. The snap grid is based on a rhombus. Refer to [code]to_grid()[/code] for more information.
	set(val):
		snap = max(1, val)
		grid_changed = true
var via_hole : int = 4 :  ## Radius of holes in joints.
	set(val):
		via_hole = max(1, val)
		grid_changed = true
var max_wire : int = 9 :  ## Maximum thickness of a wire.
	set(val):
		max_wire = clamp(val, 1, snap)
		grid_changed = true
var clearance : int = 2 :  ## Minimum distance between conductors.
	set(val):
		clearance = max(0, val)
		grid_changed = true

var joint_rad : float  ## Radius of a joint that fits in a grid cell.

## Returns the actual space position snapped to the grid from a grid coordinate.
func from_grid(coord:Vector2i) -> Vector2:
	var pos := Vector2.ZERO
	pos.x = 2 * snap * coord.x
	pos.y = snap * coord.y
	if coord.y % 2 == 0:  # Make cell position staggered between rows
		pos.x += snap
	return pos

## Returns [code]coord[/code]
func to_grid(position:Vector2) -> Dictionary:
	var coord := Vector2i(  ## Find cell coordinate in the grid
		roundi(inverse_lerp(0, snap * 2, position.x)),
		roundi(inverse_lerp(0, snap, position.y))
		)
	if coord.y % 2 == 0:
		var offset = position.x - snap
		coord.x = roundi(inverse_lerp(0, snap * 2, offset))
	return {"position": from_grid(coord), "coord": coord}

func _process(_delta: float) -> void:
	if grid_changed:
		grid_changed = false
		joint_rad = snap / 2.0 #- clearance
		max_wire = clampi(max_wire, 0, snap - clearance * 2)
		#get_tree().call_group("grid_size_response", "on_grid_size_changed")


var setts := ConfigFile.new()

var mode : Flowchart.Mode
func _on_flowchart_mode_changed(m):
	mode = m

#TODO Preload components on start up.
#var part_pallet : Array[Resource]
@onready var grabbed_buttons := ButtonGroup.new()

func _ready() -> void:
	setts.load("res://settings.cfg")
	grabbed_buttons.allow_unpress = true

func _exit_tree() -> void:
	setts.save("res://settings.cfg")

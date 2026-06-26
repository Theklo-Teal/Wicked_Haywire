extends Node

var setts := ConfigFile.new()

var grid_size : int = 32 :  ## The coordinates of objects on the canvas are snapped to this value, if registered using [code]place_object_snap()[/code].
	set(val):
		grid_size = max(1, val)
		get_tree().call_group("grid_size_response", "on_grid_size_changed")

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

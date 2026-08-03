@tool
extends Node

var chart : Flowchart
var appearance : FlowchartStyle = load("res://styles/flowchart/Blueprint.tres") : 
	set(val):
		appearance = val
		if chart != null:
			if not appearance.changed.is_connected(chart._on_appearance_changed):
				appearance.changed.connect(chart._on_appearance_changed)

var setts := ConfigFile.new()

@onready var grabbed_buttons := ButtonGroup.new()

func _ready() -> void:
	setts.load("res://settings.cfg")
	grabbed_buttons.allow_unpress = true

func _exit_tree() -> void:
	setts.save("res://settings.cfg")


## Returns information about each defined class, like name and script path. There are options to
## include inner classes found within the classes and if we really just want the inner classes. [br]
## If inner classes include a [code]static func get_base_class() -> StringName[/code], then the return of that
## static function is also included in the dictionary about it.
static func list_classes(include_inner:bool=false, only_inner:bool=false) -> Array[Dictionary]:
	var all_classes = ProjectSettings.get_global_class_list()
	var all_inners : Array[Dictionary]
	if include_inner:
		for klaso in all_classes:
			var script : Script = load(klaso.path)
			var karto : Dictionary = script.get_script_constant_map()
			for konst in karto:
				if karto[konst] is Script:  # Filter out constant variables.
					all_inners.append({
						"container" : klaso,  # The class of the script defining the inner class
						"base" : "",  # What this inner class extends
						"name" : konst,  # is this the script? What's the name?
						"value" : karto[konst],  # The script or resource of the inner class?
						})
					if "get_base_class" in karto[konst]:  #NOTE: karto[konst].has_method() doesn't work here.
						all_inners.back().base = karto[konst].get_base_class()
	if only_inner:
		return all_inners
	else:
		all_classes.append_array(all_inners)
		return all_classes

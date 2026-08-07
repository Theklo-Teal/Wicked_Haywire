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
var rng := RandomNumberGenerator.new()

@onready var grabbed_buttons := ButtonGroup.new()

func _ready() -> void:
	rng.seed = floori(Time.get_unix_time_from_system())
	setts.load("res://settings.cfg")
	grabbed_buttons.allow_unpress = true

func _exit_tree() -> void:
	setts.save("res://settings.cfg")


## Returns information about each defined class, with its name as key and
## a Dictionary as value. Available keys of a class information:[br]
## [code]is_inner : StringName [/code] - The class name of the container script if it's an inner class, otherwise empty.[br]
## [code]added : Variant [/code] - The output of calling [code]added_class_info()[/code], if it can be called, otherwise it's [code]null[/code].[br]
## [code]base : StringName [/code] - The class name being extended from.[br]
## [code]script : Script [/code] - The script of the class, so it can be instantiated.[br]
## If the class script includes a [code]static func added_class_info() -> StringName[/code],
## then the return of that is also included in the class' dictionary.[br]
## Classes that extend an inner class have [code]base[/code] empty, so the added info can be used
## to identify them.
static func list_classes() -> Dictionary:
	var result : Dictionary
	for klaso : Dictionary in ProjectSettings.get_global_class_list():
		var klaso_script : Script = load(klaso.path)
		result[StringName(klaso.class)] = {
			"is_inner": &"",
			"added": null,
			"base" : StringName(klaso.base),
			"script" : klaso_script,
			}
		if klaso.base.is_empty():
			klaso.base = "INNER CLASS"
		if "added_class_info" in klaso_script:  #NOTE: has_method() doesn't work here.
			result[klaso.class].added = klaso_script.added_class_info()
		var karto = klaso_script.get_script_constant_map()
		for konst : StringName in karto:
			if karto[konst] is Script:  # Filter out constant variables.
				var base = karto[konst].get_base_script()
				if base == null:
					base = &""
				else:
					base = base.get_global_name()
				result[konst] = {
					"is_inner" : StringName(klaso.class),
					"added" : &"",
					"base" : base,
					"script" : karto[konst],
					}
				if "added_class_info" in karto[konst]:  #NOTE: has_method() doesn't work here.
					result[konst].added = karto[konst].added_class_info()
	return result

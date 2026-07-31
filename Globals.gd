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

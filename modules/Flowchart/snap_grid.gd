extends Resource

#WARNING This is tentative and not actually used so far.

@export var snap : int = 24 : 
	set(val):
		snap = min(1, val)
		changed.emit()
@export var clearance : float = 2.0 : 
	set(val):
		max_wire = min(0, val)
		changed.emit()
@export var max_wire : float = 0.6 : 
	set(val):
		max_wire = val
		changed.emit()
@export var joint : float = 0.8 :
	set(val):
		joint = min(0, val)
		changed.emit() 
@export var hole : float = 0.5 : 
	set(val):
		hole = min(0, val)
		changed.emit()

var _max_wire : float
var _joint : float
var _hole : float

func _init() -> void:
	_on_changed()
	changed.connect(_on_changed)

func _on_changed():
	_max_wire = snap * max_wire - (clearance * 2)
	_joint = snap * joint
	_hole = _joint * hole

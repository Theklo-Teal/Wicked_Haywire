@tool
extends Electronics

static func toybox_included() -> bool:
	return true

var inps : Array[GizmoSocket]
var pos : GizmoSocket
var neg : GizmoSocket
var in_cluster : Cluster
var out_cluster : Cluster

func _update_sockdex():
	super()
	if sockets.is_empty(): return
	inps = sockets.keys().slice(2)
	pos = sockets.keys()[0]
	neg = sockets.keys()[1]
	in_cluster = sockets[inps[0]]
	out_cluster = sockets[pos]


#region Logic Rules
enum {
	AND,
	OR,
	XOR
}
@export_enum("AND", "OR", "XOR") var rule : int = 0 : 
	set(val):
		rule = val
		%rule_option.select(rule)
		%rule_invert.text = NEG_RULE[rule]

const NEG_RULE = ["SOME", "NONE", "EVEN"]

func _sim_update(graph:FlowchartNetwork):
	match rule:
		AND:
			pass
		OR:
			pass
		XOR:
			pass
#endregion


#region Layout Rules
enum {
	EAST,
	SOUTH,
	WEST,
	NORTH
}

@export_enum("East", "South", "West", "North") var facing : int = 0 :
	set(val):
		facing = val
		update_layout()
@export var mirror : bool = false :
	set(val):
		mirror = val
		update_layout()
@export var spread : bool = false : 
	set(val):
		spread = val
		update_layout()
@export var perpendicular : bool = false : 
	set(val):
		perpendicular = val
		update_layout()

func _update_layout():
	out_cluster.limit.y = _grid.size.y - 1
	match facing:
		EAST:
			panels = {0: 1 if mirror else 0}
			out_cluster.perpendicular = false
			in_cluster.perpendicular = false
			if mirror:
				out_cluster.coord = Vector2i(-1, -3)
				in_cluster.coord = Vector2i(0, 0)
			else:
				out_cluster.coord = Vector2i(-1, 0)
				in_cluster.coord = Vector2i(0, -1 * inps.size())
		SOUTH:
			panels = {1: 0 if mirror else 1}
			out_cluster.perpendicular = true
			in_cluster.perpendicular = true
			if mirror:
				out_cluster.coord = Vector2i(0,-1)
				in_cluster.coord = Vector2i(-2, 0)
			else:
				out_cluster.coord = Vector2i(-1,-1)
				in_cluster.coord = Vector2i(0, 1)
		WEST:
			panels = {0: 1 if mirror else 0}
			if mirror:
				out_cluster.coord = Vector2i(0, -4)
				in_cluster.coord = Vector2i(-1, 1)
			else:
				out_cluster.coord = Vector2i(0, 1)
				in_cluster.coord = Vector2i(-1, -3)
		NORTH:
			panels = {1: 1 if mirror else 0}
			out_cluster.coord = Vector2i(1, 0)
			in_cluster.coord = Vector2i(-1, -1)
#endregion


func _on_rule_option_item_selected(index: int) -> void:
	if OS.has_feature("editor_hint"): return
	rule = %rule_option.selected
	%rule_invert.text = NEG_RULE[rule]

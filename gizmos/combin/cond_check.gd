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
		update_layout()

const NEG_RULE = ["SOME", "NONE", "EVEN"]

func _sim_update(_graph:FlowchartNetwork):
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

const _horiz_panel := Rect2(0.5, 0.0, -1.5, -1.0)
const _verti_panel := Rect2(0.0, 0.5, -1.0, -1.5)

func _update_layout():
	%rule_invert.text = NEG_RULE[rule] if facing in [EAST, WEST] else ["↓", "↑"][(facing == NORTH) as int]
	%rule_invert.reset_size()
	out_cluster.limit.y = _grid.size.y - 1
	size = Vector2(5, 5) * Flowchart.SNAP
	var inp_offset = (inps.size() - 2) * Flowchart.SNAP
	match facing:
		EAST:
			size.y += inp_offset
			panels = {_horiz_panel: 1 if mirror else 0}
			out_cluster.perpendicular = false
			in_cluster.perpendicular = false
			out_cluster.mirror_y = true if mirror else false
			in_cluster.mirror_y = false if mirror else true
			if mirror:
				out_cluster.coord = Vector2i(-1, -1)
				in_cluster.coord = Vector2i(0, 0)
			else:
				out_cluster.coord = Vector2i(-1, 0)
				in_cluster.coord = Vector2i(0, -1)
		SOUTH:
			size.x += inp_offset
			panels = {_verti_panel: 0 if mirror else 1}
			out_cluster.perpendicular = true
			in_cluster.perpendicular = true
			out_cluster.mirror_y = true if mirror else false
			in_cluster.mirror_y = false if mirror else true
			if mirror:
				out_cluster.coord = Vector2i(0,-1)
				in_cluster.coord = Vector2i(-1, 0)
			else:
				out_cluster.coord = Vector2i(-1,-1)
				in_cluster.coord = Vector2i(0, 0)
		WEST:
			size.y += inp_offset
			panels = {_horiz_panel: 1 if mirror else 0}
			out_cluster.perpendicular = false
			in_cluster.perpendicular = false
			out_cluster.mirror_y = false if mirror else true
			in_cluster.mirror_y = true if mirror else false
			if mirror:
				out_cluster.coord = Vector2i(0, 0)
				in_cluster.coord = Vector2i(-1, -1)
			else:
				out_cluster.coord = Vector2i(0, -1)
				in_cluster.coord = Vector2i(-1, 0)
		NORTH:
			size.x += inp_offset
			panels = {_verti_panel: 0 if mirror else 1}
			out_cluster.perpendicular = true
			in_cluster.perpendicular = true
			out_cluster.mirror_y = false if mirror else true
			in_cluster.mirror_y = true if mirror else false
			if mirror:
				out_cluster.coord = Vector2i(-1, 0)
				in_cluster.coord = Vector2i(0, -1)
			else:
				out_cluster.coord = Vector2i(0, 0)
				in_cluster.coord = Vector2i(-1, -1)
	_layout_widgets()

func _layout_widgets():
	var pos_coord = Vector2(out_cluster.transform_coord(pos.coord, get_bound_coord))
	var neg_coord = Vector2(out_cluster.transform_coord(neg.coord, get_bound_coord))
	var butts_coord = Vector2(in_cluster.transform_coord(inps[0].coord, get_bound_coord))
	var opt_wid = Vector2(Flowchart.to_grid(%rule_option.size).x, 0)
	var inv_wid = Vector2(Flowchart.to_grid(%rule_invert.size).x, 0)
	var butts_wid = Vector2(Flowchart.to_grid(%buttons.size))
	match facing:
		EAST:
			%rule_option.set_meta("grid_bound", pos_coord - opt_wid)
			%rule_invert.set_meta("grid_bound", neg_coord - inv_wid)
			var padding = 0.0 if mirror else -0.2
			%buttons.set_meta("grid_bound", butts_coord + Vector2(1.5, padding))
		WEST:
			%rule_option.set_meta("grid_bound", pos_coord + Vector2(1, 0))
			%rule_invert.set_meta("grid_bound", neg_coord + Vector2(1, 0))
			var padding = 0.4 if mirror else -0.2
			%buttons.set_meta("grid_bound", butts_coord - Vector2(butts_wid.x, padding))
		SOUTH:
			%rule_option.set_meta("grid_bound", neg_coord - Vector2(1, 1))
			%rule_invert.set_meta("grid_bound", pos_coord - Vector2(-0.2, 1))
			var padding = 1.2 - butts_wid.x if mirror else 0.2
			%buttons.set_meta("grid_bound", butts_coord + Vector2(padding, 1.2))
		NORTH:
			%rule_option.set_meta("grid_bound", neg_coord + Vector2(-opt_wid.x / 2.0, 1))
			%rule_invert.set_meta("grid_bound", pos_coord + Vector2(0.2, 1))
			var padding = 0.2 if mirror else 1.2 - butts_wid.x
			%buttons.set_meta("grid_bound", butts_coord + Vector2(padding, -1.5))

#endregion


func _on_rule_option_item_selected(index: int) -> void:
	if OS.has_feature("editor_hint"): return
	rule = index
	%rule_invert.text = NEG_RULE[rule]


func _on_add_pressed() -> void:
	var new_inp = GizmoSocket.new()
	new_inp.mode = GizmoSocket.SINK
	new_inp.coord.y = inps.size()
	inps.append(new_inp)
	_update_sockdex()
	update_layout()


func _on_rem_pressed() -> void:
	if inps.size() < 2:
		return
	inps.pop_back()
	_update_sockdex()
	update_layout()

@tool
extends Electronics

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	update_layout()

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


#region Controls
func _on_rule_option_item_selected(index: int) -> void:
	if OS.has_feature("editor_hint"): return
	rule = index
	%rule_invert.text = NEG_RULE[rule]

func _on_add_pressed() -> void:
	var new_inp = GizmoSocket.new()
	new_inp.mode = GizmoSocket.SINK
	new_inp.coord.y = inps.size()
	sockets[new_inp] = sockets[inps[0]]
	inps.append(new_inp)
	_update_sockdex()
	update_layout()

func _on_rem_pressed() -> void:
	if inps.size() < 3:
		return
	var rem = inps.pop_back()
	sockets.erase(rem)
	_update_sockdex()
	update_layout()
#endregion


#region Logic Rules
enum {
	AND,
	OR,
	XOR,
	HIGH,
}
@export_enum("AND", "OR", "XOR", "HIGH") var rule : int = 0 : 
	set(val):
		rule = val
		update_layout()
		if not is_node_ready(): await ready
		%rule_option.select(rule)
		

const NEG_RULE = ["SOME", "NONE", "EVEN", "LOW"]

#func _sim_update(_graph:FlowchartNetwork):
	#var words : PackedInt32Array
	#for i in inps:
		#words.append(i.read())
	#
	#var digit : int = -1
	#var parallel : Array[bool]
	#var inverted : Array[bool]
	#parallel.resize(bitwidth)
	#inverted.resize(bitwidth)
	#for cnt in parallel_bit_count(words, bitwidth):
		#match rule:
			#AND:
				#parallel[digit] = cnt == inps.size()
				#inverted[digit] = not parallel[digit]
			#OR:
				#parallel[digit] = cnt != 0
				#inverted[digit] = not parallel[digit]
			#XOR:  # The intuitive form of the XOR which performs parity check.
				#parallel[digit] = cnt % 2 == 0
				#inverted[digit] = not parallel[digit]
			#HIGH:  # A XOR as per IEC standard: Output High if only one input is high. The negated detects if only one input is low.
				#parallel[digit] = cnt == 1
				#inverted[digit] = bitwidth - cnt == 1
	##pos.write(parallel_to_int(parallel))
	##neg.write(invert)
#endregion


#region Layout Rules

@export var mirrored : bool = false :
	set(val):
		mirrored = val
		update_layout()
@export var spread : bool = false : 
	set(val):
		spread = val
		update_layout()
@export var perpendicular : bool = false : 
	set(val):
		perpendicular = val
		update_layout()

func _orientation(_prev:FACE, _towards:FACE) -> void:
	pass

func _mirror(axis_y:bool) -> void:
	mirrored = not mirrored
	match facing:
		FACE.EAST:
			if not axis_y:
				facing = FACE.WEST
		FACE.SOUTH:
			if axis_y:
				facing = FACE.NORTH
		FACE.WEST:
			if not axis_y:
				facing = FACE.EAST
		FACE.NORTH:
			if axis_y:
				facing = FACE.SOUTH

func _update_layout():
	%rule_invert.text = NEG_RULE[rule] if facing in [FACE.EAST, FACE.WEST] else ["↓", "↑"][(facing == FACE.NORTH) as int]
	%rule_invert.reset_size()
	out_cluster.limit.y = _grid.size.y - 1
	size = Vector2(5, 5) * Flowchart.SNAP
	$layout_fsm.set_layout(facing)

#endregion

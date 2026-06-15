@tool
extends Electronics
class_name ConditionCheck

@onready var pos_q : ChartSocketSource = sockets[0]
@onready var neg_q : ChartSocketSource = sockets[1]
@onready var inps : Array[ChartSocketSink] = [sockets[2], sockets[3]]

func set_bitwidth(val:int):
	super(val)
	if not is_node_ready():
		await ready
	for sock in sockets:
		sock.bitwidth = bitwidth

func _ready() -> void:
	options["Bitwidth"] = "bitwidth"
	options["Output Direction"] = "out_layout"
	options["Input Direction"] = "inp_layout"
	options["Orientation"] = "orientation"

var pan_init_size = {
	AXLE.HORIZ : Vector2(128, 192),
	AXLE.VERTI : Vector2(192, 128),
}

var pan = {
	AXLE.HORIZ : 0,
	AXLE.VERTI : 1,
}

func set_layout(code:int):
	super(code)
	custom_minimum_size = pan_init_size[layout_axle]
	panels[0] = pan[layout_axle]
	match layout_axle:
		AXLE.HORIZ:
			custom_minimum_size.y += (inps.size() - 2) * G.grid_size
			%inp_buttons.set_meta("grid_pos", Vector2(-1.75, 0.25))
			for i in range(inps.size()):
				var s = inps[i]
				s.coord = Vector2i(0, (i + 2) * G.grid_size)
		AXLE.VERTI:
			custom_minimum_size.x += (inps.size() - 2) * G.grid_size
			%inp_buttons.set_meta("grid_pos", Vector2(-1.75, 0.25))
			for i in range(inps.size()):
				var s = inps[i]
				s.coord = Vector2i((i + 2) * G.grid_size, 0)

func _on_extender_pressed():
	match layout_axle:
		AXLE.HORIZ:
			custom_minimum_size.y += G.grid_size
			var new_sink = ChartSocketSink.new()
			inps.append(new_sink)
			add_graph_socket(new_sink, Vector2i(0, sockets.size()))
	if %retractor.disabled == true:
		%retractor.disabled = false

func _on_retractor_pressed() -> void:
	if sockets.size() > 5:
		match layout_axle:
			AXLE.HORIZ:
				custom_minimum_size.y -= G.grid_size
				var old_sink = inps.pop_back()
				rem_graph_socket(old_sink)
	if sockets.size() <= 4:
		%retractor.disabled = true

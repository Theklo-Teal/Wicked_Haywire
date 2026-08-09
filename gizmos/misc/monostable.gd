@tool
extends Electronics

@export var duration : int = 200  ## Amount of jiffy until state reset.
@export var slew : int = 50  ## Amount of jiffy after being triggered that outputs respond.
@export var resettable : bool = false  ## Whether input triggering resets the instable state timer.
@export var blocking : bool = false  ## Whether input can jam the output at the unstable state.
@export var alternate_rise_position : bool
@export var alternate_fall_position : bool
@export var mirrored : bool

var rise : BitInput
var fall : BitInput
var pos : BitOutput
var neg : BitOutput
var triggered : bool = true
var switched : bool = true
var elapsed : int = 0

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	rise = sockets.keys()[0]
	fall = sockets.keys()[1]
	pos = sockets.keys()[2]
	neg = sockets.keys()[3]
	watch_sockets.call_deferred(rise, fall)

func _sim_update(graph:FlowchartNetwork):
	super(graph)
		
	if elapsed == 0:
		if triggered:
			triggered = false
			switched = true
			elapsed = duration
		elif switched:
			switched = false
		else:
			switched = false
	else:
		elapsed -= 1
		if triggered: 
			$Bar.value = remap(elapsed, 0, slew, 0, 100)
			$Counter.text = str(-elapsed).pad_zeros(3)
			if blocking and (rise.read("bool") or not fall.read("bool")):
				elapsed = slew
				return
		elif switched: 
			$Bar.value = remap(elapsed, 0, duration, 100, 0)
			$Counter.text = str(elapsed).pad_zeros(3)
			if blocking and (rise.read("bool") or not fall.read("bool")):
				elapsed = duration


func _edge_triggered_sampling(_graph:FlowchartNetwork, socket: BitInput, rising:int, falling:int):
	if elapsed > 0 and not resettable: return
	if socket == rise:
		if (rising & 1) == 1:
			triggered = true
			switched = false
			elapsed = slew
	if socket == fall:
		if (falling & 1) == 1:
			triggered = true
			switched = false
			elapsed = slew

func _sim_update_respond(_graph:FlowchartNetwork):
	if triggered or switched:
		pos.write(int(elapsed > 0), "value", bitwidth)
		neg.write(int(elapsed == 0), "value", bitwidth)

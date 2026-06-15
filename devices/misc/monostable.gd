@tool
extends Electronics

## Works as some arrangement of capacitors with active amplification.[br]
## Can be used to lengthen periods of pulses, or make a short pulse from rising edges.[br]
## It can also emulate Minecraft Repeaters, by combining the "enable" pin and setting a delay equal to the period.[br]
## It has a stable state, which it will return to and maintain when not triggered. Once triggered it switches to the unstable state for a given period.

var period : int = 1
var delay : int = 0  ## Time until the input sets to unstable state. Makes it work like Minecraft Repeater.
var stable_high := false  ## Is the high level the stable state?
var input_reset := false  ## Whether the input falling edge sets to stable state, bypassing the period.
var input_set := false  ## Whether the input rising edge resets the elapsed time of unstable state. Keeping state unstable as long as pulses repeat while unstable.

var counts : Array[int]
var last_level : int
var delayed : Array[int]

func _ready() -> void:
	counts.resize(%output.bitwidth)

func _update(graph:FlowchartGraph):
	var jam = graph.read($enable).val  # Enable stops state from changing. Essential pauses any await period from counting.
	var val : int = 0
	var curr_level = graph.read(%input)
	var trigger_diff = last_level ^ curr_level
	for i in range(%input.bitwidth):
		if delayed[i] > 0 and jam[i] > 0:  # delays of 0 were not triggered into unstable state.
			delayed[i] += 1
		elif delayed[i] > delay:  # after trigger_delay, set bit high
			val |= int(not stable_high) << i 
		
		if trigger_diff >> 1 & 1 == 1:  # for bits that have changed
			if curr_level == 1:  # rising edge
				delayed[i] = 1  # start waiting until setting to unstable state
				if input_set and jam[i] > 0:  # maintain unstable state
					counts[i] = 0
			elif curr_level == 0 and input_reset:  # falling edge, if input is supposed to haste return to stable state.
				if jam[i] > 0:
					counts[i] = 0
					val &= int(not stable_high) << i
		elif last_level >> i & 1 == 1:  # if a rising edge happened in the past, so we are in unstable state.
			if jam[i] > 0:
				counts[i] += 1  # track elapsed time in unstable state
			if counts[i] > period:  # if elapsed time reached period
				counts[i] = 0  # return to stable state
				val &= int(not stable_high) << i
	graph.write(%output, {"val":val, "hiz":0})

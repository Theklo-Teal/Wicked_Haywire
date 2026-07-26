@tool
extends Electronics

## This represents a flip-flop, if the input is a single bit, or a register, with multiple bits.[br]
## By default it works synchronously and is opaque. If only the Asynchronous inputs are used ("Set" and "Reset), then it behaves like a latch.[br]
## By "opaque" it means that output,thus internal state, only changes at the rising edge of the "update" pin. By setting the option for "transparent", then state changes while level of "update" is high.[br]


var dual_edge := false  # State is updated on both edges of "update" signal, which then also selects which state is exposed at output.
var transparent := false

func visible_synch(show:=true):
	pass

func visible_reset(show:=true):
	pass

func visible_set(show:=true):
	pass

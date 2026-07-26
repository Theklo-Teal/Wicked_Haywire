@tool
extends ConditionCheck

func _ready() -> void:
	super()
	P.name = "ODD"
	N.name = "EVEN"

func _update(graph:FlowchartGraph):
	var valp = P.digital_protocol()
	var valn = N.digital_protocol()
	var vals : Array[int]
	for sock in %Inputs.get_children():
		vals.append(graph.read(sock).val)
	var counts = parallel_bit_count(vals, P.bitwidth)
	for i in range(P.bitwidth):
		valp.val |= int(counts[i] % 2 == 1 ) << i
	valn.val = valp.val ^ ((1 << N.bitwidth) - 1)
	graph.write(P, valp)
	graph.write(N, valn )

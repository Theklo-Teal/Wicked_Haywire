@tool
extends Resource
class_name ChartSocket

var pressed : bool
var hover : bool
var link : FlowchartGraph.Link
var bitwidth : int

#WARNING We shouldn't have a function like this, because references back to owner Chart Node from a shared resource are problematic.
#func get_canvas_pos() -> Vector2:


## Opportunity to configure the link
func _set_link(l:FlowchartGraph.Link):
	l.bitwidth = bitwidth
	link = l

@export var enabled : bool = true : 
	set(val):
		enabled = val
		emit_changed()
@export var coord : Vector2i : 
	set(val):
		coord = val
		emit_changed()
@export_group("Linking")
@export var link_class : StringName = "Link"  ## What kind of link is preferred if there's none when connecting this socket? It defines what format, protocol, and variable type the read and write values are.
@export var accepted_link : Array[StringName] = ["Link"]  ## When connecting to another socket, we assume we can connect to it, but something in our [code]refuse_link[/code] is its [code]link_class[/code] we refuse to connect. Adding it to this array, allows an exception to accept connection.
@export var refuse_link : Array[StringName]  ## When connecting to another socket, we assume we can connect to it, except if something in our [code]refuse_link[/code] is its [code]link_class[/code], so we refuse to connect. Unless, its [code]link_class[/code] is also in [code]accept_link[/code], so we excpetionally allow connection.

func _init() -> void:
	pass

var show_check : bool = true
var checked : bool = false
func draw(canvas:FlowchartNode, where:Vector2):
	var color = Color.WEB_GRAY
	if enabled:
		color = Color.WHITE
	if show_check and checked:
		canvas.draw_circle(where, G.grid_size * 0.3, color)
	if pressed:
		canvas.draw_circle(where, G.grid_size * 0.3 , color, false, 3)
	elif hover:
		canvas.draw_circle(where, G.grid_size * 0.5, color, false, 3)
	else:
		canvas.draw_circle(where, G.grid_size * 0.33 , color, false, 3)


@warning_ignore_start("unused_parameter")
func connecter(other_socket:FlowchartSocket, wire:FlowchartWire):
	pass
#NOTE The connect/disconnect functions are meant to be overriden if desired, in which case knowing the wire might be of interest, altough it isn't relevant by default.
func connectee(other_socket:FlowchartSocket, wire:FlowchartWire):
	pass
#NOTE In principle it only makes sense to have a single disconnect function, but if overriding this function is desired, knowing which socket is asking for disconnect might be of interest.
func disconnecter(other_socket:FlowchartSocket):
	pass
func disconnectee(other_socket:FlowchartSocket):
	pass
	
## This socket was used to read a Link.
func has_read(val):
	pass
## This socket was used to write a Link.
func has_written(val):
	pass
	
@warning_ignore_restore("unused_parameter")

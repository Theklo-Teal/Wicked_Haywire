@tool
extends NetBase.Joint
class_name ChartSocket

enum {
	HIZ,  ## Electrically isolated socket
	SINK,  ## This socket reads a value
	SOURCE,  ## This socket writes a value
	BIDIR  ## This socket can relay a value
	}

var pressed : bool
var hover : bool
var bitwidth : int

@export_enum("Hi-Z", "Sink", "Source", "Bidir") var mode : int

@export_group("Porting")
@export var port_class : StringName = "Port"  ## What kind of link is preferred if there's none when connecting this socket? It defines what format, protocol, and variable type the read and write values are.
@export var accepted_port : Array[StringName] = ["Port"]  ## When connecting to another socket, we assume we can connect to it, but something in our [code]refuse_link[/code] is its [code]link_class[/code] we refuse to connect. Adding it to this array, allows an exception to accept connection.
@export var refuse_port : Array[StringName]  ## When connecting to another socket, we assume we can connect to it, except if something in our [code]refuse_link[/code] is its [code]link_class[/code], so we refuse to connect. Unless, its [code]link_class[/code] is also in [code]accept_link[/code], so we excpetionally allow connection.

func _init() -> void:
	pass

var show_check : bool = true
var checked : bool = false
func draw(canvas:Control, _highlighted:=false):
	draw_wires(canvas)
	var color = G.appearance.trace_primary if hover else G.appearance.trace_secondary
	match mode:
		HIZ:
			color = G.appearance.color.inverted()
			canvas.draw_circle(_position, G.joint_rad, color)
		SINK:
			canvas.draw_rect(Rect2(-Vector2.ONE * G.joint_rad + _position, Vector2.ONE * G.snap), color)
		SOURCE:
			var polyline := [
				_position + Vector2(0, -G.joint_rad),
				_position + Vector2(G.joint_rad, 0),
				_position + Vector2(0, G.joint_rad),
				_position + Vector2(-G.joint_rad, 0),
			]
			canvas.draw_colored_polygon(polyline, color)
		BIDIR:
			canvas.draw_circle(_position, G.joint_rad, color)
	
	#if show_check and checked:
		#canvas.draw_circle(where, G.grid_size * 0.3, color)
	#if pressed:
		#canvas.draw_circle(where, G.grid_size * 0.3 , color, false, 3)
	#elif hover:
		#canvas.draw_circle(where, G.grid_size * 0.5, color, false, 3)
	#else:
		#canvas.draw_circle(where, G.grid_size * 0.33 , color, false, 3)

## Opportunity to configure the link
@warning_ignore_start("unused_parameter")
func connecter(other_socket:ChartSocket, wire:NetBase.Link):
	pass
#NOTE The connect/disconnect functions are meant to be overriden if desired, in which case knowing the wire might be of interest, altough it isn't relevant by default.
func connectee(other_socket:ChartSocket, wire:NetBase.Link):
	pass
#NOTE In principle it only makes sense to have a single disconnect function, but if overriding this function is desired, knowing which socket is asking for disconnect might be of interest.
func disconnecter(other_socket:ChartSocket):
	pass
func disconnectee(other_socket:ChartSocket):
	pass
	
## This socket was used to read a Port.
func has_read(val):
	pass
## This socket was used to write a Port.
func has_written(val):
	pass
	
@warning_ignore_restore("unused_parameter")

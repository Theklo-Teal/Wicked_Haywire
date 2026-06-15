@tool
@abstract
extends Control
class_name FlowchartSocket

signal button_up
signal button_down
signal pressed(mouse_button:MouseButton)

@export var link_class : StringName = "Link"  ## What kind of link is preferred if there's none when connecting this socket? It defines what format, protocol, and variable type the read and write values are.
@export var accepted_link : Array[StringName] = ["Link"]  ## When connecting to another socket, we assume we can connect to it, but something in our [code]refuse_link[/code] is its [code]link_class[/code] we refuse to connect. Adding it to this array, allows an exception to accept connection.
@export var refuse_link : Array[StringName]  ## When connecting to another socket, we assume we can connect to it, except if something in our [code]refuse_link[/code] is its [code]link_class[/code], so we refuse to connect. Unless, its [code]link_class[/code] is also in [code]accept_link[/code], so we excpetionally allow connection.
@export var show_name : bool = true :  ## Name appears as a label beside the socket. Check [code]label_side[/code] to tell where the label is placed.
	set(val):
		show_name = val
		queue_redraw()
@export var font : LabelSettings : 
	set(val):
		font = val
		queue_redraw()
@export_enum("Right", "Left", "Below", "Above") var label_side : String = "Right" : 
	set(val):
		label_side = val
		queue_redraw()
@export var color := Color.BLACK : 
	set(val):
		color = val
		queue_redraw()
@export var alt_color := Color.WEB_GRAY :  ## Color used for highlighting or effects that must constrast the regular [code]color[/code].
	set(val):
		alt_color = val
		queue_redraw()
@export var check_color := Color.WHITE  ## Color used for indicator on the socket's signal state.

var checked : bool = false
var show_checked : bool = false
var menu : PopupMenu

@export_storage var wires : Dictionary[FlowchartSocket, FlowchartWire]  # [socket_id] -> wire_parameters ; Which sockets this one leads to.
@export_storage var seriw : Array[FlowchartSocket]  # [socket_id] ; Which sockets lead to this one.
# var tunnel  #NOTE: Not all sockets can have tunnel because changing tunnel requires access to the graph, which regular sockets can't do.
@export_storage var link : FlowchartGraph.Link : set=_set_link  # Link this socket writes or reads.

@export_storage var bitwidth : int = 1

## Opportunity to configure the link
func _set_link(l:FlowchartGraph.Link):
	l.bitwidth = bitwidth
	link = l

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	renamed.connect(queue_redraw)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if font == null:
		font = LabelSettings.new()
		font.font = SystemFont.new()
	
	menu = PopupMenu.new()
	add_child(menu)
	menu.add_item("[Nothing]")
	menu.index_pressed.connect(_on_menu_index_pressed)

func _on_menu_index_pressed(idx:int):
	queue_redraw()
	var txt = menu.get_item_text(idx)
	match txt:
		"Show Signal":
			show_checked = not show_checked
			menu.set_item_checked(idx, show_checked)
		"Invert Signal":
			show_checked = not show_checked
			menu.set_item_checked(idx, show_checked)

func draw_label(text:String):
	var text_size = Vector2( font.font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font.font_size).x, font.font_size) 
	var text_position = Vector2.ZERO
	match label_side:
		"Right":
			text_position.y += size.y / 2 + text_size.y / 2
			text_position.x += min(size.x, size.y) + text_size.y * 0.5
		"Left":
			text_position.y += size.y / 2 + text_size.y / 2
			text_position.x -= text_size.x + text_size.y / 2
		"Below":
			text_position.y += min(size.x, size.y) + text_size.y
			text_position.x -= text_size.x / 2.0 - size.x * 0.5
		"Above":
			text_position.y -= text_size.y * 0.5
			text_position.x -= text_size.x / 2.0 - size.x * 0.5
	
	draw_string(font.font, text_position, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font.font_size, font.font_color)

func _draw() -> void:
	var rad = min(size.x, size.y) / 2
	var center = Vector2.ONE * rad
	var thick = rad * 0.4
	
	if show_checked and checked:
		draw_circle(center, rad, check_color)
	
	if mouse_over:
		draw_circle(center, rad, alt_color)
	if button_pressed:
		draw_circle(center, rad, color)
	else:
		draw_circle(center, rad - thick, color, false, thick)
	if show_name:
		draw_label(name)

func _on_mouse_enter():
	mouse_over = true
	queue_redraw()

func _on_mouse_exit():
	mouse_over = false
	button_pressed = false
	queue_redraw()

var mouse_over : bool = false
var button_pressed : bool = false
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			queue_redraw()
			if event.is_pressed():
				button_pressed = true
				button_down.emit()
			elif event.is_released():
				button_up.emit()
				if button_pressed:
					button_pressed = false
					pressed.emit(MOUSE_BUTTON_LEFT)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_released():
				menu.popup(Rect2(event.global_position, Vector2(100, 100)))
				pressed.emit(MOUSE_BUTTON_RIGHT)

func get_wire_count() -> int:
	return wires.size() + seriw.size()

func connecter(other_socket:FlowchartSocket, wire:FlowchartWire):
	wires[other_socket] = wire
@warning_ignore("unused_parameter")
#NOTE The connect/disconnect functions are meant to be overriden if desired, in which case knowing the wire might be of interest, altough it isn't relevant by default.
func connectee(other_socket:FlowchartSocket, wire:FlowchartWire):
	if not other_socket in seriw:
		seriw.append(other_socket)
#NOTE In principle it only makes sense to have a single disconnect function, but if overriding this function is desired, knowing which socket is asking for disconnect might be of interest.
func disconnecter(other_socket:FlowchartSocket):
	wires.erase(other_socket)
	seriw.erase(other_socket)
func disconnectee(other_socket:FlowchartSocket):
	wires.erase(other_socket)
	seriw.erase(other_socket)

## This socket was used to read a Link.
@warning_ignore("unused_parameter")
func has_read(val):
	pass

## This socket was used to write a Link.
@warning_ignore("unused_parameter")
func has_written(val):
	pass

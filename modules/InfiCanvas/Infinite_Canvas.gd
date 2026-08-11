@tool
extends "res://modules/InfiCanvas/Infinite_Canvas_Base.gd"
class_name InfiCanvas

## A window to an area that has as much space as you need.[br]
## It takes SpatialPartition instances to track contained objects and quickly find them or cull them (implemented by extending this class).[br]
## Use [code]place_object()[/code] for what is to be added to the canvas, then override [code]draw_*_geometry()[/code] to tell how to display that object with custom draw calls if necessary.[br]
## You can find the objects in view by applying the provided [code]canvas_rect[/code] to [code]SpatialPartition.find_objects_*()[/code.[br]
## Other UI details like the background pattern and the compass arrow can also be changed by overriding their functions.[br]
## Remember to use coordinates translated into canvas coordinates with [code]to_canvas_coord()[/code], or things will looks fixed on the screen. Then convert back with [code]to_screen_coord()[/code], for them to display in the correct place on screen.[br]
## There are equivalent functions for Rect2, [code]to_canvas_rect()[/code], [code]to_screen_rect()[/code], which will resize a rect according to zoom.[br]
## If you are seeing background patterns being drawn outside the visible area, set "Layout/Clip Contents" in the inspector.[br]
## Objects can be grouped and ungrouped by defining an InputEventAction in Project Settings' Input Map for [code]inficanvas_group[/code] and [code]inficanvas_ungroup[/code].
## Grouped objects will move together when one or more of them is repositioned.

# MODIFICATIONS
# Restructured the class to separate visuals from controls and implement a state machine.
# There's built-in behavior for selecting and moving objects without extending the script.
# Modulation of object positioning can now vary according to what object is it.
# Added override functions for when starting or stopping to move an object.
# Added object grouping feature. Objects in the same group move together.
# Added `objects_selected` signal.
# Enabled option to not draw highlight on objects, if their Rect2 doesn't have area.
# Added `_hover_object` as a mechanism to improve interactions with objects on the canvas.

#TODO Make zoom into the center
#TODO Implement more signals
#FIXME go_to(Vector2.ZERO) doesn't seem to work if InfiCanvas isn't root node.

@export_enum("Mouse Motion", "Input Event", "Process", "Physics")  var overlay_mode : String = "Mouse Motion" ##  Method that updates the overlay. Regardless It will always update when this class redraws.

#region State Machine
var curr : StringName : set=_on_curr_state_set
func _on_curr_state_set(val:StringName):
	curr = val

var states : Dictionary[StringName, State]

## Return whether the current state is any of the given arguments (StringName).
func at_state(...stt) -> bool:
	return curr in stt

## Call a method [code]funk[/code] on the current state.
func state(funk:StringName="", ...args):
	return states[curr].callv(funk, args)

## Immediately change to [code]next[/code] state.
func switch_state(next:StringName):
	var prev = curr
	states[prev].exit(next)
	curr = next
	states[next].enter(prev)


@warning_ignore_start("unused_parameter")
@abstract class State:
	signal switch_state(next:StringName)
	
	var me : InfiCanvas
	func _init(manager:InfiCanvas) -> void:
		me = manager
	
	func my(node:NodePath) -> Node:
		return me.get_node(node)
	
	func enter(prev:StringName): pass
	func exit(next:StringName): pass
	## Called if the user wants to cancel an operation.
	func cancel(): pass
	## This is called whether the mouse is over an object that sets
	## [code]me.hover_object[/code] or that variable is set to [code]null[/code].
	func hover_object(object): pass
	func back_draw(canvas:Control, viewed_canvas_rect:Rect2): pass
	func fore_draw(canvas:Control, viewed_canvas_rect:Rect2): pass
	func over_draw(canvas:Control, viewed_canvas_rect:Rect2): pass
	## A drag operation was attempted. Return [code]true[/code] if the [code]drag_button[/code]
	## is acceptable.
	func drag_started(drag_button:MouseButton) -> bool: return true
	func drag_stopped(drag_button:MouseButton): pass
	func gui_input(event:InputEvent): pass
	func input(event:InputEvent): pass
@warning_ignore_restore("unused_parameter")


class Idle extends State:
	func hover_object(_object):
		switch_state.emit("Hover")
	
	var _ini_origin : Vector2
	
	func drag_started(drag_button:MouseButton) -> bool:
		if drag_button == MOUSE_BUTTON_LEFT:
			switch_state.emit("Lasso")
			return true
		if drag_button == MOUSE_BUTTON_MIDDLE:
			me.origin = _ini_origin + me.displacement() / me.zoom
			return true
		return false
	
	func gui_input(event:InputEvent):
		if event is InputEventMouseButton and event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					if Input.is_key_pressed(KEY_CTRL):
						me.zoom += me.ZOOM_SPEED
					else:
						me.origin.y += me.SCROLL_SPEED.y
				MOUSE_BUTTON_WHEEL_DOWN:
					if Input.is_key_pressed(KEY_CTRL):
						me.zoom -= me.ZOOM_SPEED
					else:
						me.origin.y -= me.SCROLL_SPEED.y
				MOUSE_BUTTON_WHEEL_LEFT:
						me.origin.x += me.SCROLL_SPEED.x
				MOUSE_BUTTON_WHEEL_RIGHT:
						me.origin.x -= me.SCROLL_SPEED.x
	
	func input(event:InputEvent):
		if event is InputEventMouseMotion and me._drag_button == MOUSE_BUTTON_MIDDLE:
			me.origin = me.displacement() + _ini_origin
		
		if Input.is_action_just_pressed_by_event("inficanvas_group", event):
			var default_group_name = str(Time.get_ticks_usec())
			me.obj_groups[default_group_name] = []
			for each in me._selected:
				var data = me.get_obj_data(each)
				data["obj_group"] = default_group_name
				me.obj_groups[default_group_name].append(each)
			me._selected.clear()
		
		if Input.is_action_just_pressed_by_event("inficanvas_ungroup", event):
			#FIXME
			for each in me._selected:
				var data = me.get_obj_data(each)
				if "obj_group" in data and data["obj_group"] in me.obj_groups:
					me.obj_groups[data["obj_group"]].erase(each)
					if me.obj_groups[data["obj_group"]].size() == 0:
						me.obj_groups.erase(data["obj_group"])
				data.erase("obj_group")


class Lasso extends State:
	func over_draw(canvas:Control, _viewed_canvas_rect:Rect2):
		me.draw_lasso(canvas)
	
	func drag_stopped(drag_button:MouseButton):
		if drag_button == MOUSE_BUTTON_LEFT:
			me.lasso_select_objects(me.lasso_canvas_rect)
			me.queue_redraw()
		switch_state.emit("Idle")
	
	func input(event:InputEvent):
		if event is InputEventMouseMotion:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				match me.chirality:
					me.CHIRAL.NONE:
						me.lasso_mode = false
					me.CHIRAL.HORIZONTAL:
						me.lasso_mode = me.displacement().x < 0
					me.CHIRAL.VERTICAL:
						me.lasso_mode = me.displacement().y < 0


class Hover extends State:
	func enter(_prev:StringName):
		if not "position" in me._hover_object:
			switch_state.emit("Idle")
	
	func hover_object(object):
		if object == null:
			switch_state.emit("Idle")
	
	func drag_started(drag_button:MouseButton) -> bool:
		if drag_button == MOUSE_BUTTON_LEFT:
			switch_state.emit("Move")
			return true
		return false

class Move extends Hover:
	var _selected_positions : Array[Vector2]
	func enter(_prev:StringName):
		# Add all object in common with group of a selected one to the selected list.
		for each in me._selected.duplicate():
			var data = me.get_obj_data(each)
			var group = data.get("obj_group", "")
			for other in me.obj_groups.get(group, []):
				if other in me._selected: continue
				me._selected.append(other)
		
	func exit(_next:StringName):
		for i in range(me._selected.size()):
			var obj = me._selected[i]
			var data : Dictionary = me.get_obj_data(obj)
			me.all_objs[obj].update_object(obj)
			if obj.has_method("_canvas_repositioned"):
				obj._canvas_repositioned(data)
			me._selected_obj_movement_stop(obj)
		
		# Track the initial position of selected objects
		for each in me._selected:
			if me.get_obj_data(each).centered:
				_selected_positions.append(me.get_obj_rect(each).get_center())
			else:
				_selected_positions.append(me.get_obj_rect(each).position)
			me._selected_obj_movement_start(each)
	
	func input(event:InputEvent):
		if event is InputEventMouseMotion:
			for i in range(me._selected.size()):
				var obj = me._selected[i]
				var data : Dictionary = me.get_obj_data(obj)
				data.position = me._obj_movement_modulate(obj, _selected_positions[i] + me.displacement() / me.zoom)
				if "position" in obj:
					obj.position = data.position
					if obj.has_method("_canvas_repositioning"):
						obj._canvas_repositioning(data)
#endregion

#region Boilerplate
var ini_mouse : Vector2  ## Coordinate of the mouse when the left button was last pressed.
var fin_mouse : Vector2  ## Coordinate of the mouse when the left button was last released. Current mouse button can be found with [code]get_local_mouse_position()[/code].

var hover_object : FlowchartPanel : set=_set_hover_object  # Define a way to tell which canvas object the mouse is over and implement the `_set_hover_object()` to disable functions that would conflict with object interaction. Set `null` if no relevant object is under the mouse.
func _set_hover_object(val):
	hover_object = val
	state("hover_object", val)


func _init():
	super()
	
	# Establist state machine
	var state_chain : Array[Array]  # A stack of found State scripts. By popping the stack, we ensure the most base forms of states can be overriden by sub-classes.
	var klaso : Script = get_script()
	var prev : Script = null
	while prev == null or prev.get_global_name() != &"InfiCanvas":
		var karto : Dictionary = klaso.get_script_constant_map()
		for konst in karto:
			if karto[konst] is Script and karto[konst].has_script_signal("switch_state"):
				state_chain.push_back([konst, karto[konst]])
		prev = klaso 
		klaso = klaso.get_base_script()
	
	while not state_chain.is_empty():
		var stt = state_chain.pop_back()
		states[stt[0]] = stt[1].new(self)
		states[stt[0]].switch_state.connect(switch_state, ConnectFlags.CONNECT_DEFERRED)
	
	await ready
	curr = &"Idle"
	state(&"enter")

func _process(_delta: float) -> void:
	if overlay_mode == "Process": overlay.queue_redraw()
func _physics_process(_delta: float) -> void:
	if overlay_mode == "Physics": overlay.queue_redraw()


func displacement() -> Vector2:
	return get_local_mouse_position() - ini_mouse

## Override this function to decide which objects are selected after a lasso
## drag operation.[br]
## By default it selects only Godot Nodes added with [code]place_object()[/code].
func lasso_select_objects(lasso_rect:Rect2):
	var selection : Array[Node]
	var partis : Dictionary[SpatialPartition, bool]  # Track all encountered partitions so we don't have to check all objects.
	for each in all_objs:
		if partis.size() >= parti.size(): break
		var checked = partis.get_or_add(all_objs[each], false)
		if each is Node and not checked:
			selection.append_array(all_objs[each].find_objects(lasso_rect))


var _drag_button : MouseButton = MOUSE_BUTTON_NONE 
func _gui_input(event: InputEvent) -> void:
	state("gui_input", event)
	
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			# Only allow the main three mouse buttons to start a drag operation.
			if _drag_button == MOUSE_BUTTON_NONE:
				if event.is_pressed():
					# Track the button starting a drag operation
					if state("drag_started", event.button_index):
						ini_mouse = get_local_mouse_position()
						_drag_button = event.button_index
	
	if event is InputEventMouseMotion:
		if overlay_mode == "Mouse Motion": overlay.queue_redraw()
	
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or \
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			lasso_screen_rect = Rect2(ini_mouse, displacement()).abs()

func _input(event: InputEvent) -> void:
	if overlay_mode == "Input Event": overlay.queue_redraw()
	
	state("input", event)
	
	if event is InputEventMouseButton:
		if event.is_released() and _drag_button == event.button_index:
			# Reset the drag operation if same button that started it is released
			state("drag_stopped", _drag_button)
			fin_mouse = get_local_mouse_position()
			_drag_button = MOUSE_BUTTON_NONE
	
	if event is InputEventKey and event.is_released():
		if event.keycode == KEY_ESCAPE:
			state("cancel")


func draw_back_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	super(canvas, viewed_canvas_rect)
	state("back_draw", canvas, viewed_canvas_rect)

func draw_fore_geometry():
	super()
	state("fore_draw", forecanvas, _view_rect)

func draw_overlay():
	super()
	state("over_draw", overlay, _view_rect)

#endregion

#region Object Repositioning (Movement)
## Override this function to implement things like grid snapping.
@warning_ignore("unused_parameter")
func _obj_movement_modulate(object, new_position:Vector2) -> Vector2:
	return new_position

## Override this function to define what to do with an object being repositioned.
@warning_ignore("unused_parameter")
func _selected_obj_movement_start(obj):
	pass

## Override this function to define what to do with an object after repositioned.
@warning_ignore("unused_parameter")
func _selected_obj_movement_stop(obj):
	pass

## Override this function if something is to happen when selecting objects.
func set_selected(val:Array):
		_selected = val
		objects_selected.emit(val)
		_set_selected(val)

@warning_ignore("unused_parameter")
func _set_selected(val:Array):
	pass
#endregion

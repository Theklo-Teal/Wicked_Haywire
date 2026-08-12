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
# Added `hover_object` as a mechanism to improve interactions with objects on the canvas.

#TODO Make zoom into the center
#TODO Implement more signals
#FIXME go_to(Vector2.ZERO) doesn't seem to work if InfiCanvas isn't root node.

const LASSO_THRESHOLD = 6  ## Size the lasso must have to be considered the start of a drag operation.

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
func state(funk:StringName, ...args):
	return states[curr].callv(funk, args)

## Immediately change to [code]next[/code] state.
func switch_state(next:StringName):
	if next == curr: return
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
	
	## Allows inheriting states to make new states and make them be entered instead
	## Of a previous one of the same name.
	static func override_state() -> StringName:
		return &""
	
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
	## Drag operation was finished. [code]drag_button()[/code] provided as a convinience.
	## This function is only call if the button that made [code]drag_started()[/code]
	## return [code]true[/code] is released.
	func drag_stopped(drag_button:MouseButton): pass
	func gui_input(event:InputEvent): pass
	func input(event:InputEvent): pass
@warning_ignore_restore("unused_parameter")


class Idle extends State:
	func hover_object(_object):
		switch_state.emit("Hover")
	
	var ini_origin : Vector2
	var lasso_primed : bool
	
	func drag_started(drag_button:MouseButton) -> bool:
		if drag_button == MOUSE_BUTTON_LEFT:
			lasso_primed = true  # Wait for the lasso_rect to be big enough to justify switching state.
			return true
		elif drag_button == MOUSE_BUTTON_MIDDLE:
			ini_origin = me.origin
			return true
		return false
	
	func drag_stopped(_drag_button:MouseButton):
		lasso_primed = false
		me.clear_selected()
	
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
		if event is InputEventMouseMotion:
			if me._drag_button == MOUSE_BUTTON_MIDDLE:
				me.origin = ini_origin +  me.displacement() / me.zoom
			elif me._drag_button == MOUSE_BUTTON_LEFT and lasso_primed:
				var lasso_size = max(me.lasso_screen_rect.size.x, me.lasso_screen_rect.size.y)
				if lasso_size > me.LASSO_THRESHOLD:
					switch_state.emit("Lasso")
		
		if Input.is_action_just_pressed_by_event("inficanvas_group", event):
			var default_group_name = str(Time.get_ticks_usec())
			me.obj_groups[default_group_name] = []
			for each in me._selected:
				var data = me.get_obj_data(each)
				data["obj_group"] = default_group_name
				me.obj_groups[default_group_name].append(each)
			me.clear_selected()
		
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
		me.queue_redraw()
		if drag_button == MOUSE_BUTTON_LEFT:
			me.lasso_select_objects(me.lasso_canvas_rect)
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
	var move_primed : bool
	
	func enter(_prev:StringName):
		if me.hover_object == null or \
		not("position" in me.hover_object or "rect" in me.hover_object):
			switch_state.emit("Idle")
	
	func hover_object(object):
		if object == null:
			switch_state.emit("Idle")
	
	func drag_started(drag_button:MouseButton) -> bool:
		if drag_button == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SHIFT):
				if me.hover_object in me._selected:
					me.rem_selected(me.hover_object)
				else:
					me.add_selected(me.hover_object)
			elif not me.hover_object in me._selected:
				me.set_selected(me.hover_object)
			move_primed = true
			return true
		return false
	
	func exit(_next:StringName): move_primed = false
	func drag_stopped(_drag_button:MouseButton): move_primed = false
	
	func input(event:InputEvent):
		if event is InputEventMouseButton and event.is_released():
			if event.button_index == MOUSE_BUTTON_LEFT and not Input.is_key_pressed(KEY_SHIFT):
				me.set_selected(me.hover_object)
		
		if event is InputEventMouseMotion and move_primed:
			switch_state.emit("Move")


class Move extends State:
	func enter(_prev:StringName):
		# Track the initial position of selected objects
		# Add all objects in common with group of a selected one to the selected list.
		for obj in me._selected.duplicate():
			me._selected[obj] = _move_unmodulate(obj, get_position(obj))
			var data = me.get_obj_data(obj)
			var group = data.get("obj_group", "")
			for other in me.obj_groups.get(group, []):
				me._selected[other] = _move_unmodulate(other, get_position(other))
			_move_start(obj)
	
	func exit(_next:StringName):
		for obj in me._selected:
			var data : Dictionary = me.get_obj_data(obj)
			me.all_objs[obj].update_object(obj)
			if obj.has_method("_canvas_repositioned"):
				obj._canvas_repositioned(data)
			_move_stop(obj)
	
	func drag_stopped(_drag_button:MouseButton):
		if me.hover_object == null:
			switch_state.emit("Idle")
		else:
			switch_state.emit("Hover")
	
	func input(event:InputEvent):
		if event is InputEventMouseMotion:
			me.queue_redraw()
			for obj in me._selected:
				var data : Dictionary = me.get_obj_data(obj)
				var new_pos = _move_modulate(obj,  me._selected[obj] + me.displacement() / me.zoom)
				set_position(obj, new_pos)
				if obj is Object and obj.has_method("_canvas_repositioning"):
					obj._canvas_repositioning(data)
	
	func get_position(object) -> Vector2:
		if "position" in object:
			return object.position
		elif "rect" in object:
			return object.rect.position
		elif object is Object and object.has_method("get_rect"):
			return object.get_rect().position
		return Vector2.ZERO
	
	func set_position(object, position:Vector2) -> void:
		if "position" in object:
			object.position = position
		elif "rect" in object:
			object.rect.position = position
	
	@warning_ignore("unused_parameter")
	func _move_start(obj):
		me._selected_obj_movement_start(obj)
	@warning_ignore("unused_parameter")
	func _move_stop(obj):
		me._selected_obj_movement_stop(obj)
	func _move_modulate(obj, new_position:Vector2) -> Vector2:
		return me._obj_movement_modulate(obj, new_position)
	func _move_unmodulate(obj, raw_position:Vector2) -> Vector2:
		return me._obj_movement_unmodulate(obj, raw_position)
	
#endregion

#region Boilerplate
var ini_mouse : Vector2  ## Coordinate of the mouse when the left button was last pressed.
var fin_mouse : Vector2  ## Coordinate of the mouse when the left button was last released. Current mouse button can be found with [code]get_local_mouse_position()[/code].

var hover_object : set=_set_hover_object  # Define a way to tell which canvas object the mouse is over and implement the `_sethover_object()` to disable functions that would conflict with object interaction. Set `null` if no relevant object is under the mouse.
func _set_hover_object(val):
	hover_object = val
	state(&"hover_object", val)

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
				if konst == &"State": continue
				state_chain.push_back([konst, karto[konst]])
		prev = klaso 
		klaso = klaso.get_base_script()
	
	while not state_chain.is_empty():
		var stt = state_chain.pop_back()
		var override = stt[1].override_state()
		if not override.is_empty(): stt[0] = override
		states[stt[0]] = stt[1].new(self)
		states[stt[0]].switch_state.connect(switch_state, ConnectFlags.CONNECT_DEFERRED)
	
	await ready
	curr = &"Idle"
	state(&"enter", "")

func _process(_delta: float) -> void:
	if overlay_mode == "Process": overlay.queue_redraw()
	
	
func _physics_process(_delta: float) -> void:
	if overlay_mode == "Physics": overlay.queue_redraw()


func displacement() -> Vector2:
	return get_local_mouse_position() - ini_mouse

## Override this function to decide which objects are selected after a lasso
## drag operation.[br]
## By default it selects only Godot Nodes added with [code]place_object()[/code].
func lasso_select_objects(lasso_rect:Rect2) -> void:
	var selection : Array[Node]
	var partis : Dictionary[SpatialPartition, bool]  # Track all encountered partitions so we don't have to check all objects.
	for each in all_objs:
		if partis.size() >= parti.size(): break
		var checked = partis.get_or_add(all_objs[each], false)
		if each is Node and not checked:
			selection.append_array(all_objs[each].find_objects_tolerant(lasso_rect))
	set_selected.callv(selection)


func _gui_input(event: InputEvent) -> void:
	state(&"gui_input", event)

var _drag_button : MouseButton = MOUSE_BUTTON_NONE
var is_dragging : bool  #NOTE Technically you could tell if a drag operation is happening by checking `_drag_button == MOUSE_BUTTON_NONE`, but if dragging while states change, it might be become ambiguous.
func _input(event: InputEvent) -> void:
	state(&"input", event)
	if overlay_mode == "Input Event": overlay.queue_redraw()
	
	if event is InputEventMouseButton:
		if _drag_button == MOUSE_BUTTON_NONE and event.is_pressed():
			if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
				# Track the button starting a drag operation
				ini_mouse = get_local_mouse_position()
				if state(&"drag_started", event.button_index):
					is_dragging = true
					_drag_button = event.button_index
		elif event.is_released() and _drag_button == event.button_index:
			# Reset the drag operation if same button that started it is released
			state(&"drag_stopped", _drag_button)
			fin_mouse = get_local_mouse_position()
			is_dragging = false
			_drag_button = MOUSE_BUTTON_NONE
	
	if event is InputEventKey and event.is_released():
		if event.keycode == KEY_ESCAPE:
			state(&"cancel")
	
	
	if event is InputEventMouseMotion:
		if overlay_mode == "Mouse Motion": overlay.queue_redraw()
		#NOTE Dragging operations are valid for the three main mouse buttons.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or \
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			lasso_screen_rect = Rect2(ini_mouse, displacement()).abs()


func draw_back_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	super(canvas, viewed_canvas_rect)
	state(&"back_draw", canvas, viewed_canvas_rect)

func draw_fore_geometry():
	super()
	state(&"fore_draw", forecanvas, _view_rect)

func draw_overlay():
	super()
	state(&"over_draw", overlay, _view_rect)

#endregion

#region Object Repositioning (Movement)
## Override this function to implement things like grid snapping.
@warning_ignore("unused_parameter")
func _obj_movement_modulate(object, new_position:Vector2) -> Vector2:
	return new_position

## Override this function to undo things like grid snapping.
@warning_ignore("unused_parameter")
func _obj_movement_unmodulate(object, new_position:Vector2) -> Vector2:
	return new_position

## Override this function to define what to do with an object being repositioned.
@warning_ignore("unused_parameter")
func _selected_obj_movement_start(obj):
	pass

## Override this function to define what to do with an object after repositioned.
@warning_ignore("unused_parameter")
func _selected_obj_movement_stop(obj):
	pass

@warning_ignore("unused_parameter")
func _set_selected(val:Array):
	pass
#endregion

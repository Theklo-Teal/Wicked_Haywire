extends PanelContainer
class_name SidebarTray

@export_enum("expand_right", "expand_left") var direction : int = 0
@export var resize_margin : int = 12
@export var collapse_size : int = 20
@export var expand_size : int = 200

var tween : Tween
var mouse_over : bool :
	set(val):
		if lock_check.button_pressed:
			mouse_over = true
			_box.show()
			custom_minimum_size.x = expand_size
			return
		
		mouse_over = val
		if tween != null and tween.is_valid():
			tween.kill()		
		tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		if val:
			tween.set_trans(Tween.TRANS_SPRING)
			tween.tween_property(self, "custom_minimum_size:x", expand_size, 0.25)
			_box.visible = true
		else:
			tween.set_trans(Tween.TRANS_BOUNCE)
			tween.tween_property(self, "custom_minimum_size:x", collapse_size, 1.0)
			_box.visible = false

var _box := VBoxContainer.new()
var lock_check := Button.new()
var content := ScrollContainer.new()
func _ready() -> void:
	custom_minimum_size.x = 32
	size_flags_horizontal = Control.SIZE_SHRINK_END if (direction as bool) else Control.SIZE_SHRINK_BEGIN
	
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.add_child(lock_check)
	_box.add_child(content)
	_box.hide()
	
	lock_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_check.mouse_filter = Control.MOUSE_FILTER_PASS
	lock_check.text = name
	lock_check.toggle_mode = true
	
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	mouse_entered.connect(func():mouse_over=true)
	mouse_exited.connect(func():if not resize_drag: mouse_over=false)


func _can_resize(event_position:int) -> bool:
	return event_position < resize_margin if (direction as bool) else event_position > size.x - resize_margin

var resize_drag:=false
var resize_start : Vector2
var expand_ini : int
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed() and lock_check.button_pressed and _can_resize(event.position.x):
			resize_start = event.position
			expand_ini = expand_size
			resize_drag = true
		if event.is_released():
			resize_drag = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and lock_check.button_pressed:
		@warning_ignore("narrowing_conversion")
		if _can_resize(get_local_mouse_position().x):
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		
		if resize_drag:
			var delta = resize_start.x - get_local_mouse_position().x if (direction as bool) else get_local_mouse_position().x - resize_start.x
			expand_size = clamp(expand_ini + delta, collapse_size, get_parent().size.x / 3)
			custom_minimum_size.x = expand_size

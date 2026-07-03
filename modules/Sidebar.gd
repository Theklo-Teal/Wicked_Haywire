extends PanelContainer
class_name SidebarTray

var tween : Tween

var mouse_over : bool :
	set(val):
		mouse_over = val
		if tween != null and tween.is_valid():
			tween.kill()
		tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		if val:
			tween.set_trans(Tween.TRANS_SPRING)
			tween.tween_property(self, "custom_minimum_size:x", 200, 0.25)
			_box.visible = true
		elif not lock_check.button_pressed:
			tween.set_trans(Tween.TRANS_BOUNCE)
			tween.tween_property(self, "custom_minimum_size:x", 32, 1.0)
			_box.visible = false

var _box := VBoxContainer.new()
var lock_check := Button.new()
var content := ScrollContainer.new()
func _ready() -> void:
	custom_minimum_size.x = 32
	
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
	mouse_exited.connect(func():mouse_over=false)

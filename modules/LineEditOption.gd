extends LineEdit
class_name LineEditOption

## A LineEdit which includes a drop down with things the user might want to type.[br]
## This isn't meant as an auto-complete system, but rather for example as file load widget, where
## recently opened files are shown and the user has an option to type a new filename to create a new one.[br]
## This is inspired by such widgets in GTK interfaces.


@export var items : Array[String] : 
	set(val):
		items = val
		if not is_node_ready():
			await ready
			popupmenu.clear()
			for each in items:
				popupmenu.add_item(each)

var popupmenu : PopupMenu

func _init() -> void:
	popupmenu = PopupMenu.new()
	add_child(popupmenu)
	focus_entered.connect(__on_focus_entered)
	gui_input.connect(__on_gui_input)
	popupmenu.index_pressed.connect(__on_popup_index_pressed)

func _draw():
	var half_hei = size.y * 0.35
	draw_arc(Vector2(size.x - half_hei - 8, half_hei), half_hei, 0, PI, 3, Color.WHITE, 3)

func popup():
	popupmenu.popup(Rect2(
		global_position + Vector2(0, size.y),
		Vector2(size.x, 200)
		))

func __on_focus_entered():
	popup()

func __on_popup_index_pressed(idx:int):
	text = popupmenu.get_item_text(idx)

func __on_gui_input(event:InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		popup()

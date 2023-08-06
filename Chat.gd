extends Control
var chat_id = "0"
@export var chat_label: Label
@export var name_label: Label

func set_size_for_wrap():
	var ysize = chat_label.get_line_count() * chat_label.get_line_height()
	print(ysize)
	set_custom_minimum_size(Vector2(0,ysize))

func set_chat_text(text):
	chat_label.text = text
	set_size_for_wrap()

	
func set_chat_id(id):
	chat_id = id

func set_name_text(name):
	name_label.text = name + ": "


func _on_chat_label_resized():
	set_size_for_wrap()

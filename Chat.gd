extends Control
var chat_id = "0"
@export var chat_label: Label
@export var name_label: Label

func set_chat_text(text):
	chat_label.text = text
	
func set_chat_id(id):
	chat_id = id

func set_name_text(name):
	name_label.text = name + ": "

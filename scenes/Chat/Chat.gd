extends Control
var chat_id = "0"
@export var chat_label: RichTextLabel
@export var name_label: Label

func _ready():
	set_font_defaults(40)

func set_font_defaults(font_size):
	chat_label.add_theme_font_size_override("normal_font_size",font_size)
	chat_label.add_theme_font_size_override("bold_font_size",font_size)
	chat_label.add_theme_font_size_override("italics_font_size",font_size)
	chat_label.add_theme_font_size_override("bold_italics_font_size",font_size)
	chat_label.add_theme_font_size_override("mono_font_size",font_size)
	name_label.add_theme_font_size_override("font_size",font_size)

func set_size_for_wrap():
	# Gets the size of a line, needs to be checked 
	# incase of wraparound and if the window is resized
	var ysize = chat_label.get_content_height()
	set_custom_minimum_size(Vector2(0,ysize))

func set_chat_text(text):
	chat_label.text = text
	set_size_for_wrap()

	
func set_chat_id(id):
	chat_id = id

func set_name_text(username):
	name_label.text = username + ": "

func _on_rich_chat_label_resized():
	set_size_for_wrap()

extends Control

@export var name_entry: LineEdit
signal name_changed(name)
signal exited_options()

func _on_exit_button_pressed():
	emit_signal("exited_options")
	queue_free()


func _on_set_name_button_pressed():
	_on_line_edit_text_submitted(name_entry.text)


func _on_line_edit_text_submitted(new_text):
	if new_text != "":
		Globals.username = new_text
		emit_signal("name_changed", new_text)

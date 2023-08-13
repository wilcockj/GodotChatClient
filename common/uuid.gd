extends Node

func generate_uuid() -> String:
	var chars: Array = []
	for i in range(8):
		chars.append(randi_range(0, 15))
	chars.append("-")
	for i in range(4):
		chars.append(randi_range(0, 15))
	chars.append("-")
	chars.append(4)  # Version 4
	chars.append(randi_range(0, 15))
	chars.append("-")
	chars.append(randi_range(8, 11))  # UUID variant 1
	for i in range(3):
		chars.append(randi_range(0, 15))
	chars.append("-")
	for i in range(12):
		chars.append(randi_range(0, 15))

	var uuid: String = ""
	for chr in chars:
		if typeof(chr) == TYPE_INT:
			uuid += "%x" % chr
		else:
			uuid += chr
	return uuid

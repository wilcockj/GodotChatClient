extends Node2D

@export var text_input: LineEdit
@export var chat_container: VBoxContainer
# The URL we will connect to
@export var websocket_url = "wss://swiftnotes.net/ws"
@onready var label_scene = preload("res://Chat.tscn")

var uuid_util = preload('res://uuid.gd').new()

# make chat a class with methods to send and set timestamp etc.
var chat = {"finished": false, "message": "", "userid": "", "username": "", "uuid":"", "timestamp": 0}
# Our WebSocketClient instance
var socket = WebSocketPeer.new()

func _ready():
	print(uuid_util.generate_uuid())
	socket.connect_to_url(websocket_url)
	chat.userid = uuid_util.generate_uuid()
	chat.username = "JohnGodot"
	chat.finished = false
	chat.timestamp = Time.get_unix_time_from_system()
	chat.uuid = uuid_util.generate_uuid()

func contains_chat_id(search_id):
	for child in chat_container.get_children():
		if child is Control and child.has_method("set_chat_id"):
			if child.chat_id == search_id:
				return child
	return false

func add_label(chatdata):
	var label_instance = label_scene.instantiate()
	label_instance.set_chat_text(chatdata.message)
	label_instance.set_name_text(chatdata.username)
	label_instance.set_chat_id(chatdata.uuid)
	chat_container.add_child(label_instance)

func set_label(label,message):
	label.set_chat_text(message)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var recv_chat = socket.get_packet().get_string_from_utf8()
			var json = JSON.new()
			var error = json.parse(recv_chat)
			if error == OK:
				var data_received = json.data
				print(data_received)
				if data_received.userid != chat.userid:
					var chat_present = contains_chat_id(data_received.uuid)
					if !chat_present:
						add_label(data_received)
					else:
						set_label(chat_present,data_received.message)
			
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
		# need to add actual retry connecting with backoff
		socket.connect_to_url(websocket_url)

func _on_line_edit_text_changed(new_text):
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# send the json object stringified
		chat.message = new_text
		socket.send_text(JSON.stringify(chat))



func _on_line_edit_text_submitted(new_text):
	text_input.clear()
	chat.finished = true
	chat.message = new_text
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(chat))
		chat.uuid = uuid_util.generate_uuid()

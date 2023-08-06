extends Node2D

@onready var text_input = $CanvasLayer/Control/HBoxContainer/MarginContainer2/LineEdit
# The URL we will connect to
@export var websocket_url = "wss://swiftnotes.net/ws"

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

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var chat = socket.get_packet().get_string_from_utf8()
			var json = JSON.new()
			var error = json.parse(chat)
			if error == OK:
				var data_received = json.data
				print(data_received)
			print("Packet: ", chat)
			
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
		print(new_text)
		chat.message = new_text
		var json = JSON.new()
		socket.send_text(json.stringify(chat))



func _on_line_edit_text_submitted(new_text):
	print("submitted this trash: ", new_text)
	text_input.clear()
	chat.finished = true
	chat.message = new_text
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		var json = JSON.new()
		socket.send_text(json.stringify(chat))
		chat.uuid = uuid_util.generate_uuid()

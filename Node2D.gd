extends Node2D

# The URL we will connect to
@export var websocket_url = "wss://swiftnotes.net/ws"


var chat = {"finished": false, "message": "", "userid": "", "username": "", "uuid":""}
# Our WebSocketClient instance
var socket = WebSocketPeer.new()

func _ready():
	socket.connect_to_url(websocket_url)

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
		socket.connect_to_url(websocket_url)


func _on_text_edit_text_changed():
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# send the json object stringified
		pass

extends Node2D


#todo delete node after a timer
#dont have websocket node in scene instatiate in ready
#time to send __ping__ message and check for that in the recieve
enum {DISCONNECTED, CONNECTED} 
var connection_state = DISCONNECTED
# Variables related to retry connection and backoff
var max_retries = 5  # The maximum number of times to retry
var current_retry = 0  # The current retry count
var retry_delay = 1.0  # Start with a delay of 1 second
var max_retry_delay = 16.0  # The maximum delay of 16 seconds
var websocket_url = ""
@export var retry_timer: Timer

@export var text_input: LineEdit
@export var chat_container: VBoxContainer
@export var connection_indicator: TextureRect
@export var disconnect_player: AudioStreamPlayer
@export var connect_player: AudioStreamPlayer
@onready var connection_image = preload("res://images/connect.svg")
@onready var disconnection_image = preload("res://images/disconnect.svg")

# The URL we will connect to
#@export var websocket_url = "wss://swiftnotes.net/ws"
# Audio player for connect and disconnect
@export var audio_player: AudioStreamPlayer

@onready var label_scene = preload("res://Chat.tscn")

var uuid_util = preload('res://uuid.gd').new()

# make chat a class with methods to send and set timestamp etc.
var chat = {"finished": false, "message": "", "userid": "", "username": "", "uuid":"", "timestamp": 0}
# Our WebSocketClient instance
var socket: WebSocketPeer

func _ready():
	print(uuid_util.generate_uuid())
	socket = $WebSocketConnection.socket
	websocket_url = $WebSocketConnection.websocket_url
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
	if chatdata.username == "":
		chatdata.username = "Anon"
	var label_instance = label_scene.instantiate()
	label_instance.set_chat_text(chatdata.message)
	label_instance.set_name_text(chatdata.username)
	label_instance.set_chat_id(chatdata.uuid)
	chat_container.add_child(label_instance)

func set_label(label,message):
	label.set_chat_text(message)

func play_connect_sound():
	connect_player.play()

func play_disconnect_sound():
	disconnect_player.play()

func init_backoff_values():
	max_retries = 5  # The maximum number of times to retry
	current_retry = 0  # The current retry count
	retry_delay = 1.0  # Start with a delay of 1 second
	max_retry_delay = 16.0  # The maximum delay of 16 seconds

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		
		
		if connection_state == DISCONNECTED:
			connection_state = CONNECTED
			play_connect_sound()
			connection_indicator.texture = connection_image
			#connection_indicator.
 
		while socket.get_available_packet_count():
			var recv_chat = socket.get_packet().get_string_from_utf8()
			var json = JSON.new()
			var error = json.parse(recv_chat)
			if error == OK:
				var data_received = json.data
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
		#close socket so it can be reconnected
		
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		
		if connection_state == CONNECTED:
			connection_state = DISCONNECTED
			play_disconnect_sound()
			connection_indicator.texture = disconnection_image
			socket.close(-1)
		
		# has to be -1 to close immediately

		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		#$WebSocketConnection.socket = null
		#$WebSocketConnection.queue_free()
		
		# TODO free the websocket connection after 10 seconds
		# need to add actual retry connecting with backoff
		if current_retry == 0:
			var websocket_scene_instance = load("res://WebSocketConnection.tscn").instantiate()
			add_child(websocket_scene_instance)
			socket = websocket_scene_instance.socket
			retry_timer.start(retry_delay)
		else:
			print("Max retries reached. Stopping reconnection attempts.")

func retry_connecting():
	current_retry += 1
	print("Attempting to reconnect to %s. Try number: %d" % [websocket_url, current_retry])
	# Try to connect again
	print(socket.get_ready_state())
	socket.connect_to_url(websocket_url)
	# Increment delay for the next potential retry, but cap it to max_retry_delay
	retry_timer.stop()
	retry_timer.start(retry_delay)
	print(retry_delay)
	retry_delay = min(retry_delay * 2, max_retry_delay)
	
func _on_retry_timer_timeout():
	retry_connecting()

func is_text_clear(text) -> bool:
	var text_clear = text.replace(" ","")
	if text_clear == "":
		#only spaces dont send
		return true
	return false
	
func _on_line_edit_text_changed(new_text):
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# send the json object stringified
		chat.message = new_text
		if !is_text_clear(new_text):
			socket.send_text(JSON.stringify(chat))



func _on_line_edit_text_submitted(new_text):
	if is_text_clear(new_text):
		#only spaces dont send
		return
	text_input.clear()
	chat.finished = true
	chat.message = new_text
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(chat))
		chat.uuid = uuid_util.generate_uuid()
	add_label(chat)


func _on_button_pressed():
	_on_line_edit_text_submitted(text_input.text)

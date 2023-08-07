extends Node2D

# todo add messages sent by self
enum {DISCONNECTED, CONNECTED} 
var connection_state = DISCONNECTED
# Variables related to retry connection and backoff
var max_retries = 5  # The maximum number of times to retry
var current_retry = 0  # The current retry count
var retry_delay = 1.0  # Start with a delay of 1 second
var max_retry_delay = 16.0  # The maximum delay of 16 seconds

@export var retry_timer: Timer

@export var text_input: LineEdit
@export var chat_container: VBoxContainer

# The URL we will connect to
@export var websocket_url = "wss://swiftnotes.net/ws"
# Audio player for connect and disconnect
@export var audio_player: AudioStreamPlayer

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

func play_connect_sound():
	var stream = AudioStreamMP3.new()
	var file = FileAccess.open("res://sounds/connect.mp3", FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	audio_player.stream = sound
	# Play the audio
	audio_player.play()

func play_disconnect_sound():
	var stream = AudioStreamMP3.new()
	var file = FileAccess.open("res://sounds/disconnect.mp3", FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	audio_player.stream = sound
	# Play the audio
	audio_player.play()

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if connection_state == DISCONNECTED:
			connection_state = CONNECTED
			play_connect_sound()
 
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
		
		if connection_state == CONNECTED:
			connection_state = DISCONNECTED
			play_disconnect_sound()
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		socket.close()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
		# need to add actual retry connecting with backoff
		if current_retry == 0:
			socket = WebSocketPeer.new()
		if current_retry < max_retries:
			retry_connecting()
		else:
			print("Max retries reached. Stopping reconnection attempts.")
			set_process(false)  # Stop processing.

func retry_connecting():
	current_retry += 1
	print("Attempting to reconnect. Try number: %d" % current_retry)
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


func _on_button_pressed():
	_on_line_edit_text_submitted(text_input.text)

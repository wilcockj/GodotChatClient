extends Node2D

#add bolding of actively typing message
#remove bolding once completed

#clean up state machine logic for virtual keyboard

enum {DISCONNECTED, CONNECTED} 
var connection_state = DISCONNECTED
# Variables related to retry connection and backoff
var max_retries = 5  # The maximum number of times to retry
var current_retry = 0  # The current retry count
var retry_delay = 1.0  # Start with a delay of 1 second
var max_retry_delay = 16.0  # The maximum delay of 16 seconds
var websocket_url = ""
var websocket_scene_instances = []
var virtual_keyboard_handled = false
var virtual_keyboard_height = 0
var bottom_menu_size = 0
var opened_once = false # variable to check if ever successfully connected
						# to enable retry if first connection fails
@export var retry_timer: Timer

@export var text_input: TextEdit
@export var chat_container: VBoxContainer
@export var connection_indicator: TextureRect
@export var disconnect_player: AudioStreamPlayer
@export var connect_player: AudioStreamPlayer
@export var url_label: Label
@export var gui_control: Control
@export var name_label: Label
@export var canvas_layer: CanvasLayer
@export var blur_rect: ColorRect
@onready var connection_image = preload("res://assets/images/connect.svg")
@onready var disconnection_image = preload("res://assets/images/disconnect.svg")
@onready var websocket_scene = preload("res://scenes/WebSocketConnection/WebSocketConnection.tscn")
@onready var options_scene = preload("res://scenes/Options/options.tscn")

@onready var label_scene = preload("res://scenes/Chat/Chat.tscn")

var uuid_util = preload("res://lib/uuid.gd").new()
# make chat a class with methods to send and set timestamp etc.
var chat = {"finished": false, "message": "", "userid": "", "username": "", "uuid":"", "timestamp": 0}
# Our WebSocketClient instance
var socket: WebSocketPeer
var websocket_scene_instance
func _ready():
	websocket_scene_instance = websocket_scene.instantiate()
	add_child(websocket_scene_instance)
	socket = websocket_scene_instance.socket
	websocket_url = websocket_scene_instance.websocket_url
	
	chat.userid = uuid_util.generate_uuid()
	chat.username = Globals.username
	chat.finished = false
	chat.timestamp = Time.get_unix_time_from_system()
	chat.uuid = uuid_util.generate_uuid()
	url_label.text = "Connected to: " + socket.get_requested_url()
	set_name_label(Globals.username)


func set_name_label(name):
	name_label.text = name
	chat.username = name

func is_virtual_keyboard_shown():
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return DisplayServer.virtual_keyboard_get_height() != 0
	else:
		return 0

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

func _delete_instances_except(instances,index_to_keep):
	for i in instances:
		print(typeof(i))
		#print(i.bundled)
		if typeof(i) == TYPE_OBJECT:
			if i != index_to_keep:
				var wr = weakref(i)
				if (!wr.get_ref()):
					pass
				else:
					# not freed
					i.queue_free()
	instances.clear()
	instances.append(websocket_scene_instance)

func _adjust_gui_vbox_size(delta_height: float) -> void:
	var temp_y = gui_control.size.y + delta_height
	if temp_y > DisplayServer.get_display_safe_area().size.y:
		#too big
		return
	gui_control.size.y += delta_height
	
func _subtract_keyboard_height_deferred(timer):
	virtual_keyboard_height = DisplayServer.virtual_keyboard_get_height()
	_adjust_gui_vbox_size(-virtual_keyboard_height+bottom_menu_size)
	timer.queue_free()
	
func handle_virtual_keyboard():
	if is_virtual_keyboard_shown() and not virtual_keyboard_handled:
		if DisplayServer.virtual_keyboard_get_height() > 30:
			# bottom menu with back button and home button height
			bottom_menu_size = DisplayServer.get_display_safe_area().size.y - gui_control.size.y
			var bottom_padding = 20
			bottom_menu_size -= bottom_padding
			var timer = Timer.new()
			timer.wait_time = 0.3 # have to wait for keyboard to be fully deployed
			timer.one_shot = true
			# Add the timer to the current scene
			self.add_child(timer)
			# Start the timer
			timer.start()
			# Connect the timer's timeout signal to a function
			timer.connect("timeout",_subtract_keyboard_height_deferred.bind(timer))
			virtual_keyboard_handled = true
	elif not is_virtual_keyboard_shown() and virtual_keyboard_handled:
		_adjust_gui_vbox_size(virtual_keyboard_height-bottom_menu_size)
		virtual_keyboard_handled = false
		
func _process(_delta):
	handle_virtual_keyboard()
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:		
		opened_once = true
		if connection_state == DISCONNECTED:
			connection_state = CONNECTED
			play_connect_sound()
			connection_indicator.texture = connection_image
			retry_timer.stop()
			_delete_instances_except(websocket_scene_instances,websocket_scene_instance)
			init_backoff_values()
			#delete all but current websocket node
			#connection_indicator.
 
		while socket.get_available_packet_count():
			var recv_chat = socket.get_packet().get_string_from_utf8()
			if recv_chat == "__pong__":
				#got return from out ping
				continue
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
		
		if connection_state == CONNECTED or not opened_once:
			opened_once = true
			connection_state = DISCONNECTED
			play_disconnect_sound()
			connection_indicator.texture = disconnection_image
			socket.close(-1)
			retry_timer.start(retry_delay)
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		
		# has to be -1 to close immediately

func retry_connecting():
	if connection_state == DISCONNECTED:
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
	text_clear = text.replace("\n","")
	if text_clear == "":
		#only spaces dont send
		return true
	return false
	
func _on_line_edit_text_changed(new_text):
	var state = socket.get_ready_state()
	if is_text_clear(new_text):
		return
	if state == WebSocketPeer.STATE_OPEN:
		# send the json object stringified
		chat.message = new_text
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


func _on_ping_timer_timeout():
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		print("Sending ping")
		socket.send_text("__ping__")


func _on_text_edit_gui_input(event):
	if event is InputEventKey:
		var keys_pressed_string = OS.get_keycode_string(event.get_key_label_with_modifiers())
		if event.pressed and event.keycode == KEY_ENTER and "Shift" not in keys_pressed_string:
			var new_text = text_input.text
			_on_line_edit_text_submitted(new_text)
		elif event.pressed and event.keycode == KEY_ENTER and "Shift" in keys_pressed_string:
			text_input.insert_text_at_caret("\n")
			



func _on_text_edit_text_changed():
	if is_text_clear(text_input.text):
		text_input.text = "" 
	_on_line_edit_text_changed(text_input.text)

func remove_blur():
	blur_rect.material.set_shader_parameter("lod",0)

func _on_options_button_pressed():
	blur_rect.material.set_shader_parameter("lod",2)
	var opt = options_scene.instantiate()
	opt.connect("name_changed", set_name_label)
	opt.connect("exited_options", remove_blur)
	gui_control.add_child(opt)
	

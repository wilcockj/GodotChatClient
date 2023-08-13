extends Node2D
var socket = WebSocketPeer.new()
var websocket_url: String


func _ready():
#	if OS.is_debug_build():
#		websocket_url = "ws://localhost:8089/ws"
#	else:
	websocket_url = "wss://swiftnotes.net/ws"
	socket.connect_to_url(websocket_url)
	print("Connecting to:", websocket_url)

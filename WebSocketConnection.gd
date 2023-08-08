extends Node2D
var socket = WebSocketPeer.new()

@export var websocket_url: String


func _ready():
	socket.connect_to_url(websocket_url)

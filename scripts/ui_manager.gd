extends Node

# Global UI Sound Manager
# Plays sounds for buttons automatically

var hover_sound = preload("res://assets/audio/interface/hover.ogg")
var click_sound = preload("res://assets/audio/interface/click.ogg")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to existing buttons and any new ones
	get_tree().node_added.connect(_on_node_added)
	_setup_existing_buttons(get_tree().root)

func _setup_existing_buttons(node):
	if node is Button:
		_connect_button(node)
	for child in node.get_children():
		_setup_existing_buttons(child)

func _on_node_added(node):
	if node is Button:
		_connect_button(node)

func _connect_button(button: Button):
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)
	if not button.pressed.is_connected(_on_button_click):
		button.pressed.connect(_on_button_click)

func _on_button_hover():
	_play_sound(hover_sound)

func _on_button_click():
	_play_sound(click_sound)

func _play_sound(stream: AudioStream):
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.bus = "UI"
	player.play()
	player.finished.connect(player.queue_free)

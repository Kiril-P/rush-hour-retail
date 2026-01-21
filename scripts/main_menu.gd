extends Control

@onready var menu_camera = $MenuCamera
@onready var menu_ui = $MenuUI
@onready var game_scene_container = $GameSceneContainer

var game_instance = null

func _ready():
	# Play main menu/game music
	var music_manager = get_node_or_null("/root/MusicManager")
	if music_manager:
		music_manager.play_music(load("res://assets/music/Swing-Machine-chosic.com_.mp3"))

	# Instance the market scene but don't start the game yet
	var game_scene = load("res://blender_market.tscn")
	game_instance = game_scene.instantiate()
	game_scene_container.add_child(game_instance)
	
	# Find the player and disable it for now
	var player = game_instance.find_child("FpsPlayer")
	if player:
		player.set_physics_process(false)
		player.set_process(false)
		player.set_process_input(false) # Disable input handling in menu
		var player_cam = player.find_child("Camera3D")
		if player_cam:
			player_cam.current = false
	
	# Make sure menu camera is current
	menu_camera.current = true
	
	# Ensure cursor is visible (Player might have captured it in its _ready)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_start_button_pressed():
	print("Starting game from menu...")
	menu_ui.hide()
	menu_camera.current = false
	
	# Enable the player
	var player = game_instance.find_child("FpsPlayer")
	if player:
		player.set_physics_process(true)
		player.set_process(true)
		player.set_process_input(true) # Re-enable input
		var player_cam = player.find_child("Camera3D")
		if player_cam:
			player_cam.current = true
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Start the game logic
	if GameManager:
		GameManager.start_game()

func _on_quit_button_pressed():
	get_tree().quit()

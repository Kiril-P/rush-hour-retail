extends Control

@onready var menu_camera = $MenuCamera
@onready var menu_ui = $MenuUI
@onready var game_scene_container = $GameSceneContainer
@onready var settings_container = $SettingsContainer

var game_instance = null

# Available maps - randomly selected when playing
const AVAILABLE_MAPS = [
	"res://blender_market.tscn",
	"res://blender_market2.tscn"
]

func _ready():
	# Initially hide settings
	if settings_container:
		settings_container.hide()
	
	# Play main menu/game music
	var music_manager = get_node_or_null("/root/MusicManager")
	if music_manager:
		music_manager.play_music(load("res://assets/music/Swing-Machine-chosic.com_.mp3"))

	# PERFORMANCE FIX: Don't load the game scene until player clicks play!
	# Just pick a random map and load it when needed
	randomize()  # Seed the random number generator
	var random_map = AVAILABLE_MAPS[randi() % AVAILABLE_MAPS.size()]
	var game_scene = load(random_map)
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
		
		# Hide HUD elements while in menu
		var canvas = player.find_child("CanvasLayer")
		if canvas:
			canvas.hide()
		var crosshair_ui = player.find_child("Control")
		if crosshair_ui:
			crosshair_ui.hide()
	
	# Make sure menu camera is current
	menu_camera.current = true
	
	# Ensure cursor is visible (Player might have captured it in its _ready)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_start_button_pressed():
	print("Starting game from menu...")
	
	if get_tree().root.has_node("SceneTransition"):
		var transition = get_tree().root.get_node("SceneTransition")
		await transition.fade_out().finished
		
		# Do the setup while it's black
		menu_ui.hide()
		menu_camera.current = false
		
		# Enable the player
		var player = game_instance.find_child("FpsPlayer")
		if player:
			player.set_physics_process(true)
			player.set_process(true)
			player.set_process_input(true)
			var player_cam = player.find_child("Camera3D")
			if player_cam:
				player_cam.current = true
			
			# Show HUD elements
			var canvas = player.find_child("CanvasLayer")
			if canvas:
				canvas.show()
			var crosshair_ui = player.find_child("Control")
			if crosshair_ui:
				crosshair_ui.show()
		
		# Capture mouse
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Start the game logic
		if GameManager:
			GameManager.start_game()
			
		await transition.fade_in().finished
	else:
		menu_ui.hide()
		menu_camera.current = false
		# ... (rest of old logic)
		var player = game_instance.find_child("FpsPlayer")
		if player:
			player.set_physics_process(true)
			player.set_process(true)
			player.set_process_input(true)
			var player_cam = player.find_child("Camera3D")
			if player_cam:
				player_cam.current = true
			var canvas = player.find_child("CanvasLayer")
			if canvas:
				canvas.show()
			var crosshair_ui = player.find_child("Control")
			if crosshair_ui:
				crosshair_ui.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if GameManager:
			GameManager.start_game()

func _on_settings_button_pressed():
	menu_ui.hide()
	settings_container.show()

func _on_settings_back_pressed():
	settings_container.hide()
	menu_ui.show()

func _on_quit_button_pressed():
	get_tree().quit()

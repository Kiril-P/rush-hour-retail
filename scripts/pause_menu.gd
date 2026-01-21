extends Control

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func pause():
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume():
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_button_pressed():
	resume()

func _on_main_menu_button_pressed():
	get_tree().paused = false
	if GameManager:
		GameManager.is_game_active = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()

func _input(event):
	if event.is_action_pressed("ui_cancel") and get_tree().paused:
		resume()
		get_viewport().set_input_as_handled()

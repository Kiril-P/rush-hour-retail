extends Control

@onready var sens_slider = %SensSlider
@onready var fov_slider = %FovSlider
@onready var master_vol = %MasterVol
@onready var music_vol = %MusicVol
@onready var sfx_vol = %SfxVol
@onready var tutorial_toggle = %TutorialToggle

func _ready():
	_load_current_values()

func _load_current_values():
	if not GameManager: return
	
	sens_slider.value = GameManager.mouse_sensitivity * 10000.0 # Scale for slider
	fov_slider.value = GameManager.target_fov
	master_vol.value = GameManager.volume_master * 100.0
	music_vol.value = GameManager.volume_music * 100.0
	sfx_vol.value = GameManager.volume_sfx * 100.0
	tutorial_toggle.button_pressed = GameManager.tutorial_enabled

func _on_sens_slider_value_changed(value):
	GameManager.mouse_sensitivity = value / 10000.0
	GameManager.save_game_data()

func _on_fov_slider_value_changed(value):
	GameManager.target_fov = value
	GameManager.save_game_data()

func _on_master_vol_value_changed(value):
	GameManager.volume_master = value / 100.0
	_update_audio_buses()
	GameManager.save_game_data()

func _on_music_vol_value_changed(value):
	GameManager.volume_music = value / 100.0
	_update_audio_buses()
	GameManager.save_game_data()

func _on_sfx_vol_value_changed(value):
	GameManager.volume_sfx = value / 100.0
	_update_audio_buses()
	GameManager.save_game_data()

func _on_tutorial_toggle_toggled(button_pressed):
	GameManager.tutorial_enabled = button_pressed
	if button_pressed:
		# Reset tutorials so they show again if enabled
		for key in GameManager.completed_tutorials.keys():
			GameManager.completed_tutorials[key] = false
	GameManager.save_game_data()

func _update_audio_buses():
	# Update actual Godot audio buses
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(GameManager.volume_master))
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(GameManager.volume_music))
		
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(GameManager.volume_sfx))

	var ui_bus = AudioServer.get_bus_index("UI")
	if ui_bus != -1:
		AudioServer.set_bus_volume_db(ui_bus, linear_to_db(GameManager.volume_sfx))

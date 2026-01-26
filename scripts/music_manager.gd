extends Node

# Music Manager for dynamic supermarket atmosphere
# This script handles music playback and "muffling" when outside

var music_player: AudioStreamPlayer
var low_pass_filter: AudioEffectLowPassFilter

var is_inside: bool = true
var target_cutoff: float = 20000.0  # Default (no filter)
var current_cutoff: float = 20000.0

var target_pitch: float = 1.0
var current_pitch: float = 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create AudioStreamPlayer
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"
	
	# Loop music when finished
	music_player.finished.connect(func(): music_player.play())
	
	# Setup Audio Bus if it doesn't exist
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		music_bus_idx = AudioServer.get_bus_count()
		AudioServer.add_bus(music_bus_idx)
		AudioServer.set_bus_name(music_bus_idx, "Music")
	
	# Add LowPassFilter effect if not present
	if AudioServer.get_bus_effect_count(music_bus_idx) == 0:
		low_pass_filter = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(music_bus_idx, low_pass_filter)
	
	print("MusicManager ready. System waiting for audio stream.")
	
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)
		GameManager.game_over.connect(_on_game_over)
		GameManager.game_won.connect(_on_game_won)

func _on_time_changed(seconds_remaining: float):
	if seconds_remaining <= 10.0:
		target_pitch = 1.25 # Frantic
	elif seconds_remaining <= 30.0:
		target_pitch = 1.1 # Tense
	else:
		target_pitch = 1.0 # Calm/Normal

func _on_game_over():
	target_pitch = 0.8 # Sad slow down
	if GameManager:
		GameManager.play_sfx("res://assets/sfx/Classic Alarm Clock - Sound Effect _ ProSounds.mp3")
	
func _on_game_won():
	target_pitch = 1.0 # Reset
	if GameManager:
		GameManager.play_sfx("res://assets/sfx/win_sfx.wav")

var _cached_bus_idx: int = -2  # -2 = not cached yet
var _cached_effect: AudioEffectLowPassFilter = null

func _process(delta):
	# PERFORMANCE FIX: Only process if values need to change
	var cutoff_diff = abs(current_cutoff - target_cutoff)
	var pitch_diff = abs(current_pitch - target_pitch)
	
	# Skip processing if already at target values
	if cutoff_diff < 1.0 and pitch_diff < 0.001:
		return
	
	# Smoothly transition values
	if cutoff_diff >= 1.0:
		current_cutoff = lerp(current_cutoff, target_cutoff, delta * 4.0)
		
		# PERFORMANCE FIX: Cache bus index and effect reference
		if _cached_bus_idx == -2:
			_cached_bus_idx = AudioServer.get_bus_index("Music")
			if _cached_bus_idx != -1 and AudioServer.get_bus_effect_count(_cached_bus_idx) > 0:
				var effect = AudioServer.get_bus_effect(_cached_bus_idx, 0)
				if effect is AudioEffectLowPassFilter:
					_cached_effect = effect
		
		if _cached_effect:
			_cached_effect.cutoff_hz = current_cutoff
	
	if pitch_diff >= 0.001:
		current_pitch = lerp(current_pitch, target_pitch, delta * 2.0)
		if music_player:
			music_player.pitch_scale = current_pitch

func set_inside(inside: bool):
	is_inside = inside
	# PERFORMANCE FIX: Set target cutoff here instead of checking every frame
	if is_inside:
		target_cutoff = 20000.0
	else:
		target_cutoff = 1200.0

func play_music(stream: AudioStream):
	music_player.stream = stream
	music_player.play()

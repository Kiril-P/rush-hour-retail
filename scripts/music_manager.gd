extends Node

# Music Manager for dynamic supermarket atmosphere
# This script handles music playback and "muffling" when outside

var music_player: AudioStreamPlayer
var low_pass_filter: AudioEffectLowPassFilter

var is_inside: bool = true
var target_cutoff: float = 20000.0  # Default (no filter)
var current_cutoff: float = 20000.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create AudioStreamPlayer
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"
	
	# Setup Audio Bus
	var bus_idx = AudioServer.get_bus_count()
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, "Music")
	
	# Add LowPassFilter effect
	low_pass_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(bus_idx, low_pass_filter)
	
	print("MusicManager ready. System waiting for audio stream.")

func _process(delta):
	# Smoothly transition filter cutoff
	if is_inside:
		target_cutoff = 20000.0
	else:
		target_cutoff = 1200.0 # "Muffled" effect
	
	current_cutoff = lerp(current_cutoff, target_cutoff, delta * 4.0)
	
	# Update the effect in the AudioServer
	var bus_idx = AudioServer.get_bus_index("Music")
	var effect = AudioServer.get_bus_effect(bus_idx, 0)
	if effect is AudioEffectLowPassFilter:
		effect.cutoff_hz = current_cutoff

func set_inside(inside: bool):
	is_inside = inside
	if is_inside:
		print("Player is INSIDE - Music normal")
	else:
		print("Player is OUTSIDE - Music muffled")

func play_music(stream: AudioStream):
	music_player.stream = stream
	music_player.play()

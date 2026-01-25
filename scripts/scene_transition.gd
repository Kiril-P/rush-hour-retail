extends CanvasLayer

@onready var color_rect = $ColorRect

func fade_out(duration: float = 0.5):
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween.tween_property(color_rect, "color:a", 1.0, duration)

func fade_in(duration: float = 0.5):
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween.tween_property(color_rect, "color:a", 0.0, duration)

func change_scene(target_path: String):
	get_tree().paused = true
	await fade_out().finished
	get_tree().change_scene_to_file(target_path)
	get_tree().paused = false
	await get_tree().process_frame # Wait for new scene to load
	await fade_in().finished

func reload_scene():
	get_tree().paused = true
	await fade_out().finished
	get_tree().reload_current_scene()
	get_tree().paused = false
	await get_tree().process_frame
	await fade_in().finished

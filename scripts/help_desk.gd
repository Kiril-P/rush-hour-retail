extends StaticBody3D

## Help Desk Script - With 10s cooldown and visual feedback

@export var cooldown_time: float = 30.0
var current_cooldown: float = 0.0

func _process(delta):
	if current_cooldown > 0:
		current_cooldown -= delta

func interact():
	"""Called when player interacts with the help desk"""
	if current_cooldown > 0:
		_show_cooldown_feedback()
		return

	var help_desk_ui = get_tree().root.get_node_or_null("HelpDeskUI")
	if help_desk_ui:
		help_desk_ui.open()
		current_cooldown = cooldown_time
	else:
		# Fallback
		var ui_scene = load("res://objects/help_desk_ui.tscn")
		if ui_scene:
			var ui_inst = ui_scene.instantiate()
			get_tree().root.add_child(ui_inst)
			ui_inst.open()
			current_cooldown = cooldown_time

func _show_cooldown_feedback():
	# Error sound
	if GameManager:
		GameManager.play_sfx("res://assets/sfx/error.wav") # Reusing existing error sound
	
	# Red flash
	_flash_red()
	
	# Floating text if possible, or just let player controller handle it
	# The player controller updates the tooltip every frame, so we can just
	# rely on the tooltip showing the remaining time.

func _flash_red():
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.2)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)
	canvas.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(canvas.queue_free)

func get_cooldown_text() -> String:
	if current_cooldown <= 0:
		return "Press Left Click to Use"
	return "Cooldown: %d seconds remaining" % ceil(current_cooldown)

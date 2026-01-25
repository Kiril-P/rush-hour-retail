extends CanvasLayer

@onready var progress_bar = $Control/ProgressBar
@onready var status_label = $Control/StatusLabel
@onready var tip_label = $Control/TipLabel
@onready var control = $Control

func _ready():
	# Hide by default
	control.modulate.a = 0
	control.hide()
	
	# Connect to LoadingManager
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	if loading_manager:
		loading_manager.loading_started.connect(_on_loading_started)
		loading_manager.loading_progress.connect(_on_loading_progress)
		loading_manager.loading_finished.connect(_on_loading_finished)

func _on_loading_started():
	progress_bar.value = 0
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	if loading_manager:
		tip_label.text = "Tip: " + loading_manager.get_random_tip()
	control.show()
	
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

var _last_progress_value: float = -1.0

func _on_loading_progress(current, total, message):
	var target_value = (float(current) / total) * 100
	
	# Only update if change is significant (>1%)
	if abs(target_value - _last_progress_value) < 1.0:
		return
		
	_last_progress_value = target_value
	
	# Update progress bar directly for speed, or with a very short tween
	progress_bar.value = target_value
	
	status_label.text = message
	
	# Occasionally change tip (less frequent)
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	if randf() < 0.05 and loading_manager:
		tip_label.text = "Tip: " + loading_manager.get_random_tip()

func _on_loading_finished():
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.5)
	await tween.finished
	control.hide()

extends Control

@onready var title_label = %TitleLabel
@onready var percent_label = %PercentLabel
@onready var message_label = %MessageLabel
@onready var progress_bar = %ProgressBar
@onready var money_label = %MoneyLabel
@onready var items_label = %ItemsLabel
@onready var lists_label = %ListsLabel
@onready var high_score_label = %HighScoreLabel
@onready var stats_container = %StatsContainer
@onready var buttons_container = %ButtonsContainer
@onready var new_record_label = %NewRecordLabel

func _ready():
	# Initially hide everything for animation
	modulate.a = 0
	title_label.modulate.a = 0
	percent_label.modulate.a = 0
	message_label.modulate.a = 0
	progress_bar.value = 0
	stats_container.modulate.a = 0
	buttons_container.modulate.a = 0
	new_record_label.visible = false
	new_record_label.scale = Vector2.ZERO

	GameManager.game_over.connect(_on_game_over)

func _on_game_over():
	# Unlock mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Pause game
	get_tree().paused = true
	
	visible = true
	_setup_stats()
	_animate_in()

func _setup_stats():
	var score = GameManager.total_score
	var target = GameManager.target_score
	var percent = min(100.0, (float(score) / float(target)) * 100.0)
	
	percent_label.text = "%d%%" % percent
	message_label.text = GameManager.get_performance_message(percent)
	money_label.text = "Money Collected: $%d / $%d" % [score, target]
	items_label.text = "Items Found: %d" % GameManager.total_items_collected
	lists_label.text = "Lists Completed: %d" % GameManager.total_lists_completed
	
	var is_new_record = score >= GameManager.high_score and score > 0
	high_score_label.text = "Personal Best: $%d" % GameManager.high_score
	new_record_label.visible = is_new_record

func _animate_in():
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Fade in background
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# 2. Fade in title
	tween.tween_property(title_label, "modulate:a", 1.0, 0.3)
	
	# 3. Animate percentage and progress bar
	var target_percent = min(100.0, (float(GameManager.total_score) / float(GameManager.target_score)) * 100.0)
	tween.parallel().tween_property(progress_bar, "value", target_percent, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(percent_label, "modulate:a", 1.0, 0.5)
	
	# 4. Message fade in
	tween.tween_property(message_label, "modulate:a", 1.0, 0.4)
	
	# 5. New Record Pop
	if new_record_label.visible:
		tween.tween_property(new_record_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 6. Stats list fade in
	tween.tween_property(stats_container, "modulate:a", 1.0, 0.5)
	
	# 7. Buttons fade in
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.3)

func _on_play_again_pressed():
	get_tree().paused = false
	if get_tree().root.has_node("SceneTransition"):
		get_tree().root.get_node("SceneTransition").reload_scene()
	else:
		get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().paused = false
	if get_tree().root.has_node("SceneTransition"):
		get_tree().root.get_node("SceneTransition").change_scene("res://main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://main_menu.tscn")

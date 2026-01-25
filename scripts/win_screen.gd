extends Control

@onready var title_label = %TitleLabel
@onready var stars_container = %StarsContainer
@onready var star_1 = %Star1
@onready var star_2 = %Star2
@onready var star_3 = %Star3
@onready var message_label = %MessageLabel
@onready var money_label = %MoneyLabel
@onready var items_label = %ItemsLabel
@onready var lists_label = %ListsLabel
@onready var time_label = %TimeLabel
@onready var high_score_label = %HighScoreLabel
@onready var stats_container = %StatsContainer
@onready var buttons_container = %ButtonsContainer
@onready var new_record_label = %NewRecordLabel
@onready var confetti_particles = %ConfettiParticles

var star_gold = Color(1.0, 0.85, 0.2)
var star_empty = Color(0.2, 0.2, 0.2, 0.5)

func _ready():
	# Initially hide everything for animation
	modulate.a = 0
	title_label.modulate.a = 0
	star_1.modulate.a = 0
	star_2.modulate.a = 0
	star_3.modulate.a = 0
	message_label.modulate.a = 0
	stats_container.modulate.a = 0
	buttons_container.modulate.a = 0
	new_record_label.visible = false
	new_record_label.scale = Vector2.ZERO
	
	if GameManager:
		GameManager.game_won.connect(_on_game_won)

func _on_game_won():
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
	var time_left = GameManager.time_remaining
	
	money_label.text = "Total Money: $%d" % score
	items_label.text = "Items Collected: %d" % GameManager.total_items_collected
	lists_label.text = "Lists Completed: %d" % GameManager.total_lists_completed
	time_label.text = "Time Remaining: %ds" % int(time_left)
	
	# Star Rating Logic
	# 1 Star: Just for winning (always true if we are here)
	# 2 Stars: 30+ seconds remaining
	# 3 Stars: 150% of target money collected
	
	var stars = 1
	if time_left >= 30.0:
		stars += 1
	if score >= target * 1.5:
		stars += 1
		
	# Update star visuals (initially gray, will animate to gold)
	star_1.modulate = star_empty
	star_2.modulate = star_empty
	star_3.modulate = star_empty
	
	# Performance message
	if stars == 3:
		message_label.text = "ABSOLUTE LEGEND! You're the master of the market!"
	elif stars == 2:
		message_label.text = "FANTASTIC! Speed and efficiency at its best!"
	else:
		message_label.text = "VICTORY! You got everything on the list!"

	var is_new_record = score >= GameManager.high_score and score > 0
	high_score_label.text = "Personal Best: $%d" % GameManager.high_score
	new_record_label.visible = is_new_record

func _animate_in():
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Fade in background and confetti
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	if confetti_particles:
		confetti_particles.emitting = true
	
	# 2. Slide/Fade in title
	title_label.position.y -= 50
	tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(title_label, "position:y", title_label.position.y + 50, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Stars animation with "Ding" sound placeholder
	var time_left = GameManager.time_remaining
	var score = GameManager.total_score
	var target = GameManager.target_score
	
	# Star 1
	tween.tween_interval(0.2)
	tween.tween_property(star_1, "modulate", star_gold, 0.3)
	tween.parallel().tween_property(star_1, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(star_1, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_property(star_1, "modulate:a", 1.0, 0.1)
	
	# Star 2
	if time_left >= 30.0:
		tween.tween_interval(0.2)
		tween.tween_property(star_2, "modulate", star_gold, 0.3)
		tween.parallel().tween_property(star_2, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(star_2, "scale", Vector2(1.0, 1.0), 0.1)
		tween.parallel().tween_property(star_2, "modulate:a", 1.0, 0.1)
	else:
		tween.tween_property(star_2, "modulate:a", 0.3, 0.2) # Dim show
		
	# Star 3
	if score >= target * 1.5:
		tween.tween_interval(0.2)
		tween.tween_property(star_3, "modulate", star_gold, 0.3)
		tween.parallel().tween_property(star_3, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(star_3, "scale", Vector2(1.0, 1.0), 0.1)
		tween.parallel().tween_property(star_3, "modulate:a", 1.0, 0.1)
	else:
		tween.tween_property(star_3, "modulate:a", 0.3, 0.2) # Dim show

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

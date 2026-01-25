extends CanvasLayer

@onready var item_list_container = $Control/Panel/VBox/ScrollContainer/ItemList
@onready var close_button = $Control/Panel/VBox/CloseButton
@onready var feedback_label = $Control/Panel/VBox/FeedbackLabel
@onready var control = $Control

var marker_scene = preload("res://objects/item_marker.tscn")
var current_marker = null

func _ready():
	control.hide()
	close_button.pressed.connect(close)
	
	# Connect to GameManager signal if shopping list changes
	if GameManager.has_signal("list_generated"):
		GameManager.list_generated.connect(refresh_list)
	
	# Cleanup on game over/win
	GameManager.game_over.connect(clear_marker)
	GameManager.game_won.connect(clear_marker)

func open():
	refresh_list()
	control.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func close():
	control.hide()
	if not get_tree().root.get_node_or_null("PauseMenu") or not get_tree().root.get_node("PauseMenu").visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _input(event):
	if control.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func refresh_list():
	# Clear existing
	for child in item_list_container.get_children():
		child.queue_free()
	
	feedback_label.text = ""
	
	var shopping_list = GameManager.get_current_list()
	if shopping_list.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Your shopping list is empty!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list_container.add_child(empty_label)
		return
	
	# Create a button for each item
	for item_name in shopping_list:
		var btn = Button.new()
		btn.text = item_name
		btn.custom_minimum_size.y = 40
		btn.pressed.connect(_on_item_selected.bind(item_name))
		item_list_container.add_child(btn)

func _on_item_selected(item_name: String):
	# Cleanup previous marker before creating new one
	clear_marker()
	
	# Find item in world
	var target_item = _find_item_in_world(item_name)
	
	if target_item:
		current_marker = marker_scene.instantiate()
		get_tree().current_scene.add_child(current_marker)
		current_marker.set_target(target_item)
		close()
	else:
		feedback_label.text = "Error: " + item_name + " not found in store!"

func clear_marker():
	"""Properly removes the current active marker from the world"""
	if is_instance_valid(current_marker):
		current_marker.queue_free()
		current_marker = null

func _find_item_in_world(item_name: String) -> Node3D:
	var items = get_tree().get_nodes_in_group("item")
	var player = get_tree().get_first_node_in_group("player")
	var player_pos = player.global_position if player else Vector3.ZERO
	
	var best_item = null
	var min_dist = INF
	
	for item in items:
		if not is_instance_valid(item) or not item.is_inside_tree():
			continue
			
		# Check item name
		var current_name = ""
		if item.has_method("get_product_name"):
			current_name = item.get_product_name()
		elif "item_name" in item:
			current_name = item.item_name
		
		if current_name == item_name:
			# Only items on shelves (not in cart/held)
			if item.get_parent() and item.get_parent().name == "ItemStorageArea":
				continue
				
			var dist = player_pos.distance_to(item.global_position)
			if dist < min_dist:
				min_dist = dist
				best_item = item
				
	return best_item

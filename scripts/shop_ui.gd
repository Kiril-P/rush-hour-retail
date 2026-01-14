extends Control

@onready var item_grid = $Panel/ScrollContainer/MarginContainer/ItemGrid
var item_button_scene = preload("res://objects/ui/shop_item_button.tscn")

func _ready():
	# Hide the shop initially
	visible = false
	
	# AUTOMATICALLY FIND AND CONNECT CLOSE BUTTON
	# This looks for a node named "CloseButton" or "close_button"
	var close_btn = find_child("CloseButton", true, false)
	if not close_btn:
		close_btn = find_child("close_button", true, false)
	
	if close_btn:
		close_btn.pressed.connect(_on_close_button_pressed)
		print("ShopUI: Connected close button: ", close_btn.name)
	else:
		print("ShopUI ERROR: Could not find close_button!")
	
	refresh_shop()

func refresh_shop():
	# Clear any old buttons
	for child in item_grid.get_children():
		child.queue_free()
	
	# Create a button for every product in the GameManager
	for product in GameManager.available_products:
		var btn = item_button_scene.instantiate()
		item_grid.add_child(btn)
		btn.setup(product)
	
func toggle():
	visible = !visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Move the ShopUI to the front of the CanvasLayer
		get_parent().move_child(self, get_parent().get_child_count() - 1)
		refresh_shop() 
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_close_button_pressed():
	toggle()

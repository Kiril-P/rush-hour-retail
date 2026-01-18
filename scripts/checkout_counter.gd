extends StaticBody3D

# Position where popup text appears (above the cash register)
@export var popup_spawn_offset: Vector3 = Vector3(0, -20, 0)

func interact():
	"""Called when player clicks on the checkout counter"""
	
	# Find the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Get the interaction component from player
	var interaction = player.get_node_or_null("InteractionComponent")
	if not interaction:
		return
	
	# Check if player is holding something
	if not interaction.picked_object:
		return
	
	# Get the held item
	var held_item = interaction.picked_object
	
	# Check if it has product_data
	if not "product_data" in held_item:
		return
	
	var product = held_item.product_data
	if not product:
		return
	
	# Check if this item is on the shopping list
	if GameManager.check_item_correct(product):
		_handle_correct_item(product, held_item, interaction)
	else:
		_handle_wrong_item(product, held_item)

func _handle_correct_item(product: ProductData, item: Node3D, interaction):
	"""Item is on the shopping list - accept it!"""
	print("✓ CORRECT ITEM: ", product.item_name)
	
	# Tell GameManager we collected a correct item
	GameManager.collect_correct_item(product)
	
	# Destroy the item
	item.queue_free()
	
	# Clear player's held object
	interaction.picked_object = null
	
	# Visual feedback
	_show_time_bonus_popup(2.0)  # Show +2s
	_flash_screen(Color(0.2, 1.0, 0.3, 0.3))  # Green flash
	
	print("→ Items remaining: ", GameManager.current_shopping_list.size())

func _handle_wrong_item(product: ProductData, item: Node3D):
	"""Item is NOT on the shopping list - reject it!"""
	print("✗ WRONG ITEM: ", product.item_name, " is not on your list!")
	
	# Tell GameManager (resets combo, optional penalty)
	GameManager.collect_wrong_item()
	
	# Visual feedback - red flash
	_flash_screen(Color(1.0, 0.2, 0.2, 0.4))  # Red flash

func _show_time_bonus_popup(seconds: float):
	"""Show floating +Xs text above cash register"""
	var popup = Label3D.new()
	popup.text = "+%.0fs" % seconds
	popup.font_size = 96
	popup.modulate = Color(0.3, 1.0, 0.4)  # Bright green
	popup.outline_size = 8
	popup.outline_modulate = Color.BLACK
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Position above cash register
	get_tree().current_scene.add_child(popup)
	popup.global_position = global_position + popup_spawn_offset
	
	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y + 1.5, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)

func _flash_screen(color: Color):
	"""Flash the screen with a color overlay"""
	# Find or create screen flash overlay
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var camera = player.get_node_or_null("Camera3D")
	if not camera:
		return
	
	# Look for existing flash overlay
	var flash = camera.get_node_or_null("ScreenFlash")
	
	if not flash:
		# Create the flash overlay if it doesn't exist
		flash = ColorRect.new()
		flash.name = "ScreenFlash"
		flash.color = Color.TRANSPARENT
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Position it to cover whole screen
		flash.anchor_left = 0
		flash.anchor_top = 0
		flash.anchor_right = 1
		flash.anchor_bottom = 1
		
		camera.add_child(flash)
	
	# Flash animation
	flash.color = color
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5)

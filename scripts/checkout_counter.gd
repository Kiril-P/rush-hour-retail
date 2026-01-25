extends StaticBody3D

## Checkout Counter - Subtle Smooth Flash!

@onready var game_manager = get_node("/root/GameManager")
@onready var detection_area: Area3D = null

func _ready():
	
	# Add to group so interaction system can find us
	add_to_group("checkout")
	

func _on_body_entered(body):
	"""Handles items THROWN into the checkout area"""
	if body.is_in_group("pickable"):
		_scan_item(body)

func interact(item_held = null):
	"""Called when player CLICKS the checkout counter"""
	
	# If player is holding an item, scan it!
	if item_held:
		var result = _scan_item(item_held)
		return result  # Return true only if correct item!
	else:
		_flash_screen_smooth(Color.GRAY, 0.15)
		return false

func _scan_item(item) -> bool:
	"""Scans an item - returns true if correct, false if wrong"""
	# Get item name directly from the item
	var item_name = ""
	
	if item.has_method("get_item_name"):
		item_name = item.get_item_name()
	elif "item_name" in item:
		item_name = item.item_name
	else:
		_flash_screen_smooth(Color.GRAY, 0.15)
		return false
	
	# Check with game manager FIRST
	if game_manager.check_item_correct(item_name):
		
		# SUBTLE GREEN FLASH - Item is correct!
		_flash_screen_smooth(Color.GREEN, 0.25)
		
		# Tell game manager (adds score, updates list, etc.)
		game_manager.collect_correct_item(item_name)
		
		# Remove the item from the world
		item.queue_free()
		
		return true  # Item was correct!
		
	else:
		
		# SUBTLE RED FLASH - Item is wrong!
		_flash_screen_smooth(Color.RED, 0.35)
		
		# Tell game manager (penalty, reset combo)
		game_manager.collect_wrong_item(item_name)
		
		# DON'T remove item! Return false so interaction component keeps it
		return false  # Item was wrong!

func _flash_screen_smooth(flash_color: Color, max_intensity: float = 0.3):
	"""Creates a smooth, subtle screen flash with fade in and fade out"""
	# Create flash overlay
	var flash = ColorRect.new()
	flash.color = flash_color
	flash.color.a = 0.0  # Start transparent
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the whole screen
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to HUD layer
	var canvas = CanvasLayer.new()
	canvas.layer = 100  # On top of everything
	get_tree().root.add_child(canvas)
	canvas.add_child(flash)
	
	# Smooth tween with fade IN then fade OUT
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade IN quickly (0.1s)
	tween.tween_property(flash, "color:a", max_intensity, 0.1)
	
	# Hold briefly (0.05s)
	tween.tween_interval(0.05)
	
	# Fade OUT smoothly (0.4s)
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	
	# Remove after animation
	tween.tween_callback(func():
		canvas.queue_free()
	)

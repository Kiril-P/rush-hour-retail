extends StaticBody3D

## Checkout Counter - With Feedback!
## Green flash for correct items, red flash for wrong items

@onready var game_manager = get_node("/root/GameManager")
@onready var detection_area: Area3D = null

# Screen flash overlay
var screen_flash: ColorRect = null

func _ready():
	print("Checkout Counter Ready - With Feedback System")
	
	# Add to group so interaction system can find us
	add_to_group("checkout")
	
	# Find the Area3D child for detection (throwing items into it)
	for child in get_children():
		if child is Area3D:
			detection_area = child
			detection_area.body_entered.connect(_on_body_entered)
			print("✓ Found detection area: ", child.name)
			break
	
	if not detection_area:
		push_warning("Checkout counter needs an Area3D child for item detection!")
	
	# Create screen flash overlay
	_create_screen_flash()

func _create_screen_flash():
	"""Creates a full-screen overlay for feedback flashes"""
	# Get the viewport
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Create ColorRect for flash
	screen_flash = ColorRect.new()
	screen_flash.name = "ScreenFlash"
	screen_flash.color = Color(0, 0, 0, 0)  # Transparent by default
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	
	# Make it cover full screen
	screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_flash.z_index = 100  # On top of everything
	
	# Add to viewport's canvas layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.name = "FlashLayer"
	canvas_layer.add_child(screen_flash)
	
	# Add to tree
	viewport.add_child(canvas_layer)
	
	print("✓ Screen flash overlay created")

func _on_body_entered(body):
	"""Handles items THROWN into the checkout area"""
	# Check if it's an item
	if body.is_in_group("pickable"):
		print("📦 Item thrown into checkout area!")
		_scan_item(body)

func interact(item_held = null):
	"""Called when player CLICKS the checkout counter"""
	print("\n🖱️ Player clicked checkout counter!")
	
	# If player is holding an item, scan it!
	if item_held:
		print("📦 Player is holding an item!")
		_scan_item(item_held)
		return true
	else:
		print("⚠️ Player clicked checkout but not holding an item!")
		_flash_screen(Color.GRAY, 0.2, 0.3)  # Gray flash for empty hands
		return false

func _scan_item(item):
	"""Scans an item - checks if correct FIRST!"""
	# Get item name directly from the item
	var item_name = ""
	
	if item.has_method("get_item_name"):
		item_name = item.get_item_name()
	elif "item_name" in item:
		item_name = item.item_name
	else:
		print("⚠️ Item has no name!")
		_flash_screen(Color.GRAY, 0.2, 0.3)
		return
	
	print("\n🛒 SCANNING: ", item_name)
	
	# Check with game manager FIRST
	if game_manager.check_item_correct(item_name):
		print("✅ CORRECT ITEM!")
		
		# GREEN FLASH - Item is correct!
		_flash_screen(Color.GREEN, 0.3, 0.5)
		
		# Tell game manager (adds score, updates list, etc.)
		game_manager.collect_correct_item(item_name)
		
		# Remove the item from the world
		item.queue_free()
		
	else:
		print("❌ WRONG ITEM!")
		
		# RED FLASH - Item is wrong!
		_flash_screen(Color.RED, 0.5, 0.7)
		
		# Tell game manager (penalty, reset combo)
		game_manager.collect_wrong_item(item_name)
		
		# DON'T remove item! Player keeps it
		# They can drop it or bring another item

func _flash_screen(color: Color, intensity: float = 0.5, duration: float = 0.5):
	"""Flash the screen with a color"""
	if not screen_flash:
		print("⚠️ Screen flash not available!")
		return
	
	# Set flash color with intensity as alpha
	var flash_color = color
	flash_color.a = intensity
	screen_flash.color = flash_color
	
	# Create tween to fade out
	var tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, duration)

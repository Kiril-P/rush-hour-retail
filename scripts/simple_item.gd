extends RigidBody3D

## Simple Item Script - OPTIMIZED FOR PERFORMANCE!
## Just stores item name and price directly

@export var item_name: String = "Unknown Item"
@export var price: float = 1.0
@export var category: String = "General"

var is_on_shelf: bool = true
var was_picked_up: bool = false

func _ready():
	# Make pickable
	add_to_group("pickable")
	add_to_group("item")  # For game manager scanning
	
	# OPTIMIZED COLLISION SETTINGS
	collision_layer = 1  # Keep on Layer 1 so player raycast can see them
	collision_mask = 1  # Only collide with world/floor
	
	# CRITICAL PERFORMANCE SETTINGS
	contact_monitor = false  # Disable expensive contact monitoring
	max_contacts_reported = 0  # No contact reports needed
	continuous_cd = false  # Disable continuous collision detection (HUGE performance gain!)
	
	# AGGRESSIVE PHYSICS OPTIMIZATION
	can_sleep = true
	freeze = true  # Start frozen on shelf
	freeze_mode = FREEZE_MODE_STATIC
	
	# Damping for when item falls
	linear_damp = 3.0
	angular_damp = 3.0
	
	# Lower gravity slightly for better shelf behavior
	gravity_scale = 1.0
	
	if item_name == "Unknown Item":
		push_warning("Item ", name, " needs item_name set in Inspector!")

func pick_up(interaction):
	"""Called when player picks up this item"""
	if not was_picked_up:
		was_picked_up = true
		is_on_shelf = false
		
		# Unfreeze for physics
		freeze = false
		freeze_mode = FREEZE_MODE_KINEMATIC
		
		# Re-enable necessary collision
		contact_monitor = false  # Keep disabled for performance
		continuous_cd = false  # Keep disabled

func drop_item():
	"""Called when item is dropped"""
	freeze = false
	freeze_mode = FREEZE_MODE_KINEMATIC
	
	# Item will sleep automatically after settling
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func get_item_name() -> String:
	return item_name

func get_product_name() -> String:
	"""For game manager compatibility"""
	return item_name

func get_price() -> float:
	return price

func get_category() -> String:
	return category

func get_is_on_shelf() -> bool:
	"""Used by performance manager for culling"""
	return is_on_shelf and not was_picked_up

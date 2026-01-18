extends RigidBody3D

# This script makes an item pickable and scannable at checkout
# Attach this to any RigidBody3D item you want the player to pick up

@export var product_data: ProductData

func _ready():
	# Make sure the item is pickable
	add_to_group("pickable")
	
	# Collision settings - IMPORTANT for raycast detection
	collision_layer = 1  # Default layer
	collision_mask = 1
	
	# Physics settings
	freeze = false
	can_sleep = true
	
	if not product_data:
		push_warning("Item ", name, " has no ProductData assigned!")

func pick_up(interaction):
	"""Called by the player's interaction system when picking up this item"""
	# The interaction component handles the actual pickup logic
	# This function just needs to exist so the system knows this is pickable
	print("Picked up: ", product_data.item_name if product_data else name)

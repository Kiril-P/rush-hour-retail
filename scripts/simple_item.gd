extends RigidBody3D

## Simple Item Script - NO ProductData needed!
## Just stores item name and price directly

@export var item_name: String = "Unknown Item"
@export var price: float = 1.0
@export var category: String = "General"

func _ready():
	# Make pickable
	add_to_group("pickable")
	
	# Collision settings
	collision_layer = 1
	collision_mask = 1
	
	# Physics settings
	freeze = false
	can_sleep = true
	
	if item_name == "Unknown Item":
		push_warning("Item ", name, " needs item_name set in Inspector!")

func pick_up(interaction):
	"""Called when player picks up this item"""
	print("Picked up: ", item_name)

func get_item_name() -> String:
	return item_name

func get_price() -> float:
	return price

func get_category() -> String:
	return category

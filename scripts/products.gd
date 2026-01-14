extends RigidBody3D

# REMOVED @export to avoid circular dependency loop
var product_data: ProductData 

var player

# Helper properties to make accessing data easier
var product_name: String:
	get: return product_data.item_name if product_data else "Unknown"

var sell_price: float:
	get: return product_data.sell_price if product_data else 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	pass

func pick_up(new_parent):
	reparent(new_parent)

extends RigidBody3D

@export var product_data: ProductData # THE ONLY SOURCE OF TRUTH NOW

@onready var visual_node = %item_ingredient
@onready var outline_mesh = %outline_mesh

var selected = false
var outline_width = 0.05
var player

# Helper properties to make accessing data easier
var product_name: String:
	get: return product_data.item_name if product_data else "Unknown"

var sell_price: float:
	get: return product_data.sell_price if product_data else 0.0

func _ready():
	if outline_mesh:
		outline_mesh.visible = false
		
	player = get_tree().get_first_node_in_group("player")
	if player:
		if player.is_connected("interact_object", _set_selected):
			player.disconnect("interact_object", _set_selected)
		player.connect("interact_object", _set_selected)

func _process(_delta: float) -> void:
	var is_carried = get_parent().name == "InteractionComponent"
	if outline_mesh:
		outline_mesh.visible = selected and not is_carried
	
	if visual_node:
		if selected and not is_carried:
			visual_node.position.y = outline_width
		else: 
			visual_node.position.y = 0

func pick_up(new_parent):
	reparent(new_parent)
	selected = false

func _set_selected(object):
	if object == self or (object is Node and is_ancestor_of(object)):
		selected = true
	else:
		selected = false

extends RigidBody3D

@export var product_data: ProductData 
var max_capacity: int = 10 

var contents: Array[PackedScene] = []
var player

func _ready():
	player = get_tree().get_first_node_in_group("player")

	# Setup capacity and initial fill
	if product_data:
		max_capacity = product_data.amount_per_box
		if contents.is_empty():
			for i in product_data.amount_per_box:
				contents.append(product_data.item_scene)
	
	await get_tree().process_frame
	update_ui()

func _process(_delta: float) -> void:
	pass

func pick_up(new_parent):
	reparent(new_parent)

func _set_selected(object):
	pass

# --- BOX LOGIC ---

func take_item() -> PackedScene:
	if contents.is_empty():
		return null
	var item = contents.pop_back()
	update_ui()
	return item

func can_add_item(item_to_add) -> bool:
	if contents.size() >= max_capacity: 
		print("Box: Full!")
		return false
	
	# IMPORTANT FIX: Check the resource directly on the node
	if item_to_add.get("product_data") == product_data:
		return true
	
	# Extra debug check
	var item_data = item_to_add.get("product_data")
	print("Box DEBUG: My Data: ", product_data.resource_path if product_data else "null")
	print("Box DEBUG: Item Data: ", item_data.resource_path if item_data else "null")
	
	print("Box: Wrong item type!")
	return false

func add_item():
	if product_data:
		contents.append(product_data.item_scene)
		update_ui()

func is_empty() -> bool:
	return contents.is_empty()

func update_ui():
	var name_text = ""
	var count_text = ""
	if product_data:
		name_text = product_data.item_name
		count_text = str(contents.size()) + "/" + str(max_capacity)
	
	var ui_nodes = get_tree().get_nodes_in_group("box_ui")
	for node in ui_nodes:
		if is_ancestor_of(node):
			if node is Label3D:
				if "count" in node.name.to_lower():
					node.text = count_text
				else:
					node.text = name_text
				node.pixel_size = 0.001
				
			if node is Sprite3D and product_data and product_data.icon:
				node.texture = product_data.icon
				var tex = product_data.icon
				var max_dim = max(tex.get_width(), tex.get_height())
				node.pixel_size = 0.2 / max_dim 
				node.shaded = true

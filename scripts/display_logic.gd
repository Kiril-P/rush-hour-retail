extends StaticBody3D
class_name store_object

@onready var objects: Node3D = get_node_or_null("Objects")
@onready var object_places: Node3D = get_node_or_null("ObjectPlaces")

var furniture_data: FurnitureData

var supported_categories: Array[ProductData.Category]:
	get:
		if furniture_data:
			return furniture_data.supported_categories
		# Fallback for standard shelves if auto-linking fails
		return [ProductData.Category.SHELF]

var itemsPlaced = []
var is_placed = true 

func _ready() -> void:
	# AUTO-ASSIGN DATA FOR PRE-PLACED ITEMS
	if not furniture_data:
		_find_my_data()

	if not object_places:
		return
		
	# Add to group via code just in case you forgot in the editor
	add_to_group("shelf")
	for i in object_places.get_child_count():
		itemsPlaced.append(null)

func _find_my_data():
	var my_path = scene_file_path
	if my_path.begins_with("uid://"):
		var res = load(my_path)
		if res:
			my_path = res.resource_path
	
	var resource_dir = "res://objects/furniture/resources/"
	if not DirAccess.dir_exists_absolute(resource_dir):
		return

	var dir = DirAccess.open(resource_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var data = load(resource_dir + file_name)
				if data is FurnitureData and data.scene:
					var data_scene_path = data.scene.resource_path
					if data_scene_path.begins_with("uid://"):
						var s_res = load(data_scene_path)
						if s_res:
							data_scene_path = s_res.resource_path
					
					if data_scene_path == my_path:
						furniture_data = data
						print("DisplayLogic: Auto-linked ", name, " to ", file_name, " (", furniture_data.supported_categories, ")")
						break
			file_name = dir.get_next()

func has_space() -> bool:
	if not is_placed or not object_places: return false
	return itemsPlaced.has(null)

func can_accept_item(object) -> bool:
	if not object.has_method("get") and not "category" in object:
		return false
	
	var item_category = object.category if "category" in object else -1
	if item_category == -1 and "product_data" in object and object.product_data:
		item_category = object.product_data.category
		
	return item_category in supported_categories

func get_item_count() -> int:
	if not object_places: return 0
	var count = 0
	for item in itemsPlaced:
		if item != null:
			count += 1
	return count

func take_specific_item(data: ProductData) -> Node:
	if not object_places: return null
	for i in range(itemsPlaced.size()):
		var item = itemsPlaced[i]
		if item != null and "product_data" in item and item.product_data == data:
			item.reparent(get_tree().current_scene)
			if item is CollisionObject3D:
				item.collision_layer = 3
			return item
	return null

func take_random_item() -> Node:
	if not object_places: return null
	var stocked_indices = []
	for i in range(itemsPlaced.size()):
		if itemsPlaced[i] != null:
			stocked_indices.append(i)
	
	if stocked_indices.is_empty():
		return null
		
	var random_index = stocked_indices.pick_random()
	var item = itemsPlaced[random_index]
	
	# The _on_objects_child_exiting_tree will handle nulling the array
	item.reparent(get_tree().current_scene) 
	if item is CollisionObject3D:
		item.collision_layer = 1
	return item
		
func add_object(object):
	if not object_places or not objects: return false
	if not has_space(): return false
	if not can_accept_item(object): return false
	
	# Move to the shelf's node
	object.reparent(objects)
	
	# Lock physics and change collision layer to 2 (Items)
	# This allows player raycast (on mask 1) to go through them
	if object is CollisionObject3D:
		object.collision_layer = 2 
		
	if object is RigidBody3D:
		object.freeze = true
		object.linear_velocity = Vector3.ZERO
		object.angular_velocity = Vector3.ZERO
	
	for i in len(itemsPlaced):
		if itemsPlaced[i] == null:
			object.global_position = object_places.get_children()[i].global_position
			object.rotation_degrees = Vector3(0, 90, 0)
			itemsPlaced[i] = object
			return true

	return false
	
func _on_objects_child_exiting_tree(node: Node) -> void:
	var index = itemsPlaced.find(node)
	if index != -1:
		itemsPlaced[index] = null

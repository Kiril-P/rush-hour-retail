extends StaticBody3D
class_name store_object

@onready var objects: Node3D = $Objects
@onready var object_places: Node3D = $ObjectPlaces

var itemsPlaced = []
var is_placed = true 

func _ready() -> void:
	# Add to group via code just in case you forgot in the editor
	add_to_group("shelf")
	for i in object_places.get_child_count():
		itemsPlaced.append(null)

func has_space() -> bool:
	if not is_placed: return false
	return itemsPlaced.has(null)

func get_item_count() -> int:
	var count = 0
	for item in itemsPlaced:
		if item != null:
			count += 1
	return count

func take_specific_item(data: ProductData) -> Node:
	for i in range(itemsPlaced.size()):
		var item = itemsPlaced[i]
		if item != null and "product_data" in item and item.product_data == data:
			item.reparent(get_tree().current_scene)
			if item is CollisionObject3D:
				item.collision_layer = 3
			return item
	return null

func take_random_item() -> Node:
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
	if not has_space(): return false
	
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

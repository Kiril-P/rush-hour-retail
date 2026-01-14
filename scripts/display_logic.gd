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
		
func add_object(object):
	if not has_space(): return false
	
	# Move to the shelf's node
	object.reparent(objects)
	
	# Lock physics
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

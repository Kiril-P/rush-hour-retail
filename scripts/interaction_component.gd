extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D # <--- Change this
@export var throw_force: float = 8.0 

var picked_object = null
var player_node: CharacterBody3D

func _ready():
	player_node = get_parent()
	# Check if we forgot to assign it in the Inspector
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned in the Inspector!")

func _process(_delta):
	if picked_object:
		picked_object.global_transform = carry_marker.global_transform
		
		# Now we use the variable instead of the % path
		if ray_cast_3d.is_colliding() and ray_cast_3d.get_collider() == picked_object:
			ray_cast_3d.add_exception(picked_object)

func handle_interaction(collider, hold_duration):
	# If we are holding something...
	if picked_object:
		# 1. Use the 'collider' passed from the Player's RayCast
		var shelf = _find_shelf(collider)
		
		if shelf:
			print("RayCast hit shelf: ", shelf.name)
			_place_on_shelf(shelf)
			return # Stop here if we placed it
			
		# 2. If the RayCast didn't hit a shelf, drop or throw
		if hold_duration > 0.25:
			throw_object()
		else:
			drop_object()
			
	# If we aren't holding anything, try to pick up
	elif collider and collider.has_method("pick_up"):
		pick_up_object(collider)
# Helper function to climb the tree and find the shelf root
func _find_shelf(node):
	var current = node
	while current != null:
		# Check if THIS specific node has the script
		if current is store_object or current.has_method("add_object"):
			return current
		current = current.get_parent()
	return null

func _place_on_shelf(shelf):
	var item = picked_object
	
	# Clean up exceptions
	ray_cast_3d.remove_exception(item) 
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D:
		item.freeze = false
		item.reparent(get_tree().current_scene)
	
	if shelf.add_object(item):
		picked_object = null
	else:
		pick_up_object(item)

func pick_up_object(object):
	picked_object = object
	if picked_object is RigidBody3D:
		picked_object.freeze = true
		player_node.add_collision_exception_with(picked_object)
	
	picked_object.pick_up(self)
	picked_object.global_transform = carry_marker.global_transform

func drop_object():
	if not picked_object: return
	var item = picked_object
	
	ray_cast_3d.remove_exception(item) # Clean up
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D: item.freeze = false
	item.reparent(get_tree().current_scene)
	picked_object = null

func throw_object():
	if not picked_object: return
	var item = picked_object
	
	ray_cast_3d.remove_exception(item) # Clean up
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D:
		item.freeze = false
		var camera = get_viewport().get_camera_3d()
		item.reparent(get_tree().current_scene)
		item.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	picked_object = null

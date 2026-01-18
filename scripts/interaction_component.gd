extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D 
@export var throw_force: float = 8.0 

var picked_object = null
var player_node: CharacterBody3D

func _ready():
	player_node = get_parent()
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned in the Inspector!")

func _process(delta):
	# Handle held object position
	if picked_object:
		picked_object.global_transform = carry_marker.global_transform
		if ray_cast_3d.is_colliding() and ray_cast_3d.get_collider() == picked_object:
			ray_cast_3d.add_exception(picked_object)

func handle_interaction(collider, hold_duration, is_secondary: bool = false):
	# If holding an item
	if picked_object:
		if is_secondary:
			# RIGHT CLICK: Drop/Throw
			if hold_duration > 0.25:
				throw_object()
			else:
				drop_object()
		else:
			# LEFT CLICK while holding item
			print("\n=== LEFT CLICK WHILE HOLDING ITEM ===")
			print("Held item: ", picked_object.name if picked_object else "None")
			print("Clicked on: ", collider.name if collider else "Nothing")
			
			# FIXED: Check collider AND parent nodes for interact method
			var interact_node = _find_interactable(collider)
			
			if interact_node:
				print("✓ Found interact() on: ", interact_node.name)
				interact_node.interact()
			else:
				print("✗ No interact() method found")
			print("===================================\n")
	
	# If not holding anything
	elif collider:
		if not is_secondary:
			# LEFT CLICK: Pick up items
			if collider.has_method("pick_up"):
				print("Picking up: ", collider.name)
				pick_up_object(collider)
			# Or interact with objects
			else:
				var interact_node = _find_interactable(collider)
				if interact_node:
					print("Interacting with: ", interact_node.name)
					interact_node.interact()

# NEW: Search node and parents for interact method
func _find_interactable(node):
	"""Search the node and its parents for interact() method"""
	var current = node
	var depth = 0
	while current != null and depth < 5:  # Max 5 levels up
		if current.has_method("interact"):
			return current
		current = current.get_parent()
		depth += 1
	return null

# Helper function to find if a node or its parent has product_data
func _find_product(node):
	var current = node
	while current != null:
		if "product_data" in current:
			return current
		current = current.get_parent()
	return null

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
	
	ray_cast_3d.remove_exception(item)
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D: item.freeze = false
	item.reparent(get_tree().current_scene)
	picked_object = null

func throw_object():
	if not picked_object: return
	var item = picked_object
	
	ray_cast_3d.remove_exception(item)
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D:
		item.freeze = false
		var camera = get_viewport().get_camera_3d()
		item.reparent(get_tree().current_scene)
		item.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	picked_object = null

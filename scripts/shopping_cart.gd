extends RigidBody3D
class_name ShoppingCart

## Shopping Cart - DEBUG VERSION
## With extensive debug output to find adding issues!

signal item_added(item)
signal item_removed(item)
signal cart_released

@export var push_distance: float = 0.4
@export var push_height: float = -0.4
@export var follow_speed: float = 10.0
@export var rotation_offset: float = 180.0
@export var max_items: int = 10
@export var stack_spacing: float = 0  # Small gap between items (was 0.2)
@export var base_height: float = -0.1
@export var use_dynamic_stacking: bool = true  # Use actual item sizes for stacking

@onready var item_storage_area: Node3D = $ItemStorageArea

var stored_items: Array = []
var is_being_pushed: bool = false
var pushing_player = null
var body_collision_shapes: Array = []
var handle_collision_shapes: Array = []
var owner_customer: CustomerAI = null  # Track which customer owns this cart

func _ready():
	mass = 2.0
	gravity_scale = 1.0
	
	_find_collision_shapes(self)
	
	collision_layer = 4
	collision_mask = 1
	
	linear_damp = 5.0
	angular_damp = 5.0
	can_sleep = true
	lock_rotation = true
	
	freeze = true
	freeze_mode = FREEZE_MODE_STATIC
	

func _find_collision_shapes(node: Node):
	if node is CollisionShape3D:
		var parent = node.get_parent()
		if parent is Area3D or parent.name == "Handle":
			handle_collision_shapes.append(node)
		else:
			body_collision_shapes.append(node)
	
	for child in node.get_children():
		_find_collision_shapes(child)

func _physics_process(delta):
	if is_being_pushed and pushing_player:
		_follow_player(delta)

func _follow_player(delta):
	if not pushing_player:
		return
	
	var player_forward = -pushing_player.global_transform.basis.z
	var target_pos = pushing_player.global_position + (player_forward * push_distance)
	target_pos.y = pushing_player.global_position.y + push_height
	
	global_position = target_pos
	rotation.y = pushing_player.rotation.y + deg_to_rad(rotation_offset)

func grab_handle(player):
	if is_being_pushed:
		return false
	
	# DETACH FROM CUSTOMER IF OWNED BY ONE
	if owner_customer:
		print("🔓 Player taking cart from customer: ", owner_customer.name)
		owner_customer.cart_taken_by_player()
		owner_customer = null
	
	is_being_pushed = true
	pushing_player = player
	
	freeze = true
	gravity_scale = 0.0
	
	collision_layer = 0
	collision_mask = 0
	
	for shape in body_collision_shapes:
		shape.disabled = true
	
	player.add_collision_exception_with(self)
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	var player_forward = -player.global_transform.basis.z
	var spawn_pos = player.global_position + (player_forward * push_distance)
	spawn_pos.y = player.global_position.y + push_height
	global_position = spawn_pos
	rotation.y = player.rotation.y + deg_to_rad(rotation_offset)
	
	return true

func release_handle():
	"""Release cart - re-enable collision and let cart fall"""
	if not is_being_pushed:
		return
	
	# Cart remains detached from customer (owner_customer stays null)
	
	if pushing_player:
		pushing_player.remove_collision_exception_with(self)
	
	for shape in body_collision_shapes:
		shape.disabled = false
	
	collision_layer = 4
	collision_mask = 1
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	freeze = false
	gravity_scale = 1.0
	
	is_being_pushed = false
	pushing_player = null
	
	await get_tree().create_timer(0.5).timeout
	if not is_being_pushed and not owner_customer:  # Only freeze if not owned by customer
		freeze = true
	
	cart_released.emit()

func interact():
	"""Called when player clicks cart"""
	if is_being_pushed:
		release_handle()
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			grab_handle(player)

func add_item(item: Node3D) -> bool:
	"""Add item to TOP of stack - WITH DYNAMIC STACKING!"""
	
	# Check 1: Max capacity
	if stored_items.size() >= max_items:
		return false
	
	# Check 2: Item is valid
	if not item:
		return false
	
	# Add to array
	stored_items.append(item)
	
	# Reparent to cart
	var old_parent = item.get_parent()
	
	if old_parent:
		old_parent.remove_child(item)

	item_storage_area.add_child(item)
	
	# Calculate stack position with dynamic height
	var height: float
	if use_dynamic_stacking and stored_items.size() > 1:
		# Stack on top of previous items based on their actual sizes
		height = _calculate_next_stack_position(item)
	else:
		# Use fixed spacing (original method)
		height = base_height + (stored_items.size() * stack_spacing)
	
	# Get item's half-height to position it correctly
	var item_half_height = _get_item_half_height(item)
	var final_y = height + item_half_height
	
	item.position = Vector3(0, final_y, 0)
	item.rotation = Vector3.ZERO
	
	# Freeze item
	if item is RigidBody3D:
		item.freeze = true
		item.freeze_mode = FREEZE_MODE_STATIC
	
	item_added.emit(item)
	return true

func remove_last_item() -> Node3D:
	"""Remove TOP item from stack (LIFO)"""
	if stored_items.is_empty():
		return null
	
	var item = stored_items.pop_back()	
	if item.get_parent() == item_storage_area:
		item_storage_area.remove_child(item)
	
	get_tree().current_scene.add_child(item)
	item.global_position = global_position + Vector3(0, 0.5, -0.8)
	
	if item is RigidBody3D:
		item.freeze = false
		item.freeze_mode = FREEZE_MODE_STATIC
	
	item_removed.emit(item)
	
	return item

func _restack_items():
	"""Restack items after removal with dynamic heights"""
	
	var cumulative_height = base_height
	
	for i in range(stored_items.size()):
		var item = stored_items[i]
		var item_half_height = _get_item_half_height(item)
		
		# Position item at cumulative height + its half height
		var final_y = cumulative_height + item_half_height
		item.position = Vector3(0, final_y, 0)
				
		# Add this item's full height + gap for next item
		if use_dynamic_stacking:
			cumulative_height += (item_half_height * 2) + stack_spacing
		else:
			cumulative_height += stack_spacing

func get_item_count() -> int:
	return stored_items.size()

func is_full() -> bool:
	return stored_items.size() >= max_items

func is_empty() -> bool:
	return stored_items.is_empty()

func get_tower_height() -> float:
	"""Get total height of item stack"""
	if stored_items.is_empty():
		return 0.0
	
	if use_dynamic_stacking:
		# Calculate actual cumulative height
		var total_height = base_height
		for item in stored_items:
			var item_height = _get_item_half_height(item) * 2.0
			total_height += item_height + stack_spacing
		return total_height - stack_spacing  # Remove last spacing
	else:
		# Use fixed spacing
		return base_height + (stored_items.size() * stack_spacing)

func is_being_held() -> bool:
	return is_being_pushed

func set_owner_customer(customer: CustomerAI):
	"""Set which customer owns this cart"""
	owner_customer = customer

func _get_item_half_height(item: Node3D) -> float:
	"""Get half the height of an item using its AABB (bounding box)"""
	var aabb = _get_item_aabb(item)
	if aabb:
		var height = aabb.size.y
		return height / 2.0
	
	# Fallback to default spacing if we can't get AABB
	return stack_spacing / 2.0

func _get_item_aabb(item: Node3D) -> AABB:
	"""Get the AABB (bounding box) of an item by checking its visual and collision children"""
	var combined_aabb = AABB()
	var has_aabb = false
	
	# Check for MeshInstance3D children
	for child in item.get_children():
		if child is MeshInstance3D:
			var mesh_aabb = child.get_aabb()
			var global_aabb = AABB(
				child.global_position + mesh_aabb.position - item.global_position,
				mesh_aabb.size
			)
			
			if not has_aabb:
				combined_aabb = global_aabb
				has_aabb = true
			else:
				combined_aabb = combined_aabb.merge(global_aabb)
		
		# Also check CollisionShape3D for more accurate bounds
		elif child is CollisionShape3D and child.shape:
			var shape = child.shape
			var shape_size = Vector3.ZERO
			
			if shape is BoxShape3D:
				shape_size = shape.size
			elif shape is SphereShape3D:
				var radius = shape.radius
				shape_size = Vector3(radius * 2, radius * 2, radius * 2)
			elif shape is CapsuleShape3D:
				var radius = shape.radius
				shape_size = Vector3(radius * 2, shape.height, radius * 2)
			elif shape is CylinderShape3D:
				var radius = shape.radius
				shape_size = Vector3(radius * 2, shape.height, radius * 2)
			
			if shape_size != Vector3.ZERO:
				var shape_aabb = AABB(
					child.position - shape_size / 2.0,
					shape_size
				)
				
				if not has_aabb:
					combined_aabb = shape_aabb
					has_aabb = true
				else:
					combined_aabb = combined_aabb.merge(shape_aabb)
	
	# If no children found, check item itself
	if not has_aabb and item is MeshInstance3D:
		combined_aabb = item.get_aabb()
		has_aabb = true
	
	return combined_aabb if has_aabb else AABB(Vector3.ZERO, Vector3(0.1, 0.1, 0.1))

func _calculate_next_stack_position(new_item: Node3D) -> float:
	"""Calculate where to place the next item based on actual heights of existing items"""
	var cumulative_height = base_height
	
	# Add heights of all previous items (excluding the one we just added)
	for i in range(stored_items.size() - 1):
		var item = stored_items[i]
		var item_full_height = _get_item_half_height(item) * 2.0
		cumulative_height += item_full_height + stack_spacing
	
	return cumulative_height

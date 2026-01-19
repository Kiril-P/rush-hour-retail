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
@export var stack_spacing: float = 0.2
@export var base_height: float = -0.1

@onready var item_storage_area: Node3D = $ItemStorageArea

var stored_items: Array = []
var is_being_pushed: bool = false
var pushing_player = null
var body_collision_shapes: Array = []
var handle_collision_shapes: Array = []

func _ready():
	mass = 2.0
	gravity_scale = 1.0
	
	_find_collision_shapes(self)
	
	print("=== CART READY ===")
	print("Max tower height: ", max_items, " items")
	print("Stack spacing: ", stack_spacing, "m per item")
	print("Base height (first item): ", base_height, "m")
	print("ItemStorageArea: ", item_storage_area)
	
	collision_layer = 4
	collision_mask = 1
	
	linear_damp = 5.0
	angular_damp = 5.0
	can_sleep = true
	lock_rotation = true
	
	freeze = true
	freeze_mode = FREEZE_MODE_STATIC
	
	print("==================\n")

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
	
	print("\n=== GRABBING CART ===")
	
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
	
	print("✓ CART GRABBED")
	print("=====================\n")
	
	return true

func release_handle():
	"""Release cart - re-enable collision and let cart fall"""
	if not is_being_pushed:
		return
	
	print("\n=== RELEASING CART ===")
	
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
	if not is_being_pushed:
		freeze = true
	
	cart_released.emit()
	
	print("✓ CART RELEASED")
	print("======================\n")

func interact():
	"""Called when player clicks cart"""
	if is_being_pushed:
		release_handle()
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			grab_handle(player)

func add_item(item: Node3D) -> bool:
	"""Add item to TOP of stack - WITH DEBUG!"""
	print("\n  === CART.ADD_ITEM() CALLED ===")
	print("  Item received: ", item)
	print("  Item name: ", item.name if item else "NULL")
	print("  Current items in cart: ", stored_items.size())
	print("  Max items: ", max_items)
	print("  ItemStorageArea: ", item_storage_area)
	
	# Check 1: Max capacity
	if stored_items.size() >= max_items:
		print("  ✗ FAILED: Cart is full! (", stored_items.size(), "/", max_items, ")")
		return false
	
	# Check 2: Item is valid
	if not item:
		print("  ✗ FAILED: Item is null!")
		return false
	
	print("  ✓ Checks passed, adding item...")
	
	# Add to array
	stored_items.append(item)
	print("  → Added to stored_items array. New size: ", stored_items.size())
	
	# Reparent to cart
	var old_parent = item.get_parent()
	print("  → Item's old parent: ", old_parent.name if old_parent else "None")
	
	if old_parent:
		print("  → Removing from old parent...")
		old_parent.remove_child(item)
		print("  → Removed from old parent")
	
	print("  → Adding to ItemStorageArea...")
	item_storage_area.add_child(item)
	print("  → Added to ItemStorageArea")
	print("  → Item's new parent: ", item.get_parent().name if item.get_parent() else "None")
	
	# Stack position
	var height = base_height + (stored_items.size() * stack_spacing)
	print("  → Calculated height: ", height, "m")
	print("  → Setting position to: ", Vector3(0, height, 0))
	
	item.position = Vector3(0, height, 0)
	item.rotation = Vector3.ZERO
	
	print("  → Position set: ", item.position)
	print("  → Rotation set: ", item.rotation)
	
	# Freeze item
	if item is RigidBody3D:
		print("  → Item is RigidBody3D, freezing...")
		item.freeze = true
		item.freeze_mode = FREEZE_MODE_STATIC
		print("  → Item frozen")
	else:
		print("  → Item is NOT RigidBody3D (type: ", item.get_class(), ")")
	
	print("  ✓ Item successfully added to cart!")
	print("  Final tower height: ", stored_items.size(), " items (", get_tower_height(), "m)")
	print("  ================================\n")
	
	item_added.emit(item)
	return true

func remove_last_item() -> Node3D:
	"""Remove TOP item from stack (LIFO)"""
	if stored_items.is_empty():
		print("Tower is empty!")
		return null
	
	var item = stored_items.pop_back()
	
	print("✓ Removed TOP item: ", item.name, " (", stored_items.size(), " items left)")
	
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
	"""Restack items after removal"""
	print("  → Restacking ", stored_items.size(), " items...")
	for i in range(stored_items.size()):
		var item = stored_items[i]
		var height = base_height + ((i + 1) * stack_spacing)
		item.position = Vector3(0, height, 0)
		print("    Item ", i+1, ": ", item.name, " at ", height, "m")

func get_item_count() -> int:
	return stored_items.size()

func is_full() -> bool:
	return stored_items.size() >= max_items

func is_empty() -> bool:
	return stored_items.is_empty()

func get_tower_height() -> float:
	if stored_items.is_empty():
		return 0.0
	return base_height + (stored_items.size() * stack_spacing)

func is_being_held() -> bool:
	return is_being_pushed

extends RigidBody3D
class_name ShoppingBasket

## Shopping Basket - DEBUG VERSION
## Extensive logging to find interaction issues!

signal item_added(item)
signal item_removed(item)
signal basket_released

@export var hold_distance: float = 0.6
@export var hold_height: float = -0.2
@export var hold_forward: float = 0.3
@export var max_items: int = 3
@export var stack_spacing: float = 0.2
@export var base_height: float = -0.1

@onready var item_storage_area: Node3D = $ItemStorageArea

var stored_items: Array = []
var being_held: bool = false
var holding_player = null
var body_collision_shapes: Array = []
var handle_collision_shapes: Array = []

func _ready():
	# print("\n==================================================")
	# print("=== SHOPPING BASKET DEBUG READY ===")
	# print("==================================================")
	
	# Add to basket group
	add_to_group("basket")
	# print("✓ Added to 'basket' group")
	
	mass = 1.0
	gravity_scale = 1.0
	
	# print("\n--- COLLISION SETUP ---")
	# print("Collision Layer: ", collision_layer)
	# print("Collision Mask: ", collision_mask)
	# print("Expected Layer: 4 (bit 2)")
	# print("Expected Mask: 1 (bit 0)")
	
	_find_collision_shapes(self)
	
	# print("\n--- COLLISION SHAPES ---")
	# print("Body shapes found: ", body_collision_shapes.size())
	for i in range(body_collision_shapes.size()):
		var shape = body_collision_shapes[i]
		# print("  Shape ", i, ": ", shape.name)
		# print("    Disabled: ", shape.disabled)
		# print("    Shape: ", shape.shape)
		#if shape.disabled:
			# print("    ⚠️ WARNING: Shape is DISABLED!")
		#if not shape.shape:
			# print("    ⚠️ WARNING: No shape assigned!")
	
	# print("\n--- SCENE STRUCTURE ---")
	# print("ItemStorageArea: ", item_storage_area)
	#if not item_storage_area:
		# print("⚠️ ERROR: ItemStorageArea not found!")
	
	# print("\n--- PHYSICS SETTINGS ---")
	# print("Mass: ", mass)
	# print("Gravity Scale: ", gravity_scale)
	# print("Lock Rotation: ", lock_rotation)
	# print("Freeze: ", freeze)
	
	collision_layer = 4
	collision_mask = 1
	
	linear_damp = 5.0
	angular_damp = 5.0
	can_sleep = true
	lock_rotation = true
	
	freeze = true
	freeze_mode = FREEZE_MODE_STATIC
	
	# print("\n--- METHODS CHECK ---")
	# print("Has interact() method: ", has_method("interact"))
	# print("Has grab_handle() method: ", has_method("grab_handle"))
	# print("Has add_item() method: ", has_method("add_item"))
	
	# print("\n==================================================")
	# print("BASKET INITIALIZATION COMPLETE")
	# print("==================================================\n")

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
	if being_held and holding_player:
		_follow_player(delta)

func _follow_player(delta):
	if not holding_player:
		return
	
	var player_forward = -holding_player.global_transform.basis.z
	var player_right = holding_player.global_transform.basis.x
	
	var target_pos = holding_player.global_position
	target_pos += player_right * hold_distance
	target_pos += player_forward * hold_forward
	target_pos.y = holding_player.global_position.y + hold_height
	
	global_position = target_pos
	rotation.y = holding_player.rotation.y

func grab_handle(player):
	# print("\n*** BASKET.GRAB_HANDLE() CALLED ***")
	# print("Player: ", player.name if player else "None")
	# print("Currently held: ", being_held)
	
	if being_held:
		# print("✗ Already being held!")
		return false
	
	# print("✓ Grabbing basket...")
	
	being_held = true
	holding_player = player
	
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
	var player_right = player.global_transform.basis.x
	
	var spawn_pos = player.global_position
	spawn_pos += player_right * hold_distance
	spawn_pos += player_forward * hold_forward
	spawn_pos.y = player.global_position.y + hold_height
	
	global_position = spawn_pos
	rotation.y = player.rotation.y
	
	# print("✓ BASKET GRABBED")
	# print("  Position: ", global_position)
	# print("  On right side of player")
	# print("***********************************\n")
	
	return true

func release_handle():
	# print("\n*** BASKET.RELEASE_HANDLE() CALLED ***")
	
	if not being_held:
		# print("✗ Not being held!")
		return
	
	# print("✓ Releasing basket...")
	
	if holding_player:
		holding_player.remove_collision_exception_with(self)
	
	for shape in body_collision_shapes:
		shape.disabled = false
	
	collision_layer = 4
	collision_mask = 1
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	freeze = false
	gravity_scale = 1.0
	
	being_held = false
	holding_player = null
	
	await get_tree().create_timer(0.5).timeout
	if not being_held:
		freeze = true
	
	basket_released.emit()
	
	# print("✓ BASKET RELEASED")
	# print("**************************************\n")

func interact():
	# print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	# print("!!! BASKET.INTERACT() CALLED !!!")
	# print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	# print("Currently held: ", being_held)
	
	if being_held:
		# print("→ Calling release_handle()")
		release_handle()
	else:
		# print("→ Trying to grab basket")
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# print("  Found player: ", player.name)
			# print("  Calling grab_handle()")
			grab_handle(player)
		#else:
			# print("  ✗ ERROR: Player not found!")
	
	# print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")

func add_item(item: Node3D) -> bool:
	# print("\n=== BASKET.ADD_ITEM() ===")
	# print("Item: ", item.name if item else "NULL")
	# print("Current items: ", stored_items.size(), "/", max_items)
	
	if stored_items.size() >= max_items:
		# print("✗ BASKET FULL!")
		return false
	
	if not item:
		# print("✗ Item is null!")
		return false
	
	stored_items.append(item)
	
	var old_parent = item.get_parent()
	if old_parent:
		old_parent.remove_child(item)
	
	item_storage_area.add_child(item)
	
	var height = base_height + (stored_items.size() * stack_spacing)
	item.position = Vector3(0, height, 0)
	item.rotation = Vector3.ZERO
	
	if item is RigidBody3D:
		item.freeze = true
		item.freeze_mode = FREEZE_MODE_STATIC
	
	# print("✓ Added to basket at height: ", height, "m")
	# print("===========================\n")
	
	item_added.emit(item)
	return true

func remove_last_item() -> Node3D:
	if stored_items.is_empty():
		# print("Basket is empty!")
		return null
	
	var item = stored_items.pop_back()
	
	# print("✓ Removed from basket: ", item.name)
	
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
	for i in range(stored_items.size()):
		var item = stored_items[i]
		var height = base_height + ((i + 1) * stack_spacing)
		item.position = Vector3(0, height, 0)

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
	return being_held

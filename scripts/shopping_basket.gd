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
	
	# Add to basket group
	add_to_group("basket")
	
	mass = 1.0
	gravity_scale = 1.0
	
	
	_find_collision_shapes(self)
	
	for i in range(body_collision_shapes.size()):
		var shape = body_collision_shapes[i]
	
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
	
	if being_held:
		return false
	
	
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
	
	
	return true

func release_handle():
	
	if not being_held:
		return
	
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

func interact():
	
	if being_held:
		release_handle()
	else:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			grab_handle(player)


func add_item(item: Node3D) -> bool:
	
	if stored_items.size() >= max_items:
		return false
	
	if not item:
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
	
	
	item_added.emit(item)
	return true

func remove_last_item() -> Node3D:
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

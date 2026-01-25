extends Node3D

## Shelf Spawner - ASYNC SPAWNING (Fast startup!)
## Spawns items over multiple frames to prevent lag

@export var allowed_products: Array[PackedScene] = []
@export var spawn_on_ready: bool = true
@export var items_per_shelf: int = 4

@export_group("Positioning")
@export var spawn_height_offset: float = 0
@export var drop_items: bool = true
@export var drop_time: float = 1

@export_group("Performance")
@export var spawn_delay_per_item: float = 0.02  # Delay between each item (prevents lag)

var spawn_points: Array[Marker3D] = []
var spawned_items: Array = []
var selected_products: Array[PackedScene] = []

func _ready():
	_find_spawn_points()
	
	if spawn_on_ready:
		# Spawn asynchronously - doesn't block!
		spawn_items_async()

func _find_spawn_points():
	spawn_points.clear()
	
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)

func spawn_items_async():
	"""ASYNC spawning - doesn't freeze game!"""
	if allowed_products.is_empty() or spawn_points.is_empty():
		return
	
	clear_items()
	
	# Select random items for this shelf
	_select_items_for_shelf()
	
	# Create spawn list
	var spawn_list = []
	for product in selected_products:
		spawn_list.append(product)
	
	# Fill remaining spots
	var remaining = spawn_points.size() - selected_products.size()
	for i in range(remaining):
		spawn_list.append(selected_products[randi() % selected_products.size()])
	
	spawn_list.shuffle()
	
	# Spawn items ONE AT A TIME with delays
	for i in range(min(spawn_points.size(), spawn_list.size())):
		_spawn_item_at_marker(spawn_list[i], spawn_points[i])
		
		# Wait before spawning next item (prevents lag spike!)
		if spawn_delay_per_item > 0:
			await get_tree().create_timer(spawn_delay_per_item).timeout
	
	# Drop all at once after spawning
	if drop_items:
		await get_tree().create_timer(drop_time).timeout
		_freeze_all_items()

func _select_items_for_shelf():
	selected_products.clear()
	var num_to_select = min(items_per_shelf, allowed_products.size())
	var available = allowed_products.duplicate()
	
	for i in range(num_to_select):
		if available.size() > 0:
			var random_index = randi() % available.size()
			selected_products.append(available[random_index])
			available.remove_at(random_index)

func _spawn_item_at_marker(product_scene: PackedScene, marker: Marker3D):
	if not product_scene:
		return
	
	var item = product_scene.instantiate()
	if not item:
		return
	
	get_tree().current_scene.add_child(item)
	
	var spawn_pos = marker.global_position
	spawn_pos.y += spawn_height_offset
	
	item.global_position = spawn_pos
	item.global_rotation = Vector3.ZERO
	
	if item is RigidBody3D:
		if drop_items:
			item.freeze = false
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
			item.linear_damp = 2.0
			item.angular_damp = 2.0
		else:
			item.freeze = true
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	
	spawned_items.append(item)

func _freeze_all_items():
	for item in spawned_items:
		if is_instance_valid(item) and item is RigidBody3D:
			item.freeze = true
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO

func clear_items():
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()

func respawn_items():
	spawn_items_async()

func get_spawned_count() -> int:
	return spawned_items.size()

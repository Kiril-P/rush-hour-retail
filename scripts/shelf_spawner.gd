extends Node3D

## Shelf Spawner - Random Selection from Master Pool
## Each shelf picks random items from the full pool

@export var allowed_products: Array[PackedScene] = []  # Master list of ALL possible items
@export var spawn_on_ready: bool = true
@export var items_per_shelf: int = 4  # How many DIFFERENT items to pick for THIS shelf

@export_group("Positioning")
@export var spawn_height_offset: float = 0
@export var drop_items: bool = true
@export var drop_time: float = 1

var spawn_points: Array[Marker3D] = []
var spawned_items: Array = []
var selected_products: Array[PackedScene] = []  # Products chosen for THIS shelf

func _ready():
	_find_spawn_points()
	
	if spawn_on_ready:
		spawn_items()

func _find_spawn_points():
	"""Find all Marker3D children to use as spawn points"""
	spawn_points.clear()
	
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)
	
	print("\n========== SHELF SPAWNER ==========")
	print("Shelf: ", name)
	print("✓ ", spawn_points.size(), " spawn points")
	print("✓ Master pool: ", allowed_products.size(), " items")
	print("✓ Will select: ", items_per_shelf, " items for this shelf")
	print("✓ Drop physics: ", "ENABLED" if drop_items else "DISABLED")
	
	if spawn_points.is_empty():
		print("⚠️ No spawn points found!")
	
	if allowed_products.is_empty():
		push_warning("Shelf ", name, " has no products assigned!")
	
	print("==========================================\n")

func spawn_items():
	"""Spawn items - pick random selection from master pool"""
	if allowed_products.is_empty():
		print("No products to spawn on shelf: ", name)
		return
	
	if spawn_points.is_empty():
		print("No spawn points found on shelf: ", name)
		return
	
	# Clear any existing items
	clear_items()
	
	# Select random items from master pool for THIS shelf
	_select_items_for_shelf()
	
	print("\n>>> SPAWNING: Random Selection")
	print("  Selected ", selected_products.size(), " items for this shelf")
	
	# Create spawn list - each selected product at least once, then fill randomly
	var spawn_list = []
	
	# Add each selected product once (guaranteed)
	for product in selected_products:
		spawn_list.append(product)
	
	# Fill remaining spots with random selections from selected products
	var remaining_spots = spawn_points.size() - selected_products.size()
	for i in range(remaining_spots):
		var random_product = selected_products[randi() % selected_products.size()]
		spawn_list.append(random_product)
	
	# Shuffle for random positions
	spawn_list.shuffle()
	
	# Spawn items at each marker
	for i in range(min(spawn_points.size(), spawn_list.size())):
		_spawn_item_at_marker(spawn_list[i], spawn_points[i])
	
	# If dropping, wait for items to settle
	if drop_items:
		await get_tree().create_timer(drop_time).timeout
		_freeze_all_items()
	
	print("✓ Spawned ", spawned_items.size(), " items")
	print("=========================================\n")

func _select_items_for_shelf():
	"""Randomly select items_per_shelf items from the master pool"""
	selected_products.clear()
	
	# Make sure we don't try to select more items than exist
	var num_to_select = min(items_per_shelf, allowed_products.size())
	
	# Create a copy of allowed_products to pick from
	var available = allowed_products.duplicate()
	
	# Randomly pick items
	for i in range(num_to_select):
		if available.size() > 0:
			var random_index = randi() % available.size()
			selected_products.append(available[random_index])
			available.remove_at(random_index)  # Don't pick same item twice

func _spawn_item_at_marker(product_scene: PackedScene, marker: Marker3D):
	"""Spawn item - can drop or spawn frozen"""
	if not product_scene:
		print("⚠️ Product scene is null!")
		return
	
	var item = product_scene.instantiate()
	
	if not item:
		print("⚠️ Failed to instantiate item!")
		return
	
	# Add to scene root (no parent scale inheritance!)
	get_tree().current_scene.add_child(item)
	
	# Get spawn position (above marker)
	var spawn_pos = marker.global_position
	spawn_pos.y += spawn_height_offset
	
	item.global_position = spawn_pos
	item.global_rotation = Vector3.ZERO
	
	# Handle physics based on drop_items setting
	if item is RigidBody3D:
		if drop_items:
			# Let it drop!
			item.freeze = false
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
			item.linear_damp = 2.0
			item.angular_damp = 2.0
		else:
			# Spawn frozen
			item.freeze = true
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
	
	spawned_items.append(item)

func _freeze_all_items():
	"""Freeze all items after they've dropped"""
	print("  → Freezing items in place...")
	
	for item in spawned_items:
		if is_instance_valid(item) and item is RigidBody3D:
			item.freeze = true
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO

func clear_items():
	"""Remove all spawned items"""
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	
	spawned_items.clear()

func respawn_items():
	"""Clear and respawn all items"""
	spawn_items()

func get_spawned_count() -> int:
	"""Get number of currently spawned items"""
	return spawned_items.size()

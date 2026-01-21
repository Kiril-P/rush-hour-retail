extends Node3D

## Simple Shelf Spawner - WITH DROP PHYSICS!
## Items can drop onto shelf naturally, or spawn frozen

@export var allowed_products: Array[PackedScene] = []
@export var spawn_on_ready: bool = true
@export var fill_entire_shelf: bool = true

@export_group("Positioning")
@export var spawn_height_offset: float = 0  # Height above marker to spawn
@export var drop_items: bool = true  # Let items fall naturally?
@export var drop_time: float = 1  # How long to let them fall

var spawn_points: Array[Marker3D] = []
var spawned_items: Array = []

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
	
	print("\n========== SIMPLE SHELF SPAWNER ==========")
	print("Shelf: ", name)
	print("✓ ", spawn_points.size(), " spawn points")
	print("✓ Allowed products: ", allowed_products.size())
	print("✓ Drop physics: ", "ENABLED" if drop_items else "DISABLED")
	
	if spawn_points.is_empty():
		print("⚠️ No spawn points found!")
	
	if allowed_products.is_empty():
		push_warning("Shelf ", name, " has no products assigned!")
	
	print("==========================================\n")

func spawn_items():
	"""Spawn items at all spawn points"""
	if allowed_products.is_empty():
		print("No products to spawn on shelf: ", name)
		return
	
	if spawn_points.is_empty():
		print("No spawn points found on shelf: ", name)
		return
	
	# Clear any existing items
	clear_items()
	
	if fill_entire_shelf:
		var chosen_product = allowed_products[randi() % allowed_products.size()]
		
		print("\n>>> SPAWNING: ", chosen_product.resource_path.get_file())
		
		for marker in spawn_points:
			_spawn_item_at_marker(chosen_product, marker)
		
		# If dropping, wait for items to settle
		if drop_items:
			await get_tree().create_timer(drop_time).timeout
			_freeze_all_items()
		
		print("✓ Spawned ", spawned_items.size(), " items")
		print("=========================================\n")
	else:
		print("\n>>> SPAWNING: Mixed Products")
		
		for marker in spawn_points:
			var random_product = allowed_products[randi() % allowed_products.size()]
			_spawn_item_at_marker(random_product, marker)
		
		# If dropping, wait for items to settle
		if drop_items:
			await get_tree().create_timer(drop_time).timeout
			_freeze_all_items()
		
		print("✓ Spawned ", spawned_items.size(), " items")
		print("=========================================\n")

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
			item.linear_damp = 2.0  # Some air resistance
			item.angular_damp = 2.0
			# Gravity will pull it down naturally
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

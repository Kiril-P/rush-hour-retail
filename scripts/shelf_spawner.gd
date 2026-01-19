extends Node3D

## Simple Shelf Spawner - NO ProductData needed!
## Spawns items using PackedScenes directly

@export var allowed_products: Array[PackedScene] = []  # Item SCENES, not resources!
@export var spawn_on_ready: bool = true
@export var fill_entire_shelf: bool = true  # If true, spawns same product on all markers

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
		# Pick ONE random product and fill entire shelf with it
		var chosen_product = allowed_products[randi() % allowed_products.size()]
		
		print("\n>>> SHELF CATEGORY: Single Product")
		print("Filling entire shelf with same product...")
		
		for marker in spawn_points:
			_spawn_item_at_marker(chosen_product, marker)
		
		print("✓ Spawned ", spawned_items.size(), " items")
		print("=========================================\n")
	else:
		# Random product at each spawn point
		print("\n>>> SHELF: Mixed Products")
		
		for marker in spawn_points:
			var random_product = allowed_products[randi() % allowed_products.size()]
			_spawn_item_at_marker(random_product, marker)
		
		print("✓ Spawned ", spawned_items.size(), " items")
		print("=========================================\n")

func _spawn_item_at_marker(product_scene: PackedScene, marker: Marker3D):
	"""Spawn a single item at a marker"""
	if not product_scene:
		print("⚠️ Product scene is null!")
		return
	
	# Instantiate the item
	var item = product_scene.instantiate()
	
	if not item:
		print("⚠️ Failed to instantiate item!")
		return
	
	# Add to scene
	add_child(item)
	
	# Position at marker
	item.global_transform = marker.global_transform
	
	# Store reference
	spawned_items.append(item)

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

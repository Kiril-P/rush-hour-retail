extends Node3D
class_name ShelfSpawnerCategory

## Category-Based Spawner
## Picks ONE random item from allowed list, then fills entire shelf with it
## Perfect for realistic store layout!

## Example Usage:
## - Freezer: allowed_products = [Chicken, Ice Cream, Frozen Pizza]
##   → Spawns ALL chicken or ALL ice cream (not mixed!)
## - Cereal Shelf: allowed_products = [Cereal Box, Oats, Granola]
##   → Entire shelf has same cereal brand
## - Drink Shelf: allowed_products = [Water, Soda, Juice]
##   → All water bottles or all soda (not mixed!)

@export var item_scene: PackedScene  # The generic item model (or leave empty for matching)
@export var allowed_products: Array[ProductData] = []  # What CAN spawn here
@export var max_items: int = 6
@export var spawn_on_ready: bool = true

var spawn_markers: Array[Marker3D] = []
var spawned_items: Array = []
var chosen_product: ProductData = null  # The ONE product for this shelf

func _ready():
	print("\n========== CATEGORY SHELF SPAWNER ==========")
	print("Shelf: ", name)
	
	_find_spawn_markers()
	
	if spawn_markers.is_empty():
		print("ERROR: No spawn markers!")
		return
	
	if allowed_products.is_empty():
		print("ERROR: No allowed products assigned!")
		print("→ In Inspector, add ProductData to 'Allowed Products'")
		return
	
	print("✓ ", spawn_markers.size(), " spawn points")
	print("✓ Allowed products: ", allowed_products.size())
	for product in allowed_products:
		print("  - ", product.item_name)
	
	if spawn_on_ready:
		await get_tree().create_timer(0.5).timeout
		spawn_category_items()
	
	print("=========================================\n")

func _find_spawn_markers():
	spawn_markers.clear()
	_find_markers_recursive(self)

func _find_markers_recursive(node: Node):
	for child in node.get_children():
		if child is Marker3D:
			spawn_markers.append(child)
		_find_markers_recursive(child)

func spawn_category_items():
	"""Pick ONE random product and fill entire shelf with it"""
	
	if allowed_products.is_empty():
		print("ERROR: No allowed products!")
		return
	
	clear_items()
	
	# PICK ONE RANDOM PRODUCT from allowed list
	chosen_product = allowed_products[randi() % allowed_products.size()]
	
	print("\n>>> SHELF CATEGORY: ", chosen_product.item_name)
	print("Filling entire shelf with this product...")
	
	var num_to_spawn = min(max_items, spawn_markers.size())
	
	for i in range(num_to_spawn):
		var marker = spawn_markers[i]
		_spawn_item_at_marker(chosen_product, marker)
	
	print("✓ Spawned ", spawned_items.size(), " × ", chosen_product.item_name)

func _spawn_item_at_marker(product: ProductData, marker: Marker3D):
	var item = null
	
	# If item_scene is provided, use it
	if item_scene:
		item = item_scene.instantiate()
	# Otherwise try to use product's item_scene
	elif product.item_scene:
		item = product.item_scene.instantiate()
	else:
		print("ERROR: No item scene available!")
		return
	
	# Assign ProductData
	if "product_data" in item:
		item.product_data = product
	
	# Add to scene
	get_tree().current_scene.add_child(item)
	item.global_position = marker.global_position
	item.global_rotation = marker.global_rotation
	
	spawned_items.append(item)

func clear_items():
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()
	chosen_product = null

func respawn():
	"""Clear and choose new category"""
	clear_items()
	await get_tree().create_timer(0.1).timeout
	spawn_category_items()

func get_current_category() -> String:
	"""Get the name of current product filling this shelf"""
	if chosen_product:
		return chosen_product.item_name
	return "None"

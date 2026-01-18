extends Node3D
class_name ShelfSpawnerSmart

## Smart Spawner - Matches Item Models to Their ProductData
## Automatically pairs models with correct data based on names!

@export var item_scenes: Array[PackedScene] = []  # Add all your item scenes here
@export var max_items: int = 6
@export var spawn_on_ready: bool = true

var spawn_markers: Array[Marker3D] = []
var spawned_items: Array = []

func _ready():
	print("\n========== SMART SHELF SPAWNER ==========")
	print("Shelf: ", name)
	
	_find_spawn_markers()
	
	if spawn_markers.is_empty():
		print("ERROR: No spawn markers found!")
		return
	
	if item_scenes.is_empty():
		print("ERROR: No item scenes assigned in Inspector!")
		return
	
	print("✓ ", spawn_markers.size(), " spawn points")
	print("✓ ", item_scenes.size(), " item scenes")
	
	if spawn_on_ready:
		await get_tree().create_timer(0.5).timeout
		spawn_random_items()
	
	print("=========================================\n")

func _find_spawn_markers():
	spawn_markers.clear()
	_find_markers_recursive(self)

func _find_markers_recursive(node: Node):
	for child in node.get_children():
		if child is Marker3D:
			spawn_markers.append(child)
		_find_markers_recursive(child)

func spawn_random_items():
	if not GameManager or GameManager.available_products.is_empty():
		print("ERROR: GameManager or products not ready!")
		return
	
	clear_items()
	
	var num_to_spawn = min(max_items, spawn_markers.size())
	
	print("Spawning ", num_to_spawn, " items...")
	
	for i in range(num_to_spawn):
		var marker = spawn_markers[i]
		
		# Pick random scene
		var random_scene = item_scenes[randi() % item_scenes.size()]
		
		# Find matching ProductData for this scene
		var matching_product = _find_matching_product(random_scene)
		
		if matching_product:
			_spawn_item_at_marker(random_scene, matching_product, marker)
		else:
			print("  WARNING: No matching product for ", random_scene.resource_path)

func _find_matching_product(scene: PackedScene) -> ProductData:
	"""Find ProductData that matches the scene name"""
	
	var scene_name = scene.resource_path.get_file().get_basename().to_lower()
	
	# Try to match by name similarity
	for product in GameManager.available_products:
		var product_name = product.item_name.to_lower().replace(" ", "_")
		
		# Check if scene name contains product name or vice versa
		if product_name in scene_name or scene_name in product_name:
			return product
		
		# Also try without underscores/spaces
		var clean_scene = scene_name.replace("_", "").replace("-", "")
		var clean_product = product_name.replace("_", "").replace("-", "")
		
		if clean_product in clean_scene or clean_scene in clean_product:
			return product
	
	# If no match found, return random product as fallback
	print("  No name match found for ", scene_name, ", using random product")
	return GameManager.available_products[randi() % GameManager.available_products.size()]

func _spawn_item_at_marker(item_scene: PackedScene, product: ProductData, marker: Marker3D):
	var item = item_scene.instantiate()
	
	# Assign ProductData
	if "product_data" in item:
		item.product_data = product
	
	# Add to scene
	get_tree().current_scene.add_child(item)
	item.global_position = marker.global_position
	item.global_rotation = marker.global_rotation
	
	spawned_items.append(item)
	
	var scene_name = item_scene.resource_path.get_file()
	print("  ✓ ", scene_name, " → ", product.item_name)

func clear_items():
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()

## Manual matching (if auto-match doesn't work)
## Override this function to manually define scene → product mappings

func _get_manual_product(scene_path: String) -> ProductData:
	"""Manual override for matching scenes to products"""
	
	# Example mappings - adjust to your file names:
	var mappings = {
		"milk_carton": "Milk Carton",
		"bread": "Bread",
		"cereal": "Cereal Box",
		"water": "Water Bottle",
	}
	
	var scene_name = scene_path.get_file().get_basename().to_lower()
	
	for key in mappings.keys():
		if key in scene_name:
			var product_name = mappings[key]
			for product in GameManager.available_products:
				if product.item_name == product_name:
					return product
	
	return null

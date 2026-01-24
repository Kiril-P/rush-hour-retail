extends Node3D

## Customer Spawner - Spawns AI customers at round start
## Handles both types: WITH_CART and WITHOUT_CART
## Version without CustomerAI type casting for compatibility

@export var customer_scene: PackedScene  # customer.tscn
@export var shopping_cart_scene: PackedScene  # shopping_cart.tscn
@export var available_items: Array[PackedScene] = []  # All item scenes

@export_group("Spawn Settings")
@export var type1_customers: int = 3  # WITHOUT_CART
@export var type2_customers: int = 3  # WITH_CART
@export var min_items_per_cart: int = 2
@export var max_items_per_cart: int = 10

@export_group("Spawn Timing")
@export var spawn_on_ready: bool = true
@export var spawn_delay: float = 0.5  # Delay between each spawn

# Customer type enum (matches customer_ai.gd)
enum CustomerType {
	WITHOUT_CART,
	WITH_CART
}

func _ready():
	if spawn_on_ready:
		await get_tree().create_timer(1.0).timeout
		spawn_all_customers()

func spawn_all_customers():
	"""Spawn all customers at round start"""
	print("\n=== CUSTOMER SPAWNER ===")
	print("Spawning ", type1_customers, " WITHOUT_CART customers")
	print("Spawning ", type2_customers, " WITH_CART customers")
	print("========================\n")
	
	# Spawn Type 1 (WITHOUT_CART)
	for i in range(type1_customers):
		await get_tree().create_timer(spawn_delay).timeout
		_spawn_customer_without_cart(i)
	
	# Spawn Type 2 (WITH_CART)
	for i in range(type2_customers):
		await get_tree().create_timer(spawn_delay).timeout
		_spawn_customer_with_cart(i)
	
	print("✅ All customers spawned!\n")

func _spawn_customer_without_cart(index: int):
	"""Spawn Type 1: Customer parks cart, walks around"""
	if not customer_scene:
		push_error("Customer scene not assigned!")
		return
	
	# Find spawn points
	var customer_spawns = get_tree().get_nodes_in_group("customer_spawn_type1")
	var cart_parking_spots = get_tree().get_nodes_in_group("parked_cart_spot")
	
	if customer_spawns.is_empty():
		push_error("No customer_spawn_type1 markers found!")
		return
	
	# Pick random spawn point
	var spawn_point = customer_spawns[index % customer_spawns.size()]
	
	# Spawn customer (without type casting)
	var customer = customer_scene.instantiate()
	customer.customer_type = CustomerType.WITHOUT_CART
	get_tree().current_scene.add_child(customer)
	customer.global_position = spawn_point.global_position
	
	# Spawn and park cart
	if not cart_parking_spots.is_empty() and shopping_cart_scene:
		var parking_spot = cart_parking_spots[index % cart_parking_spots.size()]
		var cart = await _spawn_cart(parking_spot.global_position)
		customer.attach_cart(cart)
		
		# Fill cart with items
		await _fill_cart_with_items(cart)
	
	print("🚶 Spawned Type 1 customer: ", customer.name)

func _spawn_customer_with_cart(index: int):
	"""Spawn Type 2: Customer walks with cart"""
	if not customer_scene:
		push_error("Customer scene not assigned!")
		return
	
	# Find spawn points
	var customer_spawns = get_tree().get_nodes_in_group("customer_spawn_type2")
	
	if customer_spawns.is_empty():
		push_error("No customer_spawn_type2 markers found!")
		return
	
	# Pick random spawn point
	var spawn_point = customer_spawns[index % customer_spawns.size()]
	
	# Spawn customer (without type casting)
	var customer = customer_scene.instantiate()
	customer.customer_type = CustomerType.WITH_CART
	get_tree().current_scene.add_child(customer)
	customer.global_position = spawn_point.global_position
	
	# Spawn cart with customer
	if shopping_cart_scene:
		var cart = await _spawn_cart(spawn_point.global_position)
		customer.attach_cart(cart)
		
		# Fill cart with items
		await _fill_cart_with_items(cart)
	
	print("🛒 Spawned Type 2 customer: ", customer.name)

func _spawn_cart(position: Vector3):
	"""Spawn a shopping cart at position"""
	var cart = shopping_cart_scene.instantiate()
	get_tree().current_scene.add_child(cart)
	
	# Wait for cart to be ready
	await get_tree().process_frame
	
	cart.global_position = position
	
	return cart

func _fill_cart_with_items(cart):
	"""Fill cart with random items"""
	if available_items.is_empty():
		print("  ⚠️ No items available to fill cart!")
		return
	
	# Wait for cart's ItemStorageArea to be ready
	await get_tree().process_frame
	
	var num_items = randi_range(min_items_per_cart, max_items_per_cart)
	
	print("  → Filling cart with ", num_items, " items...")
	
	for i in range(num_items):
		# Pick random item
		var random_item_scene = available_items[randi() % available_items.size()]
		
		# Check if scene is valid
		if not random_item_scene:
			print("  ⚠️ Item scene is null at index ", i)
			continue
		
		# Instantiate item
		var item = random_item_scene.instantiate()
		
		if not item:
			print("  ⚠️ Failed to instantiate item from: ", random_item_scene.resource_path)
			continue
		
		# Add to cart
		if cart.has_method("add_item"):
			if cart.add_item(item):
				print("    ✓ Added ", item.name, " to cart")
			else:
				print("    ✗ Failed to add ", item.name)
				item.queue_free()
		else:
			print("  ⚠️ Cart doesn't have add_item method!")
			item.queue_free()
			break
	
	if cart.has_method("get") and "stored_items" in cart:
		print("  ✅ Cart filled with ", cart.stored_items.size(), " items")
	else:
		print("  ✅ Cart filled")

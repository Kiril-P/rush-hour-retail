extends Node3D

## Customer Spawner - CONTINUOUS SPAWNING
## Spawns initial wave, then spawns new customers over time

@export var customer_scene: PackedScene
@export var shopping_cart_scene: PackedScene
@export var available_items: Array[PackedScene] = []

@export_group("Initial Spawn")
@export var type1_customers: int = 3
@export var type2_customers: int = 3
@export var initial_spawn_delay: float = 0.5

@export_group("Continuous Spawning")
@export var enable_continuous_spawning: bool = true
@export var min_spawn_interval: float = 5.0  # Min seconds between spawns
@export var max_spawn_interval: float = 20.0  # Max seconds between spawns
@export var max_total_customers: int = 10  # Max customers in store at once
@export var continuous_spawn_ratio: float = 0.5  # 0-1, chance of Type1 vs Type2

@export_group("Cart Settings")
@export var min_items_per_cart: int = 2
@export var max_items_per_cart: int = 10

@export_group("Spawn Timing")
@export var spawn_on_ready: bool = true

var active_customers: int = 0
var spawning_active: bool = false

# PERFORMANCE: Cache spawn points to avoid repeated get_nodes_in_group()
var cached_type1_spawns: Array = []
var cached_type2_spawns: Array = []
var cached_parking_spots: Array = []

func _ready():
	# Cache spawn points once at startup (HUGE performance gain!)
	_cache_spawn_points()
	
	# PERFORMANCE FIX: Preload all customer models before spawning to avoid lag spikes
	CustomerAI.preload_all_models()
	
	if spawn_on_ready:
		var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
		if loading_manager:
			loading_manager.register_loading_task(spawn_initial_wave, 5, "Preparing customers...")
		else:
			await get_tree().create_timer(1.0).timeout
			spawn_initial_wave()

func _cache_spawn_points():
	"""Cache all spawn point groups to avoid repeated scene tree searches"""
	cached_type1_spawns = get_tree().get_nodes_in_group("customer_spawn_type1")
	cached_type2_spawns = get_tree().get_nodes_in_group("customer_spawn_type2")
	cached_parking_spots = get_tree().get_nodes_in_group("parked_cart_spot")

func spawn_initial_wave():
	"""Spawn initial batch of customers"""
	
	# Use shorter delay when loading
	var delay = initial_spawn_delay if not LoadingManager.is_loading() else 0.05
	
	# Spawn initial Type 1
	for i in range(type1_customers):
		if delay > 0:
			await get_tree().create_timer(delay).timeout
		_spawn_customer_without_cart()
	
	# Spawn initial Type 2
	for i in range(type2_customers):
		if delay > 0:
			await get_tree().create_timer(delay).timeout
		_spawn_customer_with_cart()
	
	
	# Start continuous spawning
	if enable_continuous_spawning:
		spawning_active = true
		_continuous_spawn_loop()

func _continuous_spawn_loop():
	"""Continuously spawn new customers at random intervals"""
	while spawning_active:
		# Wait random time
		var wait_time = randf_range(min_spawn_interval, max_spawn_interval)
		await get_tree().create_timer(wait_time).timeout
		
		# Check if we're at max capacity
		_update_customer_count()
		
		
		# Spawn random customer type
		var spawn_type1 = randf() < continuous_spawn_ratio
		
		if spawn_type1:
			_spawn_customer_without_cart()
		else:
			_spawn_customer_with_cart()
		

func _update_customer_count():
	"""Count how many customers are currently active"""
	active_customers = get_tree().get_nodes_in_group("ai_customer").size()

func _spawn_customer_without_cart():
	if not customer_scene:
		return
	
	# Use cached spawn points (no scene tree search!)
	if cached_type1_spawns.is_empty():
		return
	
	var spawn_point = cached_type1_spawns[randi() % cached_type1_spawns.size()]
	
	var customer = customer_scene.instantiate()
	customer.customer_type = 0  # WITHOUT_CART
	customer.add_to_group("ai_customer")  # Track for counting
	get_tree().current_scene.add_child(customer)
	customer.global_position = spawn_point.global_position
	
	if not cached_parking_spots.is_empty() and shopping_cart_scene:
		var parking_spot = cached_parking_spots[randi() % cached_parking_spots.size()]
		var cart = await _spawn_cart(parking_spot.global_position)
		customer.attach_cart(cart)
		await _fill_cart_with_items_async(cart)  # ASYNC version to prevent lag!
	
	active_customers += 1

func _spawn_customer_with_cart():
	if not customer_scene:
		return
	
	# Use cached spawn points (no scene tree search!)
	if cached_type2_spawns.is_empty():
		return
	
	var spawn_point = cached_type2_spawns[randi() % cached_type2_spawns.size()]
	
	var customer = customer_scene.instantiate()
	customer.customer_type = 1  # WITH_CART
	customer.add_to_group("ai_customer")  # Track for counting
	get_tree().current_scene.add_child(customer)
	customer.global_position = spawn_point.global_position
	
	if shopping_cart_scene:
		var cart = await _spawn_cart(spawn_point.global_position)
		customer.attach_cart(cart)
		await _fill_cart_with_items_async(cart)  # ASYNC version to prevent lag!
	
	active_customers += 1

func _spawn_cart(spawn_pos: Vector3):
	var cart = shopping_cart_scene.instantiate()
	if not is_inside_tree(): return null
	get_tree().current_scene.add_child(cart)
	await get_tree().process_frame
	cart.global_position = spawn_pos
	return cart

func _fill_cart_with_items_async(cart):
	"""ASYNC version - spawns items over multiple frames to prevent lag spikes!"""
	if available_items.is_empty():
		return
	
	if not is_inside_tree(): return
	await get_tree().process_frame
	
	var num_items = randi_range(min_items_per_cart, max_items_per_cart)
	
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	var is_loading = loading_manager.is_loading() if loading_manager else false
	
	for i in range(num_items):
		if not is_instance_valid(cart) or not is_inside_tree():
			return
			
		var random_item_scene = available_items[randi() % available_items.size()]
		
		if not random_item_scene:
			continue
		
		var item = null
		if loading_manager:
			item = loading_manager.request_item(random_item_scene)
		else:
			item = random_item_scene.instantiate()
			
		if not item:
			continue
		
		if not item.is_inside_tree():
			get_tree().current_scene.add_child(item)
		
		if cart.has_method("add_item"):
			if not cart.add_item(item):
				item.queue_free()
		else:
			item.queue_free()
		
		# Only yield if not loading and we've spawned a few
		if not is_loading and i % 3 == 0:
			if not is_inside_tree(): return
			await get_tree().process_frame

func stop_spawning():
	"""Stop continuous spawning"""
	spawning_active = false

func resume_spawning():
	"""Resume continuous spawning"""
	if not spawning_active and enable_continuous_spawning:
		spawning_active = true
		_continuous_spawn_loop()

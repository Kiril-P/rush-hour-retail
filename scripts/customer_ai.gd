extends CharacterBody3D
class_name CustomerAI

## AI Customer - Walks around store with NavMesh pathfinding
## Two types: With cart or without cart

enum CustomerType {
	WITHOUT_CART,  # Parks cart somewhere, walks around
	WITH_CART      # Pushes cart while walking
}

@export var customer_type: CustomerType = CustomerType.WITHOUT_CART
@export var movement_speed: float = 1.5
@export var rotation_speed: float = 5.0
@export var min_stop_time: float = 2.0
@export var max_stop_time: float = 10.0
@export var stops_before_leaving: int = 4
@export var wander_radius: float = 15.0  # How far from spawn to wander

# Cart settings (for WITH_CART type)
@export var cart_offset: Vector3 = Vector3(0, 0, 0.8)  # Cart in front of customer

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var shopping_cart: ShoppingCart = null
var spawn_position: Vector3
var current_stops: int = 0
var is_stopping: bool = false
var stop_timer: float = 0.0
var current_state: String = "IDLE"

# Target tracking
var current_target: Vector3
var shelf_to_face: Node3D = null

func _ready():
	spawn_position = global_position
	
	# Configure NavigationAgent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.4
	
	# Set up collision
	collision_layer = 2  # Customer layer
	collision_mask = 1 + 2  # Collides with world and other customers
	
	print("🚶 Customer spawned: ", name)
	print("  Type: ", "WITH CART" if customer_type == CustomerType.WITH_CART else "WITHOUT CART")
	
	# Wait for navigation to be ready
	await get_tree().physics_frame
	
	# Start wandering
	_pick_random_destination()

func _physics_process(delta):
	match current_state:
		"IDLE":
			_state_idle(delta)
		"WALKING":
			_state_walking(delta)
		"STOPPING":
			_state_stopping(delta)
		"LEAVING":
			_state_leaving(delta)

func _state_idle(delta):
	"""Waiting before starting to walk"""
	# This state is brief, just transition immediately
	current_state = "WALKING"

func _state_walking(delta):
	"""Walking to destination"""
	if nav_agent.is_navigation_finished():
		# Reached destination
		if current_stops < stops_before_leaving:
			# Stop and look at shelves
			_start_stopping()
		else:
			# Done shopping, head to exit
			_start_leaving()
		return
	
	# Get next path position
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	# Move towards target
	velocity = direction * movement_speed
	move_and_slide()
	
	# Rotate to face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	# Update cart position if WITH_CART type
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

func _state_stopping(delta):
	"""Stopped at a shelf, looking at items"""
	velocity = Vector3.ZERO
	move_and_slide()
	
	# Face the shelf
	if shelf_to_face:
		var direction = (shelf_to_face.global_position - global_position).normalized()
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	# Count down stop timer
	stop_timer -= delta
	
	if stop_timer <= 0:
		# Done stopping, pick new destination
		current_stops += 1
		print("  🛍️ Customer finished stop ", current_stops, "/", stops_before_leaving)
		current_state = "WALKING"
		_pick_random_destination()

func _state_leaving(delta):
	"""Walking to exit"""
	if nav_agent.is_navigation_finished():
		# Reached exit, despawn
		print("  👋 Customer leaving: ", name)
		_despawn()
		return
	
	# Walk to exit (same as walking state)
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	velocity = direction * movement_speed
	move_and_slide()
	
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	# Update cart
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

func _pick_random_destination():
	"""Pick a random point near a shelf to walk to"""
	# Find all shelf markers
	var shelf_markers = get_tree().get_nodes_in_group("shelf_stop_point")
	
	if shelf_markers.is_empty():
		# No shelf markers, just wander randomly
		var random_offset = Vector3(
			randf_range(-wander_radius, wander_radius),
			0,
			randf_range(-wander_radius, wander_radius)
		)
		current_target = spawn_position + random_offset
		shelf_to_face = null
	else:
		# Pick random shelf marker
		var random_shelf = shelf_markers[randi() % shelf_markers.size()]
		current_target = random_shelf.global_position
		
		# Try to find the shelf itself (parent or nearby)
		shelf_to_face = _find_nearby_shelf(random_shelf)
	
	nav_agent.target_position = current_target
	print("  🎯 Customer heading to: ", current_target)

func _find_nearby_shelf(marker: Node3D) -> Node3D:
	"""Find a shelf near the marker to face"""
	# Check if marker's parent is a shelf
	if marker.get_parent() and marker.get_parent().name.contains("Shelf"):
		return marker.get_parent()
	
	# Check for nearby objects with "shelf" in name
	var nearby = get_tree().get_nodes_in_group("shelf")
	var closest_shelf = null
	var closest_distance = 999.0
	
	for shelf in nearby:
		var distance = marker.global_position.distance_to(shelf.global_position)
		if distance < closest_distance and distance < 3.0:
			closest_distance = distance
			closest_shelf = shelf
	
	return closest_shelf

func _start_stopping():
	"""Start stopping at current location"""
	current_state = "STOPPING"
	stop_timer = randf_range(min_stop_time, max_stop_time)
	is_stopping = true
	
	print("  🛒 Customer stopping for ", "%.1f" % stop_timer, " seconds")

func _start_leaving():
	"""Head to exit and despawn"""
	current_state = "LEAVING"
	
	# Find exit marker
	var exit_markers = get_tree().get_nodes_in_group("customer_exit")
	
	if exit_markers.is_empty():
		# No exit, just despawn
		print("  ⚠️ No exit marker found, despawning immediately")
		_despawn()
		return
	
	# Pick closest exit
	var closest_exit = exit_markers[0]
	var closest_distance = global_position.distance_to(closest_exit.global_position)
	
	for exit in exit_markers:
		var distance = global_position.distance_to(exit.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_exit = exit
	
	nav_agent.target_position = closest_exit.global_position
	print("  🚪 Customer heading to exit")

func _update_cart_position():
	"""Update cart to follow customer (for WITH_CART type)"""
	if not shopping_cart:
		return
	
	# Calculate cart position (in front of customer)
	var cart_world_offset = global_transform.basis * cart_offset
	var target_pos = global_position + cart_world_offset
	
	# Set cart position and rotation
	shopping_cart.global_position = target_pos
	shopping_cart.global_rotation = global_rotation

func attach_cart(cart: ShoppingCart):
	"""Attach a shopping cart to this customer"""
	shopping_cart = cart
	
	if customer_type == CustomerType.WITH_CART:
		# For WITH_CART, make cart follow customer
		cart.freeze = true  # Disable physics
		cart.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_update_cart_position()
		print("  🛒 Customer attached to cart: ", cart.name)
	else:
		# For WITHOUT_CART, cart stays where it spawned
		cart.freeze = true
		print("  🅿️ Customer parked cart: ", cart.name)

func _despawn():
	"""Remove customer and cart from scene"""
	if shopping_cart:
		shopping_cart.queue_free()
	
	queue_free()

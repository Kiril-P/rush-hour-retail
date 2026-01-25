extends CharacterBody3D
class_name CustomerAI

## AI Customer - With visual adjustment markers!

enum CustomerType {
	WITHOUT_CART,
	WITH_CART
}

@export var customer_type: CustomerType = CustomerType.WITHOUT_CART
@export var movement_speed: float = 1.5
@export var rotation_speed: float = 5.0
@export var min_stop_time: float = 2.0
@export var max_stop_time: float = 10.0
@export var stops_before_leaving: int = 4

@export_group("Visual Adjustments")
@export var ground_height_offset: float = 0.0  # Adjust if floating/clipping
@export var cart_distance_forward: float = 0.8  # How far in front
@export var cart_height_offset: float = 0.0  # Height adjustment for cart
@export var cart_side_offset: float = 0.0  # Left/right offset

# Or use a marker for precise control!
@onready var cart_attach_point: Node3D = $CartAttachPoint if has_node("CartAttachPoint") else null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var shopping_cart: ShoppingCart = null
var spawn_position: Vector3
var current_stops: int = 0
var is_stopping: bool = false
var stop_timer: float = 0.0
var current_state: String = "IDLE"
var current_target: Vector3
var shelf_to_face: Node3D = null

static var cached_shelf_markers: Array = []
static var cached_exit_markers: Array = []
static var markers_cached: bool = false

func _ready():
	# Add to customer group for avoidance detection
	add_to_group("customer")
	
	spawn_position = global_position
	
	# Apply ground height offset
	global_position.y += ground_height_offset
	
	# Configure NavigationAgent (with slight randomization to prevent clustering)
	nav_agent.path_desired_distance = randf_range(0.4, 0.6)
	nav_agent.target_desired_distance = randf_range(0.4, 0.6)
	
	# PROPER AVOIDANCE SETUP
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5  # Slightly larger collision radius
	nav_agent.neighbor_distance = 3.0  # How far to look for neighbors
	nav_agent.max_neighbors = 10  # How many neighbors to avoid
	nav_agent.time_horizon_agents = 1.0  # Time to predict collisions with agents
	nav_agent.time_horizon_obstacles = 0.5  # Time to predict collisions with obstacles
	nav_agent.max_speed = movement_speed
	
	# Set avoidance layers (bit 1 = customers avoid each other)
	nav_agent.set_avoidance_layers(1)
	nav_agent.set_avoidance_mask(1)
	
	# Set up collision
	collision_layer = 2
	collision_mask = 1 + 2
	
	# Connect velocity computed signal for proper avoidance
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	
	# Cache markers once
	if not markers_cached:
		_cache_markers()
	
	await get_tree().physics_frame
	_pick_random_destination()

func _cache_markers():
	cached_shelf_markers = get_tree().get_nodes_in_group("shelf_stop_point")
	cached_exit_markers = get_tree().get_nodes_in_group("customer_exit")
	markers_cached = true
	

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
	current_state = "WALKING"

func _state_walking(delta):
	if nav_agent.is_navigation_finished():
		if current_stops < stops_before_leaving:
			_start_stopping()
		else:
			_start_leaving()
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	# USE NAVIGATION AGENT VELOCITY FOR AVOIDANCE
	var desired_velocity = direction * movement_speed
	nav_agent.velocity = desired_velocity
	# The actual movement happens in _on_velocity_computed()
	
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

func _state_stopping(delta):
	velocity = Vector3.ZERO
	move_and_slide()
	
	if shelf_to_face:
		var direction = (shelf_to_face.global_position - global_position).normalized()
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	stop_timer -= delta
	
	if stop_timer <= 0:
		current_stops += 1
		current_state = "WALKING"
		_pick_random_destination()

func _state_leaving(delta):
	if nav_agent.is_navigation_finished():
		_despawn()
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	# USE NAVIGATION AGENT VELOCITY FOR AVOIDANCE
	var desired_velocity = direction * movement_speed
	nav_agent.velocity = desired_velocity
	# The actual movement happens in _on_velocity_computed()
	
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

func _pick_random_destination():
	if cached_shelf_markers.is_empty():
		return
	
	var random_marker = cached_shelf_markers[randi() % cached_shelf_markers.size()]
	current_target = random_marker.global_position
	shelf_to_face = _find_nearby_shelf(random_marker)
	nav_agent.target_position = current_target

func _find_nearby_shelf(marker: Node3D) -> Node3D:
	if marker.get_parent() and "Shelf" in marker.get_parent().name:
		return marker.get_parent()
	return null

func _start_stopping():
	"""Start stopping at shelf - check for personal space first"""
	# Check if another customer is too close
	if _is_another_customer_nearby(1.5):
		_pick_random_destination()
		return
	
	current_state = "STOPPING"
	stop_timer = randf_range(min_stop_time, max_stop_time)
	is_stopping = true

func _start_leaving():
	"""Customer finished shopping, heading to exit"""
	current_state = "LEAVING"
	
	if cached_exit_markers.is_empty():
		_despawn()
		return
	
	var exit = cached_exit_markers[randi() % cached_exit_markers.size()]
	nav_agent.target_position = exit.global_position
	
func _update_cart_position():
	"""Update cart to follow customer - use marker if available!"""
	if not shopping_cart or not is_instance_valid(shopping_cart):
		return
	
	# Check if we still own the cart (player might have taken it)
	if shopping_cart.owner_customer != self:
		shopping_cart = null
		return
	
	var target_pos: Vector3
	
	# Option 1: Use CartAttachPoint marker (precise!)
	if cart_attach_point:
		target_pos = cart_attach_point.global_position
	else:
		# Option 2: Use export variables (manual adjustment)
		var forward_offset = global_transform.basis.z * -cart_distance_forward
		var side_offset_vec = global_transform.basis.x * cart_side_offset
		target_pos = global_position + forward_offset + side_offset_vec
		target_pos.y = global_position.y + cart_height_offset
	
	shopping_cart.global_position = target_pos
	shopping_cart.global_rotation = global_rotation

func attach_cart(cart: ShoppingCart):
	shopping_cart = cart
	cart.set_owner_customer(self)  # Register ownership
	
	if customer_type == CustomerType.WITH_CART:
		cart.freeze = true
		cart.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_update_cart_position()
	else:
		cart.freeze = true

func _despawn():
	"""Remove customer and cart from scene"""
	# Only delete cart if we still own it (player might have taken it)
	if shopping_cart and is_instance_valid(shopping_cart):
		# Check if cart is still owned by us
		if shopping_cart.owner_customer == self:
			shopping_cart.queue_free()
	
	queue_free()

func _on_velocity_computed(safe_velocity: Vector3):
	"""Called by NavigationAgent when avoidance velocity is computed"""
	# This is the velocity adjusted to avoid other agents
	velocity = safe_velocity
	move_and_slide()
	
	# BACKUP: Handle physical collisions if avoidance fails
	_handle_collision_push()

func _handle_collision_push():
	"""Push customers apart if they physically collide (backup to avoidance)"""
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If we collided with another customer, push away
		if collider is CustomerAI:
			var push_direction = (global_position - collider.global_position).normalized()
			push_direction.y = 0  # Keep push horizontal
			
			# Apply a small push away from the other customer
			var push_force = push_direction * 0.5
			velocity += push_force

func _is_another_customer_nearby(radius: float) -> bool:
	"""Check if another customer is within the given radius"""
	var customers = get_tree().get_nodes_in_group("customer")
	for customer in customers:
		if customer != self and customer is CustomerAI:
			var distance = global_position.distance_to(customer.global_position)
			if distance < radius:
				return true
	return false

func cart_taken_by_player():
	"""Called when player takes the cart from this customer"""
	print("🛒 Customer ", name, " lost their cart to player - leaving immediately!")
	
	# Clear cart reference
	shopping_cart = null
	
	# Immediately leave the store (angry customer!)
	current_state = "LEAVING"
	current_stops = stops_before_leaving  # Skip remaining shops
	
	if cached_exit_markers.is_empty():
		_despawn()
		return
	
	var exit = cached_exit_markers[randi() % cached_exit_markers.size()]
	nav_agent.target_position = exit.global_position

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
	spawn_position = global_position
	
	# Apply ground height offset
	global_position.y += ground_height_offset
	
	# Configure NavigationAgent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.4
	
	# Set up collision
	collision_layer = 2
	collision_mask = 1 + 2
	
	print("🚶 Customer spawned: ", name)
	print("  Type: ", "WITH CART" if customer_type == CustomerType.WITH_CART else "WITHOUT CART")
	
	# Cache markers once
	if not markers_cached:
		_cache_markers()
	
	await get_tree().physics_frame
	_pick_random_destination()

func _cache_markers():
	cached_shelf_markers = get_tree().get_nodes_in_group("shelf_stop_point")
	cached_exit_markers = get_tree().get_nodes_in_group("customer_exit")
	markers_cached = true
	
	print("📍 Cached ", cached_shelf_markers.size(), " shelf markers")
	print("🚪 Cached ", cached_exit_markers.size(), " exit markers")

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
	
	velocity = direction * movement_speed
	move_and_slide()
	
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
		print("  👋 Customer leaving: ", name)
		_despawn()
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	velocity = direction * movement_speed
	move_and_slide()
	
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
	current_state = "STOPPING"
	stop_timer = randf_range(min_stop_time, max_stop_time)
	is_stopping = true

func _start_leaving():
	"""Customer finished shopping, heading to exit"""
	current_state = "LEAVING"
	
	if cached_exit_markers.is_empty():
		print("  ⚠️ No exit marker, despawning")
		_despawn()
		return
	
	var exit = cached_exit_markers[randi() % cached_exit_markers.size()]
	nav_agent.target_position = exit.global_position
	print("  🚪 Customer ", name, " heading to exit after ", stops_before_leaving, " stops")

func _update_cart_position():
	"""Update cart to follow customer - use marker if available!"""
	if not shopping_cart:
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
	
	if customer_type == CustomerType.WITH_CART:
		cart.freeze = true
		cart.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_update_cart_position()
		print("  🛒 Cart attached to customer")
	else:
		cart.freeze = true
		print("  🅿️ Cart parked")

func _despawn():
	"""Remove customer and cart from scene"""
	if shopping_cart:
		shopping_cart.queue_free()
	
	queue_free()

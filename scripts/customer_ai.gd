extends CharacterBody3D
class_name CustomerAI

## AI Customer - With animated character models!
## 
## This system loads character models from res://assets/customer_char/ with animations.
## Each customer randomly selects one of 4 character variants on spawn.
## Character models are FBX files with embedded animations (idle, walk, extra).
## 
## The system automatically:
## - Loads the character mesh and skeleton from the idle FBX
## - Merges walk animation from the walk FBX
## - Detects and plays idle/walk animations based on movement state
## - Scales models appropriately (use character_scale export to adjust)
## 
## Visual adjustments can be made via exported variables or CartAttachPoint marker.

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
@export var character_scale: float = 0.01  # FBX models often need 0.01 or 1.0

# Character variant data - Each character has a model file + separate animation files
const CHARACTER_VARIANTS = [
	{
		"name": "Black Guy",
		"model": "res://assets/customer_char/black guy/LowPolyCharacter_BLACK.fbx",
		"idle": "res://assets/customer_char/black guy/Happy Idle.fbx",
		"walk": "res://assets/customer_char/black guy/Happy Walk.fbx"
	},
	{
		"name": "Gustave",
		"model": "res://assets/customer_char/gustave/LowPolyCharacter_GUSTAVE.fbx",
		"idle": "res://assets/customer_char/gustave/Breathing Idle.fbx",
		"walk": "res://assets/customer_char/gustave/Walking.fbx"
	},
	{
		"name": "Jew Hat",
		"model": "res://assets/customer_char/jew hat/LowPolyCharacter2_JEW.fbx",
		"idle": "res://assets/customer_char/jew hat/Dwarf Idle.fbx",
		"walk": "res://assets/customer_char/jew hat/Dwarf Walk.fbx"
	},
	{
		"name": "Woman",
		"model": "res://assets/customer_char/woman/LowPolyCharacter_WOMAN.fbx",
		"idle": "res://assets/customer_char/woman/Dwarf Idle.fbx",
		"walk": "res://assets/customer_char/woman/Female Tough Walk.fbx"
	}
]

# Fallback scene paths (if you create .tscn files later)
const CHARACTER_VARIANT_SCENES = [
	"res://scenes/characters/customer_black_guy.tscn",
	"res://scenes/characters/customer_gustave.tscn",
	"res://scenes/characters/customer_jew_hat.tscn",
	"res://scenes/characters/customer_woman.tscn"
]

# Or use a marker for precise control!
@onready var cart_attach_point: Node3D = $CartAttachPoint if has_node("CartAttachPoint") else null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var placeholder_mesh = $MeshInstance3D if has_node("MeshInstance3D") else null

var character_model: Node3D
var animation_player: AnimationPlayer
var last_animation: String = ""
var spawn_position: Vector3
var current_stops: int = 0
var is_stopping: bool = false
var stop_timer: float = 0.0
var current_state: String = "IDLE"
var current_target: Vector3
var shelf_to_face: Node3D = null
var selected_variant_index: int = -1
var idle_anim_name: String = ""
var walk_anim_name: String = ""
var shopping_cart: RigidBody3D = null

static var cached_shelf_markers: Array = []
static var cached_exit_markers: Array = []
static var markers_cached: bool = false

func _ready():
	# Add to customer group for avoidance detection
	add_to_group("customer")
	
	spawn_position = global_position
	
	# Setup character model
	_setup_character_model()
	
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
	
	
	# Cache markers (with validation check for scene reloads)
	if not markers_cached or not _validate_cached_markers():
		_cache_markers()
	
	await get_tree().physics_frame
	_pick_random_destination()

func _setup_character_model():
	"""Load character model and apply animations from separate FBX files"""
	# Pick a random character variant
	selected_variant_index = randi() % CHARACTER_VARIANTS.size()
	var variant = CHARACTER_VARIANTS[selected_variant_index]
	
	print("=== SETTING UP CHARACTER: ", variant["name"], " ===")
	
	# Try to load pre-configured scene first (if it exists)
	var scene_path = CHARACTER_VARIANT_SCENES[selected_variant_index]
	if ResourceLoader.exists(scene_path):
		print("Loading pre-configured scene: ", scene_path)
		var character_scene = load(scene_path)
		character_model = character_scene.instantiate()
		add_child(character_model)
		character_model.scale = Vector3.ONE * character_scale
		character_model.position.y = -0.9 * character_scale
		
		animation_player = _find_animation_player(character_model)
		if animation_player:
			var anims = animation_player.get_animation_list()
			for anim in anims:
				if not "RESET" in anim.to_upper():
					if idle_anim_name == "":
						idle_anim_name = anim
					elif walk_anim_name == "":
						walk_anim_name = anim
		
		if placeholder_mesh:
			placeholder_mesh.visible = false
		return
	
	# Load the character model FBX (contains mesh and skeleton)
	print("Loading model: ", variant["model"])
	var model_scene = load(variant["model"])
	if not model_scene:
		push_error("Failed to load character model!")
		return
	
	character_model = model_scene.instantiate()
	add_child(character_model)
	character_model.scale = Vector3.ONE * character_scale
	character_model.position.y = -0.9 * character_scale
	
	# Find skeleton and animation player
	var skeleton = _find_skeleton(character_model)
	animation_player = _find_animation_player(character_model)
	
	if not skeleton:
		push_error("No Skeleton3D found in model!")
		return
	
	if not animation_player:
		push_error("No AnimationPlayer found in model!")
		return
	
	print("Found Skeleton with ", skeleton.get_bone_count(), " bones")
	print("Found AnimationPlayer")
	
	# Configure AnimationPlayer
	animation_player.active = true
	animation_player.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Set root node for animations
	var armature = skeleton.get_parent()
	if armature:
		var relative_path = animation_player.get_path_to(armature)
		animation_player.root_node = relative_path
		print("Set AnimationPlayer root to: ", relative_path)
	
	# Load and merge animations from separate FBX files
	print("Loading idle animation: ", variant["idle"])
	_load_animation_from_fbx(variant["idle"], "idle", skeleton)
	
	print("Loading walk animation: ", variant["walk"])
	_load_animation_from_fbx(variant["walk"], "walk", skeleton)
	
	# Wait a frame for everything to be set up
	await get_tree().process_frame
	
	# Find the animations we just loaded
	var anim_list = animation_player.get_animation_list()
	print("Available animations: ", anim_list)
	
	# Detect idle and walk animations (skip RESET)
	for anim_name in anim_list:
		if "RESET" in anim_name.to_upper():
			continue
		
		var lower = anim_name.to_lower()
		if "idle" in lower and idle_anim_name == "":
			idle_anim_name = anim_name
			print("Set idle animation: ", idle_anim_name)
		elif ("walk" in lower or "locomotion" in lower) and walk_anim_name == "":
			walk_anim_name = anim_name
			print("Set walk animation: ", walk_anim_name)
	
	# Fallback to first available animations
	if idle_anim_name == "" and anim_list.size() > 0:
		for anim in anim_list:
			if not "RESET" in anim.to_upper():
				idle_anim_name = anim
				break
	
	if walk_anim_name == "":
		for anim in anim_list:
			if not "RESET" in anim.to_upper() and anim != idle_anim_name:
				walk_anim_name = anim
				break
	
	if walk_anim_name == "":
		walk_anim_name = idle_anim_name
	
	print("Final animations - idle: '", idle_anim_name, "', walk: '", walk_anim_name, "'")
	
	# Set animations to loop
	if animation_player.has_animation(idle_anim_name):
		var lib = animation_player.get_animation_library("")
		if lib:
			var anim = lib.get_animation(idle_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	
	if animation_player.has_animation(walk_anim_name):
		var lib = animation_player.get_animation_library("")
		if lib:
			var anim = lib.get_animation(walk_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	
	# Start playing idle animation
	if animation_player.has_animation(idle_anim_name):
		animation_player.play(idle_anim_name)
		print("Started playing: ", idle_anim_name)
		last_animation = idle_anim_name
	
	# Hide placeholder
	if placeholder_mesh:
		placeholder_mesh.visible = false

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively find AnimationPlayer in the node hierarchy"""
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	"""Recursively find Skeleton3D in the node hierarchy"""
	if node is Skeleton3D:
		return node
	
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	
	return null

func _load_animation_from_fbx(fbx_path: String, anim_prefix: String, target_skeleton: Skeleton3D):
	"""Load animation from a separate FBX file and add it to the AnimationPlayer"""
	var anim_scene = load(fbx_path)
	if not anim_scene:
		push_error("Failed to load animation FBX: ", fbx_path)
		return
	
	# Instantiate the animation FBX temporarily
	var temp_instance = anim_scene.instantiate()
	var temp_anim_player = _find_animation_player(temp_instance)
	
	if not temp_anim_player:
		push_error("No AnimationPlayer in animation FBX: ", fbx_path)
		temp_instance.queue_free()
		return
	
	# Get the animation library
	var library_names = temp_anim_player.get_animation_library_list()
	
	for lib_name in library_names:
		var temp_library = temp_anim_player.get_animation_library(lib_name)
		if not temp_library:
			continue
		
		var anim_list = temp_library.get_animation_list()
		
		for anim_name in anim_list:
			# Skip RESET animations
			if "RESET" in anim_name.to_upper():
				continue
			
			var animation = temp_library.get_animation(anim_name)
			if not animation:
				continue
			
			# Create a new name for this animation
			var new_anim_name = anim_prefix + "_" + anim_name
			
			# Duplicate the animation so we can modify it
			var anim_copy = animation.duplicate()
			
			# Remove root motion from walk animations (keep character in place)
			if anim_prefix == "walk":
				_remove_root_motion(anim_copy)
			
			# Get or create the animation library in our main AnimationPlayer
			var main_library = null
			if animation_player.has_animation_library(""):
				main_library = animation_player.get_animation_library("")
			else:
				main_library = AnimationLibrary.new()
				animation_player.add_animation_library("", main_library)
			
			# Add the animation
			if not main_library.has_animation(new_anim_name):
				main_library.add_animation(new_anim_name, anim_copy)
				print("  Added animation: ", new_anim_name, " (", animation.get_track_count(), " tracks)")
	
	temp_instance.queue_free()

func _remove_root_motion(animation: Animation):
	"""Remove forward/sideways motion from animation (keep vertical movement for bobbing)"""
	# Find the Hips/Root bone track and remove X/Z position animation
	for track_idx in range(animation.get_track_count()):
		var track_path = animation.track_get_path(track_idx)
		var track_path_str = str(track_path)
		
		# Check if this is the root/hips position track
		if "Hips" in track_path_str or "hips" in track_path_str:
			var track_type = animation.track_get_type(track_idx)
			
			# Type 1 = Position3D track
			if track_type == Animation.TYPE_POSITION_3D:
				# Get the first keyframe position as the "in-place" position
				if animation.track_get_key_count(track_idx) > 0:
					var first_pos = animation.track_get_key_value(track_idx, 0)
					
					# Set all keyframes to have the same X and Z (remove forward movement)
					# But keep Y animation for natural bobbing
					for key_idx in range(animation.track_get_key_count(track_idx)):
						var current_pos = animation.track_get_key_value(track_idx, key_idx)
						var new_pos = Vector3(first_pos.x, current_pos.y, first_pos.z)
						animation.track_set_key_value(track_idx, key_idx, new_pos)
					
					print("  Removed root motion from Hips track (kept vertical bob)")
				break

func _print_node_hierarchy(node: Node, indent: int):
	"""Debug helper to print node hierarchy"""
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	print(indent_str, node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_node_hierarchy(child, indent + 1)

func _play_animation(anim_type: String):
	"""Play the specified animation type (idle or walk)"""
	# If using pre-configured character model, use its methods
	if character_model and character_model is CustomerCharacterModel:
		if anim_type == "idle":
			character_model.play_idle()
		elif anim_type == "walk":
			character_model.play_walk()
		return
	
	# Otherwise use direct AnimationPlayer control (fallback/old method)
	if not animation_player:
		return
	
	var target_anim = ""
	
	match anim_type:
		"idle":
			target_anim = idle_anim_name
		"walk":
			target_anim = walk_anim_name
	
	if target_anim == "":
		return
	
	# Only change animation if different from current
	if target_anim != last_animation:
		if animation_player.has_animation(target_anim):
			animation_player.play(target_anim)
			last_animation = target_anim
		else:
			if get_tree().get_frame() % 120 == 0:  # Don't spam console
				print("Animation not found: ", target_anim)

func _validate_cached_markers() -> bool:
	"""Check if cached markers are still valid (not freed after scene reload)"""
	if cached_shelf_markers.is_empty() or cached_exit_markers.is_empty():
		return false
	
	# Check if first marker is still valid
	if cached_shelf_markers.size() > 0 and not is_instance_valid(cached_shelf_markers[0]):
		return false
	
	return true

func _cache_markers():
	"""Cache markers and clear old invalid ones"""
	cached_shelf_markers.clear()
	cached_exit_markers.clear()
	
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
	_play_animation("idle")
	current_state = "WALKING"

func _state_walking(delta):
	_play_animation("walk")
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
	_play_animation("idle")
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
	_play_animation("walk")
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
	
	# SAFETY CHECK: Validate marker before accessing (fixes scene reload crash)
	if not is_instance_valid(random_marker):
		# Marker was freed, re-cache and try again
		_cache_markers()
		if cached_shelf_markers.is_empty():
			return
		random_marker = cached_shelf_markers[randi() % cached_shelf_markers.size()]
		if not is_instance_valid(random_marker):
			return
	
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
	
	# SAFETY CHECK: Validate exit marker before accessing
	if not is_instance_valid(exit):
		# Exit was freed, re-cache and try again
		_cache_markers()
		if cached_exit_markers.is_empty():
			_despawn()
			return
		exit = cached_exit_markers[randi() % cached_exit_markers.size()]
		if not is_instance_valid(exit):
			_despawn()
			return
	
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
	"""Remove customer and cart from scene - ASYNC cleanup to prevent lag"""
	# Only delete cart if we still own it (player might have taken it)
	if shopping_cart and is_instance_valid(shopping_cart):
		# Check if cart is still owned by us
		if shopping_cart.owner_customer == self:
			# ASYNC: Free cart items first, then cart
			await _cleanup_cart_async(shopping_cart)
	
	# Free customer
	queue_free()

func _cleanup_cart_async(cart: ShoppingCart):
	"""Async cart cleanup - returns items to pool over multiple frames"""
	if not cart or not is_instance_valid(cart):
		return
	
	# Return items to pool
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	var items_to_free = cart.stored_items.duplicate()
	for item in items_to_free:
		if is_instance_valid(item):
			if loading_manager:
				loading_manager.despawn_item(item)
			else:
				item.queue_free()
		# Wait a frame between freeing items (prevents lag spike)
		await get_tree().process_frame
	
	# Finally free the cart itself (we could pool carts too, but items are the main lag)
	cart.queue_free()

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
	# Clear cart reference
	shopping_cart = null
	
	# Immediately leave the store (angry customer!)
	current_state = "LEAVING"
	current_stops = stops_before_leaving  # Skip remaining shops
	
	if cached_exit_markers.is_empty():
		_despawn()
		return
	
	var exit = cached_exit_markers[randi() % cached_exit_markers.size()]
	
	# SAFETY CHECK: Validate exit marker before accessing
	if not is_instance_valid(exit):
		_cache_markers()
		if cached_exit_markers.is_empty():
			_despawn()
			return
		exit = cached_exit_markers[randi() % cached_exit_markers.size()]
		if not is_instance_valid(exit):
			_despawn()
			return
	
	nav_agent.target_position = exit.global_position

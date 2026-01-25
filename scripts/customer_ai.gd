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

enum CustomerState {
	IDLE,
	WALKING,
	STOPPING,
	LEAVING,
	FALLING,  # Being knocked back
	AGGRESSIVE,  # Chasing player
	ATTACKING  # Attacking player
}

@export var customer_type: CustomerType = CustomerType.WITHOUT_CART
@export var movement_speed: float = 1.5
@export var rotation_speed: float = 5.0
@export var min_stop_time: float = 2.0
@export var max_stop_time: float = 10.0
@export var stops_before_leaving: int = 4

@export_group("Knockback Settings")
@export var knockback_force: float = 2.0  # Reduced - just a small push to trigger fall animation
@export var knockback_duration: float = 0.3  # Shorter duration
@export var fall_recovery_time: float = 1.5

@export_group("Aggression Settings")
@export var aggression_chance: float = 0.4  # 40% chance to get angry when punched
@export var chase_speed: float = 3.0  # Faster than normal walk
@export var attack_range: float = 1.5  # Distance to attack player
@export var attack_knockback: float = 10.0  # Knockback force to player
@export var calm_down_time: float = 15.0  # Time before calming down if lose player
@export var lose_player_distance: float = 20.0  # Distance where they lose track of player

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
		"walk": "res://assets/customer_char/black guy/Happy Walk.fbx",
		"walk_cart": "res://assets/customer_char/black guy/shopping_cart_walk.fbx",
		"fall": "res://assets/customer_char/black guy/Sweep Fall.fbx",
		"run": "res://assets/customer_char/black guy/Injured Run.fbx"
	},
	{
		"name": "Gustave",
		"model": "res://assets/customer_char/gustave/LowPolyCharacter_GUSTAVE.fbx",
		"idle": "res://assets/customer_char/gustave/Breathing Idle.fbx",
		"walk": "res://assets/customer_char/gustave/Walking.fbx",
		"walk_cart": "res://assets/customer_char/gustave/shopping_cart_walk.fbx",
		"fall": "res://assets/customer_char/gustave/Sweep Fall.fbx",
		"run": "res://assets/customer_char/gustave/Injured Run.fbx"
	},
	{
		"name": "Jew Hat",
		"model": "res://assets/customer_char/jew hat/LowPolyCharacter2_JEW.fbx",
		"idle": "res://assets/customer_char/jew hat/Dwarf Idle.fbx",
		"walk": "res://assets/customer_char/jew hat/Dwarf Walk.fbx",
		"walk_cart": "res://assets/customer_char/jew hat/shopping_cart_walk.fbx",
		"fall": "res://assets/customer_char/jew hat/Sweep Fall.fbx",
		"run": "res://assets/customer_char/jew hat/Injured Run.fbx"
	},
	{
		"name": "Woman",
		"model": "res://assets/customer_char/woman/LowPolyCharacter_WOMAN.fbx",
		"idle": "res://assets/customer_char/woman/Dwarf Idle.fbx",
		"walk": "res://assets/customer_char/woman/Female Tough Walk.fbx",
		"walk_cart": "res://assets/customer_char/woman/shopping_cart_walk.fbx",
		"fall": "res://assets/customer_char/woman/Sweep Fall.fbx",
		"run": "res://assets/customer_char/woman/Injured Run.fbx"
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
var walk_cart_anim_name: String = ""  # Animation for walking with shopping cart
var fall_anim_name: String = ""  # Animation for falling/being knocked back
var run_anim_name: String = ""  # Animation for aggressive running
var shopping_cart: RigidBody3D = null

# Knockback state variables
var is_knocked_back: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_timer: float = 0.0
var recovery_timer: float = 0.0
var previous_state: String = "IDLE"

# Aggression state variables
var is_aggressive: bool = false
var target_player: CharacterBody3D = null
var aggression_timer: float = 0.0
var has_attacked: bool = false
var anger_particle: Node3D = null

static var cached_shelf_markers: Array = []
static var cached_exit_markers: Array = []
static var markers_cached: bool = false

func _ready():
	# Add to customer group for avoidance detection
	add_to_group("customer")
	add_to_group("punchable")  # For player interaction
	
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
	
	# Try to load pre-configured scene first (if it exists)
	var scene_path = CHARACTER_VARIANT_SCENES[selected_variant_index]
	if ResourceLoader.exists(scene_path):
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
	
	# Configure AnimationPlayer
	animation_player.active = true
	animation_player.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Set root node for animations
	var armature = skeleton.get_parent()
	if armature:
		var relative_path = animation_player.get_path_to(armature)
		animation_player.root_node = relative_path
	
	# Load and merge animations from separate FBX files
	_load_animation_from_fbx(variant["idle"], "idle", skeleton)
	_load_animation_from_fbx(variant["walk"], "walk", skeleton)
	_load_animation_from_fbx(variant["walk_cart"], "walk_cart", skeleton)
	_load_animation_from_fbx(variant["fall"], "fall", skeleton)
	_load_animation_from_fbx(variant["run"], "run", skeleton)
	
	# Wait a frame for everything to be set up
	await get_tree().process_frame
	
	# Find the animations we just loaded
	var anim_list = animation_player.get_animation_list()
	
	# Detect idle and walk animations (skip RESET)
	for anim_name in anim_list:
		if "RESET" in anim_name.to_upper():
			continue
		
		var lower = anim_name.to_lower()
		if "idle" in lower and idle_anim_name == "":
			idle_anim_name = anim_name
		elif "walk_cart" in lower and walk_cart_anim_name == "":
			walk_cart_anim_name = anim_name
		elif ("walk" in lower or "locomotion" in lower) and walk_anim_name == "":
			walk_anim_name = anim_name
		elif ("fall" in lower or "sweep" in lower) and fall_anim_name == "":
			fall_anim_name = anim_name
		elif ("run" in lower or "injured" in lower) and run_anim_name == "":
			run_anim_name = anim_name
	
	# Fallback to first available animations
	if idle_anim_name == "" and anim_list.size() > 0:
		for anim in anim_list:
			if not "RESET" in anim.to_upper():
				idle_anim_name = anim
				break
	
	if walk_anim_name == "":
		for anim in anim_list:
			if not "RESET" in anim.to_upper() and anim != idle_anim_name and anim != walk_cart_anim_name:
				walk_anim_name = anim
				break
	
	if walk_anim_name == "":
		walk_anim_name = idle_anim_name
	
	# Fallback for cart animation
	if walk_cart_anim_name == "":
		walk_cart_anim_name = walk_anim_name  # Use regular walk if no cart animation
	
	if fall_anim_name == "":
		fall_anim_name = idle_anim_name  # Fallback to idle if no fall animation
	
	if run_anim_name == "":
		run_anim_name = walk_anim_name  # Fallback to walk if no run animation
	
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
	
	if animation_player.has_animation(walk_cart_anim_name):
		var lib = animation_player.get_animation_library("")
		if lib:
			var anim = lib.get_animation(walk_cart_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	
	if animation_player.has_animation(fall_anim_name):
		var lib = animation_player.get_animation_library("")
		if lib:
			var anim = lib.get_animation(fall_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE  # Fall animation shouldn't loop
	
	if animation_player.has_animation(run_anim_name):
		var lib = animation_player.get_animation_library("")
		if lib:
			var anim = lib.get_animation(run_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR  # Run animation should loop
	
	# Start playing idle animation
	if animation_player.has_animation(idle_anim_name):
		animation_player.play(idle_anim_name)
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
			
			# Remove root motion from walk and run animations (keep character in place)
			if anim_prefix == "walk" or anim_prefix == "walk_cart" or anim_prefix == "run":
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
	"""Play the specified animation type (idle or walk or fall or run)"""
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
			# Use shopping cart animation if customer has a cart
			if customer_type == CustomerType.WITH_CART and shopping_cart and is_instance_valid(shopping_cart):
				target_anim = walk_cart_anim_name
			else:
				target_anim = walk_anim_name
		"fall":
			target_anim = fall_anim_name
		"run":
			target_anim = run_anim_name
	
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
		"FALLING":
			_state_falling(delta)
		"AGGRESSIVE":
			_state_aggressive(delta)
		"ATTACKING":
			_state_attacking(delta)

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

func _state_falling(delta):
	"""Handle knockback/falling state - minimal movement, focus on animation"""
	_play_animation("fall")
	
	# Apply knockback velocity (but decay it very quickly)
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		
		# Rapidly reduce knockback to almost nothing
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 10.0)
	else:
		# Knockback finished, stop all movement immediately
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		move_and_slide()
		
		recovery_timer -= delta
		if recovery_timer <= 0:
			# Recovery complete, return to previous state
			is_knocked_back = false
			current_state = previous_state
			
			# If they were navigating, resume navigation
			if current_state == "WALKING" or current_state == "LEAVING":
				if nav_agent.target_position != Vector3.ZERO:
					# Re-enable navigation
					nav_agent.set_velocity(Vector3.ZERO)

func _state_aggressive(delta):
	"""Chase the player aggressively"""
	_play_animation("run")
	
	# Find player if we don't have a reference
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
		else:
			# No player found, calm down
			_become_calm()
			return
	
	# Check distance to player
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	# Too far away? Calm down
	if distance_to_player > lose_player_distance:
		aggression_timer += delta
		if aggression_timer > calm_down_time:
			_become_calm()
			return
	else:
		aggression_timer = 0  # Reset timer if player is nearby
	
	# Close enough to attack?
	if distance_to_player < attack_range and not has_attacked:
		current_state = "ATTACKING"
		has_attacked = true
		_attack_player()
		return
	
	# Update navigation to chase player
	nav_agent.target_position = target_player.global_position
	
	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		
		# Move faster when aggressive
		var desired_velocity = direction * chase_speed
		nav_agent.velocity = desired_velocity
		
		# Face player
		if direction.length() > 0.1:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed * 1.5)

func _state_attacking(delta):
	"""Playing attack animation"""
	_play_animation("run")  # Keep running animation
	
	# Attack happens instantly when entering this state
	# After a short delay, become calm
	await get_tree().create_timer(0.5).timeout
	_become_calm()

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

func apply_knockback(from_position: Vector3, force_multiplier: float = 1.0):
	"""Apply knockback to customer from a punch/push"""
	if is_knocked_back:
		return  # Already knocked back
	
	# Save current state to return to later
	previous_state = current_state
	
	# Enter falling state
	current_state = "FALLING"
	is_knocked_back = true
	
	# Calculate knockback direction (away from punch source)
	var knockback_dir = (global_position - from_position).normalized()
	knockback_dir.y = 0  # Keep it horizontal
	
	# Apply force
	knockback_velocity = knockback_dir * knockback_force * force_multiplier
	knockback_timer = knockback_duration
	recovery_timer = fall_recovery_time
	
	# Play hit sound
	_play_hit_sound()
	
	# Spawn impact particles
	_spawn_impact_particles()
	
	# Chance to become aggressive after recovering
	if randf() < aggression_chance:
		# Will become aggressive after falling
		previous_state = "AGGRESSIVE"

func _become_aggressive():
	"""Transition to aggressive/chasing state"""
	is_aggressive = true
	current_state = "AGGRESSIVE"
	has_attacked = false
	aggression_timer = 0.0
	
	# Drop shopping cart if we have one
	if shopping_cart and is_instance_valid(shopping_cart):
		shopping_cart.set_owner_customer(null)
		shopping_cart = null
	
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]
	
	# Play angry sound
	_play_angry_sound()
	
	# Spawn anger particle effect
	_spawn_anger_particles()

func _become_calm():
	"""Return to normal shopping behavior"""
	is_aggressive = false
	has_attacked = false
	target_player = null
	aggression_timer = 0.0
	
	# Remove anger particles
	if anger_particle:
		anger_particle.queue_free()
		anger_particle = null
	
	# Return to walking state and pick a new destination
	current_state = "WALKING"
	_pick_random_destination()

func _attack_player():
	"""Attack the player - push them back and stun them"""
	if not target_player or not is_instance_valid(target_player):
		_become_calm()
		return
	
	# Calculate direction to push player
	var push_dir = (target_player.global_position - global_position).normalized()
	push_dir.y = 0
	
	# Tell player they got hit
	if target_player.has_method("take_customer_attack"):
		target_player.take_customer_attack(push_dir * attack_knockback, global_position)

func _play_hit_sound():
	"""Play the MLG hitmarker sound effect"""
	var audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	var hit_sound = load("res://assets/sfx/MLG Hitmarker Sound Effect.mp3")
	if hit_sound:
		audio_player.stream = hit_sound
		audio_player.volume_db = 0
		audio_player.max_distance = 20.0
		audio_player.play()
		
		# Auto-delete after playing
		await audio_player.finished
		audio_player.queue_free()

func _play_angry_sound():
	"""Play angry Roblox sound effect"""
	var audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	var angry_sound = load("res://assets/sfx/Roblox Angry Sound Effect.mp3")
	if angry_sound:
		audio_player.stream = angry_sound
		audio_player.volume_db = 5
		audio_player.max_distance = 25.0
		audio_player.play()
		
		# Auto-delete after playing
		await audio_player.finished
		audio_player.queue_free()

func _spawn_impact_particles():
	"""Spawn impact particles at hit location"""
	# Create simple particle burst
	var particles = CPUParticles3D.new()
	add_child(particles)
	particles.position = Vector3(0, 1, 0)  # At chest height
	
	# Configure particles
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	
	# Particle properties
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.2
	
	# Color (orange/red impact effect)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0.5, 0, 1))  # Orange
	gradient.add_point(1.0, Color(1, 0, 0, 0))     # Fade to transparent red
	particles.color_ramp = gradient
	
	# Auto-delete after particles finish
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()

func _spawn_anger_particles():
	"""Spawn exclamation mark / anger effect above customer's head"""
	# Create particle effect that stays active
	var particles = CPUParticles3D.new()
	add_child(particles)
	particles.position = Vector3(0, 2, 0)  # Above head
	anger_particle = particles
	
	# Configure continuous anger particles
	particles.emitting = true
	particles.amount = 8
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3
	
	# Particle properties - floating upward
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 20
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.0
	particles.gravity = Vector3(0, 0.5, 0)  # Slight upward float
	particles.scale_amount_min = 0.15
	particles.scale_amount_max = 0.25
	
	# Red angry color
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0, 0, 1))      # Bright red
	gradient.add_point(0.5, Color(1, 0.3, 0, 1))    # Orange-red
	gradient.add_point(1.0, Color(0.8, 0, 0, 0))    # Fade out
	particles.color_ramp = gradient

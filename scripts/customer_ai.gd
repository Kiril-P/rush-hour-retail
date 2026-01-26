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
var _current_animation_type: String = "" 

static var cached_shelf_markers: Array = []
static var cached_exit_markers: Array = []
static var markers_cached: bool = false

# PERFORMANCE FIX: Preload audio to prevent frame spikes from runtime loading
static var _hit_sound_cached: AudioStream = null
static var _angry_sound_cached: AudioStream = null

# ANTI-STUCK: Track position to detect when customer is stuck
var _last_position: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
const STUCK_THRESHOLD: float = 0  # How little movement counts as stuck (reduced)
const STUCK_TELEPORT_TIME: float = 3.5  # How long stuck before teleporting (increased from 2.0)
const TELEPORT_DISTANCE: float = 0.8  # How far to teleport forward (reduced)

# PERFORMANCE FIX: Throttle navigation updates to reduce frame spikes
var _path_update_timer: float = 0.0
var _cached_path_position: Vector3 = Vector3.ZERO
const PATH_UPDATE_INTERVAL: float = 2.0  # Update path every 2 seconds for performance

# PERFORMANCE FIX: Store computed velocity to apply in _physics_process instead of callback
var _avoidance_velocity: Vector3 = Vector3.ZERO
var _has_avoidance_velocity: bool = false

# Cache player reference
static var _cached_player: CharacterBody3D = null
static var _player_cache_valid: bool = false

# Path calculation queue - limits how many paths are calculated per frame
static var _path_queue: Array[CustomerAI] = []
static var _exit_queue: Array[CustomerAI] = []
static var _last_queue_process_frame: int = -1
const MAX_PATH_CALCS_PER_FRAME: int = 3

# Preloaded character models
static var _models_preloaded: bool = false
static var _preloaded_models: Array[PackedScene] = []
static var _preloaded_anims: Dictionary = {}

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
	
	# PERFORMANCE FIX: DISABLE AVOIDANCE COMPLETELY
	# The NavigationServer avoidance system is expensive and causes cascading lag
	# We'll use simple direct movement instead - customers will clip through each other
	# but this is MUCH faster and prevents the lag spikes
	nav_agent.avoidance_enabled = false
	nav_agent.max_speed = movement_speed
	
	# Set up collision - NO collision with anything except world geometry
	# This prevents physics cascade when player moves through crowds
	collision_layer = 2  # Customers are on layer 2
	collision_mask = 1   # Only collide with world (layer 1), not player or other customers
	
	# NOTE: velocity_computed signal no longer connected since avoidance is disabled
	
	
	# Cache markers (with validation check for scene reloads)
	if not markers_cached or not _validate_cached_markers():
		_cache_markers()
	
	await get_tree().physics_frame
	_pick_random_destination()

static func preload_all_models():
	"""PERFORMANCE FIX: Preload all character models at game start to avoid runtime spikes.
	Call this during a loading screen for best results."""
	if _models_preloaded:
		return
	
	print("CustomerAI: Preloading all character models...")
	
	# Preload all model scenes
	for i in range(CHARACTER_VARIANTS.size()):
		var variant = CHARACTER_VARIANTS[i]
		
		# Preload main model
		var model_scene = load(variant["model"])
		if model_scene:
			_preloaded_models.append(model_scene)
		else:
			_preloaded_models.append(null)
		
		# Preload all animation FBX files
		_preloaded_anims[i] = {
			"idle": load(variant["idle"]),
			"walk": load(variant["walk"]),
			"walk_cart": load(variant["walk_cart"]),
			"fall": load(variant["fall"]),
			"run": load(variant["run"])
		}
	
	# Also preload audio
	if _hit_sound_cached == null:
		_hit_sound_cached = load("res://assets/sfx/MLG Hitmarker Sound Effect.mp3")
	if _angry_sound_cached == null:
		_angry_sound_cached = load("res://assets/sfx/Roblox Angry Sound Effect.mp3")
	
	_models_preloaded = true
	print("CustomerAI: All models preloaded!")

func _setup_character_model():
	"""Load character model and apply animations from separate FBX files"""
	# PERFORMANCE FIX: Ensure models are preloaded (first customer triggers this)
	if not _models_preloaded:
		preload_all_models()
	
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
	
<<<<<<< HEAD
	# PERFORMANCE FIX: Use preloaded model instead of loading at runtime
	var model_scene = _preloaded_models[selected_variant_index] if selected_variant_index < _preloaded_models.size() else null
	if not model_scene:
		# Fallback to loading if preload failed
		model_scene = load(variant["model"])
=======
	# Load the character model FBX (contains mesh and skeleton)
	print("Loading model: ", variant["model"])
	var model_scene = load(variant["model"])
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)
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
	
<<<<<<< HEAD
	# PERFORMANCE FIX: Use preloaded animations instead of loading at runtime
	var preloaded = _preloaded_anims.get(selected_variant_index, {})
	_load_animation_from_fbx_cached(preloaded.get("idle"), variant["idle"], "idle", skeleton)
	_load_animation_from_fbx_cached(preloaded.get("walk"), variant["walk"], "walk", skeleton)
	_load_animation_from_fbx_cached(preloaded.get("walk_cart"), variant["walk_cart"], "walk_cart", skeleton)
	_load_animation_from_fbx_cached(preloaded.get("fall"), variant["fall"], "fall", skeleton)
	_load_animation_from_fbx_cached(preloaded.get("run"), variant["run"], "run", skeleton)
=======
	# Load and merge animations from separate FBX files
	print("Loading idle animation: ", variant["idle"])
	_load_animation_from_fbx(variant["idle"], "idle", skeleton)
	
	print("Loading walk animation: ", variant["walk"])
	_load_animation_from_fbx(variant["walk"], "walk", skeleton)
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)
	
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
	_load_animation_from_fbx_cached(anim_scene, fbx_path, anim_prefix, target_skeleton)

func _load_animation_from_fbx_cached(anim_scene: PackedScene, fbx_path: String, anim_prefix: String, target_skeleton: Skeleton3D):
	"""PERFORMANCE FIX: Load animation from preloaded scene (avoids runtime load() calls)"""
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
<<<<<<< HEAD
	"""Play the specified animation type (idle or walk or fall or run)"""
	# PERFORMANCE FIX: Skip if already playing this animation type
	if anim_type == _current_animation_type:
		return
	
	_current_animation_type = anim_type
	
=======
	"""Play the specified animation type (idle or walk)"""
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)
	# If using pre-configured character model, use its methods
	if character_model and character_model is CustomerCharacterModel:
		if anim_type == "idle":
			character_model.play_idle()
		elif anim_type == "walk":
			character_model.play_walk()
		return
	
	if not animation_player:
		return
	
	var target_anim: String
	
	match anim_type:
		"idle":
			target_anim = idle_anim_name
		"walk":
<<<<<<< HEAD
			# Use cart animation if customer has a cart (check shopping_cart directly, avoid is_instance_valid)
			if customer_type == CustomerType.WITH_CART and shopping_cart:
				target_anim = walk_cart_anim_name
			else:
				target_anim = walk_anim_name
		"fall":
			target_anim = fall_anim_name
		"run":
			target_anim = run_anim_name
		_:
			return
=======
			target_anim = walk_anim_name
	
	if target_anim == "":
		return
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)
	
	# Only change animation if different from current
	if target_anim != last_animation:
		if animation_player.has_animation(target_anim):
			animation_player.play(target_anim)
			last_animation = target_anim

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
	# Don't process if despawning
	if current_state == "DESPAWNING":
		return
	
	# Process path queue once per frame (first customer to run this does it)
	var current_frame = Engine.get_physics_frames()
	if current_frame != _last_queue_process_frame:
		_process_path_queues()
	
	# Simple state machine
	match current_state:
		"IDLE":
			_state_idle(delta)
		"STOPPING":
			_state_stopping(delta)
		"LEAVING":
			_state_leaving(delta)

func _state_idle(delta):
	_play_animation("idle")
	current_state = "WALKING"



func _state_stopping(delta):
	_play_animation("idle")
	velocity = Vector3.ZERO
	
	if shelf_to_face:
		var direction = (shelf_to_face.global_position - global_position).normalized()
		if direction.length_squared() > 0.01:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	stop_timer -= delta
	
	if stop_timer <= 0:
		current_stops += 1
		current_state = "WALKING"
		_pick_random_destination()

func _state_leaving(delta):
	if nav_agent.is_navigation_finished():
		current_state = "DESPAWNING"
		_despawn()
		return
	
	# ⚡ SIMPLE MOVEMENT: Update path every 2 seconds
	_path_update_timer += delta
	if _path_update_timer >= PATH_UPDATE_INTERVAL:
		_path_update_timer = 0.0
		_cached_path_position = nav_agent.get_next_path_position()
	
	# Move toward cached path position
	var direction = (_cached_path_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()
	
	# Rotate toward movement direction
	if direction.length_squared() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)
	
	# Update cart position if has cart
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

<<<<<<< HEAD

func _state_falling(delta):
	"""Handle knockback/falling state"""
	_play_animation("fall")
	
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 10.0)
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		
		recovery_timer -= delta
		if recovery_timer <= 0:
			is_knocked_back = false
			current_state = previous_state

func _state_aggressive(delta):
	"""Chase the player aggressively"""
	_play_animation("run")
	
	if not target_player or not is_instance_valid(target_player):
		target_player = _get_cached_player()
		if not target_player:
			_become_calm()
			return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	if distance_to_player > lose_player_distance:
		aggression_timer += delta
		if aggression_timer > calm_down_time:
			_become_calm()
			return
	else:
		aggression_timer = 0
	
	if distance_to_player < attack_range and not has_attacked:
		current_state = "ATTACKING"
		has_attacked = true
		_attack_player()
		return
	
	# Throttle path updates
	_path_update_timer -= delta
	if _path_update_timer <= 0:
		nav_agent.target_position = target_player.global_position
		_path_update_timer = PATH_UPDATE_INTERVAL
	
	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		
		velocity = direction * chase_speed
		move_and_slide()
		
		if direction.length_squared() > 0.01:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)

func _state_attacking(delta):
	"""Playing attack animation"""
	_play_animation("run")  # Keep running animation
	
	# Attack happens instantly when entering this state
	# After a short delay, become calm
	await get_tree().create_timer(0.5).timeout
	_become_calm()

=======
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)
func _pick_random_destination():
	"""Queue a path calculation - actual work done in _do_pick_random_destination"""
	if cached_shelf_markers.is_empty():
		return
	_queue_path_calculation()

func _do_pick_random_destination():
	"""Actually pick a destination - called from queue processor"""
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
	
	# Queue the exit destination calculation
	_queue_exit_calculation()

func _do_set_exit_destination():
	"""Actually set exit destination - called from queue processor"""
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
	"""Remove customer and cart from scene"""
	# Only delete cart if we still own it
	if shopping_cart and shopping_cart.owner_customer == self:
		# Just free the cart and its items directly
		for item in shopping_cart.stored_items:
			if item:
				item.queue_free()
		shopping_cart.queue_free()
		shopping_cart = null
	
	queue_free()

func _on_velocity_computed(_safe_velocity: Vector3):
	"""NO LONGER USED - Avoidance is disabled for performance.
	Keeping this function in case avoidance is re-enabled later."""
	pass

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

func _is_another_customer_nearby(_radius: float) -> bool:
	"""PERFORMANCE FIX: Removed expensive iteration through all customers.
	Navigation avoidance already handles spacing, this check was redundant."""
	# Always return false - let navigation avoidance handle spacing
	# This eliminates O(n²) behavior when multiple customers reach destinations
	return false

func _get_cached_player() -> CharacterBody3D:
	"""PERFORMANCE FIX: Get player with caching to avoid get_nodes_in_group every frame"""
	if _player_cache_valid and _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	
	# Cache miss - find player once
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]
		_player_cache_valid = true
		return _cached_player
	
	_player_cache_valid = false
	return null

static func _process_path_queues():
	"""PERFORMANCE FIX: Process path calculation queues - call this once per frame"""
	var current_frame = Engine.get_physics_frames()
	if current_frame == _last_queue_process_frame:
		return  # Already processed this frame
	_last_queue_process_frame = current_frame
	
	var processed = 0
	
	# Process path queue (customers picking new destinations)
	while not _path_queue.is_empty() and processed < MAX_PATH_CALCS_PER_FRAME:
		var customer = _path_queue.pop_front()
		if is_instance_valid(customer):
			customer._do_pick_random_destination()
			processed += 1
	
	# Process exit queue (customers heading to exit)
	while not _exit_queue.is_empty() and processed < MAX_PATH_CALCS_PER_FRAME:
		var customer = _exit_queue.pop_front()
		if is_instance_valid(customer):
			customer._do_set_exit_destination()
			processed += 1

func _queue_path_calculation():
	"""Add this customer to the path calculation queue"""
	if self not in _path_queue:
		_path_queue.append(self)

func _queue_exit_calculation():
	"""Add this customer to the exit destination queue"""
	if self not in _exit_queue:
		_exit_queue.append(self)

func _check_if_stuck(delta: float, intended_direction: Vector3):
	"""ANTI-STUCK: Detect if customer is stuck and teleport them forward"""
	var horizontal_pos = Vector2(global_position.x, global_position.z)
	var last_horizontal = Vector2(_last_position.x, _last_position.z)
	var movement = horizontal_pos.distance_to(last_horizontal)
	
	# Check if barely moving
	if movement < STUCK_THRESHOLD:
		_stuck_time += delta
		
		# If stuck for too long, teleport forward
		if _stuck_time >= STUCK_TELEPORT_TIME:
			_teleport_unstuck(intended_direction)
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
	
	_last_position = global_position

func _teleport_unstuck(direction: Vector3):
	"""Teleport customer forward to unstuck them"""
	if direction.length_squared() < 0.1:
		# No clear direction, pick a random one
		var angle = randf() * TAU
		direction = Vector3(cos(angle), 0, sin(angle))
	
	# Teleport forward in intended direction
	var teleport_pos = global_position + direction.normalized() * TELEPORT_DISTANCE
	teleport_pos.y = global_position.y  # Keep same height
	
	# PERFORMANCE FIX: Skip expensive navmesh query, just teleport directly
	# The navigation system will correct the position on the next path update anyway
	global_position = teleport_pos
	
	# Update cart position if we have one
	if customer_type == CustomerType.WITH_CART and shopping_cart:
		_update_cart_position()

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
	
<<<<<<< HEAD
	# Queue the exit destination calculation
	_queue_exit_calculation()

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
	
	# PERFORMANCE FIX: Use cached player lookup
	target_player = _get_cached_player()
	
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
	
	# PERFORMANCE FIX: Reset character tint instead of freeing particles
	if character_model:
		var tween = create_tween()
		tween.tween_property(character_model, "modulate", Color(1, 1, 1, 1), 0.3)
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
	# PERFORMANCE FIX: Use cached audio instead of loading at runtime
	if _hit_sound_cached == null:
		_hit_sound_cached = load("res://assets/sfx/MLG Hitmarker Sound Effect.mp3")
	
	if _hit_sound_cached:
		var audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
		audio_player.stream = _hit_sound_cached
		audio_player.volume_db = 0
		audio_player.max_distance = 20.0
		audio_player.play()
		
		# Auto-delete after playing
		await audio_player.finished
		audio_player.queue_free()

func _play_angry_sound():
	"""Play angry Roblox sound effect"""
	# PERFORMANCE FIX: Use cached audio instead of loading at runtime
	if _angry_sound_cached == null:
		_angry_sound_cached = load("res://assets/sfx/Roblox Angry Sound Effect.mp3")
	
	if _angry_sound_cached:
		var audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
		audio_player.stream = _angry_sound_cached
		audio_player.volume_db = 5
		audio_player.max_distance = 25.0
		audio_player.play()
		
		# Auto-delete after playing
		await audio_player.finished
		audio_player.queue_free()

func _spawn_impact_particles():
	"""PERFORMANCE FIX: Use simple visual feedback instead of heavy CPUParticles3D"""
	# Instead of particles, just do a quick model flash/scale effect
	if character_model:
		var tween = create_tween()
		# Quick flash white then back to normal
		tween.tween_property(character_model, "modulate", Color(2, 2, 2, 1), 0.05)
		tween.tween_property(character_model, "modulate", Color(1, 1, 1, 1), 0.15)

func _spawn_anger_particles():
	"""PERFORMANCE FIX: Use simple red tint instead of heavy CPUParticles3D"""
	# Instead of particles, tint the character red while aggressive
	if character_model:
		var tween = create_tween()
		tween.tween_property(character_model, "modulate", Color(1.5, 0.5, 0.5, 1), 0.3)
		# Store reference so we can reset it later
		anger_particle = character_model  # Reuse this variable to track that we're angry
=======
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
>>>>>>> parent of cf8fb6eb (more animations, hitting, aggression)

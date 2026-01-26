extends Node3D

@onready var arrow = $Arrow

var target_node: Node3D = null
var offset_y: float = 2
var bounce_height: float = 0.3 # Reduced for lower position
var bounce_speed: float = 3.0
var rotation_speed: float = 4.0

# PERFORMANCE FIX: Cache player and interaction component references
var _cached_player: Node = null
var _cached_interaction: Node = null
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 0.2  # Only check cart/held status 5 times per second

func _ready():
	# PERFORMANCE FIX: Cache player reference once at start
	await get_tree().process_frame
	_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player and _cached_player.has_node("InteractionComponent"):
		_cached_interaction = _cached_player.get_node("InteractionComponent")

func set_target(target: Node3D):
	target_node = target
	if target_node:
		global_position = target_node.global_position + Vector3(0, offset_y, 0)

func _process(delta):
	if not is_instance_valid(target_node) or not target_node.is_inside_tree() or target_node.is_queued_for_deletion():
		queue_free()
		return
	
	# Follow target smoothly
	var target_pos = target_node.global_position + Vector3(0, offset_y, 0)
	global_position = global_position.lerp(target_pos, delta * 15.0)
	
	# Bounce animation (adjusted for lower position)
	arrow.position.y = 0.2 + sin(Time.get_ticks_msec() * 0.001 * bounce_speed) * bounce_height
	
	# Rotation animation (faster)
	arrow.rotate_y(delta * rotation_speed)
	
	# PERFORMANCE FIX: Only check cart/held status periodically, not every frame
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		
		# If item has a parent named "ItemStorageArea" (in cart)
		if target_node.get_parent() and target_node.get_parent().name == "ItemStorageArea":
			queue_free()
			return
		
		# Check if held by player using cached reference
		if _cached_interaction and is_instance_valid(_cached_interaction):
			if _cached_interaction.picked_object == target_node:
				queue_free()
				return

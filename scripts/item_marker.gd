extends Node3D

@onready var arrow = $Arrow

var target_node: Node3D = null
var offset_y: float = 2
var bounce_height: float = 0.3 # Reduced for lower position
var bounce_speed: float = 3.0
var rotation_speed: float = 4.0

func _ready():
	# Visibility through walls is now handled by no_depth_test in material
	pass

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
	global_position = global_position.lerp(target_pos, delta * 15.0) # Faster interpolation
	
	# Bounce animation (adjusted for lower position)
	arrow.position.y = 0.2 + sin(Time.get_ticks_msec() * 0.001 * bounce_speed) * bounce_height
	
	# Rotation animation (faster)
	arrow.rotate_y(delta * rotation_speed)
	
	# If item has a parent named "ItemStorageArea" (in cart)
	if target_node.get_parent() and target_node.get_parent().name == "ItemStorageArea":
		queue_free()
		return
		
	# Check if held by player
	if not is_inside_tree(): return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("InteractionComponent"):
		var interaction = player.get_node("InteractionComponent")
		if interaction.picked_object == target_node:
			queue_free()
			return

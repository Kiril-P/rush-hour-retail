extends Node

## Performance Manager - Optimizes physics for items
## Disables physics for items far from player or not in view

@export var enable_distance_culling: bool = true
@export var culling_distance: float = 15.0  # Distance beyond which to freeze items
@export var update_interval: float = 0.5  # How often to check (seconds)
@export var enable_frustum_culling: bool = false  # Disable physics for items not in view

var player: Node3D = null
var camera: Camera3D = null
var update_timer: float = 0.0
var all_items: Array = []

func _ready():
	# Wait for scene to load
	await get_tree().create_timer(3.0).timeout
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera3D"):
		camera = player.get_node("Camera3D")
	
	# Cache all items
	_refresh_item_cache()
	
	print("🚀 Performance Manager initialized")
	print("  - Distance culling: ", "ENABLED" if enable_distance_culling else "DISABLED")
	print("  - Culling distance: ", culling_distance, "m")
	print("  - Items tracked: ", all_items.size())

func _process(delta):
	if not enable_distance_culling:
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_item_culling()

func _refresh_item_cache():
	"""Refresh list of all items in the scene"""
	all_items = get_tree().get_nodes_in_group("pickable")

func _update_item_culling():
	"""Update physics state for all items based on distance"""
	if not player:
		return
	
	var player_pos = player.global_position
	
	for item in all_items:
		if not is_instance_valid(item) or not item is RigidBody3D:
			continue
		
		# Skip items being held/pushed
		if item.has_method("get_is_on_shelf"):
			if not item.get_is_on_shelf():
				continue
		
		var distance = player_pos.distance_to(item.global_position)
		
		# Freeze items far from player
		if distance > culling_distance:
			if not item.freeze:
				item.freeze = true
				item.sleeping = true
		else:
			# Keep items near player frozen unless picked up
			# They only unfreeze when actually interacted with
			if item.freeze == false and item.linear_velocity.length() < 0.01:
				# Item is near player but not moving - freeze it
				item.freeze = true
				item.sleeping = true

func add_item(item: Node3D):
	"""Manually add an item to tracking"""
	if item and not all_items.has(item):
		all_items.append(item)

func remove_item(item: Node3D):
	"""Remove an item from tracking"""
	all_items.erase(item)


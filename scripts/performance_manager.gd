extends Node

## Performance Manager - OPTIMIZED VERSION
## Disables physics for items far from player

@export var enable_distance_culling: bool = false  # DISABLED FOR TESTING - Might be causing lag
@export var culling_distance: float = 15.0  # Distance beyond which to freeze items
@export var update_interval: float = 2.0  # How often to check (seconds) - increased for performance
@export var batch_size: int = 10  # Process items in batches to prevent lag spikes (reduced)

var player: Node3D = null
var update_timer: float = 0.0
var current_batch_index: int = 0

func _ready():
	# Wait for scene to load
	await get_tree().create_timer(3.0).timeout
	_find_player()

func _find_player():
	"""Find player in scene"""
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not enable_distance_culling:
		return
	
	# Validate player still exists
	if not is_instance_valid(player) or not player.is_inside_tree():
		_find_player()
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_item_culling_batched()

func _update_item_culling_batched():
	"""Update physics state for items - BATCHED to prevent lag spikes"""
	if not player or not is_instance_valid(player):
		return
	
	# Safety check - player must be in tree
	if not player.is_inside_tree():
		return
	
	var player_pos = player.global_position
	
	# Get fresh list of items each time (handles items being freed)
	var all_items = get_tree().get_nodes_in_group("pickable")
	
	if all_items.is_empty():
		return
	
	# Process in batches to prevent frame drops
	var items_processed = 0
	var start_index = current_batch_index
	
	for i in range(all_items.size()):
		var index = (start_index + i) % all_items.size()
		var item = all_items[index]
		
		# CRITICAL: Validate item before ANY access
		if not is_instance_valid(item):
			continue
		
		if not item is RigidBody3D:
			continue
		
		# Must be in scene tree to access global_position
		if not item.is_inside_tree():
			continue
		
		# Skip items being held/in cart
		if item.has_method("get_is_on_shelf"):
			if not item.get_is_on_shelf():
				continue
		
		# Now safe to access global_position
		var distance = player_pos.distance_to(item.global_position)
		
		# Freeze items far from player
		if distance > culling_distance:
			if not item.freeze:
				item.freeze = true
		else:
			# Keep nearby stationary items frozen for performance
			if not item.freeze and item.linear_velocity.length() < 0.01:
				item.freeze = true
		
		items_processed += 1
		if items_processed >= batch_size:
			current_batch_index = (index + 1) % all_items.size()
			return
	
	# Reset batch index if we processed all items
	current_batch_index = 0

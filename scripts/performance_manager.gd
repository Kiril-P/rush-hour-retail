extends Node

## Performance Manager - RE-ENABLED AND OPTIMIZED
## Disables physics for items far from player and manages overall performance

@export var enable_distance_culling: bool = true  # RE-ENABLED - Freezes far items
@export var culling_distance: float = 20.0  # Distance beyond which to freeze items (increased for safety)
@export var update_interval: float = 0.5  # How often to check (seconds) - more frequent for responsiveness
@export var batch_size: int = 30  # Process more items per batch (increased efficiency)

var player: Node3D = null
var update_timer: float = 0.0
var current_batch_index: int = 0

# PERFORMANCE: Cache the items array, update less frequently
var _cached_items: Array = []
var _items_cache_timer: float = 0.0
const ITEMS_CACHE_INTERVAL: float = 2.0  # Rebuild item list every 2 seconds

func _ready():
	# Wait for scene to load
	await get_tree().create_timer(2.0).timeout
	_find_player()
	_rebuild_items_cache()

func _find_player():
	"""Find player in scene"""
	player = get_tree().get_first_node_in_group("player")

func _rebuild_items_cache():
	"""Rebuild cached items list - called periodically, not every frame"""
	_cached_items = get_tree().get_nodes_in_group("pickable")

func _process(delta):
	if not enable_distance_culling:
		return
	
	# Validate player still exists
	if not is_instance_valid(player) or not player.is_inside_tree():
		_find_player()
		return
	
	# PERFORMANCE: Rebuild item cache periodically, not every culling pass
	_items_cache_timer += delta
	if _items_cache_timer >= ITEMS_CACHE_INTERVAL:
		_items_cache_timer = 0.0
		_rebuild_items_cache()
	
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
	
	# Use cached items instead of querying scene tree every time
	if _cached_items.is_empty():
		return
	
	# Process in batches to prevent frame drops
	var items_processed = 0
	var start_index = current_batch_index
	var total_items = _cached_items.size()
	
	for i in range(total_items):
		var index = (start_index + i) % total_items
		var item = _cached_items[index]
		
		# CRITICAL: Validate item before ANY access
		if not is_instance_valid(item):
			continue
		
		if not item is RigidBody3D:
			continue
		
		# Must be in scene tree to access global_position
		if not item.is_inside_tree():
			continue
		
		# Skip items being held/in cart (they need physics)
		if item.has_method("get_is_on_shelf"):
			if not item.get_is_on_shelf():
				# Item is being held - make sure it's not frozen!
				if item.freeze and item.freeze_mode == RigidBody3D.FREEZE_MODE_KINEMATIC:
					continue  # Already being held properly
				continue
		
		# Now safe to access global_position
		var distance = player_pos.distance_to(item.global_position)
		
		# Freeze items far from player (but don't unfreeze them - let pickup handle that)
		if distance > culling_distance:
			if not item.freeze:
				item.freeze = true
				item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		# Near items: only freeze if they're not moving
		elif not item.freeze and item.linear_velocity.length_squared() < 0.0001:
			item.freeze = true
			item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		
		items_processed += 1
		if items_processed >= batch_size:
			current_batch_index = (index + 1) % total_items
			return
	
	# Reset batch index if we processed all items
	current_batch_index = 0

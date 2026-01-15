extends Node3D

@export var grid_map: GridMap
@export var ghost_material: StandardMaterial3D 
# CHANGE: Now accepts FurnitureData resources instead of raw scenes
@export var buildable_items: Array[FurnitureData] = []

@export var valid_color: Color = Color(0, 1, 0, 0.4) 
@export var invalid_color: Color = Color(1, 0, 0, 0.4) 

var ray_cast_3d: RayCast3D 
var build_preview_marker: Marker3D

var is_building = false
var ghost_item = null
var current_item_index = 0 
var current_rotation_y = 0.0
var can_place: bool = true

var moving_item = null
var original_transform: Transform3D

# SNAP SETTINGS
var snap_sizes = [0.0, 0.2, 0.5, 1.0] 
var current_snap_index = 0

func _process(_delta):
	if is_building and ghost_item:
		update_ghost_position()
		_check_placement_validity()

func cycle_snap():
	current_snap_index = (current_snap_index + 1) % snap_sizes.size()
	var snap_val = snap_sizes[current_snap_index]
	if snap_val == 0.0:
		print("Snap Mode: OFF")
	else:
		print("Snap Mode: ", snap_val, "m")

func toggle_build_mode():
	is_building = !is_building
	if is_building:
		spawn_ghost()
	else:
		if moving_item:
			cancel_move()
		_cleanup_ghost_logic()

func cycle_items(dir: int):
	if moving_item: return 
	current_item_index = posmod(current_item_index + dir, buildable_items.size())
	spawn_ghost()

func delete_item(collider_node):
	if moving_item: return
	
	var target = _find_shelf(collider_node)
	
	if target:
		# CALCULATE REFUND
		var refund = 25.0 # Default fallback
		
		# Priority: furniture_data variable -> metadata
		var data = null
		if "furniture_data" in target and target.furniture_data:
			data = target.furniture_data
		elif target.has_meta("furniture_data"):
			data = target.get_meta("furniture_data")
			
		if data:
			refund = data.price * 0.5
		
		GameManager.money += refund
		GameManager.money_changed.emit(GameManager.money)
		print("BuildComponent: Sold ", target.name, " for $", refund)
		target.queue_free()
	else:
		print("BuildComponent: No shelf found at cursor.")

func _check_placement_validity():
	if not ghost_item: return
	
	if not ray_cast_3d.is_colliding():
		can_place = false
		_update_ghost_visuals()
		return
		
	var hit_collider = ray_cast_3d.get_collider()
	
	if hit_collider != null:
		var layers = hit_collider.get("collision_layer")
		if layers != null and (int(layers) & 2):
			can_place = false
			_update_ghost_visuals()
			return

	var aabb: AABB = _get_combined_aabb(ghost_item)
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsShapeQueryParameters3D.new()
	var box_shape = BoxShape3D.new()
	
	var shrink_amount = 0.05 
	box_shape.size = aabb.size - Vector3(shrink_amount, 0.01, shrink_amount)
	
	query.shape = box_shape
	var query_pos = ghost_item.global_position + Vector3(0, aabb.size.y / 2.0, 0)
	query.transform = Transform3D(ghost_item.global_transform.basis, query_pos)
	query.collision_mask = 1 | 2 
	
	var result = space_state.intersect_shape(query)
	var collision_found = false
	
	for r in result:
		var collider = r.collider
		if collider.is_in_group("floor") or "floor" in collider.name.to_lower():
			continue
		if collider == ghost_item or collider == moving_item:
			continue
			
		collision_found = true
		break
			
	can_place = !collision_found
	_update_ghost_visuals()

func _update_ghost_visuals():
	if not ghost_item: return
	ghost_material.albedo_color = valid_color if can_place else invalid_color
	
	if moving_item:
		_apply_material(moving_item, ghost_material if not can_place else null)
	else:
		_apply_material(ghost_item, ghost_material)

func _get_combined_aabb(node: Node3D) -> AABB:
	var aabb = AABB()
	var found_mesh = false
	for mesh in node.find_children("*", "MeshInstance3D"):
		var local_aabb = mesh.get_mesh().get_aabb()
		var world_aabb = mesh.get_transform() * local_aabb
		if not found_mesh:
			aabb = world_aabb
			found_mesh = true
		else:
			aabb = aabb.merge(world_aabb)
	return aabb if found_mesh else AABB(Vector3(-0.5,0,-0.5), Vector3(1,1,1))

func update_ghost_position():
	if not ray_cast_3d.is_colliding():
		ghost_item.global_position = build_preview_marker.global_position
		return

	var target_pos = ray_cast_3d.get_collision_point()
	var snap_val = snap_sizes[current_snap_index]
	
	if snap_val > 0.0:
		target_pos.x = snapped(target_pos.x, snap_val)
		target_pos.z = snapped(target_pos.z, snap_val)
		target_pos.y = snapped(target_pos.y, 0.01) 
	
	ghost_item.global_position = target_pos
	ghost_item.rotation_degrees.y = current_rotation_y

func place_item():
	if not can_place or not ghost_item: return
	
	if moving_item:
		_finalize_move()
	else:
		# NEW: Check money before placing
		var data = buildable_items[current_item_index]
		if data == null: return
		
		if GameManager.money < data.price:
			print("BuildComponent: Not enough money! ($", data.price, " needed)")
			return
			
		# Deduct money
		GameManager.money -= data.price
		GameManager.money_changed.emit(GameManager.money)
		
		var new_item = data.scene.instantiate()
		get_tree().current_scene.add_child(new_item)
		new_item.global_transform = ghost_item.global_transform
		
		# Tag it with its data so we can calculate refund later
		new_item.set_meta("furniture_data", data)
		
		# Also assign it to the script if it exists on the node or its children
		_assign_furniture_data(new_item, data)
		
		if not new_item.is_in_group("shelf"):
			new_item.add_to_group("shelf")
		
		print("BuildComponent: Purchased ", data.name, " for $", data.price)
		spawn_ghost()

func spawn_ghost():
	_cleanup_ghost_logic()
	if buildable_items.is_empty(): return
	
	var data = buildable_items[current_item_index]
	if data == null or data.scene == null: return
		
	ghost_item = data.scene.instantiate()
	get_tree().current_scene.add_child(ghost_item)
	_strip_collisions(ghost_item)
	_apply_material(ghost_item, ghost_material)

func pick_up_to_move(collider):
	var target = _find_shelf(collider)
	if target and not moving_item:
		_cleanup_ghost_logic()
		moving_item = target
		original_transform = target.global_transform
		is_building = true
		ghost_item = moving_item
		_strip_collisions(moving_item)

func _finalize_move():
	_restore_collisions(moving_item)
	_apply_material(moving_item, null)
	moving_item = null
	ghost_item = null
	if is_building: spawn_ghost()

func cancel_move():
	if moving_item:
		moving_item.global_transform = original_transform
		_finalize_move()

func _assign_furniture_data(node, data):
	if "furniture_data" in node:
		node.furniture_data = data
	for child in node.get_children():
		_assign_furniture_data(child, data)

func _cleanup_ghost_logic():
	if ghost_item and ghost_item != moving_item:
		ghost_item.queue_free()
	ghost_item = null

func _strip_collisions(node):
	if node is CollisionObject3D:
		node.collision_layer = 0
	for child in node.get_children(): _strip_collisions(child)

func _restore_collisions(node):
	if node is CollisionObject3D:
		node.collision_layer = 1
	for child in node.get_children(): _restore_collisions(child)

func _apply_material(node, mat):
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			node.set_surface_override_material(i, mat)
	for child in node.get_children(): _apply_material(child, mat)

func _find_shelf(node):
	var current = node
	while current:
		if current.is_in_group("shelf") or current is store_object or current is CashRegister: 
			return current
		current = current.get_parent()
	return null

func rotate_ghost():
	current_rotation_y -= 45.0

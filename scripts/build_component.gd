extends Node3D

@export var grid_map: GridMap
@export var ghost_material: StandardMaterial3D 
@export var buildable_items: Array[PackedScene] = []

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

func _process(_delta):
	if is_building and ghost_item:
		update_ghost_position()
		_check_placement_validity()

# --- NEW: Fixed Toggle with Cleanup ---
func toggle_build_mode():
	is_building = !is_building
	if is_building:
		spawn_ghost()
	else:
		if moving_item:
			cancel_move()
		_cleanup_ghost_logic() # This removes the ghost from the screen

# --- NEW: Added missing cycle_items ---
func cycle_items(dir: int):
	if moving_item: return # Don't swap items while moving something
	current_item_index = posmod(current_item_index + dir, buildable_items.size())
	spawn_ghost()

# --- NEW: Added missing delete_item ---
func delete_item(collider):
	if moving_item: return
	var target = _find_shelf(collider)
	if target:
		target.queue_free()

func _check_placement_validity():
	if not ghost_item: return
	var aabb: AABB = _get_combined_aabb(ghost_item)
	var space_state = get_world_3d().direct_space_state
	
	var center = ghost_item.global_position + Vector3(0, 0.5, 0)
	var size = aabb.size * 0.4 
	
	var check_points = [
		center,
		center + Vector3(size.x, 0, size.z),
		center + Vector3(-size.x, 0, size.z),
		center + Vector3(size.x, 0, -size.z),
		center + Vector3(-size.x, 0, -size.z)
	]
	
	var collision_found = false
	for point in check_points:
		var query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.2
		query.shape = sphere
		query.transform = Transform3D(Basis(), point)
		query.collision_mask = 1 
		
		var result = space_state.intersect_shape(query)
		for r in result:
			var collider = r.collider
			if collider == ghost_item or collider == moving_item or "Floor" in collider.name:
				continue
			collision_found = true
			break
			
	can_place = !collision_found
	_update_ghost_visuals()

func _update_ghost_visuals():
	if not ghost_item: return
	ghost_material.albedo_color = valid_color if can_place else invalid_color
	
	if moving_item:
		if not can_place:
			_apply_material(moving_item, ghost_material)
		else:
			_apply_material(moving_item, null)
	else:
		_apply_material(ghost_item, ghost_material)

func _get_combined_aabb(node: Node3D) -> AABB:
	var aabb = AABB()
	var found_mesh = false
	for mesh in node.find_children("*", "MeshInstance3D"):
		var local_aabb = mesh.get_mesh().get_aabb()
		aabb = aabb.merge(local_aabb)
		found_mesh = true
	return aabb if found_mesh else AABB(Vector3(-0.5,0,-0.5), Vector3(1,1,1))

func update_ghost_position():
	var target_pos = ray_cast_3d.get_collision_point() if ray_cast_3d.is_colliding() else build_preview_marker.global_position
	
	if grid_map:
		var local = grid_map.to_local(target_pos)
		var map_pos = grid_map.local_to_map(local)
		target_pos = grid_map.to_global(grid_map.map_to_local(map_pos))
	
	ghost_item.global_position = target_pos
	ghost_item.rotation_degrees.y = current_rotation_y

func place_item():
	if not can_place or not ghost_item: return
	
	if moving_item:
		_finalize_move()
	else:
		var new_item = buildable_items[current_item_index].instantiate()
		get_tree().current_scene.add_child(new_item)
		new_item.global_transform = ghost_item.global_transform
		spawn_ghost()

func spawn_ghost():
	_cleanup_ghost_logic()
	if buildable_items.is_empty(): return
	ghost_item = buildable_items[current_item_index].instantiate()
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
		if current is store_object: return current
		current = current.get_parent()
	return null

func rotate_ghost():
	current_rotation_y -= 45.0

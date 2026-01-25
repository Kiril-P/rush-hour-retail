extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D 
@export var throw_force: float = 30.0

var picked_object = null
var player_node: CharacterBody3D
var active_cart = null

func _ready():
	player_node = get_parent()
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned!")

func _process(delta):
	if picked_object:
		_move_held_object_smoothly(delta)
		_update_raycast_exceptions()

func _update_raycast_exceptions():
	if picked_object and ray_cast_3d:
		ray_cast_3d.add_exception(picked_object)

func _move_held_object_smoothly(delta):
	if not picked_object:
		return
	
	picked_object.global_position = picked_object.global_position.lerp(
		carry_marker.global_position, 
		delta * 25.0
	)
	picked_object.global_rotation = carry_marker.global_rotation

func handle_interaction(collider, hold_duration, is_secondary: bool = false):
	# RIGHT CLICK - Drop/Throw
	if is_secondary:
		if picked_object:
			if hold_duration > 0.25:
				throw_object()
			else:
				drop_object()
		return
	
	# LEFT CLICK - Find what we're clicking on
	var interact_target = _find_interactable(collider)
	
	# Check if it's a cart or basket
	var is_cart = interact_target is ShoppingCart or interact_target is ShoppingBasket
	
	# Check if it's an item IN a cart
	var is_item_in_cart = _is_item_in_cart(interact_target)
	
	# PRIORITY 1: Clicking item IN cart → Take it out
	if is_item_in_cart:
		_take_item_from_cart(interact_target)
		return
	
	# PRIORITY 2: Holding item + clicking cart → Just add item
	if is_cart and picked_object:
		_add_item_to_cart(interact_target)
		return
	
	# PRIORITY 3: Clicking cart (empty hands) → Grab/release cart
	if is_cart:
		_handle_cart_interaction(interact_target)
		return
	
	# PRIORITY 4: Clicking checkout counter while holding item
	if picked_object and interact_target and interact_target.is_in_group("checkout"):
		if interact_target.has_method("interact"):
			# Pass the held item to checkout counter!
			var was_correct = interact_target.interact(picked_object)
			
			# ONLY clear picked_object if item was CORRECT!
			if was_correct:
				picked_object = null
		return
	
	# PRIORITY 5: Already holding item → Try to use it on target
	if picked_object:
		if interact_target and interact_target.has_method("interact"):
			interact_target.interact()
		return
	
	# PRIORITY 6: Not holding anything → Pick up or interact
	if interact_target:
		if interact_target.has_method("pick_up"):
			pick_up_object(interact_target)
		elif interact_target.has_method("interact"):
			interact_target.interact()

func _is_item_in_cart(node) -> bool:
	if not node:
		return false
	
	var parent = node.get_parent()
	if parent and parent.name == "ItemStorageArea":
		return true
	
	return false

func _take_item_from_cart(item):
	if not active_cart:
		return
	
	var cart_items = active_cart.stored_items
	var item_index = cart_items.find(item)
	
	if item_index == -1:
		return
	
	active_cart.stored_items.remove_at(item_index)
	
	if item.get_parent():
		item.get_parent().remove_child(item)
	
	get_tree().current_scene.add_child(item)
	
	picked_object = item
	
	if item is RigidBody3D:
		item.freeze = false
		item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		player_node.add_collision_exception_with(item)
		if active_cart:
			item.add_collision_exception_with(active_cart)
	
	item.global_transform = carry_marker.global_transform
	
	active_cart._restack_items()
	

func _add_item_to_cart(cart):
	
	if cart.add_item(picked_object):
		picked_object = null

func _handle_cart_interaction(cart):
	
	if active_cart == cart:
		cart.release_handle()
		active_cart = null
	elif active_cart == null:
		if cart.grab_handle(player_node):
			active_cart = cart

func handle_cart_action(action: String):
	if not active_cart:
		return
	
	if action == "add_item":
		if picked_object:
			_add_item_to_cart(active_cart)
	
	elif action == "remove_item":
		var item = active_cart.remove_last_item()
		if item:
			picked_object = item
			if item is RigidBody3D:
				item.freeze = false
				item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
				player_node.add_collision_exception_with(item)
				if active_cart:
					item.add_collision_exception_with(active_cart)
			item.global_transform = carry_marker.global_transform

func _find_interactable(node):
	"""Find interactable with optimized checks - FAST PATH FIRST"""
	if not node:
		return null
	
	# Fast path: check node directly first (most common case!)
	if node is ShoppingCart or node is ShoppingBasket:
		return node
	if node.is_in_group("checkout") or node.is_in_group("pickable"):
		return node
	if node.has_method("interact") or node.has_method("pick_up"):
		return node
	
	# Slow path: search parents (limited depth)
	var current = node.get_parent()
	var depth = 0
	while current != null and depth < 3:  # Reduced from 5 to 3 for performance
		if current is ShoppingCart or current is ShoppingBasket:
			return current
		if current.is_in_group("checkout"):
			return current
		if current.has_method("interact") or current.has_method("pick_up"):
			return current
		current = current.get_parent()
		depth += 1
	
	return null

func _find_product(node):
	"""Find product with depth limit - OPTIMIZED"""
	if not node:
		return null
	
	# Fast path: direct pickable check
	if node.is_in_group("pickable"):
		return node
	
	var current = node
	var depth = 0
	while current != null and depth < 5:  # Max 5 levels to prevent infinite loops
		if current.is_in_group("pickable") or "item_name" in current or "product_data" in current:
			return current
		current = current.get_parent()
		depth += 1
	return null

func pick_up_object(object):
	picked_object = object
	
	GameManager.mark_tutorial_complete("pickup")
	GameManager.trigger_tutorial("drop_throw")
	
	if picked_object is RigidBody3D:
		picked_object.freeze = false
		picked_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		picked_object.linear_velocity = Vector3.ZERO
		picked_object.angular_velocity = Vector3.ZERO
		
		player_node.add_collision_exception_with(picked_object)
		if active_cart:
			picked_object.add_collision_exception_with(active_cart)
	
	if picked_object.has_method("pick_up"):
		picked_object.pick_up(self)
	
	picked_object.global_transform = carry_marker.global_transform
	
	# Sparkles for list items (optimized - only once on pickup)
	var item_name = ""
	if object.has_method("get_item_name"):
		item_name = object.get_item_name()
	elif "item_name" in object:
		item_name = object.item_name
		
	if GameManager.check_item_correct(item_name):
		GameManager.spawn_sparkles(object.global_position)

func drop_object():
	if not picked_object: return
	var item = picked_object
	
	GameManager.mark_tutorial_complete("drop_throw")
	
	if ray_cast_3d:
		ray_cast_3d.remove_exception(item)
	
	player_node.remove_collision_exception_with(item)
	if active_cart:
		item.remove_collision_exception_with(active_cart)
	
	if item is RigidBody3D:
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		item.global_position = item.global_position + Vector3(0, 0.1, 0)
		item.freeze = false
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		item.linear_damp = 2.0
		item.angular_damp = 2.0
	
	item.reparent(get_tree().current_scene)
	picked_object = null

func throw_object():
	if not picked_object: return
	var item = picked_object
	
	GameManager.mark_tutorial_complete("drop_throw")
	
	if ray_cast_3d:
		ray_cast_3d.remove_exception(item)
	
	player_node.remove_collision_exception_with(item)
	if active_cart:
		item.remove_collision_exception_with(active_cart)
	
	if item is RigidBody3D:
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		item.freeze = false
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		item.linear_damp = 1.0
		item.angular_damp = 1.0
		item.reparent(get_tree().current_scene)
		
		var camera = get_viewport().get_camera_3d()
		item.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	
	picked_object = null

func is_holding_item() -> bool:
	return picked_object != null

func is_pushing_cart() -> bool:
	return active_cart != null

func get_active_cart():
	return active_cart

func release_cart_if_active():
	if active_cart:
		active_cart.release_handle()
		active_cart = null

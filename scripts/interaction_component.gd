extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D 
@export var throw_force: float = 8.0 

var picked_object = null
var player_node: CharacterBody3D
var active_cart = null

func _ready():
	player_node = get_parent()
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned!")
	
	# print("\n=== INTERACTION COMPONENT READY ===")
	# print("Player: ", player_node.name if player_node else "None")
	# print("RayCast3D: ", ray_cast_3d)
	#if ray_cast_3d:
		# print("  Target Position: ", ray_cast_3d.target_position)
		# print("  Collision Mask: ", ray_cast_3d.collision_mask)
		# print("  ⚠️ RayCast should hit Layer 3 (value 4) for baskets!")
	# print("===================================\n")

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
	# print("\n============================================================")
	# print("=== INTERACTION CLICK ===")
	# print("Raw collider: ", collider)
	# print("Collider name: ", collider.name if collider else "None")
	# print("Collider type: ", collider.get_class() if collider else "None")
	
	# Check if it's a basket
	if collider:
		# print("\n--- BASKET CHECK ---")
		var is_basket_directly = collider is ShoppingBasket
		# print("Is ShoppingBasket type (direct): ", is_basket_directly)
		
		# Check parent chain
		var current = collider
		var depth = 0
		var found_basket = false
		while current != null and depth < 5:
			# print("  [Depth ", depth, "] ", current.name, " (", current.get_class(), ")")
			if current is ShoppingBasket:
				# print("    ✓ FOUND ShoppingBasket!")
				found_basket = true
				break
			current = current.get_parent()
			depth += 1
		
		#if not found_basket:
			# print("  ✗ No ShoppingBasket in parent chain")
	
	# print("\nHolding item: ", picked_object.name if picked_object else "None")
	# print("Active cart: ", active_cart.name if active_cart else "None")
	# print("============================================================")
	
	# RIGHT CLICK - Drop/Throw
	if is_secondary:
		if picked_object:
			if hold_duration > 0.25:
				throw_object()
			else:
				drop_object()
		# print("============================================================\n")
		return
	
	# LEFT CLICK - Find what we're clicking on
	var interact_target = _find_interactable(collider)
	# print("\n→ Final interact target: ", interact_target.name if interact_target else "None")
	
	# Check if it's a cart or basket
	var is_cart = interact_target is ShoppingCart or interact_target is ShoppingBasket
	# print("→ Is cart/basket: ", is_cart)
	
	# Check if it's an item IN a cart
	var is_item_in_cart = _is_item_in_cart(interact_target)
	# print("→ Is item in cart: ", is_item_in_cart)
	
	# PRIORITY 1: Clicking item IN cart → Take it out
	if is_item_in_cart:
		# print("→ CASE 1: Clicking item in cart")
		_take_item_from_cart(interact_target)
		# print("============================================================\n")
		return
	
	# PRIORITY 2: Holding item + clicking cart → Just add item
	if is_cart and picked_object:
		# print("→ CASE 2: Holding item and clicking cart/basket - ADDING!")
		_add_item_to_cart(interact_target)
		# print("============================================================\n")
		return
	
	# PRIORITY 3: Clicking cart (empty hands) → Grab/release cart
	if is_cart:
		# print("→ CASE 3: Clicking cart/basket with empty hands")
		# print("  Calling interact() on: ", interact_target.name)
		_handle_cart_interaction(interact_target)
		# print("============================================================\n")
		return
	
	# PRIORITY 4: Already holding item → Try to use it on target
	if picked_object:
		# print("→ CASE 4: Holding item, trying to interact with target")
		if interact_target and interact_target.has_method("interact"):
			interact_target.interact()
		# print("============================================================\n")
		return
	
	# PRIORITY 5: Not holding anything → Pick up or interact
	if interact_target:
		# print("→ CASE 5: Not holding anything, interacting with target")
		if interact_target.has_method("pick_up"):
			pick_up_object(interact_target)
		elif interact_target.has_method("interact"):
			interact_target.interact()
	#else:
		# print("→ CASE 6: Nothing to interact with")
	
	# print("============================================================\n")

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
	
	# print("  ✓ Took item from cart: ", item.name)

func _add_item_to_cart(cart):
	# print("  → Adding item to cart/basket: ", picked_object.name)
	
	if cart.add_item(picked_object):
		picked_object = null
		# print("  ✓ Item added successfully!")
	#else:
		# print("  ✗ Failed to add item")

func _handle_cart_interaction(cart):
	# print("  → Cart/basket interaction")
	# print("  → Calling interact() on: ", cart.name)
	
	if active_cart == cart:
		# print("  → Releasing (same as active)")
		cart.release_handle()
		active_cart = null
	elif active_cart == null:
		# print("  → Grabbing (no active cart)")
		if cart.grab_handle(player_node):
			active_cart = cart
			# print("  ✓ Now holding: ", cart.name)
	#else:
		# print("  → Already holding different cart/basket")

func handle_cart_action(action: String):
	if not active_cart:
		# print("ERROR: No active cart!")
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
	# print("\n--- SEARCHING FOR INTERACTABLE ---")
	# print("Starting from: ", node.name if node else "None")
	
	var current = node
	var depth = 0
	while current != null and depth < 5:
		# print("  [", depth, "] Checking: ", current.name, " (", current.get_class(), ")")
		
		# Check for ShoppingCart OR ShoppingBasket
		if current is ShoppingCart:
			# print("    ✓ Found ShoppingCart")
			return current
		
		if current is ShoppingBasket:
			# print("    ✓ Found ShoppingBasket!")
			return current
		
		if current.has_method("interact"):
			# print("    ✓ Has interact() method")
			return current
		
		if current.has_method("pick_up"):
			# print("    ✓ Has pick_up() method")
			return current
		
		current = current.get_parent()
		depth += 1
	
	# print("  ✗ Nothing found after ", depth, " levels")
	return null

func _find_product(node):
	var current = node
	while current != null:
		if "product_data" in current:
			return current
		current = current.get_parent()
	return null

func pick_up_object(object):
	# print("  → Picking up object: ", object.name)
	picked_object = object
	
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
	# print("  ✓ Picked up: ", object.name)

func drop_object():
	if not picked_object: return
	var item = picked_object
	
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

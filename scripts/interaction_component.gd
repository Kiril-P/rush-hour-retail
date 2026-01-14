extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D 
@export var throw_force: float = 8.0 

var picked_object = null
var player_node: CharacterBody3D

func _ready():
	player_node = get_parent()
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned in the Inspector!")

func _process(_delta):
	if picked_object:
		picked_object.global_transform = carry_marker.global_transform
		
		if ray_cast_3d.is_colliding() and ray_cast_3d.get_collider() == picked_object:
			ray_cast_3d.add_exception(picked_object)

func handle_interaction(collider, hold_duration):
	if picked_object:
		var target_product = _find_product(collider)
		var target_shelf = _find_shelf(collider)
		
		# 1. REFILL LOGIC
		if picked_object.has_method("can_add_item") and target_product:
			if picked_object.can_add_item(target_product):
				picked_object.add_item()
				target_product.queue_free()
				print("Interaction: Item added back to box!")
				return 
			else:
				print("Interaction: Cannot add this item to box")
				return 

		# 2. SHELF LOGIC
		if target_shelf:
			if picked_object.has_method("take_item"):
				if target_shelf.has_method("has_space") and not target_shelf.has_space():
					print("Interaction: Shelf is full!")
					return

				var item_scene = picked_object.take_item()
				if item_scene:
					var new_item = item_scene.instantiate()
					
					# --- CRITICAL FIX: Transfer the data to the new item! ---
					if "product_data" in new_item:
						new_item.product_data = picked_object.product_data
					
					get_tree().current_scene.add_child(new_item)
					
					if not target_shelf.add_object(new_item):
						new_item.queue_free()
						picked_object.add_item() 
					return 
				else:
					print("Interaction: Box is empty!")
					return 
			else:
				_place_on_shelf(target_shelf)
				return

		# 3. DROP/THROW
		if hold_duration > 0.25:
			throw_object()
		else:
			drop_object()
			
	elif collider:
		var target_product = _find_product(collider)
		
		# --- SCANNING LOGIC ---
		if target_product and target_product.has_meta("to_scan"):
			_scan_item(target_product)
			return

		if target_product and not target_product.has_method("take_item"):
			print("Interaction: Cannot pick up loose products with hands! Use a box.")
			return

		if collider.has_method("interact"):
			collider.interact()
			return
			
		if collider.has_method("pick_up"):
			pick_up_object(collider)

func _find_shelf(node):
	var current = node
	while current != null:
		if current is store_object or current.has_method("add_object"):
			return current
		current = current.get_parent()
	return null

func _find_product(node):
	var current = node
	while current != null:
		if "product_data" in current:
			return current
		current = current.get_parent()
	return null

func _scan_item(item):
	print("Interaction: Scanning ", item.product_data.item_name)
	
	# Add money
	if GameManager:
		GameManager.money += item.product_data.sell_price
		GameManager.money_changed.emit(GameManager.money)
	
	# Notify register
	if item.has_meta("register"):
		var register = item.get_meta("register")
		if register and register.has_method("_on_item_scanned"):
			register._on_item_scanned(item)
	
	item.queue_free()

func _place_on_shelf(shelf):
	var item = picked_object
	ray_cast_3d.remove_exception(item) 
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D:
		item.freeze = false
		item.reparent(get_tree().current_scene)
	
	if shelf.add_object(item):
		picked_object = null
	else:
		pick_up_object(item)

func pick_up_object(object):
	picked_object = object
	if picked_object is RigidBody3D:
		picked_object.freeze = true
		player_node.add_collision_exception_with(picked_object)
	
	picked_object.pick_up(self)
	picked_object.global_transform = carry_marker.global_transform

func drop_object():
	if not picked_object: return
	var item = picked_object
	
	ray_cast_3d.remove_exception(item)
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D: item.freeze = false
	item.reparent(get_tree().current_scene)
	picked_object = null

func throw_object():
	if not picked_object: return
	var item = picked_object
	
	ray_cast_3d.remove_exception(item)
	player_node.remove_collision_exception_with(item)
	
	if item is RigidBody3D:
		item.freeze = false
		var camera = get_viewport().get_camera_3d()
		item.reparent(get_tree().current_scene)
		item.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	picked_object = null

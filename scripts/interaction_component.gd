extends Node3D

@onready var carry_marker = %CarryObjectMarker
@export var ray_cast_3d: RayCast3D 
@export var throw_force: float = 8.0 

var picked_object = null
var player_node: CharacterBody3D

var continuous_action_timer: float = 0.0
const CONTINUOUS_DELAY: float = 0.4 # Snappy speed for stocking

func _ready():
	player_node = get_parent()
	if ray_cast_3d == null:
		push_error("InteractionComponent: ray_cast_3d is not assigned in the Inspector!")

func _process(delta):
	# Handle held object position
	if picked_object:
		picked_object.global_transform = carry_marker.global_transform
		if ray_cast_3d.is_colliding() and ray_cast_3d.get_collider() == picked_object:
			ray_cast_3d.add_exception(picked_object)

	# --- NEW SMARTER SPAM SYSTEM ---
	var collider = player_node.collider if "collider" in player_node else null
	var target_shelf = _find_shelf(collider) if collider else null
	
	if target_shelf:
		# 1. Instant trigger on first press
		if Input.is_action_just_pressed("interact"):
			_handle_continuous(collider, false)
			continuous_action_timer = CONTINUOUS_DELAY # Start the cooldown for holding
		elif Input.is_action_just_pressed("secondary_interact"):
			_handle_continuous(collider, true)
			continuous_action_timer = CONTINUOUS_DELAY
			
		# 2. Handle the "Hold" timer
		if Input.is_action_pressed("interact") or Input.is_action_pressed("secondary_interact"):
			continuous_action_timer -= delta
			if continuous_action_timer <= 0:
				_handle_continuous(collider, Input.is_action_pressed("secondary_interact"))
				continuous_action_timer = CONTINUOUS_DELAY
	else:
		# Reset timer if not looking at a shelf
		continuous_action_timer = 0

func _handle_continuous(collider, is_secondary):
	var target_shelf = _find_shelf(collider)
	if not target_shelf: return

	if is_secondary:
		# RIGHT CLICK HOLD: Retrieve from shelf
		if picked_object and picked_object.has_method("can_add_item"):
			# Into box
			var item = target_shelf.take_random_item()
			if item:
				if picked_object.can_add_item(item):
					picked_object.add_item()
					item.queue_free()
				else:
					target_shelf.add_object(item)
	else:
		# LEFT CLICK HOLD: Place on shelf
		if picked_object and picked_object.has_method("take_item"):
			if target_shelf.has_space():
				var item_scene = picked_object.take_item()
				if item_scene:
					var new_item = item_scene.instantiate()
					if "product_data" in new_item:
						new_item.product_data = picked_object.product_data
					get_tree().current_scene.add_child(new_item)
					if not target_shelf.add_object(new_item):
						new_item.queue_free()
						picked_object.add_item()

func handle_interaction(collider, hold_duration, is_secondary: bool = false):
	if picked_object:
		var target_product = _find_product(collider)
		var target_shelf = _find_shelf(collider)
		
		if is_secondary:
			# RIGHT CLICK RELEASE: Drop (Retrieve is now purely in _process)
			if not target_shelf and not target_product:
				if hold_duration > 0.25: throw_object()
				else: drop_object()
			return

		else:
			# LEFT CLICK RELEASE: Interact (Place is now purely in _process)
			if not target_shelf and collider and collider.has_method("interact"):
				collider.interact()
			return
			
	elif collider:
		var target_product = _find_product(collider)
		var target_shelf = _find_shelf(collider)
		
		if not is_secondary:
			# A. Scanning
			if target_product and target_product.has_meta("to_scan"):
				_scan_item(target_product)
				return
				
			# B. Picking up from floor
			if collider.has_method("pick_up"):
				pick_up_object(collider)
			# C. Static Interact
			elif collider.has_method("interact"):
				collider.interact()

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
	
	# Notify register/customer (still keep delayed payment logic)
	if item.has_meta("register"):
		var register = item.get_meta("register")
		if register and register.has_method("_on_item_scanned"):
			register._on_item_scanned(item, item.product_data.sell_price)
	
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

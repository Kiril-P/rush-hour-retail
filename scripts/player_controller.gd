extends CharacterBody3D

signal interact_object

@onready var camera_3d = $Camera3D
@onready var ray_cast_3d = $Camera3D/RayCast3D
@onready var interaction_component = $InteractionComponent
@onready var crosshair: TextureRect = $Camera3D/Control/TextureRect

const SPEED = 1.8
const SPRINT_SPEED = 3.5
const CROUCH_SPEED = 1.2
const JUMP_VELOCITY = 3.0
const CAMERA_SENS = 0.001

const BOB_FREQ = 3.0
const BOB_AMP = 0.04
var t_bob = 0.0

const CROUCH_HEIGHT = 0.4
const STAND_HEIGHT = 0.8
const CROUCH_CAM_Y = 0.1
const STAND_CAM_Y = 0.3
var is_crouching = false

const ACCEL = 10.0
const FRICTION = 8.0
const AIR_CONTROL = 0.3

const BASE_FOV = 75.0
const SPRINT_FOV = 85.0
const LEAN_AMOUNT = 0.015
const LANDING_DIP = 0.05

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var collider = null
var interact_button_pressed_time = 0.0
var secondary_interact_pressed_time = 0.0
var was_on_floor = true

@onready var collision_shape_3d = $CollisionShape3D

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	await get_tree().process_frame
	var spawn = get_tree().current_scene.find_child("PlayerSpawnPoint")
	if spawn:
		global_position = spawn.global_position
		rotation.y = spawn.rotation.y
	
	print("\n=== PLAYER READY ===")
	print("Checking input actions...")
	print("'cart_add_item' exists: ", InputMap.has_action("cart_add_item"))
	print("'cart_remove_item' exists: ", InputMap.has_action("cart_remove_item"))
	print("====================\n")

func _input(event):
	if event.is_action_pressed("quit"): 
		get_tree().quit()

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * CAMERA_SENS)
		camera_3d.rotate_x(-event.relative.y * CAMERA_SENS)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Left click
	if event.is_action_pressed("interact"):
		interact_button_pressed_time = Time.get_ticks_msec()
	
	if event.is_action_released("interact"):
		var hold_duration = (Time.get_ticks_msec() - interact_button_pressed_time) / 1000.0
		interaction_component.handle_interaction(collider, hold_duration, false)
	
	# Right click
	if event.is_action_pressed("secondary_interact"):
		secondary_interact_pressed_time = Time.get_ticks_msec()
	
	if event.is_action_released("secondary_interact"):
		var hold_duration = (Time.get_ticks_msec() - secondary_interact_pressed_time) / 1000.0
		interaction_component.handle_interaction(collider, hold_duration, true)
	
	# E key - NEW BEHAVIOR!
	if event.is_action_pressed("cart_add_item"):
		print("\n>>> E KEY PRESSED <<<")
		
		# Priority 1: If pushing cart, release it
		if interaction_component.is_pushing_cart():
			print("Releasing cart with E key...")
			interaction_component.release_cart_if_active()
		
		# Priority 2: If looking at cart with empty hands, take out item
		elif _is_looking_at_cart() and not interaction_component.is_holding_item():
			print("Taking item from cart with E key...")
			var cart = _get_cart_in_view()
			if cart and not cart.is_empty():
				var item = cart.remove_last_item()
				if item:
					interaction_component.picked_object = item
					if item is RigidBody3D:
						item.freeze = false
						item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
						add_collision_exception_with(item)
						if interaction_component.active_cart:
							item.add_collision_exception_with(interaction_component.active_cart)
					item.global_transform = interaction_component.carry_marker.global_transform
					print("✓ Picked up item from cart with E key")
			else:
				print("Cart is empty!")
		
		# Priority 3: If holding item, add to cart
		elif interaction_component.is_holding_item():
			interaction_component.handle_cart_action("add_item")
		
		else:
			print("E key: Nothing to do")
	
	# R key - Remove item from cart (when pushing cart)
	if event.is_action_pressed("cart_remove_item"):
		print("\n>>> R KEY PRESSED <<<")
		interaction_component.handle_cart_action("remove_item")

func _is_looking_at_cart() -> bool:
	"""Check if player is looking at a cart"""
	if not collider:
		return false
	
	# Check if collider or its parents is a cart
	var current = collider
	var depth = 0
	while current != null and depth < 5:
		if current is ShoppingCart:
			return true
		current = current.get_parent()
		depth += 1
	
	return false

func _get_cart_in_view() -> ShoppingCart:
	"""Get the cart player is looking at"""
	if not collider:
		return null
	
	var current = collider
	var depth = 0
	while current != null and depth < 5:
		if current is ShoppingCart:
			return current
		current = current.get_parent()
		depth += 1
	
	return null

func _physics_process(delta):
	var current_speed = SPEED
	if Input.is_action_pressed("crouch"):
		current_speed = CROUCH_SPEED
		is_crouching = true
	elif Input.is_action_pressed("sprint") and not is_crouching:
		current_speed = SPRINT_SPEED
		is_crouching = false
	else:
		is_crouching = false

	var target_height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var target_cam_y = CROUCH_CAM_Y if is_crouching else STAND_CAM_Y
	collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, target_height, delta * 12.0)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_on_floor = false
	else:
		if not was_on_floor:
			_apply_landing_effects()
			was_on_floor = true
		
		if Input.is_action_just_pressed("ui_accept") and not is_crouching:
			velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var accel_to_use = ACCEL if is_on_floor() else ACCEL * AIR_CONTROL
	var friction_to_use = FRICTION if is_on_floor() else FRICTION * AIR_CONTROL

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * accel_to_use)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * accel_to_use)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * friction_to_use)
		velocity.z = lerp(velocity.z, 0.0, delta * friction_to_use)

	move_and_slide()

	t_bob += delta * velocity.length() * float(is_on_floor())
	var bob_pos = _head_bob(t_bob)
	
	var target_lean = -input_dir.x * LEAN_AMOUNT
	camera_3d.rotation.z = lerp(camera_3d.rotation.z, target_lean, delta * 6.0)

	camera_3d.position.y = lerp(camera_3d.position.y, target_cam_y + bob_pos.y, delta * 12.0)
	camera_3d.position.x = lerp(camera_3d.position.x, bob_pos.x, delta * 12.0)

	var target_fov = SPRINT_FOV if (Input.is_action_pressed("sprint") and velocity.length() > 2.0) else BASE_FOV
	camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * 8.0)

func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _apply_landing_effects():
	camera_3d.position.y -= LANDING_DIP

func _process(_delta):
	if ray_cast_3d.is_colliding():
		collider = ray_cast_3d.get_collider()
		interact_object.emit(collider)
	else: 
		collider = null
		interact_object.emit(null)
	
	_update_crosshair_visual(_delta)

func _update_crosshair_visual(delta):
	if not crosshair: return
	
	var is_interactable = false
	if collider:
		if collider is ShoppingCart or _find_cart_parent(collider):
			is_interactable = true
		elif collider.has_method("pick_up"):
			is_interactable = true
		elif collider.has_method("interact"):
			is_interactable = true
		elif interaction_component._find_product(collider):
			is_interactable = true
		
	var target_color = Color.WHITE
	var target_scale = Vector2(1.0, 1.0)
	
	if is_interactable:
		target_color = Color(0.2, 1.0, 0.8)
		target_scale = Vector2(1.2, 1.2)
	
	crosshair.modulate = crosshair.modulate.lerp(target_color, delta * 20.0)
	crosshair.scale = crosshair.scale.lerp(target_scale, delta * 20.0)

func _find_cart_parent(node) -> ShoppingCart:
	var current = node
	var depth = 0
	while current != null and depth < 5:
		if current is ShoppingCart:
			return current
		current = current.get_parent()
		depth += 1
	return null

extends CharacterBody3D

signal interact_object

@onready var camera_3d = $Camera3D
@onready var ray_cast_3d = $Camera3D/RayCast3D
@onready var interaction_component = $InteractionComponent
@onready var crosshair: TextureRect = $Camera3D/Control/TextureRect
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var tutorial_ui = $CanvasLayer/TutorialUI
@onready var tooltip_ui = %TooltipUI
@onready var item_name_label = %ItemNameLabel
@onready var item_price_label = %ItemPriceLabel

const SPEED = 2
const SPRINT_SPEED = 4
const CROUCH_SPEED = 1.2
const JUMP_VELOCITY = 3.0

# Dynamic settings from GameManager
var current_mouse_sens = 0.001
var current_base_fov = 75.0

# CART/BASKET SPEED MODIFIERS
const CART_SPEED_MULT = 0.5   # 50% speed with cart
const BASKET_SPEED_MULT = 0.8 # 80% speed with basket

const BOB_FREQ = 3.0
const BOB_AMP = 0.04
var t_bob = 0.02

const CROUCH_HEIGHT = 0.4
const STAND_HEIGHT = 0.8
const CROUCH_CAM_Y = 0.1
const STAND_CAM_Y = 0.3
var is_crouching = false

const ACCEL = 10.0
const FRICTION = 8.0
const AIR_CONTROL = 0.3

const LEAN_AMOUNT = 0.015
const LANDING_DIP = 0.05

# ANTI-STUCK MECHANICS
const COYOTE_TIME = 0.15  # Seconds after leaving ground where jump still works
const JUMP_BUFFER_TIME = 0.1  # Seconds before landing where jump input is remembered
const UNSTUCK_CHECK_TIME = 0.5  # How long stuck before allowing emergency jump
const GROUND_PROXIMITY = 0.5  # Distance from ground to allow jumping

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var collider = null
var interact_button_pressed_time = 0.0
var secondary_interact_pressed_time = 0.0
var was_on_floor = true

# PERFORMANCE: Cache to prevent redundant lookups
var cached_collider = null
var cached_interactable = null
var cached_tooltip_item = null

# Anti-stuck variables
var time_left_ground = 0.0  # Time since we left the ground
var jump_buffer = 0.0  # Time since jump was pressed
var time_stuck = 0.0  # Time spent not moving with input
var last_position = Vector3.ZERO

# Screen Shake
var shake_amount: float = 0.0
var shake_decay: float = 5.0

# Player Stun System
var is_stunned: bool = false
var stun_duration: float = 0.0
var stun_vignette_amount: float = 0.0

@onready var collision_shape_3d = $CollisionShape3D
@onready var ground_check_ray: RayCast3D = null  # Will create in _ready

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create ground proximity raycast for anti-stuck jumping
	ground_check_ray = RayCast3D.new()
	add_child(ground_check_ray)
	ground_check_ray.target_position = Vector3(0, -GROUND_PROXIMITY, 0)
	ground_check_ray.enabled = true
	ground_check_ray.collide_with_areas = false
	
	await get_tree().process_frame
	var spawn = get_tree().current_scene.find_child("PlayerSpawnPoint")
	if spawn:
		global_position = spawn.global_position
		rotation.y = spawn.rotation.y
	
	last_position = global_position
	

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		# If game is already paused or over/won, don't try to pause again
		if get_tree().paused or not GameManager.is_game_active:
			return
			
		if pause_menu:
			print("Opening Pause Menu...")
			pause_menu.pause()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * current_mouse_sens)
		camera_3d.rotate_x(-event.relative.y * current_mouse_sens)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	# Jump buffering - remember jump input for a short time
	if event.is_action_pressed("ui_accept"):
		jump_buffer = JUMP_BUFFER_TIME

	# Left click
	if event.is_action_pressed("interact"):
		# Check if looking at a customer
		if ray_cast_3d.is_colliding():
			var hit = ray_cast_3d.get_collider()
			if hit and hit is CustomerAI:
				_punch_customer(hit)
				return  # Don't do regular interaction if we punched
		
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
		
		# Priority 1: If pushing cart, release it
		if interaction_component.is_pushing_cart():
			interaction_component.release_cart_if_active()
		
		# Priority 2: If looking at cart with empty hands, take out item
		elif _is_looking_at_cart() and not interaction_component.is_holding_item():
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
		
		# Priority 3: If holding item, add to cart
		elif interaction_component.is_holding_item():
			interaction_component.handle_cart_action("add_item")
		
	
	# R key - Remove item from cart (when pushing cart)
	if event.is_action_pressed("cart_remove_item"):
		interaction_component.handle_cart_action("remove_item")

func _is_looking_at_cart() -> bool:
	"""Check if player is looking at a cart or basket"""
	if not collider:
		return false
	
	# Check if collider or its parents is a cart or basket
	var current = collider
	var depth = 0
	while current != null and depth < 5:
		if current is ShoppingCart or current is ShoppingBasket:
			return true
		current = current.get_parent()
		depth += 1
	
	return false

func _get_cart_in_view():
	"""Get the cart or basket player is looking at"""
	if not collider:
		return null
	
	var current = collider
	var depth = 0
	while current != null and depth < 5:
		if current is ShoppingCart or current is ShoppingBasket:
			return current
		current = current.get_parent()
		depth += 1
	
	return null

func _get_carry_speed_multiplier() -> float:
	"""Get speed multiplier based on what player is carrying"""
	var cart = interaction_component.get_active_cart()
	
	if cart:
		# Check if it's a basket or cart
		if cart.is_in_group("basket"):
			return BASKET_SPEED_MULT  # 80% speed with basket
		else:
			return CART_SPEED_MULT    # 50% speed with cart
	
	return 1.0  # Normal speed

func _physics_process(delta):
	# Update from GameManager settings
	if GameManager:
		current_mouse_sens = GameManager.mouse_sensitivity
		current_base_fov = GameManager.target_fov
	
	# Update stun effect
	_update_stun_effect(delta)
	
	# If stunned, don't process normal movement
	if is_stunned:
		# Apply gravity while stunned
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		# Reduce knockback velocity
		velocity.x = lerp(velocity.x, 0.0, delta * 5.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 5.0)
		
		move_and_slide()
		return

	# Crouching and Sprinting logic
	is_crouching = Input.is_action_pressed("crouch")
	var is_sprinting = Input.is_action_pressed("sprint")
	var current_speed = SPEED
	
	if is_sprinting:
		GameManager.mark_tutorial_complete("movement")
	if is_crouching:
		GameManager.mark_tutorial_complete("movement")
	
	# Determine speed
	if is_sprinting and not is_crouching:
		current_speed = SPRINT_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED
		# Allow a bit faster crouch-sprint if desired
		if is_sprinting:
			current_speed = (SPRINT_SPEED + CROUCH_SPEED) / 1.5
	else:
		current_speed = SPEED
	
	# APPLY CART/BASKET SPEED MODIFIERS
	var speed_mult = _get_carry_speed_multiplier()
	current_speed *= speed_mult

	var target_height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var target_cam_y = CROUCH_CAM_Y if is_crouching else STAND_CAM_Y
	
	# Handle collision shape height (need to adjust position too or use centered shape)
	collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, target_height, delta * 12.0)
	
	# Update coyote time and jump buffer
	if is_on_floor():
		time_left_ground = COYOTE_TIME
		if not was_on_floor:
			_apply_landing_effects()
			was_on_floor = true
	else:
		time_left_ground -= delta
		was_on_floor = false
	
	if jump_buffer > 0:
		jump_buffer -= delta
	
	# Check if player is stuck
	_check_if_stuck(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# IMPROVED JUMP LOGIC - Multiple conditions to prevent getting stuck
	var can_jump = false
	var jump_reason = ""
	
	# Standard jump
	if is_on_floor() and (Input.is_action_just_pressed("ui_accept") or jump_buffer > 0):
		can_jump = true
		jump_reason = "normal"
	
	# Coyote time jump
	elif time_left_ground > 0 and Input.is_action_just_pressed("ui_accept"):
		can_jump = true
		jump_reason = "coyote"
	
	# Ground proximity jump (for when stuck between objects)
	elif _is_near_ground() and (Input.is_action_just_pressed("ui_accept") or jump_buffer > 0):
		can_jump = true
		jump_reason = "proximity"
	
	# Emergency unstuck jump
	elif time_stuck > UNSTUCK_CHECK_TIME and (Input.is_action_just_pressed("ui_accept") or jump_buffer > 0):
		can_jump = true
		jump_reason = "unstuck"
	
	if can_jump:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0  # Consume the buffer
		time_stuck = 0  # Reset stuck timer

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

	# FOV effect
	var target_fov = (current_base_fov + 10.0) if is_sprinting else current_base_fov
	camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * 8.0)

func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _apply_landing_effects():
	camera_3d.position.y -= LANDING_DIP

func _process(_delta):
	# Get current collider
	var new_collider = ray_cast_3d.get_collider() if ray_cast_3d.is_colliding() else null
	
	# OPTIMIZATION: Only update if collider actually changed!
	if new_collider != cached_collider:
		collider = new_collider
		cached_collider = new_collider
		
		# Clear caches when collider changes
		cached_interactable = null
		cached_tooltip_item = null
		
		# Emit signal and update UI (expensive operations only when needed!)
		interact_object.emit(collider)
		_update_item_tooltip(collider)
		_update_crosshair_visual(_delta)
	
	_apply_screen_shake(_delta)

func _update_item_tooltip(target):
	if not tooltip_ui: 
		return
	
	# Check for special interactables first (like Help Desk)
	if target and target.has_method("interact") and not target.is_in_group("pickable") and not target.is_in_group("checkout"):
		tooltip_ui.show()
		item_name_label.text = "Help Desk"
		if target.has_method("get_cooldown_text"):
			item_price_label.text = target.get_cooldown_text()
		else:
			item_price_label.text = "Press Left Click to Use"
		return

	# Use cached result if available (HUGE performance win!)
	var item = cached_tooltip_item
	if item == null and target:
		item = _find_product_fast(target)
		cached_tooltip_item = item
	
	if item and not interaction_component.is_holding_item():
		tooltip_ui.show()
		var name_to_show = item.get_item_name() if item.has_method("get_item_name") else item.item_name
		
		# SPECIAL CASE: Help Desk
		if target.has_method("interact") and not target.is_in_group("pickable") and not target.is_in_group("checkout"):
			item_name_label.text = "Help Desk"
			item_price_label.text = "Press Left Click to Use"
			return

		# Get points from GameManager
		var points = GameManager.available_items.get(name_to_show, 10)
		
		item_name_label.text = name_to_show
		item_price_label.text = "$%d" % points
	else:
		tooltip_ui.hide()

func _find_product_fast(node) -> Node:
	"""Optimized product finder with depth limit and group checks"""
	if not node:
		return null
	
	# Fast path: check if it's directly pickable (most common case!)
	if node.is_in_group("pickable"):
		return node
	
	# Walk up tree with depth limit
	var current = node
	var depth = 0
	while current != null and depth < 5:  # Max 5 levels up
		if current.is_in_group("pickable") or "item_name" in current or "product_data" in current:
			return current
		current = current.get_parent()
		depth += 1
	
	return null

func add_shake(amount: float):
	shake_amount += amount

func _apply_screen_shake(delta):
	if shake_amount > 0:
		var offset = Vector3(
			randf_range(-1.0, 1.0) * shake_amount,
			randf_range(-1.0, 1.0) * shake_amount,
			0.0
		)
		camera_3d.h_offset = offset.x
		camera_3d.v_offset = offset.y
		shake_amount = lerp(shake_amount, 0.0, delta * shake_decay)
	else:
		camera_3d.h_offset = 0
		camera_3d.v_offset = 0

func _update_crosshair_visual(delta):
	if not crosshair: 
		return
	
	# Check if looking at a customer (punchable!)
	var looking_at_customer = false
	if ray_cast_3d.is_colliding():
		var hit = ray_cast_3d.get_collider()
		if hit and hit is CustomerAI:
			looking_at_customer = true
	
	# Use cached result (only calculated when collider changes!)
	var is_interactable = cached_interactable
	if is_interactable == null:
		is_interactable = _check_if_interactable(collider)
		cached_interactable = is_interactable
	
	var target_color = Color.WHITE
	var target_scale = Vector2(1.0, 1.0)
	
	# Priority: Customer (punchable) overrides regular interactable
	if looking_at_customer:
		target_color = Color(1.0, 0.3, 0.3)  # Red for punch
		target_scale = Vector2(1.3, 1.3)
	elif is_interactable:
		target_color = Color(0.2, 1.0, 0.8)  # Cyan for interact
		target_scale = Vector2(1.2, 1.2)
	
	crosshair.modulate = crosshair.modulate.lerp(target_color, delta * 20.0)
	crosshair.scale = crosshair.scale.lerp(target_scale, delta * 20.0)

func _check_if_interactable(target) -> bool:
	"""Check if target is interactable - OPTIMIZED with early returns"""
	if not target:
		return false
	
	# Fast checks first (no tree traversal)
	if target is ShoppingCart or target is ShoppingBasket:
		GameManager.trigger_tutorial("cart_basket")
		return true
	
	if target.has_method("pick_up"):
		GameManager.trigger_tutorial("pickup")
		return true
	
	if target.has_method("interact"):
		if target.is_in_group("checkout"):
			GameManager.trigger_tutorial("checkout")
		return true
	
	# Group check (fast!)
	if target.is_in_group("pickable"):
		return true
	
	# Last resort: parent search (expensive, but limited depth)
	if _find_cart_parent(target):
		GameManager.trigger_tutorial("cart_basket")
		return true
	
	if _find_product_fast(target):
		return true
	
	return false

func _find_cart_parent(node) -> ShoppingCart:
	"""Find cart parent with depth limit - OPTIMIZED"""
	if not node:
		return null
	
	var current = node
	var depth = 0
	while current != null and depth < 3:  # Reduced depth for performance
		if current is ShoppingCart or current is ShoppingBasket:
			return current
		current = current.get_parent()
		depth += 1
	return null

func _check_if_stuck(delta):
	"""Detect if player is stuck (has input but not moving)"""
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var has_input = input_dir.length() > 0.1
	var position_delta = global_position.distance_to(last_position)
	var is_stuck = has_input and position_delta < 0.01 and not is_on_floor()
	
	if is_stuck:
		time_stuck += delta
	else:
		time_stuck = 0
	
	last_position = global_position

func _is_near_ground() -> bool:
	"""Check if player is close to ground using raycast"""
	if ground_check_ray and ground_check_ray.is_colliding():
		return true
	return false

func _punch_customer(customer: CustomerAI):
	"""Punch/push a customer, applying knockback"""
	if not customer or not is_instance_valid(customer):
		return
	
	# Can't punch while stunned
	if is_stunned:
		return
	
	# Apply knockback from player's position
	customer.apply_knockback(global_position, 1.0)
	
	# Screen shake for impact feedback (use existing shake system)
	shake_amount += 0.3
	
	# TODO: Add hitmarker visual in a future update

func take_customer_attack(knockback_velocity: Vector3, from_position: Vector3):
	"""Called when an aggressive customer attacks the player"""
	if is_stunned:
		return  # Already stunned
	
	# Apply knockback
	velocity = knockback_velocity
	
	# Stun the player
	is_stunned = true
	stun_duration = 1.0
	
	# Heavy screen shake
	shake_amount += 0.8
	
	# Play hit sound
	_play_player_hit_sound()

func _play_player_hit_sound():
	"""Play sound when player gets hit"""
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var hit_sound = load("res://assets/sfx/MLG Hitmarker Sound Effect.mp3")
	if hit_sound:
		audio_player.stream = hit_sound
		audio_player.volume_db = 5
		audio_player.play()
		
		# Auto-delete after playing
		await audio_player.finished
		audio_player.queue_free()

func _update_stun_effect(delta):
	"""Handle stun timer and effects"""
	if is_stunned:
		stun_duration -= delta
		stun_vignette_amount = lerp(stun_vignette_amount, 1.0, delta * 10.0)
		
		if stun_duration <= 0:
			is_stunned = false
			stun_duration = 0
	else:
		stun_vignette_amount = lerp(stun_vignette_amount, 0.0, delta * 5.0)

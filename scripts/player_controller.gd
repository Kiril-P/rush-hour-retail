extends CharacterBody3D

signal interact_object

@onready var camera_3d = $Camera3D
@onready var ray_cast_3d = $Camera3D/RayCast3D
@onready var build_component = $BuildComponent
@onready var interaction_component = $InteractionComponent

const SPEED = 2.0
const JUMP_VELOCITY = 2.5
const CAMERA_SENS = 0.0007

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var collider = null
var interact_button_pressed_time = 0.0

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	build_component.ray_cast_3d = ray_cast_3d
	build_component.build_preview_marker = $Camera3D/BuildPreviewMarker

func _input(event):
	if event.is_action_pressed("quit"): get_tree().quit()

	# 1. HANDLE SHOP TOGGLE FIRST (so 'B' can close it)
	if event.is_action_pressed("shop"):
		$CanvasLayer/ShopUI.toggle()
		return

	# 2. DISABLE OTHER INPUTS IF SHOP IS OPEN
	if $CanvasLayer/ShopUI.visible:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * CAMERA_SENS)
		camera_3d.rotate_x(-event.relative.y * CAMERA_SENS)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("build_mode"):
		build_component.toggle_build_mode()
	
	if build_component.is_building:
		handle_build_input(event)
		return 

	if event.is_action_pressed("interact"):
		interact_button_pressed_time = Time.get_ticks_msec()
	
	if event.is_action_released("interact"):
		var hold_duration = (Time.get_ticks_msec() - interact_button_pressed_time) / 1000.0
		interaction_component.handle_interaction(collider, hold_duration)
func handle_build_input(event):
	# Rotate (Now 45 degrees inverted)
	if event.is_action_pressed("rotate_object"): 
		build_component.rotate_ghost()
	
	# Place / Confirm Move
	if event.is_action_pressed("interact"): # Left Click
		build_component.place_item()
		
	# Delete / Cancel Move
	if event.is_action_pressed("secondary_interact"): # Right Click
		if build_component.moving_item:
			build_component.cancel_move()
		else:
			build_component.delete_item(collider)
			
	# Pick up to Move
	if event.is_action_pressed("middle_click"):
		build_component.pick_up_to_move(collider)

	if event.is_action_pressed("next_item"): build_component.cycle_items(1)
	if event.is_action_pressed("prev_item"): build_component.cycle_items(-1)

	# NEW: Toggle Snap with Ctrl
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_CTRL:
			build_component.cycle_snap()

func _physics_process(delta):
	if $CanvasLayer/ShopUI.visible:
		# Apply ONLY gravity so player falls to floor but cannot move
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0
		
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if not is_on_floor(): velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor(): velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED if direction else move_toward(velocity.x, 0, SPEED)
	velocity.z = direction.z * SPEED if direction else move_toward(velocity.z, 0, SPEED)
	move_and_slide()

func _process(_delta):
	if ray_cast_3d.is_colliding():
		collider = ray_cast_3d.get_collider()
		interact_object.emit(collider)
	else: 
		collider = null
		interact_object.emit(null)

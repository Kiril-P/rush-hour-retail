extends CharacterBody3D

enum State { ENTERING, SHOPPING, CHECKOUT, LEAVING }

@export var movement_speed: float = 1.5
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_state = State.ENTERING
var exit_position: Vector3
var target_shelf: Node3D = null
var is_waiting: bool = false
var basket: Array[Node] = []

var shelves_to_visit: int = 0
var shelves_visited: int = 0

var current_register: Node3D = null
var is_at_head_of_queue: bool = false

# Life/Randomness variables
var pause_timer: float = 0.0
var is_paused: bool = false

func _ready():
	# Wait for first frame so navigation is ready
	await get_tree().process_frame
	shelves_to_visit = randi_range(1, 3) # Decides how many things they want to buy
	start_shopping()

func _physics_process(delta):
	if is_waiting:
		return

	# Random Pause Logic (Adds "life")
	if not is_paused and randf() < 0.002: # Small chance per frame to pause
		_start_random_pause()
	
	if is_paused:
		pause_timer -= delta
		if pause_timer <= 0:
			is_paused = false
		return
		
	if nav_agent.is_navigation_finished():
		_on_target_reached()
		return

	var next_path_position = nav_agent.get_next_path_position()
	var current_position = global_transform.origin
	var new_velocity = (next_path_position - current_position).normalized() * movement_speed
	
	velocity = new_velocity
	move_and_slide()

func start_shopping():
	current_state = State.SHOPPING
	_find_random_shelf()

func _find_random_shelf():
	var shelves = get_tree().get_nodes_in_group("shelf")
	
	if shelves.size() > 0:
		target_shelf = shelves.pick_random()
		nav_agent.target_position = target_shelf.global_position
	else:
		# If literally NO shelves exist in the world yet
		leave_shop()

func _on_target_reached():
	if is_waiting: return
	
	match current_state:
		State.SHOPPING:
			is_waiting = true
			await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
			
			# TAKE ITEM LOGIC
			if target_shelf and target_shelf.has_method("take_random_item"):
				var item = target_shelf.take_random_item()
				if item:
					basket.append(item)
					item.visible = false 
					print("Customer: Found item on shelf!")
				else:
					print("Customer: Shelf was empty! (Sad customer...)")
			
			shelves_visited += 1
			is_waiting = false
			
			if shelves_visited < shelves_to_visit:
				_find_random_shelf()
			else:
				go_to_checkout()
		State.CHECKOUT:
			if is_at_head_of_queue and not is_waiting:
				_start_checkout_process()
		State.LEAVING:
			queue_free()

func _start_checkout_process():
	is_waiting = true
	print("Customer: Placing items on counter...")
	await get_tree().create_timer(1.0).timeout
	
	if current_register and current_register.has_method("place_items_for_scanning"):
		current_register.place_items_for_scanning(basket)
		# Wait for all items to be scanned
		if not current_register.all_items_scanned.is_connected(leave_shop):
			current_register.all_items_scanned.connect(leave_shop, CONNECT_ONE_SHOT)
		basket = [] # Items are now on the counter
	else:
		# Fallback if register logic fails
		leave_shop()

func go_to_checkout():
	if basket.is_empty():
		print("Customer: Nothing to buy, leaving.")
		leave_shop()
		return

	current_state = State.CHECKOUT
	var registers = get_tree().get_nodes_in_group("register")
	if registers.size() > 0:
		# Find the register with the shortest queue
		var best_register = registers[0]
		var min_queue = 999
		
		for reg in registers:
			var q_size = 0
			if reg.has_method("get_queue_size"):
				q_size = reg.get_queue_size()
			if q_size < min_queue:
				min_queue = q_size
				best_register = reg
		
		current_register = best_register
		if current_register.has_method("join_queue"):
			current_register.join_queue(self)
	else:
		leave_shop()

func update_queue_position(target_pos: Vector3, is_head: bool):
	nav_agent.target_position = target_pos
	is_at_head_of_queue = is_head

func _start_random_pause():
	is_paused = true
	pause_timer = randf_range(0.5, 2.0)
	# Play idle animation here later if you have one
	velocity = Vector3.ZERO

func leave_shop():
	if current_register and current_register.has_method("leave_queue"):
		current_register.leave_queue(self)
	
	current_state = State.LEAVING
	nav_agent.target_position = exit_position
	is_waiting = false

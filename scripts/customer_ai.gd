extends CharacterBody3D

enum State { ENTERING, SHOPPING, CHECKOUT, LEAVING }

@export var movement_speed: float = 1.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_state = State.ENTERING
var exit_position: Vector3
var target_shelf: Node3D = null
var is_waiting: bool = false
var basket: Array[Node] = []
var pending_payment: float = 0.0

var shelves_to_visit: int = 0
var shelves_visited: int = 0

var current_register: Node3D = null
var is_at_head_of_queue: bool = false

# Shopping List & Emotions
var shopping_list: Array[ProductData] = []
var items_found: int = 0
var frustration: float = 0.0
var max_frustration: float = 100.0
var frustration_rate: float = 4.0 # per second when waiting
var speech_bubble: Label3D

var current_target_item: ProductData = null

# Life/Randomness variables
var pause_timer: float = 0.0
var is_paused: bool = false

func _ready():
	# Wait for first frame so navigation is ready
	await get_tree().process_frame
	
	# Setup Speech Bubble
	_setup_speech_bubble()
	
	# Create Shopping List
	_generate_shopping_list()
	
	start_shopping()

func _setup_speech_bubble():
	# Create a Label3D if it doesn't exist
	speech_bubble = Label3D.new()
	add_child(speech_bubble)
	speech_bubble.position = Vector3(0, 1.0, 0) # Above head
	speech_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_bubble.no_depth_test = true # See through walls slightly
	speech_bubble.outline_render_priority = 1
	speech_bubble.outline_size = 4
	speech_bubble.font_size = 48
	speech_bubble.text = ""
	speech_bubble.visible = false

func _generate_shopping_list():
	var available = GameManager.available_products
	if available.is_empty():
		shelves_to_visit = 1
		return

	var list_size = randi_range(1, 4)
	for i in range(list_size):
		shopping_list.append(available.pick_random())
	shelves_to_visit = shopping_list.size()

func _physics_process(delta):
	if is_waiting:
		# If waiting in checkout line, increase frustration
		if current_state == State.CHECKOUT:
			_increase_frustration(delta * frustration_rate)
		return
	
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
	shelves_visited = 0
	_process_next_item()

func _process_next_item():
	if shelves_visited >= shopping_list.size():
		go_to_checkout()
		return
	
	current_target_item = shopping_list[shelves_visited]
	var shelf = _find_shelf_with_item(current_target_item)
	
	if shelf:
		target_shelf = shelf
		nav_agent.target_position = target_shelf.global_position
	else:
		# Item not in store! 
		# Walk to a random shelf ANYWAY to "look" for it
		var shelves = get_tree().get_nodes_in_group("shelf")
		if shelves.size() > 0:
			target_shelf = shelves.pick_random()
			nav_agent.target_position = target_shelf.global_position
		else:
			# No shelves at all? Just leave.
			leave_shop()
		return # Crucial: don't proceed to next logic

func _find_shelf_with_item(item_data: ProductData):
	var shelves = get_tree().get_nodes_in_group("shelf")
	# Shuffle shelves so customers don't all go to the same one if multiple have the item
	shelves.shuffle()
	
	for shelf in shelves:
		if shelf.has_method("get_item_count"):
			if _shelf_has_product(shelf, item_data):
				return shelf
	return null

func _shelf_has_product(shelf, item_data):
	if "itemsPlaced" in shelf:
		for item in shelf.itemsPlaced:
			if item != null and "product_data" in item and item.product_data == item_data:
				return true
	return false

func _on_target_reached():
	if is_waiting or is_paused: return
	
	match current_state:
		State.SHOPPING:
			# ... existing logic ...
			is_waiting = true
			await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
			
			# TAKE ITEM LOGIC
			var found = false
			if target_shelf and current_target_item:
				if _shelf_has_product(target_shelf, current_target_item):
					var item = target_shelf.take_specific_item(current_target_item)
					if item:
						basket.append(item)
						item.visible = false 
						items_found += 1
						found = true
						print("Customer: Found ", current_target_item.item_name, " on shelf!")
			
			if not found:
				# They looked but couldn't find the item they wanted!
				_show_emotion("❌ " + current_target_item.item_name)
				_increase_frustration(25.0)
			
			is_waiting = false
			shelves_visited += 1
			
			# Process next item immediately. 
			_process_next_item()
			
			# Start a delayed pause check
			_check_for_moving_pause()
		State.CHECKOUT:
			# TELEPORT/SNAP to exact spot
			global_position = nav_agent.target_position
			
			if is_at_head_of_queue and not is_waiting:
				_start_checkout_process()
		State.LEAVING:
			queue_free()

func _show_emotion(text: String, duration: float = 2.0):
	if speech_bubble:
		speech_bubble.text = text
		speech_bubble.visible = true
		
		# Auto-hide after duration
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func(): if is_instance_valid(speech_bubble) and speech_bubble.text == text: speech_bubble.visible = false)

func _increase_frustration(amount: float):
	frustration += amount
	if frustration >= 50.0 and frustration < 50.0 + amount:
		_show_emotion("⌚...") # Getting impatient
	
	if frustration >= max_frustration:
		_show_emotion("😡 BYE!")
		leave_shop()

func _start_checkout_process():
	is_waiting = true
	print("Customer: Placing items on counter...")
	await get_tree().create_timer(1.5).timeout
	
	if current_register and current_register.has_method("place_items_for_scanning"):
		current_register.place_items_for_scanning(basket)
		# Wait for all items to be scanned
		if not current_register.all_items_scanned.is_connected(_on_checkout_complete):
			current_register.all_items_scanned.connect(_on_checkout_complete, CONNECT_ONE_SHOT)
		basket = [] # Items are now on the counter
	else:
		# Fallback if register logic fails
		leave_shop()

func _on_checkout_complete():
	_show_emotion("😊 Thanks!")
	
	# Pay the total amount now that checkout is finished
	if pending_payment > 0:
		GameManager.add_sale(pending_payment, items_found)
		print("Customer: Paid total of $", pending_payment)
		pending_payment = 0.0
		
	GameManager.add_customer_served()
	leave_shop()

func add_to_bill(amount: float):
	pending_payment += amount

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

func update_queue_position(target_pos: Vector3, target_rot: Vector3, is_head: bool):
	nav_agent.target_position = target_pos
	is_at_head_of_queue = is_head
	
	# If they are already very close, just snap now
	if global_position.distance_to(target_pos) < 0.2:
		global_position = target_pos
		global_rotation.y = target_rot.y
	
	# FORCE RESUME: If they were waiting, nudge them to move to the new spot
	is_waiting = false 
	print("Customer: Moving to queue spot ", target_pos)

func _check_for_moving_pause():
	if randf() < 0.4: # 40% chance
		# Wait half a second while moving
		await get_tree().create_timer(0.5).timeout
		if current_state == State.SHOPPING and not is_waiting:
			_start_random_pause()

func _start_random_pause():
	is_paused = true
	pause_timer = randf_range(3.0, 7.0) # Longer pause
	velocity = Vector3.ZERO

func leave_shop():
	if current_state == State.LEAVING: return
	
	if frustration >= max_frustration:
		GameManager.add_unsatisfied_customer()

	if current_register and current_register.has_method("leave_queue"):
		current_register.leave_queue(self)
	
	current_state = State.LEAVING
	nav_agent.target_position = exit_position
	is_waiting = false
	if speech_bubble: speech_bubble.visible = false

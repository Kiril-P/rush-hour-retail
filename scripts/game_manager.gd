extends Node

## Game Manager - With Points & Score System + PERFORMANCE!
## Only generates shopping lists from items that actually spawned!

signal time_changed(seconds_remaining)
signal game_over()
signal game_won()
signal list_completed(list_number)
signal list_generated()
signal item_collected(item_name)
signal score_changed(new_score)
signal target_score_changed(new_target)

var sparkle_scene = preload("res://objects/sparkle_particles.tscn")

# Performance Manager
var performance_manager: Node = null

# Timer System
var time_remaining: float = 60.0
var is_game_active: bool = false
var is_timer_running: bool = false

# Target Score System
var target_score: int = 500
var high_score: int = 0
const SAVE_PATH = "user://save_data.cfg"

# Tutorial System
var tutorial_enabled: bool = true

# Settings
var mouse_sensitivity: float = 0.001
var target_fov: float = 75.0
var volume_master: float = 1.0
var volume_music: float = 0.8
var volume_sfx: float = 1.0

var completed_tutorials: Dictionary = {
	"goal": false,
	"pickup": false,
	"drop_throw": false,
	"cart_basket": false,
	"checkout": false,
	"movement": false,
	"list": false
}
signal tutorial_step_triggered(step_id)
signal tutorial_step_completed(step_id)

# Shopping List System
var current_list_number: int = 1
var current_shopping_list: Array[String] = []

# Stats
var total_score: int = 0
var total_items_collected: int = 0
var total_lists_completed: int = 0
var current_combo: int = 0
var best_combo: int = 0

# Available Items - Names and POINTS (not prices!)
# NOTE: Remove items you don't want from this list!
var available_items: Dictionary = {
	"Bread": 10,
	"Avocado": 15,
	"Banana": 10,
	"Beet": 10,
	"Blue Milk": 10,
	"Bottle Ketchup": 10,
	"Bottle Mustard": 10,
	"Bottle Oil": 15,
	"Broccoli": 10,
	"Cabbage": 10,
	"Cake": 25,
	"Can": 10,
	"Carrot": 10,
	"Purple Milk": 15,
	"Creme": 15,
	"Cauliflower": 10,
	"Cereal Box": 15,
	"Cheese": 15,
	"Cherries": 10,
	"Coconut": 15,
	"Corn": 10,
	"Croissant": 15,
	"Cupcake": 15,
	"Cuttingboard": 10,
	"Chopping Knife": 100,
	"Chocolate Donut": 5,
	"Sprinkle Donut": 5,
	"Plain Donut": 5,
	"Egg": 300,
	"Eggplant": 10,
	"Fish": 20,
	"Frappe": 20,
	"Frying Pan": 20,
	"Cup": 20,
	"Wine Glass": 20,
	"Grapes": 20,
	"Honey": 20,
	"Leek": 20,
	"Lemon": 20,
	"Baguette Loaf": 20,
	"Meat": 20,
	"Sausage": 20,
	"Mushroom": 20,
	"Mussel": 20,
	"Onion": 20,
	"Orange": 20,
	"Paprika": 20,
	"Peanutbutter": 20,
	"Pear": 20,
	"Pepper": 20,
	"Pie": 20,
	"Pineapple": 20,
	"Pizza": 20,
	"Pot": 20,
	"Pumpkin": 20,
	"Radish": 20,
	"Redwine": 20,
	"Salad": 20,
	"Sandwich": 20,
	"Skewer": 20,
	"Soda Bottle": 20,
	"Soda Can": 20,
	"Strawberry": 20,
	"Taco": 20,
	"Tomato": 20,
	"Turkey": 20,
	"Watermelon": 20,
	"Whitewine": 20,
	"Whole Ham": 20,
	"Freezer Glass": 20,
}

# NEW: Track which items actually spawned in the world
var spawned_items_in_world: Array[String] = []

func _ready():
	# Initialize performance manager
	_setup_performance_manager()
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game_data()
	
	# Scan for spawned items after loading is complete
	var loading_manager = get_tree().root.get_node_or_null("LoadingManager")
	if loading_manager and loading_manager.is_loading():
		await loading_manager.loading_finished
	else:
		await get_tree().create_timer(1.0).timeout
		
	_scan_spawned_items()

func _setup_performance_manager():
	"""Create and configure performance manager for physics optimization"""
	var perf_script = load("res://scripts/performance_manager.gd")
	if perf_script:
		performance_manager = Node.new()
		performance_manager.set_script(perf_script)
		performance_manager.name = "PerformanceManager"
		add_child(performance_manager)

func save_game_data():
	var config = ConfigFile.new()
	config.set_value("Player", "high_score", high_score)
	config.set_value("Tutorial", "tutorial_enabled", tutorial_enabled)
	config.set_value("Tutorial", "completed_tutorials", completed_tutorials)
	
	config.set_value("Settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("Settings", "target_fov", target_fov)
	config.set_value("Settings", "volume_master", volume_master)
	config.set_value("Settings", "volume_music", volume_music)
	config.set_value("Settings", "volume_sfx", volume_sfx)
	
	config.save(SAVE_PATH)

func load_game_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		high_score = config.get_value("Player", "high_score", 0)
		tutorial_enabled = config.get_value("Tutorial", "tutorial_enabled", true)
		
		mouse_sensitivity = config.get_value("Settings", "mouse_sensitivity", 0.001)
		target_fov = config.get_value("Settings", "target_fov", 75.0)
		volume_master = config.get_value("Settings", "volume_master", 1.0)
		volume_music = config.get_value("Settings", "volume_music", 0.8)
		volume_sfx = config.get_value("Settings", "volume_sfx", 1.0)
		
		var saved_completed = config.get_value("Tutorial", "completed_tutorials", completed_tutorials)
		# Merge to ensure new tutorial steps are included if we update the game
		for key in saved_completed.keys():
			if completed_tutorials.has(key):
				completed_tutorials[key] = saved_completed[key]

func mark_tutorial_complete(step_id: String):
	if completed_tutorials.has(step_id):
		completed_tutorials[step_id] = true
		tutorial_step_completed.emit(step_id)
		save_game_data()

func trigger_tutorial(step_id: String):
	if tutorial_enabled and completed_tutorials.has(step_id) and not completed_tutorials[step_id]:
		tutorial_step_triggered.emit(step_id)

func get_performance_message(percent: float) -> String:
	if percent >= 100: return "SUPERMARKET LEGEND! You cleaned them out!"
	if percent >= 80: return "Incredible! Almost everything is in the cart!"
	if percent >= 60: return "Great job! That's a lot of groceries!"
	if percent >= 40: return "Not bad at all! You're getting faster!"
	if percent >= 20: return "Keep it up! Every item counts."
	return "Tough day at the market? You'll get them next time!"

func _scan_spawned_items():
	"""Scan the scene to see which items actually spawned"""
	spawned_items_in_world.clear()
	
	
	# Find all items in the scene
	var items = get_tree().get_nodes_in_group("item")
	
	for item in items:
		# Get the item's product name
		if item.has_method("get_product_name"):
			var product_name = item.get_product_name()
			if not spawned_items_in_world.has(product_name):
				spawned_items_in_world.append(product_name)
	

func _process(delta):
	if is_game_active and is_timer_running and not get_tree().paused:
		time_remaining -= delta
		time_changed.emit(time_remaining)
		
		if time_remaining <= 0:
			time_remaining = 0
			is_game_active = false
			is_timer_running = false
			
			# Check for new high score
			var is_new_record = false
			if total_score > high_score:
				high_score = total_score
				is_new_record = true
				save_game_data()
			
			game_over.emit()

func start_game():
	# Reset tutorials so they show every run if enabled
	if tutorial_enabled:
		for key in completed_tutorials.keys():
			completed_tutorials[key] = false
	
	time_remaining = 60.0
	is_game_active = true
	is_timer_running = false # Wait for InsideArea!
	current_list_number = 1
	total_score = 0
	total_items_collected = 0
	total_lists_completed = 0
	current_combo = 0
	best_combo = 0
	generate_shopping_list()
	score_changed.emit(total_score)
	target_score_changed.emit(target_score)

func start_timer():
	if is_game_active and not is_timer_running:
		is_timer_running = true

func generate_shopping_list():
	current_shopping_list.clear()
	
	# List size increases with each completed list
	var list_size = min(2 + current_list_number, 10)
	
	# Get items that ACTUALLY SPAWNED (or fallback to all items)
	var items_to_pick_from = spawned_items_in_world if spawned_items_in_world.size() > 0 else available_items.keys()
	
	# Generate list from spawned items only!
	for i in range(list_size):
		if items_to_pick_from.size() > 0:
			var random_item = items_to_pick_from[randi() % items_to_pick_from.size()]
			current_shopping_list.append(random_item)
	
	
	for item in current_shopping_list:
		var points = available_items[item] if available_items.has(item) else 10
	
	list_generated.emit()

func add_time_bonus(seconds: float):
	time_remaining += seconds
	time_changed.emit(time_remaining)

func check_item_correct(item_name: String) -> bool:
	"""Check if the item is on the current shopping list"""
	return current_shopping_list.has(item_name)

func get_item_points(item_name: String) -> int:
	"""Get points value of an item"""
	if available_items.has(item_name):
		return available_items[item_name]
	return 10  # Default points

func collect_correct_item(item_name: String):
	"""Called when player scans a correct item at checkout"""
	# Get points for this item
	var points = get_item_points(item_name)
	
	# Add combo bonus!
	var combo_multiplier = 1.0 + (current_combo * 0.1)  # +10% per combo
	var total_points = int(points * combo_multiplier)
	
	# Add to score
	total_score += total_points
	score_changed.emit(total_score)
	
	# Check for win condition
	if total_score >= target_score and is_game_active:
		is_game_active = false
		
		# Check for new high score on win too!
		if total_score > high_score:
			high_score = total_score
			save_game_data()
			
		game_won.emit()
		return
	
	# Remove item from list
	current_shopping_list.erase(item_name)
	total_items_collected += 1
	current_combo += 1
	if current_combo > best_combo:
		best_combo = current_combo
	
	# Time bonus per item
	add_time_bonus(5.0)
	
	
	# Emit signal for UI
	item_collected.emit(item_name)
	
	# Check if list is complete
	if current_shopping_list.is_empty():
		complete_list()

func collect_wrong_item(item_name: String):
	"""Called when player scans an item NOT on the list"""
	# Reset combo
	var lost_combo = current_combo
	current_combo = 0
	# Time penalty REMOVED as per request, but keeping feedback logic
	# time_remaining -= 5.0
	# if time_remaining < 0:
	# 	time_remaining = 0
	# time_changed.emit(time_remaining)
	

func complete_list():
	"""All items collected! Give big bonus and generate new list"""
	total_lists_completed += 1
	
	# Big time bonus for completing list
	var time_bonus = 15.0 + (current_list_number * 2.0)
	add_time_bonus(time_bonus)
	
	# Big score bonus for completing list!
	var completion_bonus = 100 * current_list_number
	total_score += completion_bonus
	score_changed.emit(total_score)
	
	list_completed.emit(current_list_number)
	
	
	# Generate next harder list
	current_list_number += 1
	generate_shopping_list()

func get_current_list() -> Array[String]:
	"""Returns the current shopping list (for UI)"""
	return current_shopping_list

func get_total_score() -> int:
	"""Get current total score"""
	return total_score

func add_new_item(item_name: String, points: int):
	"""Add a new item to the available items"""
	available_items[item_name] = points

# Audio cache to prevent expensive repeated loads
var _audio_cache: Dictionary = {}

func play_sfx(path: String, bus: String = "SFX"):
	# PERFORMANCE: Use cached audio stream if available
	var audio_stream: AudioStream
	if _audio_cache.has(path):
		audio_stream = _audio_cache[path]
	else:
		audio_stream = load(path)
		if audio_stream:
			_audio_cache[path] = audio_stream
		else:
			return  # Audio file not found
	
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	sfx_player.stream = audio_stream
	sfx_player.bus = bus
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func spawn_sparkles(pos: Vector3):
	# Safety check - make sure scene exists
	if not get_tree() or not get_tree().current_scene:
		return
	
	var sparkles = sparkle_scene.instantiate()
	if not sparkles:
		return
	
	get_tree().current_scene.add_child(sparkles)
	sparkles.global_position = pos
	
	# Auto-delete using built-in timer node (avoids lambda capture issues)
	var delete_timer = Timer.new()
	delete_timer.wait_time = 2.0
	delete_timer.one_shot = true
	sparkles.add_child(delete_timer)
	delete_timer.timeout.connect(sparkles.queue_free)
	delete_timer.start()

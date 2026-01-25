extends Node

## Game Manager - With Points & Score System + PERFORMANCE!
## Only generates shopping lists from items that actually spawned!

signal time_changed(seconds_remaining)
signal game_over()
signal list_completed(list_number)
signal list_generated()
signal item_collected(item_name)
signal score_changed(new_score)

# Performance Manager
var performance_manager: Node = null

# Timer System
var time_remaining: float = 60.0
var is_game_active: bool = false

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
}

# NEW: Track which items actually spawned in the world
var spawned_items_in_world: Array[String] = []

func _ready():
	# Initialize performance manager
	_setup_performance_manager()
	
	# Scan for spawned items after a short delay (let shelves spawn first)
	await get_tree().create_timer(2.0).timeout
	_scan_spawned_items()

func _setup_performance_manager():
	"""Create and configure performance manager for physics optimization"""
	var perf_script = load("res://scripts/performance_manager.gd")
	if perf_script:
		performance_manager = Node.new()
		performance_manager.set_script(perf_script)
		performance_manager.name = "PerformanceManager"
		add_child(performance_manager)
		print("✅ Performance Manager loaded")

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
	if is_game_active:
		time_remaining -= delta
		time_changed.emit(time_remaining)
		
		if time_remaining <= 0:
			time_remaining = 0
			is_game_active = false
			game_over.emit()

func start_game():
	time_remaining = 60.0
	is_game_active = true
	current_list_number = 1
	total_score = 0
	total_items_collected = 0
	total_lists_completed = 0
	current_combo = 0
	best_combo = 0
	generate_shopping_list()
	score_changed.emit(total_score)

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
	# Time penalty
	time_remaining -= 5.0
	if time_remaining < 0:
		time_remaining = 0
	time_changed.emit(time_remaining)
	

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

extends Node

## Game Manager - With Points & Score System!

signal time_changed(seconds_remaining)
signal game_over()
signal list_completed(list_number)
signal list_generated()
signal item_collected(item_name)
signal score_changed(new_score)

# Timer System
var time_remaining: float = 60.0
var is_game_active: bool = false

# Shopping List System
var current_list_number: int = 1
var current_shopping_list: Array[String] = []

# Stats
var total_score: int = 0  # NEW: Total score!
var total_items_collected: int = 0
var total_lists_completed: int = 0
var current_combo: int = 0
var best_combo: int = 0

# Available Items - Names and POINTS (not prices!)
var available_items: Dictionary = {
	"Bread": 10,
	"Avocado": 15,
	"Banana": 10,
	"Beet": 10,
	"Bottle Ketchup": 10,
	"Bottle Mustard": 10,
	"Bottle Oil": 15,
	"Bowl": 20,
	"Broccoli": 10,
	"Cabbage": 10,
	"Cake": 25,
	"Can": 10,
	"Small Can": 10,
	"Carrot": 10,
	"Purple Milk": 15,
	"Creme": 15,
	"Cauliflower": 10,
	"Cereal Box": 15,
	"Cheese": 15,
	"Cherries": 10,
	"Coconut": 15,
	"Cooking Fork": 10,
	"Cooking Knife": 10,
	"Chopping Knife": 10,
	"Cooking Spatula": 10,
	"Cooking Spoon": 10,
	"Corn": 10,
	"Croissant": 15,
	"Cup": 10,
	"Cupcake": 15,
	"Cuttingboard": 10,
	"Blue Milk": 15,
}

func _ready():
	# AUTO-START FOR TESTING
	await get_tree().create_timer(1.0).timeout
	start_game()
	
	print("\n=== GAME MANAGER WITH POINTS ===")
	print("Available items: ", available_items.size())
	for item_name in available_items.keys():
		print("  - ", item_name, " (", available_items[item_name], " points)")
	print("================================\n")

func _process(delta):
	if is_game_active:
		time_remaining -= delta
		time_changed.emit(time_remaining)
		
		if time_remaining <= 0:
			time_remaining = 0
			is_game_active = false
			game_over.emit()
			print("GAME OVER!")
			print("Final Score: ", total_score)
			print("Lists Completed: ", total_lists_completed)
			print("Items Collected: ", total_items_collected)

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
	print("GAME STARTED! Get ready to shop!")

func generate_shopping_list():
	current_shopping_list.clear()
	
	# List size increases with each completed list
	var list_size = min(2 + current_list_number, 10)
	
	# Get array of available item names
	var item_names = available_items.keys()
	
	for i in range(list_size):
		if item_names.size() > 0:
			var random_item = item_names[randi() % item_names.size()]
			current_shopping_list.append(random_item)
	
	print("\nGenerated shopping list #", current_list_number, " with ", list_size, " items:")
	for item in current_shopping_list:
		print("  - ", item, " (", available_items[item], " points)")
	
	list_generated.emit()

func add_time_bonus(seconds: float):
	time_remaining += seconds
	time_changed.emit(time_remaining)
	print("⏰ TIME BONUS: +", seconds, " seconds!")

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
	add_time_bonus(2.0)
	
	print("✓ CORRECT! ", item_name)
	print("  Points: ", total_points, " (", points, " × ", "%.1f" % combo_multiplier, ")")
	print("  Combo: x", current_combo)
	print("  Total Score: ", total_score)
	
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
	
	print("✗ WRONG ITEM: ", item_name, " not on list!")
	if lost_combo > 0:
		print("  Lost combo: x", lost_combo)
	print("  Time penalty: -5 seconds")

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
	
	print("\n🎉 LIST COMPLETED!")
	print("  Time bonus: +", time_bonus, " seconds")
	print("  Score bonus: +", completion_bonus, " points")
	print("  Total Score: ", total_score)
	
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
	print("Added new item: ", item_name, " (", points, " points)")

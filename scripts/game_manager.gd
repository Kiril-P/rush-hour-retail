extends Node

# Signals for the new game
signal time_changed(seconds_remaining)
signal game_over()
signal list_completed(list_number)
signal list_generated()
signal item_collected(product)  # NEW: Fires when an item is collected

# Timer System
var time_remaining: float = 60.0
var is_game_active: bool = false

# Shopping List System
var current_list_number: int = 1
var current_shopping_list: Array = []  # Items still needed

# Stats
var total_items_collected: int = 0
var total_lists_completed: int = 0
var current_combo: int = 0
var best_combo: int = 0

# Product Catalog
@export var available_products: Array[ProductData] = []

func _ready():
	_load_products_from_folder("res://objects/items/resources/")
	
	# AUTO-START FOR TESTING (remove later when you add proper start screen)
	await get_tree().create_timer(1.0).timeout
	start_game()

func _process(delta):
	if is_game_active:
		time_remaining -= delta
		time_changed.emit(time_remaining)
		
		if time_remaining <= 0:
			time_remaining = 0
			is_game_active = false
			game_over.emit()
			print("GAME OVER! Lists completed: ", total_lists_completed)

func _load_products_from_folder(path: String):
	print("GameManager: Loading products from: ", path)
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = path + file_name
				var res = load(full_path)
				if res is ProductData:
					available_products.append(res)
					print("GameManager: Found product: ", res.item_name)
			file_name = dir.get_next()
		print("Loaded ", available_products.size(), " products into catalog.")
	else:
		print("GameManager ERROR: Could not open directory: ", path)

func start_game():
	time_remaining = 60.0
	is_game_active = true
	current_list_number = 1
	total_items_collected = 0
	total_lists_completed = 0
	current_combo = 0
	best_combo = 0
	generate_shopping_list()
	print("GAME STARTED! Get ready to shop!")

func generate_shopping_list():
	current_shopping_list.clear()
	
	# List size increases with each completed list
	var list_size = min(1 + current_list_number, 10)  # Start with 2, max 10
	
	for i in range(list_size):
		if available_products.size() > 0:
			var random_product = available_products[randi() % available_products.size()]
			current_shopping_list.append(random_product)
	
	print("Generated shopping list #", current_list_number, " with ", list_size, " items:")
	for item in current_shopping_list:
		print("  - ", item.item_name)
	
	list_generated.emit()

func add_time_bonus(seconds: float):
	time_remaining += seconds
	time_changed.emit(time_remaining)
	print("⏰ TIME BONUS: +", seconds, " seconds!")

func check_item_correct(product: ProductData) -> bool:
	"""Check if the item is on the current shopping list"""
	for item in current_shopping_list:
		if item == product:
			return true
	return false

func collect_correct_item(product: ProductData):
	"""Called when player scans a correct item at checkout"""
	# Remove item from list
	current_shopping_list.erase(product)
	total_items_collected += 1
	current_combo += 1
	if current_combo > best_combo:
		best_combo = current_combo
	
	# Small time bonus per item
	add_time_bonus(2.0)  # 2 seconds per correct item
	print("✓ CORRECT! Collected: ", product.item_name, " | Combo: x", current_combo)
	
	# NEW: Emit signal so paper list can show checkmark
	item_collected.emit(product)
	
	# Check if list is complete
	if current_shopping_list.is_empty():
		complete_list()

func collect_wrong_item():
	"""Called when player scans an item NOT on the list"""
	# Reset combo
	current_combo = 0
	print("✗ WRONG ITEM! Combo reset.")
	# Optional: Time penalty
	# time_remaining -= 5.0

func complete_list():
	"""All items collected! Give big bonus and generate new list"""
	total_lists_completed += 1
	
	# Big time bonus for completing list
	var bonus = 15.0 + (current_list_number * 2.0)  # Increases with difficulty
	add_time_bonus(bonus)
	
	list_completed.emit(current_list_number)
	print("🎉 LIST COMPLETED! +", bonus, " second bonus!")
	
	# Generate next harder list
	current_list_number += 1
	generate_shopping_list()

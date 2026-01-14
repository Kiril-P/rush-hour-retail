extends Node

signal money_changed(new_amount)

var money: float = 1000.0
var delivery_point: Marker3D

# This is where we will store all available products for the shop
# You can fill this list in the Inspector of the GameManager (Autoload) if needed, 
# or we can load them dynamically from the resources folder.
@export var available_products: Array[ProductData] = []

func _ready():
	await get_tree().process_frame
	find_delivery_point()
	
	# Automatically load all .tres files from the correct folder
	_load_products_from_folder("res://objects/items/resources/")

func find_delivery_point():
	delivery_point = get_tree().current_scene.find_child("DeliveryPoint")

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
		print("Loaded ", available_products.size(), " products into the shop.")
	else:
		print("GameManager ERROR: Could not open directory: ", path)

# Updated buy function that takes ProductData!
func buy_product(data: ProductData):
	if money >= data.buy_price:
		money -= data.buy_price
		money_changed.emit(money)
		spawn_delivery(data)
		print("Bought ", data.item_name, "! Money left: ", money)
	else:
		print("Not enough money for ", data.item_name)

func spawn_delivery(data: ProductData):
	if delivery_point == null: 
		find_delivery_point()
		
	if delivery_point == null:
		print("GameManager ERROR: DeliveryPoint marker not found in the scene!")
		return
		
	# Check the path - we look for box.tscn in the objects folder
	var possible_paths = [
		"res://objects/box.tscn",
	]
	
	var box_scene = null
	for path in possible_paths:
		if FileAccess.file_exists(path):
			box_scene = load(path)
			if box_scene:
				print("GameManager: Found box scene at ", path)
				break
		
	if not box_scene:
		print("GameManager ERROR: Could not find shipping_box.tscn in any expected location!")
		return
			
	var new_box = box_scene.instantiate()
	new_box.product_data = data
	
	# Add to the current scene
	get_tree().current_scene.add_child(new_box)
	new_box.global_transform = delivery_point.global_transform
	new_box.rotation_degrees.y = randf_range(0, 360)
	print("GameManager: Spawned box for ", data.item_name)

extends RigidBody3D

var product_data: ProductData 

var player

# Helper properties to make accessing data easier
var product_name: String:
	get: return product_data.item_name if product_data else "Unknown"

var sell_price: float:
	get: return product_data.sell_price if product_data else 0.0

var category: ProductData.Category:
	get: 
		if product_data:
			return product_data.category
		# If it's a loose item with no data, we'll try to guess its data too
		return ProductData.Category.SHELF

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not product_data:
		_find_my_data()

func _find_my_data():
	var my_path = scene_file_path
	if my_path.begins_with("uid://"):
		var res = load(my_path)
		if res:
			my_path = res.resource_path
		
	var resource_dir = "res://objects/items/resources/"
	if not DirAccess.dir_exists_absolute(resource_dir):
		return

	var dir = DirAccess.open(resource_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var data = load(resource_dir + file_name)
				if data is ProductData and data.item_scene:
					var data_scene_path = data.item_scene.resource_path
					if data_scene_path.begins_with("uid://"):
						var s_res = load(data_scene_path)
						if s_res:
							data_scene_path = s_res.resource_path
						
					if data_scene_path == my_path:
						product_data = data
						break
			file_name = dir.get_next()

func _process(_delta: float) -> void:
	pass

func pick_up(new_parent):
	reparent(new_parent)

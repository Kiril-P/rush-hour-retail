extends Resource
class_name ProductData

enum Category {
	SHELF,
	COLD,
	FROZEN,
	PRODUCE
}

@export var item_name: String = "Product"
@export var category: Category = Category.SHELF
@export var item_scene: PackedScene # The actual 3D item (bread, milk, etc.)

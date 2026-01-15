extends Resource
class_name FurnitureData

@export var name: String = "Shelf"
@export var price: float = 50.0
@export var scene: PackedScene # The actual .tscn file
@export var icon: Texture2D    # For a future build menu!
@export var supported_categories: Array[ProductData.Category] = [ProductData.Category.SHELF]

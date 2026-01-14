extends Resource
class_name ProductData

@export var item_name: String = "Product"
@export var icon: Texture2D
@export var buy_price: float = 10.0
@export var sell_price: float = 15.0
@export var item_scene: PackedScene # The actual 3D item (bread, milk, etc.)
@export var amount_per_box: int = 4
@export var box_texture: Texture2D # Optional: a specific texture for the shipping box

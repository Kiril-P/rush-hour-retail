extends Button

var product_data: ProductData

@onready var name_label = $VBoxContainer/NameLabel
@onready var price_label = $VBoxContainer/PriceLabel
@onready var icon_rect = $VBoxContainer/MarginContainer/TextureRect

func setup(data: ProductData):
	product_data = data
	name_label.text = data.item_name

func _pressed():
	print("ShopButton: Clicked on ", product_data.item_name)
	# When clicked, tell the GameManager to buy this
	GameManager.buy_product(product_data)

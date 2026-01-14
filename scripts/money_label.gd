extends Label

func _ready():
	# Connect to the GameManager signal we made earlier
	GameManager.money_changed.connect(_on_money_changed)
	# Set the initial text
	text = "Money: $" + str(GameManager.money)

func _on_money_changed(new_amount):
	text = "Money: $" + str(new_amount)

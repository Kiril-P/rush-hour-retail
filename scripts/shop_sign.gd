extends StaticBody3D

@onready var label = $Label3D

func _ready():
	update_sign()
	# Connect to the signal to handle automatic closing
	GameManager.shop_state_changed.connect(_on_shop_state_changed)

func interact():
	if not GameManager.is_open:
		GameManager.is_open = true
		print("Sign: Shop is now OPEN. Day started!")
	else:
		print("Sign: You cannot close the shop manually! Wait for closing hours.")

func _on_shop_state_changed(_is_open):
	update_sign()

func update_sign():
	if GameManager.is_open:
		label.text = "OPEN"
		label.modulate = Color.GREEN
	else:
		label.text = "CLOSED"
		label.modulate = Color.RED

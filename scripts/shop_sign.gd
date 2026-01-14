extends StaticBody3D

@onready var label = $Label3D

func _ready():
	update_sign()
	# Connect to the signal to handle automatic closing
	GameManager.shop_state_changed.connect(_on_shop_state_changed)

func interact():
	if not GameManager.is_open:
		if GameManager.current_time >= GameManager.CLOSING_HOUR:
			# If shop is closed and it's late, show stats
			_show_stats()
		else:
			# Start the day
			GameManager.is_open = true
			print("Sign: Shop is now OPEN. Day started!")
	else:
		print("Sign: You cannot close the shop manually! Wait for closing hours.")

func _show_stats():
	var canvas = get_tree().current_scene.find_child("CanvasLayer")
	if canvas:
		var stats_ui = canvas.find_child("StatsUI", true, false)
		if stats_ui and stats_ui.has_method("show_stats"):
			stats_ui.show_stats()
		else:
			print("Sign: StatsUI node not found in CanvasLayer!")
	else:
		print("Sign: CanvasLayer not found in scene!")

func _on_shop_state_changed(_is_open):
	update_sign()

func update_sign():
	if GameManager.is_open:
		label.text = "OPEN"
		label.modulate = Color.GREEN
	else:
		label.text = "CLOSED"
		label.modulate = Color.RED

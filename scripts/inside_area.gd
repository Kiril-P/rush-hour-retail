extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Start the timer!
		if GameManager:
			GameManager.start_timer()
			
		var music_manager = get_node_or_null("/root/MusicManager")
		if music_manager:
			music_manager.set_inside(true)

func _on_body_exited(body):
	if body.is_in_group("player"):
		var music_manager = get_node_or_null("/root/MusicManager")
		if music_manager:
			music_manager.set_inside(false)

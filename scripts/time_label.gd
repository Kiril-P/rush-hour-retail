extends Label

func _ready():
	GameManager.time_changed.connect(_on_time_changed)
	_update_time_display(int(GameManager.current_time), 0)

func _on_time_changed(hour, minute):
	_update_time_display(hour, minute)

func _update_time_display(hour, minute):
	text = "%02d:%02d" % [hour, minute]
	
	# Optional: Add AM/PM
	var period = "AM" if hour < 12 else "PM"
	var display_hour = hour
	if hour == 0: display_hour = 12
	if hour > 12: display_hour -= 12
	
	text = "Time: %02d:%02d %s" % [display_hour, minute, period]

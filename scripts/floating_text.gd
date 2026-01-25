extends Label

func setup(text_to_show: String, color: Color = Color.WHITE):
	text = text_to_show
	add_theme_color_override("font_color", color)
	
	# Initial state
	scale = Vector2.ZERO
	modulate.a = 1.0
	
	var tween = create_tween().set_parallel(true)
	
	# Animate up and fade out
	tween.tween_property(self, "position:y", position.y - 100, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_delay(0.5)
	
	# Pop in effect
	var pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	pop_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Cleanup
	tween.chain().tween_callback(queue_free)

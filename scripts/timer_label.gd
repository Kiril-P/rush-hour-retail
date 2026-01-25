extends Label

var target_color: Color = Color.WHITE
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var original_position: Vector2

# Color thresholds
const COLOR_SAFE = Color(0.4, 1.0, 0.4)      # Green
const COLOR_WARNING = Color(1.0, 0.9, 0.2)   # Yellow  
const COLOR_DANGER = Color(1.0, 0.3, 0.3)    # Red
const COLOR_CRITICAL = Color(1.0, 0.1, 0.1)  # Bright Red

# Shadow colors for glow effect
var target_shadow_color: Color = Color(0, 0, 0, 0)
const SHADOW_SAFE = Color(0.2, 0.5, 0.2, 0.0)
const SHADOW_WARNING = Color(1.0, 0.8, 0.0, 0.5)
const SHADOW_DANGER = Color(1.0, 0.3, 0.0, 0.8)
const SHADOW_CRITICAL = Color(1.0, 0.0, 0.0, 1.0)

var glow_size: int = 0

func _ready():
	# Connect to GameManager signals
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)
		GameManager.game_over.connect(_on_game_over)
		# Initial display
		_on_time_changed(GameManager.time_remaining)
	
	original_position = position
	
	# Initial styling
	add_theme_font_size_override("font_size", 72)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Enable shadow for glow effect
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 0)
	add_theme_constant_override("shadow_outline_size", 0)
	add_theme_color_override("font_shadow_color", SHADOW_SAFE)
	
	# Keep scale at 1.0 always
	scale = Vector2.ONE

func _process(delta):
	# Smooth color transition (gradient effect)
	modulate = modulate.lerp(target_color, delta * 3.0)
	
	# Smooth shadow/glow transition
	var current_shadow = get_theme_color("font_shadow_color")
	var new_shadow = current_shadow.lerp(target_shadow_color, delta * 4.0)
	add_theme_color_override("font_shadow_color", new_shadow)
	
	# Pulse the glow size for urgency
	if glow_size > 0:
		var pulse = sin(Time.get_ticks_msec() / 150.0) * 0.5 + 0.5  # 0 to 1
		var size = int(glow_size + pulse * glow_size * 0.5)
		add_theme_constant_override("shadow_outline_size", size)
	
	# Tiny shake ONLY at critical time
	if shake_intensity > 0:
		shake_timer += delta * 30.0
		var shake_offset = Vector2(
			sin(shake_timer * 4.0) * shake_intensity,
			cos(shake_timer * 6.0) * shake_intensity
		)
		position = original_position + shake_offset
	else:
		position = original_position

func _on_time_changed(seconds_remaining: float):
	# Update text - JUST SHOW SECONDS
	var seconds = int(seconds_remaining)
	text = "%ds" % seconds  # Shows: "60s", "59s", etc.
	
	# Calculate time percentage
	var time_percent = seconds_remaining / 60.0  # Assuming 60 second start
	
	# Smooth color transitions based on time percentage
	if time_percent > 0.5:
		# Safe zone - Green, no glow, no shake
		target_color = COLOR_SAFE
		target_shadow_color = SHADOW_SAFE
		glow_size = 0
		shake_intensity = 0.0
		
	elif time_percent > 0.25:
		# Warning zone - Gradient from Green to Yellow with light glow
		var lerp_factor = (0.5 - time_percent) / 0.25  # 0 to 1 as time decreases
		target_color = COLOR_SAFE.lerp(COLOR_WARNING, lerp_factor)
		target_shadow_color = SHADOW_SAFE.lerp(SHADOW_WARNING, lerp_factor)
		glow_size = int(lerp(0, 10, lerp_factor))
		shake_intensity = 0.0
		
	elif time_percent > 0.1:
		# Danger zone - Gradient from Yellow to Red with medium glow
		var lerp_factor = (0.25 - time_percent) / 0.15  # 0 to 1 as time decreases
		target_color = COLOR_WARNING.lerp(COLOR_DANGER, lerp_factor)
		target_shadow_color = SHADOW_WARNING.lerp(SHADOW_DANGER, lerp_factor)
		glow_size = int(lerp(10, 20, lerp_factor))
		shake_intensity = 0.0
		
	else:
		# Critical zone - Gradient from Red to Bright Red with intense glow + TINY SHAKE
		var lerp_factor = (0.1 - time_percent) / 0.1  # 0 to 1 as time decreases
		target_color = COLOR_DANGER.lerp(COLOR_CRITICAL, lerp_factor)
		target_shadow_color = SHADOW_DANGER.lerp(SHADOW_CRITICAL, lerp_factor)
		glow_size = int(lerp(20, 30, lerp_factor))
		shake_intensity = lerp(0.5, 1.5, lerp_factor)  # Very small shake (0.5-1.5 pixels)

func _on_game_over():
	# Freeze at 0s with max intensity
	text = "0s"
	target_color = COLOR_CRITICAL
	target_shadow_color = SHADOW_CRITICAL
	shake_intensity = 0.0  # Stop shaking
	position = original_position  # Reset position
	
	# Max glow
	add_theme_constant_override("shadow_outline_size", 35)

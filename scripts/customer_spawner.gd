extends Node3D

@export var customer_scene: PackedScene
@export var base_spawn_interval: float = 12.0
@export var chaotic_spawn_interval: float = 4.0
@export var max_customers: int = 8

@onready var spawn_point = $SpawnPoint
@onready var exit_point = $ExitPoint

var active_customers = 0

func _ready():
	if not customer_scene:
		push_error("CustomerSpawner: No customer_scene assigned!")
		return
		
	# Start the spawning loop
	spawn_timer_loop()

func spawn_timer_loop():
	while true:
		if GameManager.is_open:
			if active_customers < max_customers:
				spawn_customer()
			
			# Calculate dynamic interval based on time of day
			# chaotic_factor goes from 0.0 (morning) to 1.0 (evening)
			var day_progress = (GameManager.current_time - GameManager.OPENING_HOUR) / (GameManager.CLOSING_HOUR - GameManager.OPENING_HOUR)
			day_progress = clamp(day_progress, 0.0, 1.0)
			
			var current_interval = lerp(base_spawn_interval, chaotic_spawn_interval, day_progress)
			# Add some randomness to the interval
			var random_variance = randf_range(-current_interval * 0.3, current_interval * 0.3)
			
			await get_tree().create_timer(max(0.5, current_interval + random_variance)).timeout
		else:
			# If shop is closed, wait a bit before checking again
			await get_tree().create_timer(2.0).timeout

func spawn_customer():
	var customer = customer_scene.instantiate()
	customer.exit_position = exit_point.global_position
	
	get_tree().current_scene.add_child.call_deferred(customer)
	customer.set_deferred("global_position", spawn_point.global_position)
	
	active_customers += 1
	customer.tree_exited.connect(func(): active_customers -= 1)
	print("Spawner: Customer entered the shop!")

extends Node3D

@export var customer_scene: PackedScene
@export var base_spawn_interval: float = 20.0
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
	# Initial delay when shop opens
	await get_tree().create_timer(5.0).timeout
	
	while true:
		if GameManager.is_open:
			if active_customers < max_customers:
				spawn_customer()
			
			# Calculate dynamic interval based on time of day
			var day_progress = (GameManager.current_time - GameManager.OPENING_HOUR) / (GameManager.CLOSING_HOUR - GameManager.OPENING_HOUR)
			day_progress = clamp(day_progress, 0.0, 1.0)
			
			# Base interval gets shorter as the day goes on (more customers)
			var current_interval = lerp(base_spawn_interval, chaotic_spawn_interval, day_progress)
			
			# Add "waves" of customers based on time of day (Lunch rush, etc.)
			var wave_factor = 1.0
			var hour = int(GameManager.current_time)
			if hour == 12 or hour == 13 or hour == 18 or hour == 19: # Lunch/Dinner rushes
				wave_factor = 0.4 # 60% faster spawning during rushes
				
			current_interval *= wave_factor
			
			# More randomness to the interval
			var random_variance = randf_range(-current_interval * 0.5, current_interval * 0.5)
			
			await get_tree().create_timer(max(1.0, current_interval + random_variance)).timeout
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

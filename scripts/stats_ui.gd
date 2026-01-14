extends Control

@onready var day_label = $Panel/VBoxContainer/MarginContainer/DayLabel
@onready var sales_label = $Panel/VBoxContainer/SalesLabel
@onready var items_label = $Panel/VBoxContainer/ItemsLabel
@onready var customers_label = $Panel/VBoxContainer/CustomersLabel
@onready var unsatisfied_label = $Panel/VBoxContainer/UnsatisfiedLabel
@onready var next_day_button = $Panel/NextDayButton

func _ready():
	visible = false
	if next_day_button:
		next_day_button.pressed.connect(_on_next_day_pressed)

func show_stats():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Disable player movement/looking
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)
	
	day_label.text = "End of Day " + str(GameManager.current_day)
	sales_label.text = "Total Sales: $" + str(snapped(GameManager.daily_sales, 0.01))
	items_label.text = "Items Sold: " + str(GameManager.daily_items_sold)
	customers_label.text = "Customers Served: " + str(GameManager.daily_customers_served)
	unsatisfied_label.text = "Unsatisfied Customers: " + str(GameManager.daily_unsatisfied_customers)

func _on_next_day_pressed():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Re-enable player movement
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_process(true)
		player.set_physics_process(true)
		player.set_process_input(true)
	
	GameManager.start_next_day()

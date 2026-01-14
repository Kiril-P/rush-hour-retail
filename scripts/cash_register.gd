extends Node3D

class_name CashRegister

@export var customer_spacing: float = 1.0
@export var item_placement_offset: Vector3 = Vector3(0.5, 0.8, 0) # Relative to register

var queue: Array[Node3D] = []
var items_to_scan: Array[Node] = []

signal all_items_scanned

func _ready():
	add_to_group("register")

func join_queue(customer: Node3D):
	queue.append(customer)
	_update_queue_positions()

func leave_queue(customer: Node3D):
	queue.erase(customer)
	_update_queue_positions()

func _update_queue_positions():
	for i in range(queue.size()):
		var customer = queue[i]
		if customer.has_method("update_queue_position"):
			# Position 0 is at the register, 1 is behind 0, etc.
			var target_pos = global_position + (-global_transform.basis.z * (i * customer_spacing))
			customer.update_queue_position(target_pos, i == 0)

func place_items_for_scanning(items: Array[Node]):
	# We'll use a local reference to avoid issues if the array changes
	var items_to_process = items.duplicate()
	items_to_scan = items # Keep the original reference for the register's logic
	
	if items_to_process.is_empty():
		all_items_scanned.emit()
		return

	for i in range(items_to_process.size()):
		var item = items_to_process[i]
		
		# Small delay between each item placement
		await get_tree().create_timer(0.4).timeout
		
		if not is_instance_valid(item): continue
		
		item.visible = true
		item.reparent(get_tree().current_scene)
		
		# Place items on the "counter" - spread them out slightly
		var spread = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		item.global_position = global_position + global_transform.basis.x * item_placement_offset.x + \
							Vector3(0, item_placement_offset.y, 0) + \
							global_transform.basis.z * item_placement_offset.z + spread
		
		# Make items interactable for scanning via InteractionComponent
		item.set_meta("to_scan", true)
		item.set_meta("register", self)
		
		# Make sure physics are locked while on counter
		if item is RigidBody3D:
			item.freeze = true

func _on_item_scanned(item):
	items_to_scan.erase(item)
	if items_to_scan.is_empty():
		all_items_scanned.emit()

func get_queue_size() -> int:
	return queue.size()

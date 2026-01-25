extends Node

## Loading Manager - Coordinates shelf spawning to prevent lag
## Provides progress tracking and a centralized spawning queue

signal loading_started()
signal loading_progress(current: float, total: float, message: String)
signal loading_finished()

var _task_queue: Array[Dictionary] = []
var _total_weight: int = 0
var _current_weight: int = 0
var _is_loading: bool = false

var _item_pool: Dictionary = {} # PackedScene -> Array[Node]

func request_item(scene: PackedScene) -> Node:
	"""Get an item from the pool or instantiate it if pool is empty"""
	if not scene:
		return null
		
	var scene_path = scene.resource_path
	if _item_pool.has(scene_path) and not _item_pool[scene_path].is_empty():
		var item = _item_pool[scene_path].pop_back()
		if is_instance_valid(item):
			item.show()
			item.set_process(true)
			item.set_physics_process(true)
			if item is RigidBody3D:
				item.freeze = false
			return item
			
	var item = scene.instantiate()
	return item

func despawn_item(item: Node):
	"""Return an item to the pool instead of deleting it"""
	if not is_instance_valid(item):
		return
		
	var scene_path = item.scene_file_path
	if scene_path == "":
		# If it doesn't have a scene path, we can't pool it reliably
		item.queue_free()
		return
		
	if not _item_pool.has(scene_path):
		_item_pool[scene_path] = []
		
	# Reset item state
	item.hide()
	item.set_process(false)
	item.set_physics_process(false)
	if item is RigidBody3D:
		item.freeze = true
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
	
	# Reparent to LoadingManager to keep it in tree but out of sight
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	
	_item_pool[scene_path].append(item)

func clear_pool():
	"""Completely clear the object pool"""
	for scene_path in _item_pool:
		for item in _item_pool[scene_path]:
			if is_instance_valid(item):
				item.queue_free()
	_item_pool.clear()

var loading_tips: Array[String] = [
	"Scanning items increases your score!",
	"Complete your shopping list for a big bonus.",
	"Keep an eye on the timer!",
	"You can throw items into your cart from a distance.",
	"The checkout counter is near the exit.",
	"Don't forget to scan every item in your cart.",
	"Combos give you more points per item!",
	"Stocking the shelves with fresh produce...",
	"Polishing the floor for a better shopping experience...",
	"Training the employees on customer service..."
]

func register_loading_task(task_callable: Callable, weight: int = 1, message: String = ""):
	"""Register a task to be executed during the loading process"""
	_task_queue.append({
		"callable": task_callable,
		"weight": weight,
		"message": message
	})
	_total_weight += weight
	
	if not _is_loading:
		_start_loading()

func _start_loading():
	_is_loading = true
	_current_weight = 0
	loading_started.emit()
	
	# Very short delay to let most tasks register
	await get_tree().process_frame
	await get_tree().process_frame
	
	_process_queue()

func _process_queue():
	"""Process tasks as FAST as possible, only yielding if frame takes too long"""
	var start_time = Time.get_ticks_msec()
	var last_progress_emit = 0.0
	var tasks_processed = 0
	
	while not _task_queue.is_empty():
		var task = _task_queue.pop_front()
		
		# Execute task
		if task["callable"].is_valid():
			await task["callable"].call()
		
		_current_weight += task["weight"]
		tasks_processed += 1
		
		# Update progress only every 10% or every 10 tasks
		var current_percent = (float(_current_weight) / _total_weight) * 100.0
		if current_percent >= last_progress_emit + 10.0 or tasks_processed % 10 == 0:
			loading_progress.emit(_current_weight, _total_weight, task["message"])
			last_progress_emit = current_percent
		
		# Yield only if we've spent more than 12ms (most of a frame) 
		# to keep spawning fast while preventing a complete hang
		if (Time.get_ticks_msec() - start_time) > 12:
			await get_tree().process_frame
			start_time = Time.get_ticks_msec()
			
	_finish_loading()

func _finish_loading():
	# Ensure final progress is shown
	loading_progress.emit(_total_weight, _total_weight, "Done!")
	
	# Very short delay before hiding
	await get_tree().process_frame
	await get_tree().process_frame
	
	_is_loading = false
	_total_weight = 0
	_current_weight = 0
	loading_finished.emit()

func get_random_tip() -> String:
	if loading_tips.is_empty(): return ""
	return loading_tips[randi() % loading_tips.size()]

func is_loading() -> bool:
	return _is_loading

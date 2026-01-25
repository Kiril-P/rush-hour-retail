extends Sprite3D

## Shopping List Paper - Simple Version (NO ProductData!)
## Works with item names (strings) instead of resources

@export var toggle_key: String = "toggle_shopping_list"
@export var show_position: Vector3 = Vector3(-0.3, -0.2, -0.4)
@export var hide_position: Vector3 = Vector3(-1, -0.2, -0.4)

var list_is_visible: bool = false
var target_position: Vector3

var viewport: SubViewport
var paper_ui: Control
var title_label: Label
var items_container: VBoxContainer

# Track which items have been collected (just item names now!)
var collected_items: Array[String] = []

func _ready():
	target_position = hide_position
	position = hide_position
	
	pixel_size = 0.0008
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	_find_ui_elements()
	
	if GameManager:
		GameManager.list_completed.connect(_on_list_completed)
		GameManager.list_generated.connect(_on_list_generated)
		GameManager.item_collected.connect(_on_item_collected)  # NEW: Connect to item collected signal

func _find_ui_elements():
	viewport = get_node_or_null("SubViewport")
	if viewport:
		texture = viewport.get_texture()
		paper_ui = viewport.get_node_or_null("PaperUI")
		if paper_ui:
			title_label = paper_ui.get_node_or_null("MarginContainer/VBoxContainer/Title")
			
			# Without ScrollContainer
			items_container = paper_ui.get_node_or_null("MarginContainer/VBoxContainer/ItemsContainer")
			
			# Create if missing
			if not items_container:
				var vbox = paper_ui.get_node_or_null("MarginContainer/VBoxContainer")
				if vbox:
					items_container = VBoxContainer.new()
					items_container.name = "ItemsContainer"
					vbox.add_child(items_container)

func _process(delta):
	position = position.lerp(target_position, delta * 12.0)
	
	if Input.is_action_just_pressed(toggle_key):
		toggle_visibility()
		GameManager.mark_tutorial_complete("list")
		# Update list when showing (in case items were collected)
		if list_is_visible:
			_update_list_display()

func toggle_visibility():
	list_is_visible = !list_is_visible
	target_position = show_position if list_is_visible else hide_position
	print("Paper list toggled: ", "VISIBLE" if list_is_visible else "HIDDEN")

func _on_list_generated():
	# New list generated - clear collected items tracking
	collected_items.clear()
	_update_list_display()

func _on_list_completed(_list_number):
	# List completed, new one will be generated
	pass

func _on_item_collected(item_name: String):
	"""Called by GameManager when an item is collected"""
	if not collected_items.has(item_name):
		collected_items.append(item_name)
		_update_list_display()

func _update_list_display():
	if not GameManager or not items_container:
		return
	
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	# Update title
	if title_label:
		title_label.text = "SHOPPING LIST #%d" % GameManager.current_list_number
	
	# Get the FULL original list (including collected items)
	var all_items_on_list = []
	
	# Items still needed
	for item_name in GameManager.current_shopping_list:
		all_items_on_list.append({"item_name": item_name, "collected": false})
	
	# Items already collected
	for item_name in collected_items:
		all_items_on_list.append({"item_name": item_name, "collected": true})
	
	# Display all items (collected + remaining)
	for entry in all_items_on_list:
		var item_name = entry.item_name  # Now it's just a string!
		var is_collected = entry.collected
		
		# Create HBox for checkbox + text
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		# Checkbox/checkmark
		var checkbox = Label.new()
		if is_collected:
			checkbox.text = "✓"
			checkbox.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
		else:
			checkbox.text = "☐"
			checkbox.add_theme_color_override("font_color", Color.BLACK)
		checkbox.add_theme_font_size_override("font_size", 32)
		
		# Item name - NOW JUST USE THE STRING DIRECTLY!
		var item_label = Label.new()
		item_label.text = item_name  # Changed from: product.item_name
		item_label.add_theme_font_size_override("font_size", 28)
		
		if is_collected:
			# Gray out collected items
			item_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			item_label.modulate.a = 0.6
		else:
			item_label.add_theme_color_override("font_color", Color.BLACK)
		
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		hbox.add_child(checkbox)
		hbox.add_child(item_label)
		items_container.add_child(hbox)
	

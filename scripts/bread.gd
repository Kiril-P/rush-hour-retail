extends RigidBody3D

@onready var bread_ingredient = %item_ingredient
@onready var outlineMesh = %MeshInstance3D

var selected = false
var outlineWidth = 0.05
var player

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		# SAFE CONNECTION: Avoids the "Invalid access" error
		player.connect("interact_object", _set_selected)
	outlineMesh.visible = false

func _process(_delta: float) -> void:
	var is_carried = get_parent().name == "InteractionComponent"
	outlineMesh.visible = selected and not is_carried
	
	if selected:
		bread_ingredient.position.y = outlineWidth
	else: 
		bread_ingredient.position.y = 0

func pick_up(new_parent):
	reparent(new_parent)

func _set_selected(object):
	selected = (self == object)

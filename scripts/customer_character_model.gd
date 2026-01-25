extends Node3D
class_name CustomerCharacterModel

## Simple character model wrapper for customer NPCs
## This script should be attached to character scene files created from FBX imports

@export var idle_animation: String = "Take 001"
@export var walk_animation: String = "walk_Take 001"

@onready var skeleton: Skeleton3D = $Skeleton3D if has_node("Skeleton3D") else _find_skeleton(self)
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else _find_animation_player(self)

func _ready():
	if not animation_player:
		push_error("CustomerCharacterModel: No AnimationPlayer found!")
		return
	
	# Ensure AnimationPlayer is active
	animation_player.active = true
	
	# Filter out RESET animations from available animations
	var anims = animation_player.get_animation_list()
	var valid_anims = []
	for anim in anims:
		if not "RESET" in anim.to_upper():
			valid_anims.append(anim)
	
	# Auto-detect animations if not set
	if valid_anims.size() > 0:
		if idle_animation == "" or not animation_player.has_animation(idle_animation):
			idle_animation = valid_anims[0]
		
		if walk_animation == "" or not animation_player.has_animation(walk_animation):
			# Look for walk animation
			for anim in valid_anims:
				if "walk" in anim.to_lower() and anim != idle_animation:
					walk_animation = anim
					break
			# If not found, use any different animation
			if walk_animation == "":
				for anim in valid_anims:
					if anim != idle_animation:
						walk_animation = anim
						break
	
	print("CustomerCharacterModel ready: idle='", idle_animation, "', walk='", walk_animation, "'")
	
	# Start with idle animation
	play_idle()

func play_idle():
	if animation_player and animation_player.has_animation(idle_animation):
		if animation_player.current_animation != idle_animation:
			animation_player.play(idle_animation)

func play_walk():
	if animation_player and animation_player.has_animation(walk_animation):
		if animation_player.current_animation != walk_animation:
			animation_player.play(walk_animation)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

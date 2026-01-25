# Character Animation Setup - Proper Godot Workflow

## The Problem
Loading FBX files dynamically at runtime and trying to set up AnimationPlayers programmatically is causing issues. The AnimationPlayer reports as "playing" but the animation position never advances (stuck at 0.0).

## The Solution: Pre-configured Character Scenes

Instead of loading FBX files in code, we need to:

1. **Create proper character scene files (.tscn) in the Godot editor**
2. **Configure animations once in the editor**
3. **Instantiate the pre-configured scenes at runtime**

## Steps to Fix:

### 1. Open Godot Editor and create character scenes:

For each character (black guy, gustave, jew hat, woman):

#### A. Import and Inspect FBX:
1. In FileSystem, double-click `res://assets/customer_char/black guy/Happy Idle.fbx`
2. This opens the Scene Import Settings
3. You'll see the FBX structure with Skeleton3D, MeshInstance3D, AnimationPlayer

#### B. Create Inherited Scene:
1. In the Scene Import Settings, click "Save As Scene" or right-click → "New Inherited Scene"
2. Save as `res://scenes/characters/customer_black_guy.tscn`
3. In the Scene tree, you should see:
   - Root node (rename to "CustomerCharacter")
   - └─ Skeleton3D
       └─ MeshInstance3D
   - └─ AnimationPlayer

#### C. Configure AnimationPlayer:
1. Select the AnimationPlayer node
2. In the Inspector, ensure:
   - **Playback → Active**: ON
   - **Playback → Speed Scale**: 1.0
   - **Root Node**: ".." (points to parent)
3. In the Animation panel (bottom), you should see: RESET, Take 001, mixamo_com, etc.
4. Click on "Take 001" and press Play to test - character should animate!

#### D. Add Script Variable Support:
1. Select the root node
2. Right-click → "Attach Script"
3. Use this simple script:

```gdscript
extends Node3D
class_name CustomerCharacterModel

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var idle_animation: String = "Take 001"
var walk_animation: String = "walk_Take 001"

func _ready():
    # Auto-play idle on start
    if animation_player.has_animation(idle_animation):
        animation_player.play(idle_animation)

func play_idle():
    if animation_player.has_animation(idle_animation):
        animation_player.play(idle_animation)

func play_walk():
    if animation_player.has_animation(walk_animation):
        animation_player.play(walk_animation)
```

5. Save the scene

#### E. Repeat for all 4 characters:
- `customer_black_guy.tscn` (idle: "Take 001", walk: "walk_Take 001")
- `customer_gustave.tscn` (idle: "Take 001", walk: "walk_Take 001")  
- `customer_jew_hat.tscn` (idle: "Take 001", walk: "walk_Take 001")
- `customer_woman.tscn` (idle: "Take 001", walk: "walk_Take 001")

### 2. Update customer_ai.gd:

Replace the CHARACTER_VARIANTS with scene paths:
```gdscript
const CHARACTER_VARIANTS = [
    preload("res://scenes/characters/customer_black_guy.tscn"),
    preload("res://scenes/characters/customer_gustave.tscn"),
    preload("res://scenes/characters/customer_jew_hat.tscn"),
    preload("res://scenes/characters/customer_woman.tscn")
]
```

Simplify _setup_character_model():
```gdscript
func _setup_character_model():
    selected_variant_index = randi() % CHARACTER_VARIANTS.size()
    var character_scene = CHARACTER_VARIANTS[selected_variant_index]
    
    character_model = character_scene.instantiate()
    add_child(character_model)
    character_model.scale = Vector3.ONE * character_scale
    character_model.position.y = -0.9 * character_scale
    
    # Hide placeholder
    if placeholder_mesh:
        placeholder_mesh.visible = false
```

And update _play_animation():
```gdscript
func _play_animation(anim_type: String):
    if not character_model or not character_model.has_method("play_" + anim_type):
        return
    
    if anim_type == "idle":
        character_model.play_idle()
    elif anim_type == "walk":
        character_model.play_walk()
```

This way, all the animation setup is done ONCE in the editor where it works properly, and we just instantiate pre-configured scenes at runtime.

Want me to write the updated code for this approach?

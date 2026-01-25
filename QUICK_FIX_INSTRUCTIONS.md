# Quick Fix: Create Character Scene Files

## Problem
The FBX animations won't play when loaded at runtime. The AnimationPlayer appears to work but animations don't advance.

## Solution: Create Character Scenes in Godot Editor

Follow these steps **IN THE GODOT EDITOR**:

### For each character (do this 4 times):

1. **Open the FBX in Godot:**
   - In FileSystem dock, navigate to `res://assets/customer_char/black guy/`
   - Double-click `Happy Idle.fbx`
   - This opens it as a scene

2. **Configure the scene:**
   - You'll see the imported FBX structure (Node3D root, Skeleton3D, MeshInstance3D, AnimationPlayer)
   - Click on the AnimationPlayer node
   - In the Animation panel (bottom), click "Take 001" and press Play
   - **The character SHOULD animate!** If it does, continue. If not, the FBX is broken.

3. **Save as a new scene:**
   - Scene → Save Scene As
   - Save to: `res://scenes/characters/customer_black_guy.tscn`

4. **Attach the script:**
   - Select the ROOT node (should be called "Happy Idle" or similar)
   - In the Inspector, click the script icon → "Load"
   - Select `res://scripts/customer_character_model.gd`
   - The script is now attached

5. **Configure animation names** (in Inspector):
   - With root node selected, look for exported variables:
   - **Idle Animation**: "Take 001"
   - **Walk Animation**: "walk_Take 001"
   - (These might auto-detect, but set them manually to be sure)

6. **Test it:**
   - Press F6 to run the scene
   - The character should play the idle animation
   - If it works, you're done with this character!

7. **Repeat for other 3 characters:**
   - `res://assets/customer_char/gustave/Sad Idle.fbx` → save as `customer_gustave.tscn`
   - `res://assets/customer_char/jew hat/Happy Idle.fbx` → save as `customer_jew_hat.tscn`
   - `res://assets/customer_char/woman/Orc Idle.fbx` → save as `customer_woman.tscn`

## After creating all 4 scene files:

Run your game! The customers should now spawn with working animations.

The code will:
- Try to load the .tscn scene files first (fast, reliable)
- Fall back to FBX loading if scenes don't exist (slow, broken)

## Troubleshooting

**"The animation still doesn't play in the scene!"**
- Check that AnimationPlayer is set to Active (Inspector → Playback → Active)
- Make sure Process Mode is set to Inherit
- Try pressing Play on different animations to see which one works

**"I don't see the Animation panel"**
- Click on the AnimationPlayer node
- If the Animation panel doesn't appear at the bottom, go to the top menu: Editor → Animation

**"The FBX import looks weird"**
- Right-click the FBX → Reimport
- Make sure "Import Rest As RESET" is checked in Import settings

Need help? Share a screenshot of what you're seeing in the editor.

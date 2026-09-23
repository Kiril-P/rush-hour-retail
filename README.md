# Rush Hour Retail

An impossible shopping list, a hypermarket, and a clock that's already running.

**[▶ Play in browser](https://kpetrovski.me/play/rush-hour-retail/)** · [itch.io](https://kirilp.itch.io/rush-hour-retail)

## How to play

- Race through the hypermarket and grab everything on your list before time runs out.
- Take a cart for capacity, or run with a basket for speed.
- Plan your route and chain item combos. Scanning at checkout earns bonus seconds.
- Controls are listed in the in-game options.

Made in about 3–4 days in Godot by Kiril and christophrr. The food items and help desk are downloaded assets; everything else was made by the team.

## Development

Open `project.godot` in Godot 4.5 or a compatible version, let asset imports finish, and press **F5**. Blender source assets may need a configured Blender executable during import.

- `main_menu.tscn` is the entry scene.
- `scripts/game_manager.gd` coordinates game state.
- Player movement and interaction live in `scripts/`.

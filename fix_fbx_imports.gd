@tool
extends EditorScript

## Run this script in Godot Editor (File → Run) to fix FBX import settings
## This will enable RESET animations for Mixamo characters

func _run():
	var character_folders = [
		"res://assets/customer_char/black guy/",
		"res://assets/customer_char/gustave/",
		"res://assets/customer_char/jew hat/",
		"res://assets/customer_char/woman/"
	]
	
	print("=== Fixing FBX Import Settings ===")
	
	for folder in character_folders:
		var dir = DirAccess.open(folder)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				if file_name.ends_with(".fbx"):
					var fbx_path = folder + file_name
					var import_path = fbx_path + ".import"
					
					print("Processing: ", fbx_path)
					
					# Read the import file
					var config = ConfigFile.new()
					var err = config.load(import_path)
					
					if err == OK:
						# Update the animation import settings
						config.set_value("params", "animation/import_rest_as_RESET", true)
						config.set_value("params", "animation/remove_immutable_tracks", false)
						
						# Save the updated import file
						config.save(import_path)
						print("  ✓ Updated import settings")
					else:
						print("  ✗ Failed to load import file: ", err)
				
				file_name = dir.get_next()
	
	print("=== Done! Now reimport the FBX files: ===")
	print("1. Go to Project → Reload Current Project")
	print("2. Or select all FBX files in FileSystem and click 'Reimport'")

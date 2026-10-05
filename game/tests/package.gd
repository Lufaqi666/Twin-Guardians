extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Output PCK path required")
		quit(1)
		return
	var packer := PCKPacker.new()
	var error := packer.pck_start(args[0])
	if error != OK:
		quit(1)
		return
	if not add_directory(packer, "res://"):
		quit(1)
		return
	error = packer.flush()
	print("PACKAGE ", args[0], " result=", error)
	quit(0 if error == OK else 1)

func add_directory(packer: PCKPacker, path: String) -> bool:
	var directory := DirAccess.open(path)
	if not directory:
		return false
	for child in directory.get_directories():
		if child.begins_with(".") or child == "tests":
			continue
		if not add_directory(packer, path.path_join(child)):
			return false
	for file in directory.get_files():
		if file.begins_with(".") or file.ends_with(".uid"):
			continue
		var source := path.path_join(file)
		if packer.add_file(source, source) != OK:
			return false
	return true

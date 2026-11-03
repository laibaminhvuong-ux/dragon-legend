extends SceneTree
# Tiles PNG screenshots into contact sheets: godot --headless -s res://tools_contact_sheet.gd -- <dir> <cols> <width>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]; var cols := int(a[1]); var tw := int(a[2])
	var files: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".png") and not f.begins_with("sheet"))
	files.sort()
	var per := cols * 3
	for s in range(0, files.size(), per):
		var chunk: Array = files.slice(s, s + per)
		var th := int(tw * 9.0 / 16.0)
		var rows := int(ceil(chunk.size() / float(cols)))
		var sheet := Image.create(cols * tw, rows * th, false, Image.FORMAT_RGB8)
		for i in chunk.size():
			var img := Image.load_from_file(dir.path_join(chunk[i]))
			img.convert(Image.FORMAT_RGB8)
			img.resize(tw, th)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
		sheet.save_png(dir.path_join("sheet_%d.png" % (s / per)))
		print("sheet_%d: %s" % [s / per, ", ".join(chunk)])
	quit()

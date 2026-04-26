@tool
extends EditorPlugin

var inspector_plugin: BetterPackedScenesInspectorPlugin


func _enter_tree() -> void:
	inspector_plugin = BetterPackedScenesInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)


## Inspector plugin
class BetterPackedScenesInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(_object: Object) -> bool:
		return true


	func _parse_property(_object: Object, _type: int, name: String, _hint_type: int, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
		if hint_string == "PackedScene":
			add_property_editor(name, PackedScenePropertyEditor.new())
			return true
		return false


## Main logic
class PackedScenePropertyEditor extends EditorProperty:
	var container := HBoxContainer.new()
	var unique_button := Button.new()
	var clear_button := Button.new()
	var scene_button := SceneDropButton.new()

	## Clapboard icon
	var scene_icon: Texture2D


	func _init() -> void:
		# Layout
		add_child(container)
		container.add_child(unique_button)
		container.add_child(scene_button)
		container.add_child(clear_button)

		# "Make Unique" button
		unique_button.flat = true
		unique_button.tooltip_text = "This PackedScene is external to scene.\nLeft-click to make it unique."
		unique_button.pressed.connect(_on_unique_pressed)

		# "Clear" button
		clear_button.flat = true
		clear_button.tooltip_text = "Clear"
		clear_button.pressed.connect(_on_clear_pressed)

		# Scene button
		scene_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scene_button.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		scene_button.clip_text = true
		scene_button.mouse_filter = Control.MOUSE_FILTER_STOP
		scene_button.pressed.connect(_on_scene_handle_pressed)
		scene_button.file_dropped.connect(_on_dropped_on_scene_handle)


	func _ready() -> void:
		var gui = EditorInterface.get_base_control()
		scene_icon = gui.get_theme_icon("PackedScene", "EditorIcons")
		unique_button.icon = gui.get_theme_icon("Instance", "EditorIcons")
		clear_button.icon = gui.get_theme_icon("Close", "EditorIcons")
		_update_ui()


	func _update_property() -> void:
		_update_ui()


	## Syncs UI
	func _update_ui() -> void:
		var obj = get_edited_object()
		if not is_instance_valid(obj):
			return

		var current_val = obj.get(get_edited_property())

		if current_val is PackedScene:
			# "Make Unique" button
			var is_unique = current_val.resource_path == ""
			unique_button.visible = not is_unique
			# "Clear" button
			clear_button.visible = true
			# Scene button
			scene_button.text = (current_val.resource_path.get_file() if not is_unique else "PackedScene")
			scene_button.icon = scene_icon
		else:
			unique_button.visible = false
			scene_button.text = "<empty>"
			scene_button.icon = null
			clear_button.visible = false


	## "Clear" button press
	func _on_clear_pressed() -> void:
		_apply_value(null)


	# "Make Unique" button press
	func _on_unique_pressed() -> void:
		var obj = get_edited_object()
		if not is_instance_valid(obj):
			return

		var current_val = obj.get(get_edited_property())
		if current_val is PackedScene:
			# Duplicating the resource removes its path and makes it unique to this instance
			_apply_value(current_val.duplicate(true))


	## Drop on scene button
	func _on_dropped_on_scene_handle(path: String) -> void:
		_apply_value(load(path))


	## Scene button press
	func _on_scene_handle_pressed() -> void:
		var obj = get_edited_object()
		if not is_instance_valid(obj):
			return

		var current_val = obj.get(get_edited_property())
		if current_val:
			# If value != null, opens resource
			emit_signal("resource_selected", get_edited_property(), current_val)
		else:
			# If value == null, opens a file dialog to pick a value
			var dialog = EditorFileDialog.new()
			dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
			dialog.current_dir = "res://"
			dialog.add_filter("*.tscn, *.scn", "Packed Scenes")
			dialog.file_selected.connect(
				func(path):
					_apply_value(load(path))
					dialog.queue_free()
			)
			dialog.canceled.connect(func(): dialog.queue_free())
			EditorInterface.get_base_control().add_child(dialog)
			dialog.popup_file_dialog()


	## Updates value
	func _apply_value(new_val: Resource) -> void:
		emit_changed(get_edited_property(), new_val)
		_update_ui()


## Button that allows drag-and-dropping .tscn files
class SceneDropButton extends Button:
	signal file_dropped(path: String)


	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) == TYPE_DICTIONARY and data.get("type") == "files":
			var files = data.get("files", [])
			return files.size() > 0 and (files[0].ends_with(".tscn") or files[0].ends_with(".scn"))
		return false


	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		file_dropped.emit(data["files"][0])

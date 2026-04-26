@tool
extends EditorPlugin

const SETTING_PATH = "hide_main_screen_buttons/"
const DEFAULT_BUTTONS_NAMES = ["2D", "3D", "Script", "Game", "AssetLib"]

## Main screen buttons to be hidden.
var buttons_to_hide: Array[String] = ["3D", "AssetLib"]

# We need to globally keep track of the variables below so to be able to restore the interface when the plugin is disabled :

## The default container for all main screen buttons.
var _buttons_container: Node = null
## A new container created to hide the unwanted main screen buttons.
var _hidden_container: Control = null
## The default index of each hidden button among the children of the default container.
var _default_indexs: Dictionary = { }


func _enter_tree() -> void:
	for name in DEFAULT_BUTTONS_NAMES:
		var path = SETTING_PATH + name
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, true)
			ProjectSettings.set_initial_value(path, true)
			ProjectSettings.add_property_info(
				{
					"name": path,
					"type": TYPE_BOOL,
				},
			)

	ProjectSettings.settings_changed.connect(_update_hidden_buttons)
	_update_hidden_buttons()


func _exit_tree() -> void:
	_restore_buttons()


func _update_hidden_buttons() -> void:
	# Reset
	_restore_buttons()

	# Get the editor container
	var base_control: Node = EditorInterface.get_base_control()

	# Get the container for the main screen buttons
	# we look for one of the default main screen buttons, and get its parent
	for name in DEFAULT_BUTTONS_NAMES:
		var found: Array[Node] = base_control.find_children(name, "Button", true, false)
		for btn in found:
			if btn.toggle_mode and btn.get_parent() is HBoxContainer:
				_buttons_container = btn.get_parent()
	if not _buttons_container:
		return

	# Store the original index of each button, to be able to correctly restore the interface if the plugin is disabled
	var main_screen_buttons: Array[Node] = _buttons_container.get_children()
	for i in range(main_screen_buttons.size()):
		if main_screen_buttons[i] is Button:
			_default_indexs[main_screen_buttons[i].text] = i

	# Create a hidden off-screen container, and move the buttons to hide from their default container to this one
	# we need to do this weird trick because actually hiding the buttons (CanvasItem.visible = false) seems to break editor features
	_hidden_container = Control.new()
	_hidden_container.name = "HiddenTabStorage"
	base_control.add_child(_hidden_container)
	_hidden_container.position = Vector2(-10000, -10000)
	for button in main_screen_buttons:
		if button is Button and not ProjectSettings.get_setting(SETTING_PATH + button.text):
			_buttons_container.remove_child(button)
			_hidden_container.add_child(button)


func _restore_buttons() -> void:
	if not _buttons_container or not _hidden_container:
		return

	# Move back the hidden buttons to the default container
	var hidden_buttons = _hidden_container.get_children()
	for button in hidden_buttons:
		if button is Button:
			_hidden_container.remove_child(button)
			_buttons_container.add_child(button)
			# Reinsert at its original index
			if _default_indexs.has(button.text):
				_buttons_container.move_child(button, _default_indexs[button.text])

	# Destroy the hidden container
	if _hidden_container:
		_hidden_container.queue_free()

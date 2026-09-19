## Represents the button that sits inside the editor and can be clicked to open the align menu.
##
## By default, it is set to the 3D mode; call [method setup_2d] to transition it to the 2D mode.
@tool
extends Button

enum Axis { X, Y, Z }

enum Alignment { MIN, CENTER, MAX, DISTRIBUTE, SEPARATE }

enum Target { BOUNDS, ACTIVE_NODE }

signal popup_toggled(toggled: bool)
signal align_button_pressed(axis: Axis, alignment: Alignment)

@onready var _popup := $Popup
@onready var global_local_button: CheckButton = $Popup/VBox/Options/GlobalLocalCheckButton
@onready var bounds_item_button: CheckButton = $Popup/VBox/Options/BoundsItemCheckButton


func _ready() -> void:
	toggled.connect(self._on_toggled)
	_popup.visibility_changed.connect(_on_popup_visibility_changed)

	for btn in _popup.find_children("?_*", "Button"):
		var name_parts := btn.name.split("_")
		var axis = Axis[name_parts[0]]
		var alignment = Alignment[name_parts[1]]

		btn.pressed.connect(align_button_pressed.emit.bind(axis, alignment))


func setup_2d() -> void:
	var label_x: Label = $Popup/VBox/AlignX/Header/Label
	var label_y: Label = $Popup/VBox/AlignY/Header/Label
	var vbox_align_z: VBoxContainer = $Popup/VBox/AlignZ
	var btn_y_min: Button = $Popup/VBox/AlignY/HBox/Y_MIN
	var btn_y_max: Button = $Popup/VBox/AlignY/HBox/Y_MAX

	label_x.text = "Horizontal"
	label_y.text = "Vertical"
	vbox_align_z.queue_free()
	btn_y_min.icon = preload("./icons/VTop.svg")
	btn_y_max.icon = preload("./icons/VBottom.svg")


func get_is_in_local_space() -> bool:
	return global_local_button.button_pressed

func get_alignment_target() -> Target:
	return Target.ACTIVE_NODE if bounds_item_button.button_pressed else Target.BOUNDS


func _on_toggled(button_pressed):
	if not button_pressed:
		return
	var size = self.size * get_viewport().get_canvas_transform().get_scale()

	_popup.size = Vector2(size.x, 0)
	var gp = get_screen_position()
	gp.y += size.y
	if is_layout_rtl():
		gp.x += size.x - _popup.size.x
	_popup.position = gp
	_popup.popup()


func _on_popup_visibility_changed():
	popup_toggled.emit(_popup.visible)
	button_pressed = _popup.visible

extends Container
# warning-ignore-all:return_value_discarded
# warning-ignore-all:unused_signal

signal shown
signal hidden

const PopochiuDialogOption :=\
preload('res://addons/Popochiu/Engine/Objects/Dialog/PopochiuDialogOption.gd')

@export var option_scene: PackedScene
@export var default: Color = Color('5B6EE1')
@export var used: Color = Color('3F3F74')
@export var hover: Color = Color.WHITE

var current_options := []


@onready var _panel: Container = find_child('Panel')
@onready var _options: Container = find_child('Options')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ GODOT ░░░░
func _ready() -> void:
	connect('gui_input',Callable(self,'_clicked'))
	
	# Conectarse a eventos de los evnetruchos
	D.connect('dialog_options_requested',Callable(self,'_create_options').bind(true))
	D.connect('inline_dialog_requested',Callable(self,'_create_inline_options'))
	D.connect('dialog_finished',Callable(self,'remove_options'))

	hide()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ PRIVATE ░░░░
func _clicked(event: InputEvent) -> void:
	var mouse_event: = event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT \
		and mouse_event.pressed:
			pass


# Creates an Array of PopochiuDialogOption to show dialog tree options created
# during execution, (those that are created after calling D.show_inline_dialog)
func _create_inline_options(opts: Array) -> void:
	var tmp_opts := []
	for idx in opts.size():
		var new_opt: PopochiuDialogOption = PopochiuDialogOption.new()
		var id := 'Opt%d' % (idx as int + 1)
		
		new_opt.id = id
		new_opt.text = opts[idx]
		
		tmp_opts.append(new_opt)

	_create_options(tmp_opts, true)


func _create_options(options := [], autoshow := false) -> void:
	remove_options()

	if options.is_empty():
		if not current_options.is_empty():
			show_options()
		return

	current_options = options.duplicate(true)

	for opt in options:
		var btn: Button = option_scene.instantiate() as Button
		var dialog_option: PopochiuDialogOption = opt

		btn.text = dialog_option.text
		btn.add_theme_color_override('font_color', default)
		btn.add_theme_color_override('font_color_hover', hover)
		
		if dialog_option.used and not dialog_option.always_on:
			btn.add_theme_color_override('font_color', used)

		btn.connect('pressed',Callable(self,'_on_option_clicked').bind(dialog_option))

		_options.add_child(btn)

		if dialog_option.disabled or not dialog_option.visible:
			btn.hide()
		else:
			btn.show()

	if autoshow: show_options()
	
	await get_tree().idle_frame

	_panel.minimum_size.y = _options.size.y


func remove_options() -> void:
	if not current_options.is_empty():
		current_options.clear()

		for btn in _options.get_children():
#			(btn as Button).call_deferred('queue_free')
			_options.remove_child(btn as Button)
#		hide()
	
	await get_tree().idle_frame

	_panel.size.y = 0
	_options.size.y = 0


func show_options() -> void:
	show()
	emit_signal('shown')


func _on_option_clicked(opt: PopochiuDialogOption) -> void:
	hide()
	D.emit_signal('option_selected', opt)

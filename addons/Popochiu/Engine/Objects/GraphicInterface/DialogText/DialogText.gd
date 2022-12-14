extends RichTextLabel
# Show dialogue texts char by char using a RichTextLabel.
# An invisibla Label is used to calculate the width of the RichTextLabel node.
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# warning-ignore-all:unused_signal
# warning-ignore-all:return_value_discarded

signal animation_finished

const DFLT_SIZE := 'dflt_size'

@export var wrap_width := 200.0
@export var limit_margin := 4.0

var _secs_per_character := 1.0
var _is_waiting_input := false
var _auto_continue := false
var _dialog_pos := Vector2.ZERO
var _x_limit := 0.0
var _y_limit := 0.0

@onready var _tween: Tween = null
@onready var _continue_icon: TextureProgressBar = find_child('ContinueIcon')
@onready var _continue_icon_tween: Tween = null


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ GODOT ░░░░
func _ready() -> void:
	set_meta(DFLT_SIZE, size)
	
	# Set the default values
	clear()
	
	modulate.a = 0.0
	_secs_per_character = E.current_text_speed
	_x_limit = E.width / (E.scale.x if E.settings.scale_gui else 1.0)
	_y_limit = E.height / (E.scale.y if E.settings.scale_gui else 1.0)
	
	_continue_icon.hide()
	
	# Conectarse a señales de los hijos
#	_tween.finished.connect(_wait_input)
#	_continue_icon_tween.finished.connect(_continue)
	
	# Conectarse a eventos del universo Chimpoko
	E.text_speed_changed.connect(change_speed)
	C.character_spoke.connect(_show_dialogue)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ PUBLIC ░░░░
func play_text(props: Dictionary) -> void:
	var msg: String = E.get_text(props.text)
	_is_waiting_input = false
	_dialog_pos = props.position
	
	# ==== Calculate the width of the node =====================================
	var rt := RichTextLabel.new()
	var lbl := Label.new()
	rt.append_bbcode(msg)
	lbl.text = rt.text
	add_child(lbl)
	var size := lbl.size
	if size.x > wrap_width:
		size.x = wrap_width
		rt.fit_content_height = true
		rt.size = Vector2(size.x, 0.0)
		add_child(rt)
		size.y = rt.get_content_height()
	elif size.x < get_meta(DFLT_SIZE).x:
		size.x = get_meta(DFLT_SIZE).x
	lbl.free()
	rt.free()
	# ===================================== Calculate the width of the node ====
	# Define default position (before calculating overflow)
	size = size
	position = props.position - size / 2.0
	position.y -= size.y / 2.0
	
	# Calculate overflow and reposition
	if position.x < 0.0:
		position.x = limit_margin
	elif position.x + size.x > _x_limit:
		position.x = _x_limit - limit_margin - size.x
	if position.y < 0.0:
		position.y = limit_margin
	elif position.y + size.y > _y_limit:
		position.y = _y_limit - limit_margin - size.y
	
	# Assign text and align mode (based checked overflow)
	push_color(props.color)
	
	var center := floori(position.x + (size.x / 2))
	if center == props.position.x:
		append_text('[center]%s[/center]' % msg)
	elif center < props.position.x:
		append_text('[right]%s[/right]' % msg)
	else:
		append_text(msg)

	if _secs_per_character > 0.0:
		# Que el texto aparezca animado
		if is_instance_valid(_tween) and _tween.is_running():
			_tween.kill()
		
		_tween = create_tween()
		_tween.tween_property(
			self, 'visible_ratio',
			1,
			_secs_per_character * get_total_character_count()
		).from(0)
		_tween.finished.connect(_wait_input)
	else:
		_wait_input()

	modulate.a = 1.0


func stop() ->void:
	if modulate.a == 0.0:
		return

	if _is_waiting_input:
		_notify_completion()
	else:
		# Saltarse las animaciones
		if is_instance_valid(_tween) and _tween.is_running():
			_tween.kill()
		
		visible_ratio = 1.0
		
		_wait_input()


func hide() -> void:
	if modulate.a == 0.0: return
	
	_auto_continue = false
	modulate.a = 0.5
	_is_waiting_input = false
	
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	clear()
	
	_continue_icon.hide()
	_continue_icon.modulate.a = 1.0
	
	if is_instance_valid(_continue_icon_tween)\
	and _continue_icon_tween.is_running():
		_continue_icon_tween.kill()
	
	size = get_meta(DFLT_SIZE)


func change_speed() -> void:
	_secs_per_character = E.current_text_speed


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ PRIVATE ░░░░
func _show_dialogue(chr: PopochiuCharacter, msg := '') -> void:
	play_text({
		text = msg,
		color = chr.text_color,
		position = U.get_screen_coords_for(chr.dialog_pos).floor() / (
			E.scale if E.settings.scale_gui else Vector2.ONE
		),
	})


func _wait_input() -> void:
	_is_waiting_input = true
	
	if is_instance_valid(_tween) and _tween.finished.is_connected(_wait_input):
		_tween.finished.disconnect(_wait_input)
	
	if E.auto_continue_after >= 0.0:
		_auto_continue = true
		await get_tree().create_timer(E.auto_continue_after + 0.2).timeout
		
		if _auto_continue:
			_continue(true)
	else:
		_show_icon()


func _notify_completion() -> void:
	self.hide()
	animation_finished.emit()


func _show_icon() -> void:
	if is_instance_valid(_continue_icon_tween)\
	and _continue_icon_tween.is_running():
		_continue_icon_tween.kill()
	
	_continue_icon_tween = create_tween()
	
	if not E.settings.auto_continue_text:
		# For manual continuation: make the continue icon jump
		_continue_icon.value = 100.0
		_continue_icon_tween.tween_property(
			_continue_icon, 'position:y',
			size.y + 3.0, 0.8
		).from(size.y).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_continue_icon_tween.set_loops()
	else:
		# For automatic continuation: Make the icon appear like a progress bar
		# the time players wil have to read befor auto-continuing
		_continue_icon.value = 0.0
		_continue_icon_tween.tween_property(
			_continue_icon, 'value',
			100.0, 3.0,
		).from_current().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_continue_icon_tween.pause()
	
	await get_tree().create_timer(0.2).timeout

	_continue_icon_tween.play()
	_continue_icon.show()


func _continue(forced_continue := false) -> void:
	if E.settings.auto_continue_text or forced_continue:
		G.continue_clicked.emit()

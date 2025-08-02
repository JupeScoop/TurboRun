extends Sprite2D

const FRAME_LEFT_HARD := 0
const FRAME_LEFT_SOFT := 1
const FRAME_CENTER    := 2
const FRAME_RIGHT_SOFT := 3
const FRAME_RIGHT_HARD := 4

@export var frame_width := 1039
@export var turn_hold_time := 0.2

var left_hold := 0.0
var right_hold := 0.0

func _process(delta):
	var steer_left := Input.is_action_pressed("ui_left")
	var steer_right := Input.is_action_pressed("ui_right")

	# Update hold timers
	if steer_left:
		left_hold += delta
		right_hold = 0.0
	elif steer_right:
		right_hold += delta
		left_hold = 0.0
	else:
		left_hold = 0.0
		right_hold = 0.0

	# Determine frame
	# Invert frame direction for pseudo-3D
	var selected_frame := FRAME_CENTER
	if right_hold > 0.0:
		selected_frame = FRAME_LEFT_HARD if right_hold >= turn_hold_time else FRAME_LEFT_SOFT
	elif left_hold > 0.0:
		selected_frame = FRAME_RIGHT_HARD if left_hold >= turn_hold_time else FRAME_RIGHT_SOFT


	# Display
	region_enabled = true
	if texture:
		var region_height = texture.get_height()
		region_rect = Rect2(selected_frame * frame_width, 0, frame_width, region_height)

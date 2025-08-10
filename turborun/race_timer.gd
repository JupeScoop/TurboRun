extends Label

@export var road_renderer_path: NodePath = NodePath("../Node2D")
@onready var road_renderer = get_node_or_null(road_renderer_path)

var elapsed: float = 0.0
var running: bool = false

func _ready() -> void:
	# run + draw at least once
	set_process(true)
	queue_redraw()
	# stick to bottom-left of the viewport (16 px padding)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_theme_font_size_override("font_size", 26)  # 32 px font
	position = Vector2(510, 20)   # x: from left, y: from bottom (negative goes up)

func _process(delta: float) -> void:
	elapsed += delta
	if road_renderer:
		text = "Time: %.1f" %  elapsed  

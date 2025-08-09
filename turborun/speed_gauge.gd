extends Label

@export var road_renderer_path: NodePath = NodePath("../Node2D")
@onready var road_renderer = get_node_or_null(road_renderer_path)

func _process(delta: float) -> void:
	if road_renderer:
		text = "Speed: %d" % int(road_renderer.current_speed)

extends Area3D
class_name Interactable

@onready var interactable_label = $InteractableLabel
@export_node_path("MeshInstance3D") var mesh_path: NodePath
@onready var absolute_path = get_node(mesh_path).get_path()

func _ready():
	interactable_label.visible = false

func hide_label():
	interactable_label.visible = false

func show_label():
	interactable_label.visible = true

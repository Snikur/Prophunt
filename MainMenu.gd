extends Control

@onready var join: Button = $VBoxContainer/Join
@onready var host: Button = $VBoxContainer/Host
@onready var hide: Button = $VBoxContainer/Hide
@onready var find: Button = $VBoxContainer/Find

func _ready():
	join.pressed.connect(join_server)
	host.pressed.connect(host_server)

func join_server():
	if hide.is_pressed():
		print("Hide")
		MM.join(CharacterController.ROLE.HIDE)
	elif find.is_pressed():
		print("Find")
		MM.join(CharacterController.ROLE.FIND)
	visible = false

func host_server():
	if hide.is_pressed():
		print("Hide")
		MM.host(CharacterController.ROLE.HIDE)
	elif find.is_pressed():
		print("Find")
		MM.host(CharacterController.ROLE.FIND)
	visible = false

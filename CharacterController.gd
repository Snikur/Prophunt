extends CharacterBody3D
class_name CharacterController

var id: int = -1

enum ROLE {
	NONE,
	HIDE,
	FIND,
}
@onready var mesh: Node3D = $Mesh
@onready var chase_ray: RayCast3D = $PhantomCamera3D/ChaseRay
@onready var arm: SpringArm3D = $CameraArm
@onready var camera: PhantomCamera3D = $PhantomCamera3D
@onready var found_label = $CanvasLayer/Control/FoundLabel

@export_subgroup("Properties")
@export var movement_speed: float = 350.0
@export var jump_strength: float = 7.0
@export var sprint_multiplier: float = 1.5

@export_subgroup("Controller")
@export var enable_gamepad: bool = false
@export var controller_index: int = 0

var role: ROLE = ROLE.NONE
var is_found: bool = false :
	set(value):
		is_found = value
		if multiplayer.get_unique_id() == id:
			found_label.visible = true
			set_physics_process(false)
	get:
		return is_found

var last_interactable = null
var movement_velocity: Vector3
var rotation_direction: float
var gravity: float = 0.0
var previously_floored: bool = false
var jump_single: bool = true
var jump_double: bool = true
var pitch: float = 0.0
var yaw: float = 0.0
var mouse_sensitivity: float = 0.1

func _ready():
	found_label.visible = false
	set_physics_process(multiplayer.get_unique_id() == id)
	set_process_unhandled_input(multiplayer.get_unique_id() == id)
	if multiplayer.get_unique_id() == id:
		camera.set_priority(2)
	else:
		camera.queue_free()

func set_role(new_role: ROLE):
	role = new_role
	prints(str(id), "new role:", role)
	if multiplayer.get_unique_id() == id:
		match(role):
			ROLE.FIND:
				chase_ray.set_collide_with_bodies(true)
				chase_ray.set_collide_with_areas(false)
				print("match case you are a finder")
			ROLE.HIDE:
				chase_ray.set_collide_with_bodies(false)
				chase_ray.set_collide_with_areas(true)
				print("match case you are a hider")
			ROLE.NONE:
				print("match case no role")

func send_state():
	if multiplayer:
		if multiplayer.is_server():
			server_state.rpc(global_position, mesh.rotation)
		else:
			client_state.rpc_id(1, global_position, mesh.rotation)

@rpc("any_peer", "call_remote", "unreliable")
func client_state(new_position: Vector3, new_rotation: Vector3):
	global_position = new_position
	mesh.rotation = new_rotation
	server_state.rpc(new_position, new_rotation)

@rpc("authority", "call_remote", "unreliable")
func server_state(new_position: Vector3, new_rotation: Vector3):
	global_position = new_position
	mesh.rotation = new_rotation

func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.button_index == 1 else Input.MOUSE_MODE_VISIBLE)
			
	if event is InputEventMouseMotion:
		var mouse_relative : Vector2 = event.get_relative()
		yaw = fmod(yaw  - mouse_relative.x * mouse_sensitivity , 360.0)
		pitch = max(min(pitch - mouse_relative.y * mouse_sensitivity , 89.0), -89.0)
		arm.set_rotation(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))

	if event.is_action_pressed("interact"):
		if role == ROLE.HIDE:
			if last_interactable:
				print(last_interactable.absolute_path)
				if multiplayer.is_server():
					MM.server_change_mesh.rpc(1, last_interactable.absolute_path)
				else:
					MM.client_requested_mesh.rpc_id(1, last_interactable.absolute_path)
		elif role == ROLE.FIND:
			if last_interactable:
				print("found ", last_interactable.name)
				if multiplayer.is_server():
					MM.tag_id.rpc_id(last_interactable.name.to_int())
				else:
					MM.client_found_id.rpc_id(1, last_interactable.name.to_int())

func get_ray_data():
	var collision = chase_ray.get_collider()
	if collision is Interactable:
		if last_interactable:
			last_interactable.hide_label()
		last_interactable = collision
		last_interactable.show_label()
	elif collision is CharacterController:
		last_interactable = collision
	else:
		if last_interactable is Interactable:
			last_interactable.hide_label()
			last_interactable = null
		else:
			last_interactable = null

func _physics_process(delta):
	handle_controls(delta)
	handle_gravity(delta)
	get_ray_data()
	
	var applied_velocity: Vector3
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	
	velocity = applied_velocity
	move_and_slide()
	send_state()

	if is_on_floor() and gravity > 2 and !previously_floored:
		print("Landed")
	
	previously_floored = is_on_floor()

func handle_controls(delta):
	var input: Vector3 = Vector3.ZERO
	if enable_gamepad:
		input.x = Input.get_joy_axis(controller_index, JOY_AXIS_LEFT_X)
		input.z = Input.get_joy_axis(controller_index, JOY_AXIS_LEFT_Y)
	else:
		input.x = Input.get_axis("move_left", "move_right")
		input.z = Input.get_axis("move_forward", "move_backward")
	input = input.rotated(Vector3.UP, get_viewport().get_camera_3d().rotation.y).normalized()
	movement_velocity = input * movement_speed * delta
	if Input.is_action_pressed("move_sprint"):
		movement_velocity = movement_velocity * sprint_multiplier

	if Input.is_action_just_pressed("move_jump"):
		if jump_single or jump_double:
			print("Jumped")
		
		if jump_double:
			gravity = -jump_strength
			jump_double = false
			
		if(jump_single): jump()
	
	if Vector2(input.z, input.x).length() > 0:
		rotation_direction = Vector2(input.z, input.x).angle()
	mesh.rotation.y = lerp_angle(mesh.rotation.y, rotation_direction, delta * 10)

func handle_gravity(delta):
	gravity += 25 * delta
	if gravity > 0 and is_on_floor():
		jump_single = true
		gravity = 0

func jump():
	gravity = -jump_strength
	jump_single = false;
	jump_double = true;

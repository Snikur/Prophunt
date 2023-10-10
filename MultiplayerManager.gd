extends Node

const IP_ADDRESS = "localhost"
const PORT = 25565
const MAX_CLIENTS = 4095
var player_prefab := preload("res://player.tscn")
var list_of_players := []
var selected_role: CharacterController.ROLE = CharacterController.ROLE.NONE
var list_of_tagged := []

func host(role: CharacterController.ROLE):
	selected_role = role
	prints("Selected role:", selected_role, role)
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(client_connected)
	multiplayer.peer_disconnected.connect(client_disconnected)
	add_client(1, selected_role)
	DisplayServer.window_set_title(str("HOST", " ROLE: ", selected_role))

@rpc("any_peer", "reliable", "call_remote")
func client_found_id(id: int):
	var sender_id = multiplayer.get_remote_sender_id()
	print(str(sender_id, " found ", id))
	if id == 1:
		for player in list_of_players:
			if player.id == 1:
				player.is_found = true
				list_of_tagged.append(player)
				break
	else:
		tag_id.rpc(id)
		for player in list_of_players:
			if player.id == id:
				list_of_tagged.append(player)
				break
	
	var current_hiders: int = 0
	for player in list_of_players:
		if player.role == CharacterController.ROLE.HIDE:
			current_hiders = current_hiders + 1
	print("tag count: ", current_hiders, " size: ", list_of_tagged.size())
	if current_hiders == list_of_tagged.size():
		print("all players found")

@rpc("authority", "reliable", "call_local")
func tag_id(id: int):
	for player in list_of_players:
		if player.id == id:
			player.is_found = true

@rpc("any_peer", "reliable", "call_remote")
func client_requested_mesh(mesh_path: String):
	var sender_id = multiplayer.get_remote_sender_id()
	print("client ", sender_id, " requested ", mesh_path)
	server_change_mesh.rpc(sender_id, mesh_path)

@rpc("authority", "reliable", "call_local") # change mesh from player with id
func server_change_mesh(id: int, mesh_path: String):
	print("change ", id, " clientside ", mesh_path)
	for player in list_of_players:
		if player is CharacterController:
			if player.id == id:
				print("changed mesh for ", player, " to ", mesh_path)
				var selected_node := get_node(mesh_path)
				var model = player.mesh as MeshInstance3D
				model.mesh = selected_node.mesh
				model.material_override = selected_node.material_override
				model.set_surface_override_material(0, selected_node.get_surface_override_material(0))
				model.transform = selected_node.transform
				model.scale = selected_node.scale
				return

func add_client(id: int, role: CharacterController.ROLE):
	var player: CharacterController = player_prefab.instantiate()
	player.name = str(id)
	player.id = id
	add_child(player)
	player.set_role(role)
	list_of_players.append(player)

@rpc("authority", "reliable", "call_remote")
func remote_add_client(id: int, role: CharacterController.ROLE):
	print("added client ", id, " role: ", role)
	add_client(id, role)

@rpc("authority", "reliable", "call_local")
func set_role(id: int, role: CharacterController.ROLE):
	for player in list_of_players:
		if player.id == id:
			player.set_role(role)

func add_clients(id: int):
	for player in list_of_players:
		add_client.rpc_id(id, player.id)

func client_connected(id: int):
	prints(str(id), "connected")

func client_disconnected(id: int):
	for player in list_of_players:
		if player.id == id:
			list_of_players.erase(player)
			player.queue_free()
			return

func join(role: CharacterController.ROLE):
	selected_role = role
	prints("Selected role:", selected_role, role)
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(func(): print("Connection failed"))
	multiplayer.server_disconnected.connect(func(): print("Server disconnected"))

func connected_to_server():
	DisplayServer.window_set_title(str("JOIN: Player ", multiplayer.get_unique_id(), " ROLE: ", selected_role))
	send_role.rpc_id(1, selected_role)

@rpc("any_peer", "reliable", "call_local")
func send_role(role: CharacterController.ROLE):
	var sender_id = multiplayer.get_remote_sender_id()
	add_client(sender_id, role)
	print(list_of_players)
	for player in list_of_players:
		remote_add_client.rpc_id(sender_id, player.id, role)
		if not player.id == 1 and not player.id == sender_id:
			remote_add_client.rpc_id(player.id, sender_id, role)
		

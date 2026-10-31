extends Node
# WebSocket transport also works in Godot Web exports.
var status: Label
var address: LineEdit
var avatars: Dictionary = {}
var states: Dictionary = {}
var timer := 0.0
var server_mode := false

func _ready() -> void:
	name = "Online"
	multiplayer.peer_disconnected.connect(_remove_peer)
	multiplayer.connected_to_server.connect(func(): status.text = "ONLINE: ulandi")
	multiplayer.connection_failed.connect(func(): _disconnect("ONLINE: ulanish amalga oshmadi"))
	multiplayer.server_disconnected.connect(func(): _disconnect("ONLINE: server uzildi"))
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		server_mode = true
		var peer := WebSocketMultiplayerPeer.new()
		var error := peer.create_server(9080, "127.0.0.1" if "--local" in args else "*")
		if error != OK:
			push_error("WebSocket server failed: %s" % error)
			get_tree().quit(1)
		else:
			multiplayer.multiplayer_peer = peer
			print("RP_SERVER_READY 9080")
		return
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-390, 270)
	panel.custom_minimum_size.x = 310
	get_parent().ui.add_child(panel)
	status = Label.new()
	status.text = "ONLINE: ulanmagan"
	panel.add_child(status)
	address = LineEdit.new()
	address.placeholder_text = "wss://server.example.com"
	address.custom_minimum_size.x = 300
	panel.add_child(address)
	var join := Button.new()
	join.text = "ULANISH / UZILISH"
	panel.add_child(join)
	join.pressed.connect(func():
		if (multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_disconnect("ONLINE: ulanmagan")
			return
		var url := address.text.strip_edges()
		address.release_focus()
		if not (url.begins_with("ws://") or url.begins_with("wss://")):
			status.text = "ONLINE: ws:// yoki wss:// manzil kiriting"
			return
		var peer := WebSocketMultiplayerPeer.new()
		if peer.create_client(url) == OK:
			multiplayer.multiplayer_peer = peer
			status.text = "ONLINE: ulanmoqda..."
		else:
			status.text = "ONLINE: manzil xato"
	)
	for arg in args:
		if arg.begins_with("--connect="):
			address.text = arg.trim_prefix("--connect=")
			join.pressed.emit()

func _disconnect(message: String) -> void:
	if (multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	for id in avatars.keys():
		_remove_peer(id)
	states.clear()
	if status:
		status.text = message

func _remove_peer(id: int) -> void:
	states.erase(id)
	if avatars.has(id):
		avatars[id]["root"].queue_free()
		avatars.erase(id)

func _process(delta: float) -> void:
	for avatar in avatars.values():
		var root: Node3D = avatar["root"]
		root.position = root.position.lerp(avatar["target_position"], minf(delta*12.0, 1.0))
		root.rotation.y = lerp_angle(root.rotation.y, float(avatar["target_heading"]), minf(delta*12.0, 1.0))
	if not (multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	timer += delta
	if timer < 0.1:
		return
	timer = 0.0
	if server_mode:
		_snapshot.rpc(states)
	elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var game = get_parent()
		var actor: Node3D = game.car if game.car_mode else game.player
		var model := "sedan"
		if game.rp and not game.rp.current_vehicle.is_empty():
			model = str(game.rp.current_vehicle.get("model", "sedan"))
		_submit.rpc_id(1, actor.position, actor.rotation.y, game.car_mode, game.player_role, game.player_health, model)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit(pos: Vector3, heading: float, driving: bool, role: String, health: int, model: String) -> void:
	if not server_mode or not pos.is_finite() or not is_finite(heading):
		return
	if absf(pos.x) > 240 or absf(pos.z) > 240 or pos.y < -5 or pos.y > 70:
		return
	if role not in ["civilian", "police", "thief"] or model not in ["sedan", "compact", "suv", "taxi", "police"]:
		return
	states[multiplayer.get_remote_sender_id()] = {"position":pos, "heading":heading, "driving":driving, "role":role, "health":clampi(health,0,100), "model":model}

@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(snapshot: Dictionary) -> void:
	for id in avatars.keys():
		if not snapshot.has(id):
			_remove_peer(id)
	for id in snapshot:
		if id == multiplayer.get_unique_id():
			continue
		var data: Dictionary = snapshot[id]
		if not avatars.has(id):
			var avatar := Node3D.new()
			get_parent().add_child(avatar)
			var human := Node3D.new()
			avatar.add_child(human)
			var role_color := Color("315f94") if data.get("role", "civilian") == "police" else (Color("8f4c4c") if data.get("role", "civilian") == "thief" else Color("db9946"))
			get_parent()._make_human(human, role_color, data.get("role", "civilian") == "police")
			var sedan := Node3D.new()
			avatar.add_child(sedan)
			get_parent()._build_sedan(sedan, data.get("model", "sedan") == "police")
			var label := Label3D.new()
			label.position.y = 3.0
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			avatar.add_child(label)
			avatars[id] = {"root":avatar, "human":human, "vehicle":sedan, "label":label, "target_position":data.position, "target_heading":data.heading}
		var record: Dictionary = avatars[id]
		record["target_position"] = data.position
		record["target_heading"] = data.heading
		(record["human"] as Node3D).visible = not data.driving
		(record["vehicle"] as Node3D).visible = data.driving
		(record["label"] as Label3D).text = "%s | %s | HP %d" % [id, str(data.get("role", "civilian")).to_upper(), int(data.get("health", 100))]

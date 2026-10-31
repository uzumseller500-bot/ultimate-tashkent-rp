extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.rp.select_role("police", false)
	var online = game.get_node("Online")
	var waited := 0.0
	while online.avatars.is_empty() and waited < 6.0:
		await create_timer(.2).timeout
		waited += .2
	if game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer or online.avatars.is_empty():
		push_error("No remote player received: %s; states=%s; args=%s" % [online.status.text, online.states, OS.get_cmdline_user_args()])
		quit(1)
		return
	var remote_record: Dictionary = online.avatars.values()[0]
	var remote: Node3D = remote_record["root"]
	assert(remote.position.is_finite())
	assert("POLICE" in (remote_record["label"] as Label3D).text)
	print("ONLINE_REMOTE_PLAYER_RECEIVED")
	await create_timer(1.0).timeout
	online._disconnect("test")
	assert(online.avatars.is_empty() and (not game.multiplayer.has_multiplayer_peer() or game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer))
	print("ONLINE_DISCONNECT_PASSED")
	quit()

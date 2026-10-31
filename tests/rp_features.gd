extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var rp = game.rp
	rp.set_process(false)
	assert(game.pedestrians.size() == game.POPULATION_COUNT)
	assert(rp.vehicles.size() >= 14, "City traffic and parked cars must exist")
	assert(rp.entrances.size() >= 30, "Most procedural buildings need entrances")

	var bank: Dictionary = {}
	var house: Dictionary = {}
	for entrance in rp.entrances:
		if entrance["kind"] == "bank": bank = entrance
		if entrance["kind"] == "house" and house.is_empty(): house = entrance
	assert(not bank.is_empty() and not house.is_empty())
	rp.enter_building(house)
	assert(rp.inside_building and rp.interior_root.visible)
	rp.exit_building()
	assert(not rp.inside_building and game.player.position == house["outside"])

	var money_before: int = game.cash
	rp.select_role("thief", false)
	rp.enter_building(bank)
	game.player.position = rp.VAULT_POSITION
	assert(rp.start_bank_robbery())
	rp.robbery_timer = 7.9
	rp._update_robbery(.2)
	assert(rp.robbery_state == "escape" and rp.carried_loot == 3000)
	assert(game.cash == money_before and game.wanted_level == 3)
	rp.exit_building()
	game.player.position = rp.ESCAPE_POINT
	rp._update_robbery(.1)
	assert(rp.robbery_state == "cooldown" and game.cash == money_before + 3000)

	var stolen: Dictionary = {}
	for vehicle in rp.vehicles:
		if bool(vehicle["occupied"]):
			stolen = vehicle
			break
	assert(not stolen.is_empty())
	game.player.position = stolen["node"].position
	rp._enter_vehicle(stolen)
	assert(game.car_mode and game.car == stolen["node"] and bool(stolen["stolen"]))
	assert(game.wanted_level > 0)
	rp._leave_vehicle()
	assert(not game.car_mode)

	rp.select_role("police", false)
	assert(not rp.current_suspect.is_empty())
	var suspect: Node3D = rp.current_suspect["node"]
	game.player.position = suspect.position
	game.mission_stage = 0
	rp._order_suspect()
	assert(bool(rp.current_suspect.get("surrendered", false)))
	var police_money: int = game.cash
	rp._order_suspect()
	assert(game.cash == police_money + 500)

	rp.select_role("thief", false)
	var target: Dictionary = game.pedestrians[1]
	target["surrendered"] = false
	target["health"] = 100
	game.player.position = (target["node"] as Node3D).position
	assert(rp.fire_weapon())
	rp.weapon_cooldown = 0.0
	assert(rp.fire_weapon())
	assert(int(target["health"]) == 0 and bool(target["surrendered"]))
	assert(game.wanted_level > 0)

	game.player_health = 100
	rp.compliance_active = false
	for i in range(7):
		rp.police_shot_timer = 0.0
		rp.update_police_response(1.0, 10.0)
	assert(game.player_health < 100, "Ignoring the stop order must cause damage")
	game.cash = 1000
	rp.surrender_or_order()
	assert(game.wanted_level == 0 and game.player_health == 100 and game.cash == 700)

	rp.select_role("thief", false)
	game._save_game()
	game.player_role = "civilian"
	game._load_game()
	assert(game.player_role == "thief", "Role must persist")
	print("RP_FEATURE_TESTS_PASSED")
	quit()

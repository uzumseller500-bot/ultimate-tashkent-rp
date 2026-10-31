extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.rp.set_process(false)
	game.rp.select_role("civilian", false)
	game._select_job("courier")
	var initial: int = game.cash
	game._advance_job()
	assert(game.cash == initial and not game.job_pickup)
	game._advance_job()
	assert(game.cash == initial + 250 and game.job_pickup)
	game._select_job("taxi")
	game._advance_job()
	assert(game.job_pickup, "Taxi requires a car")
	game.player.position = game.car.position
	game._toggle_car()
	assert(game.car_mode and not game.player.visible)
	game._advance_job()
	game._advance_job()
	assert(game.cash == initial + 650)
	game.car.position = game.DEPOT
	game.fuel = 50.0
	game._refuel()
	assert(game.fuel == 100.0 and game.cash == initial + 550)
	game.fuel = 20.0
	game.car.position = Vector3(100, 0, 100)
	game._refuel()
	assert(game.fuel == 20.0, "Refuel only at depot")
	game.car.position = game.DEPOT
	game.cash = 0
	game._refuel()
	assert(game.fuel == 20.0, "No free fuel")
	game._save_game()
	game.fuel = 99.0
	game.cash = 999
	game._load_game()
	assert(game.fuel == 20.0 and game.cash == 0)
	game._toggle_car()
	assert(not game.car_mode and game.player.visible)
	print("GAMEPLAY_TESTS_PASSED")
	quit()

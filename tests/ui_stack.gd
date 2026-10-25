extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.game.new_game(123)
	scene.selected = "A"
	scene.selected_ids.clear()
	scene.selected_ids.append("A")
	scene.refresh()
	scene.toggle_soldier("B")
	assert(scene.selected_ids == ["A", "B"])
	assert(scene.stack_is_legal())
	assert(scene.counter_icons["A"] != null)
	assert(scene.action_buttons.move.disabled == false)
	scene.terrain_review_mode = true
	scene.refresh()
	assert(scene.board.terrain_review_mode)
	scene.toggle_soldier("A")
	assert(scene.selected_ids == ["B"])
	print("UI STACK OK")
	quit()

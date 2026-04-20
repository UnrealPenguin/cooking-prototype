extends Node

signal coins_changed(value: int)
signal gems_changed(value: int)
signal level_started(level_data: Dictionary)
signal level_completed(summary: Dictionary)
signal level_stars_updated(level_id: int, stars: int)

var coins: int = 0
var gems: int = 0
var level_best_stars: Dictionary = {}  # str(level_id) -> int
var current_level: Dictionary = {}
var completed_orders: int = 0
var failed_orders: int = 0
var pending_level_id: int = 1

func start_level(level_id: int) -> void:
	var lvl := DataLoader.get_level(level_id)
	if lvl.is_empty():
		push_error("Unknown level id: %s" % level_id)
		return
	current_level = lvl
	completed_orders = 0
	failed_orders = 0
	emit_signal("level_started", lvl)

func add_coins(amount: int) -> void:
	coins += amount
	emit_signal("coins_changed", coins)

func add_gems(amount: int) -> void:
	gems += amount
	emit_signal("gems_changed", gems)

func record_order_result(success: bool) -> void:
	if success:
		completed_orders += 1
	else:
		failed_orders += 1
	_check_level_end()

func total_orders() -> int:
	return int(current_level.get("total_orders", 0))

func get_best_stars(level_id: int) -> int:
	return int(level_best_stars.get(str(level_id), 0))

func update_best_stars(level_id: int, stars: int) -> void:
	var key := str(level_id)
	var current := int(level_best_stars.get(key, 0))
	if stars > current:
		level_best_stars[key] = stars
		emit_signal("level_stars_updated", level_id, stars)

func _check_level_end() -> void:
	if completed_orders + failed_orders >= total_orders():
		emit_signal("level_completed", {
			"completed": completed_orders,
			"failed": failed_orders,
		})

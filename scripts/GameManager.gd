extends Node

signal coins_changed(value: int)
signal stars_changed(value: int)
signal level_started(level_data: Dictionary)
signal level_completed(summary: Dictionary)

var coins: int = 0
var stars_total: int = 0
var current_level: Dictionary = {}
var completed_orders: int = 0
var failed_orders: int = 0

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

func add_stars(amount: int) -> void:
	stars_total += amount
	emit_signal("stars_changed", stars_total)

func record_order_result(success: bool, stars_earned: int, coins_earned: int) -> void:
	if success:
		completed_orders += 1
		add_stars(stars_earned)
		add_coins(coins_earned)
	else:
		failed_orders += 1
	_check_level_end()

func total_orders() -> int:
	return int(current_level.get("total_orders", 0))

func _check_level_end() -> void:
	if completed_orders + failed_orders >= total_orders():
		emit_signal("level_completed", {
			"completed": completed_orders,
			"failed": failed_orders,
			"coins": coins,
			"stars": stars_total
		})

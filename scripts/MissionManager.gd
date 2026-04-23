extends Node

signal mission_progress_changed
signal mission_claimed(mission_id: String)
signal all_missions_completed
signal daily_reset

var missions: Array = []
var current_index: int = 0

var daily_pool: Array = []
var daily_date: String = ""
var daily_missions: Array = []  # [{id, claimed}]
var daily_stats: Dictionary = {
	"shifts_completed": 0,
	"orders_served": 0,
	"coins_earned": 0,
}

var _in_claim: bool = false

func _ready() -> void:
	missions = DataLoader._load_json("res://data/missions.json")
	if typeof(missions) != TYPE_ARRAY:
		missions = []
	daily_pool = DataLoader._load_json("res://data/daily_missions.json")
	if typeof(daily_pool) != TYPE_ARRAY:
		daily_pool = []
	GameManager.level_stars_updated.connect(func(_id, _s): emit_signal("mission_progress_changed"))
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.coins_changed.connect(_on_coins_changed)
	check_daily_reset()

func has_active_mission() -> bool:
	return current_index < missions.size()

func get_current_mission() -> Dictionary:
	if not has_active_mission():
		return {}
	return missions[current_index]

func get_progress() -> Dictionary:
	if not has_active_mission():
		return {"current": 0, "target": 0, "claimable": false, "done": true}
	var m: Dictionary = get_current_mission()
	var current := _evaluate_progress(m)
	var target := int(m.get("count", 1))
	return {
		"current": min(current, target),
		"target": target,
		"claimable": current >= target,
		"done": false,
	}

func claim_current() -> bool:
	var progress := get_progress()
	if not bool(progress.get("claimable", false)):
		return false
	var m: Dictionary = get_current_mission()
	_pay_reward(m)
	var claimed_id: String = str(m.get("id", ""))
	current_index += 1
	emit_signal("mission_claimed", claimed_id)
	emit_signal("mission_progress_changed")
	if not has_active_mission():
		emit_signal("all_missions_completed")
	return true

func reset() -> void:
	current_index = 0
	daily_date = ""
	daily_missions = []
	daily_stats = {
		"shifts_completed": 0,
		"orders_served": 0,
		"coins_earned": 0,
	}
	check_daily_reset()
	emit_signal("mission_progress_changed")

# ---------- Daily missions ----------

func check_daily_reset() -> void:
	var today := _today_string()
	if daily_date != today:
		daily_date = today
		_pick_daily_set()
		daily_stats = {
			"shifts_completed": 0,
			"orders_served": 0,
			"coins_earned": 0,
		}
		emit_signal("daily_reset")
		emit_signal("mission_progress_changed")

func get_daily_entries() -> Array:
	check_daily_reset()
	var out: Array = []
	for entry in daily_missions:
		var template := _find_daily_template(str(entry.get("id", "")))
		if template.is_empty():
			continue
		var current := _evaluate_daily_progress(template)
		var target := int(template.get("count", 1))
		var claimed := bool(entry.get("claimed", false))
		out.append({
			"template": template,
			"current": min(current, target),
			"target": target,
			"claimable": (not claimed) and current >= target,
			"claimed": claimed,
		})
	return out

func claim_daily(mission_id: String) -> bool:
	check_daily_reset()
	for entry in daily_missions:
		if str(entry.get("id", "")) != mission_id:
			continue
		if bool(entry.get("claimed", false)):
			return false
		var template := _find_daily_template(mission_id)
		if template.is_empty():
			return false
		var current := _evaluate_daily_progress(template)
		if current < int(template.get("count", 1)):
			return false
		entry["claimed"] = true
		_pay_reward(template)
		emit_signal("mission_claimed", mission_id)
		emit_signal("mission_progress_changed")
		return true
	return false

func _pick_daily_set() -> void:
	daily_missions = []
	for tpl in daily_pool:
		daily_missions.append({"id": str(tpl.get("id", "")), "claimed": false})

func _find_daily_template(id: String) -> Dictionary:
	for tpl in daily_pool:
		if str(tpl.get("id", "")) == id:
			return tpl
	return {}

func _evaluate_daily_progress(template: Dictionary) -> int:
	var type: String = str(template.get("type", ""))
	match type:
		"shifts_completed_today":
			return int(daily_stats.get("shifts_completed", 0))
		"orders_served_today":
			return int(daily_stats.get("orders_served", 0))
		"coins_earned_today":
			return int(daily_stats.get("coins_earned", 0))
		_:
			return 0

func _on_level_completed(summary: Dictionary) -> void:
	check_daily_reset()
	daily_stats["shifts_completed"] = int(daily_stats.get("shifts_completed", 0)) + 1
	daily_stats["orders_served"] = int(daily_stats.get("orders_served", 0)) + int(summary.get("completed", 0))
	emit_signal("mission_progress_changed")

func _on_coins_changed(_total: int) -> void:
	pass  # placeholder; we track via add_coins delta below

func track_coins_earned(amount: int) -> void:
	if _in_claim or amount <= 0:
		return
	check_daily_reset()
	daily_stats["coins_earned"] = int(daily_stats.get("coins_earned", 0)) + amount
	emit_signal("mission_progress_changed")

# ---------- Shared ----------

func _pay_reward(m: Dictionary) -> void:
	_in_claim = true
	var coins := int(m.get("reward_coins", 0))
	var gems := int(m.get("reward_gems", 0))
	if coins > 0:
		GameManager.add_coins(coins)
	if gems > 0:
		GameManager.add_gems(gems)
	_in_claim = false

func _evaluate_progress(m: Dictionary) -> int:
	var type: String = str(m.get("type", ""))
	match type:
		"stars_on_stages":
			var required := int(m.get("stars", 1))
			var count := 0
			for key in GameManager.level_best_stars.keys():
				if int(GameManager.level_best_stars[key]) >= required:
					count += 1
			return count
		_:
			return 0

func _today_string() -> String:
	return Time.get_date_string_from_system()

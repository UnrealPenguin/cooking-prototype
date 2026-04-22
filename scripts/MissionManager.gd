extends Node

signal mission_progress_changed
signal mission_claimed(mission_id: String)
signal all_missions_completed

var missions: Array = []
var current_index: int = 0

func _ready() -> void:
	missions = DataLoader._load_json("res://data/missions.json")
	if typeof(missions) != TYPE_ARRAY:
		missions = []
	GameManager.level_stars_updated.connect(func(_id, _s): emit_signal("mission_progress_changed"))

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
	var coins := int(m.get("reward_coins", 0))
	var gems := int(m.get("reward_gems", 0))
	if coins > 0:
		GameManager.add_coins(coins)
	if gems > 0:
		GameManager.add_gems(gems)
	var claimed_id: String = str(m.get("id", ""))
	current_index += 1
	emit_signal("mission_claimed", claimed_id)
	emit_signal("mission_progress_changed")
	if not has_active_mission():
		emit_signal("all_missions_completed")
	return true

func reset() -> void:
	current_index = 0
	emit_signal("mission_progress_changed")

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

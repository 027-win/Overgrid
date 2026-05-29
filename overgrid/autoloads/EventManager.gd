extends Node

# ── EVENT SYSTEM ──────────────────────────
# Manages rotating events, daily rewards, and engagement mechanics

signal event_started(event_data: Dictionary)
signal event_ended(event_id: String)
signal daily_reward_claimed(amount: int)
signal streak_updated(current_streak: int)

var current_event: Dictionary = {}
var current_event_id: String = ""
var event_timer: float = 0.0
var event_active: bool = false

# Daily tracking
var last_login_date: String = ""
var daily_streak: int = 0
var last_claimed_reward: bool = false

# Event definitions
const EVENT_CATALOG = {
	"surge_frenzy": {
		"name": "SURGE FRENZY",
		"description": "Surges last 2x longer!",
		"duration": 3600.0,  # 1 hour
		"color": Color("#FF8800"),
		"bonus_gt": 10,
		"effect": "surge_duration_2x",
	},
	"harvest_festival": {
		"name": "HARVEST FESTIVAL",
		"description": "Buildings produce 1.5x resources!",
		"duration": 3600.0,
		"color": Color("#44FF88"),
		"bonus_gt": 10,
		"effect": "production_1.5x",
	},
	"mystery_tiles": {
		"name": "MYSTERY TILES",
		"description": "Special tiles worth 10x energy!",
		"duration": 3600.0,
		"color": Color("#BB44FF"),
		"bonus_gt": 15,
		"effect": "special_tiles_10x",
	},
	"chain_rush": {
		"name": "CHAIN RUSH",
		"description": "Make chains = earn bonus energy!",
		"duration": 3600.0,
		"color": Color("#FFDD33"),
		"bonus_gt": 20,
		"effect": "chain_bonus_active",
	},
}

const DAILY_REWARD_AMOUNTS = [
	50,   # Day 1
	100,  # Day 2
	150,  # Day 3
	200,  # Day 4-6
	300,  # Day 7 (bonus)
]

var _event_timer: float = 0.0

func _ready() -> void:
	load_event_progress()
	start_random_event()

func _process(delta: float) -> void:
	if not event_active:
		return
	
	event_timer -= delta
	if event_timer <= 0.0:
		end_current_event()
		await get_tree().create_timer(2.0).timeout
		start_random_event()

# ── EVENT MANAGEMENT ───────────────────────
func start_random_event() -> void:
	var event_keys = EVENT_CATALOG.keys()
	var random_event_id = event_keys[randi() % event_keys.size()]
	start_event(random_event_id)

func start_event(event_id: String) -> void:
	if not EVENT_CATALOG.has(event_id):
		return
	
	current_event = EVENT_CATALOG[event_id].duplicate()
	current_event_id = event_id
	event_active = true
	event_timer = current_event.duration
	
	GameManager.add_grid_tokens(current_event.bonus_gt)
	emit_signal("event_started", current_event)
	print("[EVENT] %s started! +%d GT" % [current_event.name, current_event.bonus_gt])

func end_current_event() -> void:
	if current_event_id.is_empty():
		return
	
	event_active = false
	emit_signal("event_ended", current_event_id)
	print("[EVENT] %s ended" % current_event.name)

func get_event_time_remaining() -> float:
	return max(0.0, event_timer)

func get_active_event() -> Dictionary:
	return current_event if event_active else {}

func is_event_active(effect_id: String) -> bool:
	return event_active and current_event.get("effect", "") == effect_id

# ── DAILY STREAK SYSTEM ───────────────────
func get_today_date() -> String:
	var time = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [time.year, time.month, time.day]

func claim_daily_reward() -> bool:
	var today = get_today_date()
	
	# Already claimed today
	if last_login_date == today and last_claimed_reward:
		return false
	
	# New day - increment streak or reset
	if last_login_date != today:
		if _is_consecutive_day(last_login_date, today):
			daily_streak += 1
		else:
			daily_streak = 1
		last_login_date = today
	
	# Cap streak at 7 days (resets after)
	if daily_streak > 7:
		daily_streak = 1
	
	var reward_index = mini(daily_streak - 1, DAILY_REWARD_AMOUNTS.size() - 1)
	var reward_amount = DAILY_REWARD_AMOUNTS[reward_index]
	
	GameManager.add_grid_tokens(reward_amount)
	last_claimed_reward = true
	
	emit_signal("daily_reward_claimed", reward_amount)
	emit_signal("streak_updated", daily_streak)
	save_event_progress()
	
	print("[DAILY] Streak Day %d: +%d GT" % [daily_streak, reward_amount])
	return true

func _is_consecutive_day(prev_date: String, today_date: String) -> bool:
	if prev_date.is_empty():
		return false
	
	var prev_parts = prev_date.split("-")
	var today_parts = today_date.split("-")
	
	if prev_parts.size() != 3 or today_parts.size() != 3:
		return false
	
	var prev_day = Time.get_unix_time_from_datetime_dict({
		"year": int(prev_parts[0]),
		"month": int(prev_parts[1]),
		"day": int(prev_parts[2]),
		"hour": 0, "minute": 0, "second": 0
	})
	
	var today_day = Time.get_unix_time_from_datetime_dict({
		"year": int(today_parts[0]),
		"month": int(today_parts[1]),
		"day": int(today_parts[2]),
		"hour": 0, "minute": 0, "second": 0
	})
	
	return (today_day - prev_day) == 86400  # Exactly 1 day in seconds

func reset_daily_reward() -> void:
	last_claimed_reward = false

func get_streak_display() -> String:
	if daily_streak == 0:
		return "Day 0"
	elif daily_streak == 7:
		return "Day 7 🎁"
	else:
		return "Day %d" % daily_streak

# ── EVENT EFFECTS ─────────────────────────
func apply_event_effect(effect_type: String, base_value: float) -> float:
	if not event_active:
		return base_value
	
	match current_event.get("effect", ""):
		"surge_duration_2x":
			if effect_type == "surge_duration":
				return base_value * 2.0
		"production_1.5x":
			if effect_type == "production":
				return base_value * 1.5
		"special_tiles_10x":
			if effect_type == "special_tile_bonus":
				return base_value * 10.0
		"chain_bonus_active":
			if effect_type == "chain_bonus":
				return base_value * 2.0
	
	return base_value

# ── SAVE / LOAD ────────────────────────────
func save_event_progress() -> void:
	var data = {
		"last_login_date": last_login_date,
		"daily_streak": daily_streak,
		"last_claimed_reward": last_claimed_reward,
		"current_event_id": current_event_id,
		"event_timer": event_timer if event_active else 0.0,
	}
	
	var save_path = "user://event_data.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_event_progress() -> void:
	var save_path = "user://event_data.json"
	if not FileAccess.file_exists(save_path):
		last_login_date = get_today_date()
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return
	
	last_login_date = parsed.get("last_login_date", "")
	daily_streak = parsed.get("daily_streak", 0)
	last_claimed_reward = parsed.get("last_claimed_reward", false)
	
	# Auto-claim daily reward if new day
	var today = get_today_date()
	if last_login_date != today:
		await get_tree().process_frame
		claim_daily_reward()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_event_progress()

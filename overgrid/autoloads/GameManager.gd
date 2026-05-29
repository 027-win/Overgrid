extends Node

# Resources
var raw_energy: float = 0.0
var power_crystals: float = 50.0
var data_shards: float = 0.0
var grid_tokens: int = 0
const RAW_ENERGY_CAP: float = 10000.0

# Puzzle stats
var chain_multiplier: float = 1.0
var active_colors: int = 5

# Surge
var surge_multiplier: float = 1.0
var surge_timer: float = 0.0
const SURGE_SMALL_MULT = 1.5
const SURGE_SMALL_DUR = 12.0
const SURGE_BIG_MULT = 2.4
const SURGE_BIG_DUR = 28.0
const SURGE_MEGA_MULT = 3.8
const SURGE_MEGA_DUR = 38.0

# ── PRESTIGE SYSTEM ──────────────────────────
var prestige_level: int = 0
var total_pc_earned_all_time: float = 0.0
var total_ds_earned_all_time: float = 0.0
var prestige_resets_count: int = 0

const PRESTIGE_CONFIG = {
	"unlock_at_ds": 500.0,
	"base_bonus_per_level": 0.15,  # 15% multiplier per prestige
	"grid_token_bonus_per_level": 5,  # 5 GT per prestige level
}

# Offline
var _last_save_time: int = 0

# Building definitions
const BUILDING_ORDER = [
	"energy_tap", "converter_station", "relay_tower",
	"synthesis_lab", "grid_matrix", "quantum_forge", "void_reactor"
]

const BUILDING_DATA = {
	"energy_tap": {
		"display_name": "Energy Tap",
		"description": "Taps residual energy directly from the Grid",
		"pc_per_cycle": 0.5,
		"ds_per_cycle": 0.0,
		"cycle_duration": 4.0,
		"base_cost": 15.0,
		"cost_scale": 1.18,
		"color": Color("#1144DD"),
		"unlock_ds": 0.0,
		"milestones": [10, 25, 100, 250],
	},
	"converter_station": {
		"display_name": "Converter Station",
		"description": "Converts raw Grid energy into Power Crystals",
		"pc_per_cycle": 3.0,
		"ds_per_cycle": 0.0,
		"cycle_duration": 10.0,
		"base_cost": 150.0,
		"cost_scale": 1.18,
		"color": Color("#11AA44"),
		"unlock_ds": 0.0,
		"milestones": [10, 25, 100, 250],
	},
	"relay_tower": {
		"display_name": "Relay Tower",
		"description": "Amplifies and relays energy signals across the Grid",
		"pc_per_cycle": 25.0,
		"ds_per_cycle": 0.0,
		"cycle_duration": 20.0,
		"base_cost": 1500.0,
		"cost_scale": 1.18,
		"color": Color("#FF8800"),
		"unlock_ds": 0.0,
		"milestones": [10, 25, 100, 250],
	},
	"synthesis_lab": {
		"display_name": "Synthesis Lab",
		"description": "Synthesizes Data Shards from processed energy",
		"pc_per_cycle": 0.0,
		"ds_per_cycle": 0.5,
		"cycle_duration": 30.0,
		"base_cost": 8000.0,
		"cost_scale": 1.18,
		"color": Color("#AA44FF"),
		"unlock_ds": 0.0,
		"milestones": [10, 25, 100, 250],
	},
	"grid_matrix": {
		"display_name": "Grid Matrix",
		"description": "Processes the entire Grid, producing all resources",
		"pc_per_cycle": 200.0,
		"ds_per_cycle": 1.0,
		"cycle_duration": 60.0,
		"base_cost": 80000.0,
		"cost_scale": 1.18,
		"color": Color("#22DDCC"),
		"unlock_ds": 50.0,
		"milestones": [10, 25, 100, 250],
	},
	"quantum_forge": {
		"display_name": "Quantum Forge",
		"description": "Forges Data Shards at quantum speeds",
		"pc_per_cycle": 100.0,
		"ds_per_cycle": 8.0,
		"cycle_duration": 90.0,
		"base_cost": 800000.0,
		"cost_scale": 1.18,
		"color": Color("#FF44AA"),
		"unlock_ds": 200.0,
		"milestones": [10, 25, 100, 250],
	},
	"void_reactor": {
		"display_name": "Void Reactor",
		"description": "Harnesses void energy for massive production",
		"pc_per_cycle": 2000.0,
		"ds_per_cycle": 5.0,
		"cycle_duration": 120.0,
		"base_cost": 10000000.0,
		"cost_scale": 1.18,
		"color": Color("#FF2222"),
		"unlock_ds": 1000.0,
		"milestones": [10, 25, 100, 250],
	},
}

# Building state
var building_counts: Dictionary = {}
var building_progress: Dictionary = {}
var building_ready: Dictionary = {}
var building_managers: Dictionary = {}
var milestones_claimed: Dictionary = {}

# Puzzle upgrades
const UPGRADE_DATA = {
	"chain_power": {
		"display_name": "Chain Power",
		"description": "+50% chain energy per level",
		"base_cost": 10,
		"cost_scale": 2.5,
		"max_level": -1,
	},
	"long_chain": {
		"display_name": "Long Chain",
		"description": "6+ tile chains give x2 energy",
		"base_cost": 80,
		"cost_scale": 3.0,
		"max_level": 1,
	},
	"lucky_draw": {
		"display_name": "Lucky Draw",
		"description": "+4% special tile spawn chance",
		"base_cost": 60,
		"cost_scale": 2.8,
		"max_level": 4,
	},
	"convergence": {
		"display_name": "Convergence",
		"description": "One fewer tile color on board",
		"base_cost": 250,
		"cost_scale": 6.0,
		"max_level": 2,
	},
}

var upgrade_levels = {
	"chain_power": 0,
	"long_chain": 0,
	"lucky_draw": 0,
	"convergence": 0,
}

# Signals
signal resources_changed()
signal building_ready_changed(bld_id: String)
signal building_collected(bld_id: String, pc: float, ds: float)
signal milestone_reached(bld_id: String, milestone_index: int)
signal upgrades_changed()
signal surge_triggered(multiplier: float, duration: float)
signal surge_ended()
signal grid_token_earned(amount: int)
signal prestige_available(ds_required: float)
signal prestige_completed(new_prestige_level: int, bonus_gt: int)

const SAVE_PATH = "user://save_data.json"
const AUTO_SAVE_INTERVAL = 30.0
var _save_timer: float = 0.0

func _ready() -> void:
	_init_buildings()
	load_game()

func _init_buildings() -> void:
	for bld_id in BUILDING_DATA:
		building_counts[bld_id] = 0
		building_progress[bld_id] = 0.0
		building_ready[bld_id] = false
		building_managers[bld_id] = false
		milestones_claimed[bld_id] = [false, false, false, false]

func _process(delta: float) -> void:
	_simulate_buildings(delta)
	
	if surge_timer > 0.0:
		surge_timer -= delta
		if surge_timer <= 0.0:
			surge_multiplier = 1.0
			emit_signal("surge_ended")
	
	_save_timer += delta
	if _save_timer >= AUTO_SAVE_INTERVAL:
		_save_timer = 0.0
		save_game()

func _simulate_buildings(delta: float) -> void:
	var total_owned = 0
	for bld_id in building_counts:
		total_owned += building_counts.get(bld_id, 0)
	
	var re_ratio = raw_energy / RAW_ENERGY_CAP
	var re_bonus = 1.0 + (re_ratio * 4.2)  # Up to ~5.2x when full
	
	var drain = minf(total_owned * 1.2 * delta * (1.0 - re_ratio * 0.6), raw_energy)
	raw_energy = maxf(raw_energy - drain, 0.0)
	
	var anything_changed = false
	
	for bld_id in BUILDING_DATA:
		var count = building_counts.get(bld_id, 0)
		if count == 0 or not is_building_unlocked(bld_id):
			continue
		if building_ready.get(bld_id, false):
			continue
			
		var data = BUILDING_DATA[bld_id]
		var speed = (float(count) / data.cycle_duration) * surge_multiplier * re_bonus
		building_progress[bld_id] = minf(building_progress.get(bld_id, 0.0) + speed * delta, 1.0)
		
		if building_progress[bld_id] >= 1.0:
			building_ready[bld_id] = true
			anything_changed = true
			if building_managers.get(bld_id, false):
				_do_collect(bld_id)
			else:
				emit_signal("building_ready_changed", bld_id)
	
	if anything_changed or total_owned > 0:
		emit_signal("resources_changed")

func _do_collect(bld_id: String) -> void:
	var data = BUILDING_DATA[bld_id]
	var count = building_counts.get(bld_id, 0)
	var mult = get_building_multiplier(bld_id)
	var pc_earned = data.pc_per_cycle * count * mult * surge_multiplier
	var ds_earned = data.ds_per_cycle * count * mult
	
	power_crystals += pc_earned
	data_shards += ds_earned
	building_progress[bld_id] = 0.0
	building_ready[bld_id] = false
	
	emit_signal("building_collected", bld_id, pc_earned, ds_earned)
	emit_signal("resources_changed")
	_check_milestones(bld_id)

func collect_building(bld_id: String) -> void:
	if building_ready.get(bld_id, false):
		_do_collect(bld_id)

# ── BUILDING FUNCTIONS ─────────────────────
func get_building_cost(bld_id: String, quantity: int = 1) -> float:
	var data = BUILDING_DATA[bld_id]
	var owned = building_counts.get(bld_id, 0)
	var total = 0.0
	for i in range(quantity):
		total += data.base_cost * pow(data.cost_scale, owned + i)
	return total

func get_max_affordable(bld_id: String) -> int:
	var data = BUILDING_DATA[bld_id]
	var owned = building_counts.get(bld_id, 0)
	var budget = power_crystals
	var count = 0
	while budget >= data.base_cost * pow(data.cost_scale, owned + count) and count < 10000:
		budget -= data.base_cost * pow(data.cost_scale, owned + count)
		count += 1
	return count

func buy_building(bld_id: String, quantity: int = 1) -> bool:
	if not is_building_unlocked(bld_id):
		return false
	var cost = get_building_cost(bld_id, quantity)
	if power_crystals < cost:
		return false
	power_crystals -= cost
	building_counts[bld_id] = building_counts.get(bld_id, 0) + quantity
	emit_signal("resources_changed")
	_check_milestones(bld_id)
	return true

func get_manager_cost(bld_id: String) -> float:
	var data = BUILDING_DATA[bld_id]
	var owned = max(building_counts.get(bld_id, 0), 1)
	return data.base_cost * pow(data.cost_scale, owned) * 15.0

func buy_manager(bld_id: String) -> bool:
	if building_managers.get(bld_id, false):
		return false
	var cost = get_manager_cost(bld_id)
	if power_crystals < cost:
		return false
	power_crystals -= cost
	building_managers[bld_id] = true
	if building_ready.get(bld_id, false):
		_do_collect(bld_id)
	emit_signal("resources_changed")
	return true

func is_building_unlocked(bld_id: String) -> bool:
	return data_shards >= BUILDING_DATA[bld_id].unlock_ds

func get_building_multiplier(bld_id: String) -> float:
	var mult = 1.0
	var claimed = milestones_claimed.get(bld_id, [])
	for c in claimed:
		if c:
			mult *= 2.0
	return mult

func _check_milestones(bld_id: String) -> void:
	var data = BUILDING_DATA[bld_id]
	var count = building_counts.get(bld_id, 0)
	var claimed = milestones_claimed.get(bld_id, [false, false, false, false])
	for i in range(data.milestones.size()):
		if not claimed[i] and count >= data.milestones[i]:
			claimed[i] = true
			milestones_claimed[bld_id] = claimed
			emit_signal("milestone_reached", bld_id, i)

func add_energy(amount: float) -> void:
	raw_energy = minf(raw_energy + amount * chain_multiplier, RAW_ENERGY_CAP)
	emit_signal("resources_changed")

func add_grid_tokens(amount: int) -> void:
	grid_tokens += amount
	emit_signal("resources_changed")
	emit_signal("grid_token_earned", amount)

func trigger_surge(multiplier: float, duration: float) -> void:
	if multiplier > surge_multiplier:
		surge_multiplier = multiplier
	if duration > surge_timer:
		surge_timer = duration
	emit_signal("surge_triggered", surge_multiplier, surge_timer)

# ── UPGRADE FUNCTIONS ──────────────────────
func get_upgrade_cost(upgrade_id: String) -> int:
	var data = UPGRADE_DATA[upgrade_id]
	var level = upgrade_levels[upgrade_id]
	return int(data.base_cost * pow(data.cost_scale, level))

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_afford_upgrade(upgrade_id):
		return false
	power_crystals -= get_upgrade_cost(upgrade_id)
	upgrade_levels[upgrade_id] += 1
	
	match upgrade_id:
		"chain_power": chain_multiplier += 0.5
		"convergence": active_colors = max(3, active_colors - 1)
	
	emit_signal("resources_changed")
	emit_signal("upgrades_changed")
	return true

func can_afford_upgrade(upgrade_id: String) -> bool:
	if is_upgrade_maxed(upgrade_id):
		return false
	return power_crystals >= get_upgrade_cost(upgrade_id)

func is_upgrade_maxed(upgrade_id: String) -> bool:
	var max_lvl = UPGRADE_DATA[upgrade_id].max_level
	return max_lvl != -1 and upgrade_levels[upgrade_id] >= max_lvl

func get_building_pc_rate(bld_id: String) -> float:
	var data = BUILDING_DATA[bld_id]
	var count = building_counts.get(bld_id, 0)
	if count == 0:
		return 0.0
	var mult = get_building_multiplier(bld_id)
	return (data.pc_per_cycle * count * mult) / data.cycle_duration

func get_total_pc_rate() -> float:
	var total = 0.0
	for bld_id in BUILDING_DATA:
		total += get_building_pc_rate(bld_id)
	return total * surge_multiplier

# ── PRESTIGE SYSTEM ───────────────────────
func get_prestige_multiplier() -> float:
	return 1.0 + (prestige_level * PRESTIGE_CONFIG.base_bonus_per_level)

func can_prestige() -> bool:
	return data_shards >= PRESTIGE_CONFIG.unlock_at_ds

func get_prestige_bonus_gt() -> int:
	return prestige_level * PRESTIGE_CONFIG.grid_token_bonus_per_level

func prestige_reset() -> void:
	# Track all-time stats before reset
	total_pc_earned_all_time += power_crystals
	total_ds_earned_all_time += data_shards
	prestige_resets_count += 1
	
	# Increment prestige level and grant bonus GT
	prestige_level += 1
	var bonus_gt = PRESTIGE_CONFIG.grid_token_bonus_per_level
	grid_tokens += bonus_gt
	
	# Reset all buildings and their progress
	for bld_id in BUILDING_DATA:
		building_counts[bld_id] = 0
		building_progress[bld_id] = 0.0
		building_ready[bld_id] = false
		building_managers[bld_id] = false
		milestones_claimed[bld_id] = [false, false, false, false]
	
	# Reset resources (keep prestige multiplier for future runs)
	raw_energy = 0.0
	power_crystals = 50.0  # Starting PC
	data_shards = 0.0
	chain_multiplier = 1.0
	active_colors = 5
	surge_multiplier = 1.0
	surge_timer = 0.0
	
	# Reset upgrades for fresh gameplay
	for upg_id in upgrade_levels:
		upgrade_levels[upg_id] = 0
	
	# Emit signal for UI notification
	emit_signal("prestige_completed", prestige_level, bonus_gt)
	emit_signal("resources_changed")
	save_game()

func apply_prestige_multiplier_to_resources(base_resources: float) -> float:
	"""Apply prestige multiplier to earned resources (buildings, chain rewards, etc)"""
	return base_resources * get_prestige_multiplier()

# ── OFFLINE PROGRESS ───────────────────────
func calculate_offline_progress() -> void:
	if _last_save_time <= 0:
		return
	var time_passed = Time.get_unix_time_from_system() - _last_save_time
	time_passed = minf(time_passed, 12 * 3600)
	var offline_eff = 0.65
	var prestige_mult = get_prestige_multiplier()
	
	for bld_id in BUILDING_DATA:
		if not building_managers.get(bld_id, false): continue
		var data = BUILDING_DATA[bld_id]
		var count = building_counts.get(bld_id, 0)
		if count == 0: continue
		var mult = get_building_multiplier(bld_id)
		var cycles = (time_passed * offline_eff) / data.cycle_duration
		power_crystals += data.pc_per_cycle * count * mult * cycles * prestige_mult
		data_shards += data.ds_per_cycle * count * mult * cycles * prestige_mult
	emit_signal("resources_changed")

# ── SAVE / LOAD ────────────────────────────
func save_game() -> void:
	_last_save_time = Time.get_unix_time_from_system()
	var ms_data = {}
	for bld_id in milestones_claimed:
		ms_data[bld_id] = milestones_claimed[bld_id].duplicate()
	
	var data = {
		"raw_energy": raw_energy,
		"power_crystals": power_crystals,
		"data_shards": data_shards,
		"grid_tokens": grid_tokens,
		"chain_multiplier": chain_multiplier,
		"active_colors": active_colors,
		"upgrade_levels": upgrade_levels.duplicate(),
		"building_counts": building_counts.duplicate(),
		"building_progress": building_progress.duplicate(),
		"building_ready": building_ready.duplicate(),
		"building_managers": building_managers.duplicate(),
		"milestones_claimed": ms_data,
		"_last_save_time": _last_save_time,
		"prestige_level": prestige_level,
		"total_pc_earned_all_time": total_pc_earned_all_time,
		"total_ds_earned_all_time": total_ds_earned_all_time,
		"prestige_resets_count": prestige_resets_count,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		return
	
	raw_energy = parsed.get("raw_energy", 0.0)
	power_crystals = parsed.get("power_crystals", 50.0)
	data_shards = parsed.get("data_shards", 0.0)
	grid_tokens = int(parsed.get("grid_tokens", 0))
	chain_multiplier = parsed.get("chain_multiplier", 1.0)
	active_colors = parsed.get("active_colors", 5)
	_last_save_time = parsed.get("_last_save_time", 0)
	prestige_level = parsed.get("prestige_level", 0)
	total_pc_earned_all_time = parsed.get("total_pc_earned_all_time", 0.0)
	total_ds_earned_all_time = parsed.get("total_ds_earned_all_time", 0.0)
	prestige_resets_count = parsed.get("prestige_resets_count", 0)
	
	# Load upgrades
	var lu = parsed.get("upgrade_levels", {})
	for k in upgrade_levels:
		if lu.has(k): upgrade_levels[k] = lu[k]
	
	# Load buildings
	var lbc = parsed.get("building_counts", {})
	for k in building_counts:
		if lbc.has(k): building_counts[k] = lbc[k]
	
	var lbp = parsed.get("building_progress", {})
	for k in building_progress:
		if lbp.has(k): building_progress[k] = lbp[k]
	
	var lbr = parsed.get("building_ready", {})
	for k in building_ready:
		if lbr.has(k): building_ready[k] = lbr[k]
	
	var lbm = parsed.get("building_managers", {})
	for k in building_managers:
		if lbm.has(k): building_managers[k] = lbm[k]
	
	var lmc = parsed.get("milestones_claimed", {})
	for k in milestones_claimed:
		if lmc.has(k): milestones_claimed[k] = lmc[k]
	
	calculate_offline_progress()
	emit_signal("resources_changed")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

# ── UTILITY FUNCTIONS ──────────────────────
static func fmt(n: float) -> String:
	if n < 1000.0: return "%.1f" % n
	elif n < 1000000.0: return "%.1fK" % (n / 1000.0)
	elif n < 1000000000.0: return "%.1fM" % (n / 1000000.0)
	elif n < 1.0e12: return "%.1fB" % (n / 1.0e9)
	else: return "%.1fT" % (n / 1.0e12)

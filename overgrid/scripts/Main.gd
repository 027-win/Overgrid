extends Node2D

@onready var board_node: Node2D = $Board
@onready var re_label: Label = $UI/TopBar/EnergyLabel
@onready var pc_label: Label = $UI/TopBar/IdleRateLabel

var current_screen: String = "board"

# Factory screen
var factory_screen: Control = null
var ds_gt_label: Label = null
var rate_label: Label = null
var surge_label: Label = null
var re_bar_fill: Panel = null
var re_bar_style: StyleBoxFlat = null
var re_bar_lbl: Label = null
var factory_pc_label: Label = null

# Building rows - [bld_id] = Dictionary of node refs
var _row_refs: Dictionary = {}

# Upgrades screen
var upgrades_screen: Control = null
var _upgrade_buttons: Dictionary = {}

# Surge notification
var surge_notify: Label = null

const BAR_TRACK_W = 686

func _ready() -> void:
	GameManager.resources_changed.connect(_on_resources_changed)
	GameManager.building_ready_changed.connect(_on_building_ready)
	GameManager.building_collected.connect(_on_building_collected)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	GameManager.upgrades_changed.connect(_on_upgrades_changed)
	GameManager.surge_triggered.connect(_on_surge_triggered)
	GameManager.surge_ended.connect(_on_surge_ended)
	GameManager.grid_token_earned.connect(_on_gt_earned)
	
	_build_surge_notify()
	_build_factory_screen()
	_build_upgrades_screen()
	_build_bottom_nav()
	_switch_screen("board")
	_refresh_resources()

func _process(_delta: float) -> void:
	if current_screen == "factory":
		_update_bars()

# ── Screen Management ──────────────────────
func _switch_screen(screen: String) -> void:
	current_screen = screen
	board_node.visible = (screen == "board")
	factory_screen.visible = (screen == "factory")
	upgrades_screen.visible = (screen == "upgrades")
	if screen == "factory":
		_refresh_all_rows()
		_refresh_header()
	elif screen == "upgrades":
		_refresh_upgrades()

# ── Bottom Navigation ──────────────────────
func _build_bottom_nav() -> void:
	var nav = HBoxContainer.new()
	nav.position = Vector2(0, 1770)
	nav.size = Vector2(1080, 150)
	nav.add_theme_constant_override("separation", 4)
	$UI.add_child(nav)
	var tabs = [["BOARD", "board"], ["FACTORY", "factory"], ["UPGRADES", "upgrades"]]
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 150)
		btn.add_theme_font_size_override("font_size", 36)
		var sn = tab[1]
		btn.pressed.connect(func(): _switch_screen(sn))
		nav.add_child(btn)

# ── Surge Notification ─────────────────────
func _build_surge_notify() -> void:
	surge_notify = Label.new()
	surge_notify.position = Vector2(0, 880)
	surge_notify.size = Vector2(1080, 120)
	surge_notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surge_notify.add_theme_font_size_override("font_size", 72)
	surge_notify.add_theme_color_override("font_color", Color("#FF8800"))
	surge_notify.modulate.a = 0.0
	surge_notify.z_index = 100
	$UI.add_child(surge_notify)

func _show_surge_notify(mult: float) -> void:
	surge_notify.text = "SURGE x%.0f" % mult
	var tw = create_tween()
	tw.tween_property(surge_notify, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.9)
	tw.tween_property(surge_notify, "modulate:a", 0.0, 0.4)

# ── Factory Screen ─────────────────────────
func _build_factory_screen() -> void:
	factory_screen = Control.new()
	factory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	factory_screen.visible = false
	$UI.add_child(factory_screen)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#07070F")
	factory_screen.add_child(bg)

	# Factory title
	var title = Label.new()
	title.text = "ENERGY EMPIRE"
	title.position = Vector2(0, 156)
	title.size = Vector2(1080, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#555577"))
	factory_screen.add_child(title)

	# DS + GT + rate label
	ds_gt_label = Label.new()
	ds_gt_label.position = Vector2(0, 210)
	ds_gt_label.size = Vector2(680, 44)
	ds_gt_label.add_theme_font_size_override("font_size", 30)
	ds_gt_label.add_theme_color_override("font_color", Color("#888899"))
	factory_screen.add_child(ds_gt_label)

	factory_pc_label = Label.new()
	factory_pc_label.position = Vector2(30, 158)
	factory_pc_label.size = Vector2(1020, 52)
	factory_pc_label.add_theme_font_size_override("font_size", 44)
	factory_pc_label.add_theme_color_override("font_color", Color("#FFDD88"))
	factory_screen.add_child(factory_pc_label)

	rate_label = Label.new()
	rate_label.position = Vector2(680, 210)
	rate_label.size = Vector2(380, 44)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_label.add_theme_font_size_override("font_size", 30)
	rate_label.add_theme_color_override("font_color", Color("#44FF88"))
	factory_screen.add_child(rate_label)

	# RE bar
	_build_re_bar()

	# Surge indicator
	surge_label = Label.new()
	surge_label.position = Vector2(0, 302)
	surge_label.size = Vector2(1080, 40)
	surge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surge_label.add_theme_font_size_override("font_size", 30)
	surge_label.add_theme_color_override("font_color", Color("#FF8800"))
	surge_label.visible = false
	factory_screen.add_child(surge_label)

	# Building scroll
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 348)
	scroll.size = Vector2(1080, 1416)
	factory_screen.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	_row_refs.clear()
	for bld_id in GameManager.BUILDING_ORDER:
		var refs = _create_building_row(bld_id)
		vbox.add_child(refs.container)
		_row_refs[bld_id] = refs

func _build_re_bar() -> void:
	var bar_area = Control.new()
	bar_area.position = Vector2(30, 258)
	bar_area.size = Vector2(1020, 42)
	factory_screen.add_child(bar_area)

	var re_text = Label.new()
	re_text.text = "RE"
	re_text.position = Vector2(0, 4)
	re_text.add_theme_font_size_override("font_size", 26)
	re_text.add_theme_color_override("font_color", Color("#333355"))
	bar_area.add_child(re_text)

	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color("#111128")
	track_style.set_corner_radius_all(8)
	var track = Panel.new()
	track.position = Vector2(50, 4)
	track.size = Vector2(BAR_TRACK_W + 8, 34)
	track.add_theme_stylebox_override("panel", track_style)
	bar_area.add_child(track)

	re_bar_style = StyleBoxFlat.new()
	re_bar_style.bg_color = Color("#2244CC")
	re_bar_style.set_corner_radius_all(7)
	re_bar_fill = Panel.new()
	re_bar_fill.position = Vector2(54, 8)
	re_bar_fill.size = Vector2(0, 26)
	re_bar_fill.add_theme_stylebox_override("panel", re_bar_style)
	bar_area.add_child(re_bar_fill)

	re_bar_lbl = Label.new()
	re_bar_lbl.position = Vector2(762, 4)
	re_bar_lbl.size = Vector2(258, 34)
	re_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	re_bar_lbl.add_theme_font_size_override("font_size", 26)
	re_bar_lbl.add_theme_color_override("font_color", Color("#3355BB"))
	bar_area.add_child(re_bar_lbl)

# ── Building Row Builder ───────────────────
func _create_building_row(bld_id: String) -> Dictionary:
	var data = GameManager.BUILDING_DATA[bld_id]
	var container = Control.new()
	container.custom_minimum_size = Vector2(1080, 284)

	var accent = ColorRect.new()
	accent.size = Vector2(12, 284)
	accent.color = data.color
	container.add_child(accent)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#0C0C1A")
	var bg = Panel.new()
	bg.position = Vector2(12, 0)
	bg.size = Vector2(1068, 283)
	bg.add_theme_stylebox_override("panel", bg_style)
	container.add_child(bg)

	var name_lbl = Label.new()
	name_lbl.text = data.display_name
	name_lbl.position = Vector2(28, 10)
	name_lbl.add_theme_font_size_override("font_size", 38)
	bg.add_child(name_lbl)

	var count_lbl = Label.new()
	count_lbl.position = Vector2(730, 12)
	count_lbl.size = Vector2(320, 44)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_size_override("font_size", 34)
	count_lbl.add_theme_color_override("font_color", data.color.lightened(0.4))
	bg.add_child(count_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data.description
	desc_lbl.position = Vector2(28, 58)
	desc_lbl.size = Vector2(1020, 34)
	desc_lbl.add_theme_font_size_override("font_size", 25)
	desc_lbl.add_theme_color_override("font_color", Color("#3A3A55"))
	bg.add_child(desc_lbl)

	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color("#111128")
	track_style.set_corner_radius_all(8)
	var track = Panel.new()
	track.position = Vector2(28, 98)
	track.size = Vector2(BAR_TRACK_W + 8, 46)
	track.add_theme_stylebox_override("panel", track_style)
	bg.add_child(track)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = data.color
	fill_style.set_corner_radius_all(7)
	var bar_fill = Panel.new()
	bar_fill.position = Vector2(32, 102)
	bar_fill.size = Vector2(0, 38)
	bar_fill.add_theme_stylebox_override("panel", fill_style)
	bg.add_child(bar_fill)

	var collect_btn = Button.new()
	collect_btn.text = "COLLECT"
	collect_btn.position = Vector2(724, 98)
	collect_btn.size = Vector2(322, 46)
	collect_btn.add_theme_font_size_override("font_size", 28)
	var bid = bld_id
	collect_btn.pressed.connect(func(): GameManager.collect_building(bid))
	bg.add_child(collect_btn)

	var auto_lbl = Label.new()
	auto_lbl.text = "AUTO ✓"
	auto_lbl.position = Vector2(724, 105)
	auto_lbl.size = Vector2(322, 36)
	auto_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_lbl.add_theme_font_size_override("font_size", 28)
	auto_lbl.add_theme_color_override("font_color", Color("#44FF88"))
	auto_lbl.visible = false
	bg.add_child(auto_lbl)

	var output_lbl = Label.new()
	output_lbl.position = Vector2(28, 154)
	output_lbl.size = Vector2(380, 38)
	output_lbl.add_theme_font_size_override("font_size", 28)
	output_lbl.add_theme_color_override("font_color", Color("#44FF88"))
	bg.add_child(output_lbl)

	var buy1 = Button.new()
	buy1.position = Vector2(416, 152)
	buy1.size = Vector2(116, 42)
	buy1.add_theme_font_size_override("font_size", 26)
	buy1.pressed.connect(func(): _on_buy(bid, 1))
	bg.add_child(buy1)

	var buy10 = Button.new()
	buy10.position = Vector2(540, 152)
	buy10.size = Vector2(130, 42)
	buy10.add_theme_font_size_override("font_size", 26)
	buy10.pressed.connect(func(): _on_buy(bid, 10))
	bg.add_child(buy10)

	var buymax = Button.new()
	buymax.position = Vector2(678, 152)
	buymax.size = Vector2(368, 42)
	buymax.add_theme_font_size_override("font_size", 26)
	buymax.pressed.connect(func(): _on_buy_max(bid))
	bg.add_child(buymax)

	var mgr_lbl = Label.new()
	mgr_lbl.text = "Manager:"
	mgr_lbl.position = Vector2(28, 204)
	mgr_lbl.size = Vector2(200, 36)
	mgr_lbl.add_theme_font_size_override("font_size", 26)
	mgr_lbl.add_theme_color_override("font_color", Color("#444455"))
	bg.add_child(mgr_lbl)

	var mgr_btn = Button.new()
	mgr_btn.position = Vector2(230, 202)
	mgr_btn.size = Vector2(816, 38)
	mgr_btn.add_theme_font_size_override("font_size", 26)
	mgr_btn.pressed.connect(func(): _on_buy_manager(bid))
	bg.add_child(mgr_btn)

	var ms_track = ColorRect.new()
	ms_track.position = Vector2(28, 252)
	ms_track.size = Vector2(1020, 3)
	ms_track.color = Color("#1A1A2E")
	bg.add_child(ms_track)

	var ms_dots = []
	var milestones = data.milestones
	for i in range(milestones.size()):
		var xp = int(28 + (float(i) / (milestones.size() - 1)) * 1000)
		var dot_style = StyleBoxFlat.new()
		dot_style.set_corner_radius_all(9)
		dot_style.bg_color = Color("#1A1A2E")
		var dot = Panel.new()
		dot.position = Vector2(xp - 9, 245)
		dot.size = Vector2(18, 18)
		dot.add_theme_stylebox_override("panel", dot_style)
		bg.add_child(dot)
		var dot_lbl = Label.new()
		dot_lbl.text = str(milestones[i])
		dot_lbl.position = Vector2(xp - 24, 264)
		dot_lbl.size = Vector2(48, 24)
		dot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot_lbl.add_theme_font_size_override("font_size", 20)
		dot_lbl.add_theme_color_override("font_color", Color("#252535"))
		bg.add_child(dot_lbl)
		ms_dots.append({"dot": dot, "dot_style": dot_style, "lbl": dot_lbl})

	var sep = ColorRect.new()
	sep.position = Vector2(0, 283)
	sep.size = Vector2(1080, 1)
	sep.color = Color("#111122")
	container.add_child(sep)

	var lock_style = StyleBoxFlat.new()
	lock_style.bg_color = Color(0.02, 0.02, 0.08, 0.88)
	var lock_overlay = Panel.new()
	lock_overlay.position = Vector2(12, 0)
	lock_overlay.size = Vector2(1068, 283)
	lock_overlay.add_theme_stylebox_override("panel", lock_style)
	container.add_child(lock_overlay)

	var lock_lbl = Label.new()
	var ds_req = data.unlock_ds
	lock_lbl.text = ("LOCKED — Requires DS %.0f" % ds_req) if ds_req > 0 else ""
	lock_lbl.position = Vector2(0, 115)
	lock_lbl.size = Vector2(1068, 54)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_size_override("font_size", 34)
	lock_lbl.add_theme_color_override("font_color", Color("#444466"))
	lock_overlay.add_child(lock_lbl)

	return {
		"container": container,
		"bg": bg,
		"accent": accent,
		"name_lbl": name_lbl,
		"count_lbl": count_lbl,
		"bar_fill": bar_fill,
		"fill_style": fill_style,
		"collect_btn": collect_btn,
		"auto_lbl": auto_lbl,
		"output_lbl": output_lbl,
		"buy1": buy1,
		"buy10": buy10,
		"buymax": buymax,
		"mgr_lbl": mgr_lbl,
		"mgr_btn": mgr_btn,
		"ms_dots": ms_dots,
		"lock_overlay": lock_overlay,
	}

# ── Bar Updates (every frame) ─────────────
func _update_bars() -> void:
	if re_bar_fill != null:
		var ratio = GameManager.raw_energy / GameManager.RAW_ENERGY_CAP
		re_bar_fill.size.x = BAR_TRACK_W * ratio
		re_bar_style.bg_color = Color("#2244CC").lerp(Color("#22CCFF"), ratio)
		re_bar_lbl.text = "%s / %s" % [GameManager.fmt(GameManager.raw_energy), GameManager.fmt(GameManager.RAW_ENERGY_CAP)]

	for bld_id in _row_refs:
		var refs = _row_refs[bld_id]
		var progress = GameManager.building_progress.get(bld_id, 0.0)
		var is_ready = GameManager.building_ready.get(bld_id, false)
		var data = GameManager.BUILDING_DATA[bld_id]
		refs.bar_fill.size.x = BAR_TRACK_W * progress
		refs.fill_style.bg_color = data.color.lightened(0.25) if is_ready else data.color

# ── Row Refresh (on data change) ──────────
func _refresh_all_rows() -> void:
	for bld_id in _row_refs:
		_refresh_row(bld_id)

func _refresh_row(bld_id: String) -> void:
	if not _row_refs.has(bld_id): return
	var refs = _row_refs[bld_id]
	var data = GameManager.BUILDING_DATA[bld_id]
	var count = GameManager.building_counts.get(bld_id, 0)
	var is_ready = GameManager.building_ready.get(bld_id, false)
	var has_mgr = GameManager.building_managers.get(bld_id, false)
	var unlocked = GameManager.is_building_unlocked(bld_id)

	refs.lock_overlay.visible = not unlocked
	if not unlocked: return

	refs.count_lbl.text = "x%d" % count if count > 0 else ""

	if count > 0:
		var mult = GameManager.get_building_multiplier(bld_id)
		if data.pc_per_cycle > 0.0:
			refs.output_lbl.text = "+%s PC/cycle" % GameManager.fmt(data.pc_per_cycle * count * mult)
		elif data.ds_per_cycle > 0.0:
			refs.output_lbl.text = "+%s DS/cycle" % GameManager.fmt(data.ds_per_cycle * count * mult)
		else:
			refs.output_lbl.text = ""
	else:
		refs.output_lbl.text = "Buy one to start"
		refs.output_lbl.add_theme_color_override("font_color", Color("#333344"))

	refs.collect_btn.visible = is_ready and not has_mgr
	refs.auto_lbl.visible = has_mgr

	var cost1 = GameManager.get_building_cost(bld_id, 1)
	var cost10 = GameManager.get_building_cost(bld_id, 10)
	var max_q = GameManager.get_max_affordable(bld_id)
	var costmax = GameManager.get_building_cost(bld_id, max(max_q, 1))
	var can1 = GameManager.power_crystals >= cost1
	var can10 = GameManager.power_crystals >= cost10
	var canmax = max_q > 0

	refs.buy1.text = "x1\n%s" % GameManager.fmt(cost1)
	refs.buy10.text = "x10\n%s" % GameManager.fmt(cost10)
	refs.buymax.text = "xMAX (%d)\n%s" % [max_q, GameManager.fmt(costmax)] if canmax else "xMAX\nNeed PC"
	refs.buy1.modulate = Color.WHITE if can1 else Color(0.4, 0.4, 0.4)
	refs.buy10.modulate = Color.WHITE if can10 else Color(0.4, 0.4, 0.4)
	refs.buymax.modulate = Color.WHITE if canmax else Color(0.4, 0.4, 0.4)
	refs.buy1.disabled = not can1
	refs.buy10.disabled = not can10
	refs.buymax.disabled = not canmax

	if has_mgr:
		refs.mgr_btn.visible = false
		refs.mgr_lbl.text = "Manager: AUTO ✓"
		refs.mgr_lbl.add_theme_color_override("font_color", Color("#44FF88"))
	else:
		refs.mgr_btn.visible = true
		refs.mgr_lbl.text = "Manager:"
		refs.mgr_lbl.add_theme_color_override("font_color", Color("#444455"))
		var mgr_cost = GameManager.get_manager_cost(bld_id)
		var can_mgr = GameManager.power_crystals >= mgr_cost
		refs.mgr_btn.text = "Hire Manager %s PC" % GameManager.fmt(mgr_cost)
		refs.mgr_btn.disabled = not can_mgr
		refs.mgr_btn.modulate = Color.WHITE if can_mgr else Color(0.4, 0.4, 0.4)

	var claimed = GameManager.milestones_claimed.get(bld_id, [])
	for i in range(refs.ms_dots.size()):
		var dot_ref = refs.ms_dots[i]
		var is_claimed = i < claimed.size() and claimed[i]
		dot_ref.dot_style.bg_color = data.color if is_claimed else Color("#1A1A2E")
		dot_ref.lbl.add_theme_color_override("font_color", data.color.lightened(0.2) if is_claimed else Color("#252535"))

func _refresh_header() -> void:
	if factory_pc_label != null:
		factory_pc_label.text = "PC %s" % GameManager.fmt(GameManager.power_crystals)
	if ds_gt_label == null: return
	var parts = []
	if GameManager.data_shards > 0.0:
		parts.append("DS %s" % GameManager.fmt(GameManager.data_shards))
	if GameManager.grid_tokens > 0:
		parts.append("GT %d" % GameManager.grid_tokens)
	ds_gt_label.text = " ".join(parts)
	var rate = GameManager.get_total_pc_rate()
	rate_label.text = "+%s PC/s" % GameManager.fmt(rate)
	if GameManager.surge_timer > 0.0:
		surge_label.visible = true
		surge_label.text = "SURGE x%.0f | %.0fs remaining" % [GameManager.surge_multiplier, GameManager.surge_timer]
	else:
		surge_label.visible = false

# ── Buy Actions ───────────────────────────
func _on_buy(bld_id: String, qty: int) -> void:
	if GameManager.buy_building(bld_id, qty):
		_refresh_row(bld_id)

func _on_buy_max(bld_id: String) -> void:
	var qty = GameManager.get_max_affordable(bld_id)
	if qty > 0:
		_on_buy(bld_id, qty)

func _on_buy_manager(bld_id: String) -> void:
	if GameManager.buy_manager(bld_id):
		_refresh_row(bld_id)

# ── Upgrades Screen ────────────────────────
func _build_upgrades_screen() -> void:
	upgrades_screen = Control.new()
	upgrades_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrades_screen.visible = false
	$UI.add_child(upgrades_screen)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#07070F")
	upgrades_screen.add_child(bg)

	var title = Label.new()
	title.text = "PUZZLE UPGRADES"
	title.position = Vector2(0, 158)
	title.size = Vector2(1080, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	upgrades_screen.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Spend Power Crystals to enhance your chains"
	subtitle.position = Vector2(0, 228)
	subtitle.size = Vector2(1080, 48)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color("#333344"))
	upgrades_screen.add_child(subtitle)

	var list = VBoxContainer.new()
	list.position = Vector2(40, 290)
	list.size = Vector2(1000, 1460)
	list.add_theme_constant_override("separation", 16)
	upgrades_screen.add_child(list)

	_upgrade_buttons.clear()
	for upg_id in GameManager.UPGRADE_DATA:
		var data = GameManager.UPGRADE_DATA[upg_id]
		var row = PanelContainer.new()
		row.custom_minimum_size = Vector2(1000, 140)
		list.add_child(row)
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		row.add_child(hbox)
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)
		var name_lbl = Label.new()
		name_lbl.text = data.display_name
		name_lbl.add_theme_font_size_override("font_size", 40)
		vbox.add_child(name_lbl)
		var desc_lbl = Label.new()
		desc_lbl.text = data.description
		desc_lbl.add_theme_font_size_override("font_size", 28)
		desc_lbl.add_theme_color_override("font_color", Color("#555566"))
		vbox.add_child(desc_lbl)
		var rvbox = VBoxContainer.new()
		rvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(rvbox)
		var level_lbl = Label.new()
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_lbl.add_theme_font_size_override("font_size", 32)
		rvbox.add_child(level_lbl)
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(280, 74)
		buy_btn.add_theme_font_size_override("font_size", 30)
		var uid = upg_id
		buy_btn.pressed.connect(func(): GameManager.purchase_upgrade(uid))
		rvbox.add_child(buy_btn)
		_upgrade_buttons[upg_id] = {"buy_btn": buy_btn, "level_lbl": level_lbl}

func _refresh_upgrades() -> void:
	for upg_id in _upgrade_buttons:
		var refs = _upgrade_buttons[upg_id]
		var level = GameManager.upgrade_levels[upg_id]
		var maxed = GameManager.is_upgrade_maxed(upg_id)
		var cost = GameManager.get_upgrade_cost(upg_id)
		var can_buy = GameManager.can_afford_upgrade(upg_id)
		var max_lvl = GameManager.UPGRADE_DATA[upg_id].max_level
		refs.level_lbl.text = ("Lv.%d / %d" % [level, max_lvl]) if max_lvl != -1 else ("Lv.%d" % level)
		if maxed:
			refs.buy_btn.text = "MAXED"
			refs.buy_btn.disabled = true
			refs.buy_btn.modulate = Color(0.4, 0.8, 0.4)
		else:
			refs.buy_btn.text = "BUY %s PC" % GameManager.fmt(cost)
			refs.buy_btn.disabled = not can_buy
			refs.buy_btn.modulate = Color.WHITE if can_buy else Color(0.4, 0.4, 0.4)

# ── Resources Bar ─────────────────────────
func _refresh_resources() -> void:
	re_label.text = "RE %s" % GameManager.fmt(GameManager.raw_energy)
	pc_label.text = "PC %s" % GameManager.fmt(GameManager.power_crystals)
	if current_screen == "factory":
		_refresh_header()
	elif current_screen == "upgrades":
		_refresh_upgrades()

# ── Signals ───────────────────────────────
func _on_resources_changed() -> void:
	_refresh_resources()
	if current_screen == "factory":
		_refresh_all_rows()
		_refresh_header()
	
	# Neon Cyber Feedback - High Raw Energy
	if GameManager.raw_energy > GameManager.RAW_ENERGY_CAP * 0.8:
		# TODO: Add visual glow / particles on factory screen later
		pass

func _on_building_ready(bld_id: String) -> void:
	if current_screen == "factory" and _row_refs.has(bld_id):
		_refresh_row(bld_id)

func _on_building_collected(bld_id: String, pc: float, ds: float) -> void:
	if current_screen == "factory" and _row_refs.has(bld_id):
		_refresh_row(bld_id)
	var label = Label.new()
	if pc > 0.0:
		label.text = "+%s PC" % GameManager.fmt(pc)
		label.add_theme_color_override("font_color", Color("#44FF88"))
	elif ds > 0.0:
		label.text = "+%s DS" % GameManager.fmt(ds)
		label.add_theme_color_override("font_color", Color("#AA44FF"))
	label.add_theme_font_size_override("font_size", 52)
	label.position = Vector2(300, 860)
	label.z_index = 90
	$UI.add_child(label)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", 760.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	await tw.finished
	label.queue_free()

func _on_milestone_reached(bld_id: String, milestone_index: int) -> void:
	var data = GameManager.BUILDING_DATA[bld_id]
	var ms = data.milestones[milestone_index]
	var note = Label.new()
	note.text = "MILESTONE %s x%d — Output x2!" % [data.display_name, ms]
	note.add_theme_font_size_override("font_size", 38)
	note.add_theme_color_override("font_color", data.color.lightened(0.3))
	note.position = Vector2(40, 820)
	note.z_index = 90
	$UI.add_child(note)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(note, "position:y", 720.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(note, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	await tw.finished
	note.queue_free()
	if current_screen == "factory" and _row_refs.has(bld_id):
		_refresh_row(bld_id)

func _on_upgrades_changed() -> void:
	if current_screen == "upgrades":
		_refresh_upgrades()

func _on_surge_triggered(multiplier: float, _dur: float) -> void:
	_show_surge_notify(multiplier)
	if current_screen == "factory":
		_refresh_header()

func _on_surge_ended() -> void:
	if current_screen == "factory":
		_refresh_header()

func _on_gt_earned(amount: int) -> void:
	var label = Label.new()
	label.text = "+%d GT" % amount
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color("#FFDD33"))
	label.position = Vector2(600, 860)
	label.z_index = 90
	$UI.add_child(label)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", 760.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	await tw.finished
	label.queue_free()

class_name ItemTooltipBuilder

# BBCode quality colors
const QUALITY_HEX: Dictionary = {
	"normale":     "#c8c8c8",
	"magico":      "#4d8cff",
	"raro":        "#ffe626",
	"epico":       "#bf4cff",
	"leggendario": "#ff8c1a",
	"unico":       "#ffd91a",
}

const STAT_LABEL_KEYS: Dictionary = {
	"attack_bonus":  "STAT_ATTACK_BONUS",
	"defense_bonus": "STAT_DEFENSE_BONUS",
	"hp_bonus":      "STAT_HP_BONUS",
	"mp_bonus":      "STAT_MP_BONUS",
	"stamina_bonus": "STAT_STAMINA_BONUS",
	"speed_bonus":   "STAT_SPEED_BONUS",
	"crit_bonus":    "STAT_CRIT_BONUS",
}

const SEP: String = "[color=#333355]────────────────[/color]"


# New-format item (has instance_id / base_id).
static func build_instance(entry: Dictionary, qty: int = -1) -> String:
	return build_instance_compare(entry, qty, {})


# Same as build_instance but appends a stat diff block vs compare_stats.
static func build_instance_compare(entry: Dictionary, qty: int, compare_stats: Dictionary) -> String:
	var base_id: String  = str(entry.get("base_id", ""))
	var base: Dictionary = ItemDB.get_item(base_id)
	var quality: String  = str(entry.get("quality", "normale"))
	var gender: String   = str(base.get("gender", "m"))
	var hex: String      = QUALITY_HEX.get(quality, "#c8c8c8")
	var identified: bool = bool(entry.get("identified", false))
	var lines: Array[String] = []

	# Name
	if identified:
		lines.append("[color=%s][b]%s[/b][/color]" % [hex,
				str(entry.get("name", ItemDB.get_display_name(base_id)))])
	else:
		lines.append("[color=%s][b]%s[/b][/color]" % [hex,
				str(entry.get("name_unid", "???"))])

	# Quality + slot
	var slot_disp: String = _slot_display_name(str(base.get("slot", "")))
	if slot_disp != "":
		lines.append("[color=%s]%s[/color]  [color=#8888aa]%s[/color]" % [hex, quality.capitalize(), slot_disp])
	else:
		lines.append("[color=%s]%s[/color]" % [hex, quality.capitalize()])

	if not identified:
		lines.append("[i][color=#777799]%s[/color][/i]" % LocaleManager.t("ITEM_TIP_NOT_IDENTIFIED"))
		return "\n".join(lines)

	# Description
	var desc: String = ItemDB.get_display_description(base_id)
	if desc != "":
		lines.append("[i][color=#aaaacc]%s[/color][/i]" % desc)

	lines.append(SEP)

	var affixes: Array   = entry.get("affixes", []) as Array
	var is_leg: bool     = quality in ["leggendario", "unico"]

	if is_leg:
		# Legendary / unique: scale with level, show resolved total
		var total_stats: Dictionary = ItemGenerator.resolve_stats(entry, GameState.level)
		_append_stat_block(lines, total_stats, hex, LocaleManager.t("TOOLTIP_SECTION_STATS"))
		if quality == "leggendario":
			lines.append("[color=#888899][i]%s[/i][/color]" % LocaleManager.t("TOOLTIP_SCALES_WITH_LEVEL"))
		# Show fixed affixes for uniques
		if quality == "unico" and not affixes.is_empty():
			lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_SECTION_FIXED_AFFIXES"))
			for aid: Variant in affixes:
				var affix: Dictionary = ItemAffixDB.get_affix(str(aid))
				if affix.is_empty():
					continue
				var aname: String = ItemAffixDB.get_display_name(str(aid), gender)
				lines.append("  [color=%s]%s[/color]" % [hex, aname])
	elif not affixes.is_empty():
		# Magic / rare / epic: show base + per-affix breakdown + total
		var base_stats: Dictionary = base.get("base_stats", {}) as Dictionary
		_append_stat_block(lines, base_stats, "#888899", LocaleManager.t("TOOLTIP_SECTION_BASE"))

		lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_SECTION_AFFIXES"))
		for aid: Variant in affixes:
			var affix: Dictionary = ItemAffixDB.get_affix(str(aid))
			if affix.is_empty():
				continue
			var aname: String = ItemAffixDB.get_display_name(str(aid), gender)
			var bonuses: Dictionary = affix.get("bonuses", {}) as Dictionary
			var parts: Array[String] = []
			for bk: Variant in bonuses:
				var bv: int = int(bonuses[bk])
				if bv != 0:
					parts.append("%s %+d" % [_stat_label(str(bk)), bv])
			if not parts.is_empty():
				lines.append("  [color=%s]%s:[/color] [color=#ddddff]%s[/color]" % [hex, aname, ", ".join(parts)])

		lines.append(SEP)
		var baked: Dictionary = entry.get("baked_stats", {}) as Dictionary
		_append_stat_block(lines, baked, hex, LocaleManager.t("TOOLTIP_SECTION_TOTAL"))
	else:
		# Normal quality — no affixes
		var baked: Dictionary = entry.get("baked_stats", base.get("base_stats", {})) as Dictionary
		_append_stat_block(lines, baked, "#ccccdd", LocaleManager.t("TOOLTIP_SECTION_STATS"))

	# Value
	var base_value: int = int(base.get("base_value", base.get("value", 0)))
	if base_value > 0:
		var final_val: int = roundi(float(base_value) * _quality_mult(quality))
		lines.append("[color=#888899]%s[/color][color=#ffd700]%d %s[/color]" % [
			LocaleManager.t("TOOLTIP_VALUE"), final_val, LocaleManager.t("CURRENCY_GOLD")])

	if qty > 0:
		lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_QUANTITY", {"n": qty}))

	# Comparison block — only shown if identified and a compare target is provided
	if identified and not compare_stats.is_empty():
		var item_stats: Dictionary = ItemGenerator.resolve_stats(entry, GameState.level)
		var all_keys: Dictionary = {}
		for k: Variant in item_stats:  all_keys[k] = true
		for k: Variant in compare_stats: all_keys[k] = true
		var diff_lines: Array[String] = []
		for k: Variant in all_keys:
			var a: int = int(item_stats.get(k, 0))
			var b: int = int(compare_stats.get(k, 0))
			var d: int = a - b
			if d == 0:
				continue
			var col: String = "#88ff88" if d > 0 else "#ff8888"
			diff_lines.append("  [color=%s]%s: %+d[/color]" % [col, _stat_label(str(k)), d])
		if not diff_lines.is_empty():
			lines.append(SEP)
			lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_VS_EQUIPPED"))
			lines.append_array(diff_lines)

	return "\n".join(lines)


# Old-format item (from items.json, no instance_id).
static func build_legacy(item_id: String, data: Dictionary, qty: int = -1) -> String:
	var lines: Array[String] = []
	var item_type: String = str(data.get("type", data.get("item_category", "")))

	# Name
	lines.append("[b]%s[/b]" % ItemDB.get_display_name(item_id))

	# Type + slot
	var type_disp: String  = _type_label(item_type)
	var slot_disp: String  = _slot_display_name(str(data.get("slot", "")))
	if slot_disp != "":
		lines.append("[color=#8888aa]%s  %s[/color]" % [type_disp, slot_disp])
	else:
		lines.append("[color=#8888aa]%s[/color]" % type_disp)

	# Description
	var desc: String = ItemDB.get_display_description(item_id)
	if desc != "":
		lines.append("[i][color=#aaaacc]%s[/color][/i]" % desc)

	# Stats
	var atk: int   = int(data.get("attack_bonus", 0))
	var def_b: int = int(data.get("defense_bonus", 0))
	var eff: Dictionary = data.get("effect", {}) as Dictionary
	var has_stats: bool = atk != 0 or def_b != 0 or not eff.is_empty()
	if has_stats:
		lines.append(SEP)
	if atk > 0:
		lines.append("  [color=#88ff88]%s[/color]" % LocaleManager.t("TOOLTIP_ATTACK_PLUS", {"value": atk}))
	elif atk < 0:
		lines.append("  [color=#ff8888]%s[/color]" % LocaleManager.t("TOOLTIP_ATTACK_MINUS", {"value": atk}))
	if def_b > 0:
		lines.append("  [color=#88ccff]%s[/color]" % LocaleManager.t("TOOLTIP_DEFENSE_PLUS", {"value": def_b}))
	elif def_b < 0:
		lines.append("  [color=#ff8888]%s[/color]" % LocaleManager.t("TOOLTIP_DEFENSE_MINUS", {"value": def_b}))
	if eff.has("heal"):
		lines.append("  [color=#88ff88]%s[/color]" % LocaleManager.t("TOOLTIP_HEAL", {"value": int(eff["heal"])}))

	# Value
	var value: int = int(data.get("value", data.get("base_value", 0)))
	if value > 0:
		lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_VALUE_GOLD", {"amount": value}))

	if qty > 0:
		lines.append("[color=#888899]%s[/color]" % LocaleManager.t("TOOLTIP_QUANTITY", {"n": qty}))

	return "\n".join(lines)


static func build_gold(amount: int) -> String:
	return "[color=#ffd700][b]%s[/b][/color]\n[color=#ffd700]%s[/color]" % [
		LocaleManager.t("TOOLTIP_GOLD_NAME"),
		LocaleManager.t("CURRENCY_GOLD_AMOUNT", {"amount": amount})]


static func build_empty_slot(slot_name: String) -> String:
	return "[color=#555577][b]%s[/b][/color]\n[color=#444466]%s[/color]" % [
		slot_name, LocaleManager.t("TOOLTIP_EMPTY_SLOT")]


# ── private helpers ───────────────────────────────────────────────────────────

static func _append_stat_block(lines: Array[String], stats: Dictionary,
		color_hex: String, header: String) -> void:
	var has_any: bool = false
	for k: Variant in stats:
		if int(stats[k]) != 0:
			has_any = true
			break
	if not has_any:
		return
	lines.append("[color=#888899]%s[/color]" % header)
	for k: Variant in stats:
		var val: int = int(stats[k])
		if val == 0:
			continue
		var label: String = _stat_label(str(k))
		if val > 0:
			lines.append("  [color=%s]%s: +%d[/color]" % [color_hex, label, val])
		else:
			lines.append("  [color=#ff8888]%s: %d[/color]" % [label, val])


static func _stat_label(key: String) -> String:
	var lk: String = STAT_LABEL_KEYS.get(key, "")
	if lk != "":
		return LocaleManager.t(lk)
	return _stat_fallback(key)


static func _stat_fallback(key: String) -> String:
	return key.replace("_bonus", "").replace("_", " ").capitalize()


static func _slot_display_name(slot: String) -> String:
	if slot == "":
		return ""
	return LocaleManager.t_or("SLOT_" + slot.to_upper(), "")


static func _type_label(item_type: String) -> String:
	match item_type:
		"equipment", "weapon", "armor", "accessory":
			return LocaleManager.t("ITEM_TYPE_EQUIPMENT")
		"consumable":
			return LocaleManager.t("ITEM_TYPE_CONSUMABLE")
		"key_item":
			return LocaleManager.t("ITEM_TYPE_KEY_ITEM")
		"class_license":
			return LocaleManager.t("ITEM_TYPE_CLASS_LICENSE")
		_:
			return item_type.capitalize() if item_type != "" else LocaleManager.t("ITEM_TYPE_GENERIC")


static func _quality_mult(quality: String) -> float:
	match quality:
		"normale":     return 1.0
		"magico":      return 2.5
		"raro":        return 5.0
		"epico":       return 10.0
		"leggendario": return 25.0
		"unico":       return 20.0
		_:             return 1.0

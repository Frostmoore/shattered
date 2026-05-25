extends Node

# context keys used by get_price_multiplier:
#   base_faction    : String  — primary faction of the NPC vendor
#   transaction_type: String  — "buy" | "sell"
#   item_id         : String  — (optional) item being traded
#   location_id     : String  — (optional) current map id

# ── Tax configuration ─────────────────────────────────────────────────────────

# Gold deducted per save-point use, per joined faction.
# collegio_cartografi is absent: their tax is per-action (on deposit).
const PERIODIC_TAX: Dictionary = {
	"corporazione_camere":    25,
	"cacciatori_rogna":       10,
	"compagnia_ponti":        15,   # only when post stations exist
	"corrieri_sigillo":       10,
	"congregazione_officine": 10,
	"tavola_senza_nome":      20,
}

const CARTOGRAFI_DEPOSIT_TAX_RATE: float = 0.20   # 20% of deposit reward

const TAX_DEBT_LATE:            int = 1   # first missed payment → warning
const TAX_DEBT_EXPEL_THRESHOLD: int = 2   # second missed payment → expulsion


# ── Price multiplier ──────────────────────────────────────────────────────────

func get_price_multiplier(context: Dictionary) -> float:
	var base_faction: String = str(context.get("base_faction", ""))
	var transaction:  String = str(context.get("transaction_type", "buy"))
	if base_faction == "":
		return 1.0

	var mult: float = 1.0

	# Passive flag discounts (membership-based)
	if transaction == "buy":
		if base_faction in ["congregazione_officine", "sorelle_sale"]:
			var disc: int = int(GameState.faction_passive_flags.get("officine_potion_discount", 0))
			if disc > 0:
				mult *= (100.0 - float(disc)) / 100.0

	# Rep-state adjustments
	var state: String = FactionReputation.get_state_id(base_faction)
	match state:
		"trusted":     mult *= 0.90
		"allied":      mult *= 0.95
		"hostile":     mult *= 1.15
		"enemy_sworn": mult *= 1.25

	# Recognition sign bonus: member wearing sign → -5% on buys
	if transaction == "buy" and FactionMembership.is_member(base_faction):
		if FactionMembership.wears_recognition_sign(base_faction):
			mult *= 0.95

	return mult


# ── Periodic taxes (called on save point) ────────────────────────────────────

func on_rest() -> void:
	var joined: Array = GameState.character_faction_membership.keys().duplicate()
	var total_paid: int = 0

	for fid_var: Variant in joined:
		var fid: String = str(fid_var)
		if not FactionMembership.is_member(fid):
			continue
		var amount: int = _get_periodic_tax(fid)
		if amount <= 0:
			continue
		if int(GameState.player_stats.get("gold", 0)) >= amount:
			GameState.modify_gold(-amount)
			_reset_debt(fid)
			EventBus.tax_collected.emit(fid, amount)
			total_paid += amount
		else:
			_add_debt(fid)

	if total_paid > 0:
		EventBus.notification_shown.emit(Notification.faction_action(
			LocaleManager.t_or("NOTIF_TAX_PAID_TOTAL",
				"Tasse di gilda: -{amount} monete.", {"amount": str(total_paid)})))


func _get_periodic_tax(faction_id: String) -> int:
	if not PERIODIC_TAX.has(faction_id):
		return 0
	if faction_id == "compagnia_ponti":
		if not WorldState.has_any_post_station():
			return 0
	return int(PERIODIC_TAX[faction_id])


# ── Per-action tax: deposit mappa (cartografi) ────────────────────────────────

func collect_deposit_tax(base_reward: int) -> void:
	var fid: String = "collegio_cartografi"
	if not FactionMembership.is_member(fid):
		return
	var tax: int = roundi(float(base_reward) * CARTOGRAFI_DEPOSIT_TAX_RATE)
	if tax <= 0:
		return
	if int(GameState.player_stats.get("gold", 0)) >= tax:
		GameState.modify_gold(-tax)
		_reset_debt(fid)
		EventBus.tax_collected.emit(fid, tax)
		EventBus.notification_shown.emit(Notification.faction_action(
			LocaleManager.t_or("NOTIF_TAX_CARTOGRAFI",
				"Cartografi: -{amount} monete (certificazione mappa).", {"amount": str(tax)})))
	else:
		_add_debt(fid)


# ── Tax debt management ───────────────────────────────────────────────────────

func _add_debt(faction_id: String) -> void:
	var entry: Variant = GameState.character_faction_membership.get(faction_id, null)
	if not entry is Dictionary:
		return
	var debt: int = int((entry as Dictionary).get("tax_debt", 0)) + 1
	(entry as Dictionary)["tax_debt"] = debt

	var fname: String = FactionDisplay.get_display_name(faction_id)
	if debt >= TAX_DEBT_EXPEL_THRESHOLD:
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("NOTIF_TAX_EXPELLED",
				"{faction}: espulso per mancato pagamento delle tasse.", {"faction": fname})))
		EventBus.tax_expelled.emit(faction_id)
		FactionMembership.leave_faction(faction_id)
	else:
		EventBus.notification_shown.emit(Notification.warning(
			LocaleManager.t_or("NOTIF_TAX_WARNING",
				"{faction}: tassa non pagata! Oro insufficiente — espulsione al prossimo ritardo.", {"faction": fname})))
		EventBus.tax_warning.emit(faction_id)


func _reset_debt(faction_id: String) -> void:
	var entry: Variant = GameState.character_faction_membership.get(faction_id, null)
	if entry is Dictionary:
		(entry as Dictionary)["tax_debt"] = 0


func has_tax_restrictions(faction_id: String) -> bool:
	var entry: Variant = GameState.character_faction_membership.get(faction_id, null)
	if not entry is Dictionary:
		return false
	return int((entry as Dictionary).get("tax_debt", 0)) >= TAX_DEBT_LATE


# ── Legacy stubs (still exposed for external callers) ────────────────────────

func calculate_tax_due(faction_id: String) -> int:
	return _get_periodic_tax(faction_id)


func process_tax_payment(faction_id: String) -> void:
	var amount: int = _get_periodic_tax(faction_id)
	if amount > 0:
		_add_debt(faction_id)

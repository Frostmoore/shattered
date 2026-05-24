@tool
extends EditorScript

const VALIDATOR_PATHS := [
	"res://scripts/tools/validators/validate_items.gd",
	"res://scripts/tools/validators/validate_affixes.gd",
	"res://scripts/tools/validators/validate_loot_tables.gd",
	"res://scripts/tools/validators/validate_classes.gd",
]

func _run() -> void:
	var total_errors: int = 0
	var total_warnings: int = 0
	for path in VALIDATOR_PATHS:
		var v: RefCounted = load(path).new()
		var r: Dictionary = v.call("run")
		_print_result(r)
		total_errors   += (r["errors"]   as Array).size()
		total_warnings += (r["warnings"] as Array).size()
	print("\n══════════════════════════════")
	print("TOTALE: %d errori, %d warning" % [total_errors, total_warnings])
	if total_errors == 0 and total_warnings == 0:
		print("✓ Tutti i dati sono validi.")
	print("══════════════════════════════")


func _print_result(r: Dictionary) -> void:
	var errors:   Array = r["errors"]   as Array
	var warnings: Array = r["warnings"] as Array
	print("\n=== %s — %d %s ===" % [r["title"], r["checked"], r.get("unit", "item")])
	if errors.is_empty() and warnings.is_empty():
		print("[OK] Nessun problema trovato.")
		return
	for e in errors:
		print("[ERR]  %s" % e)
	for w in warnings:
		print("[WARN] %s" % w)

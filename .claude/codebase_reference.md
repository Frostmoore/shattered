# Shattered — Codebase Reference

Godot 4.4 · GDScript · roguelike ASCII turn-based · CELL = 16 px

---

## Autoload / Singleton

| Nome | File | Ruolo |
|------|------|-------|
| `LocaleManager` | `scripts/core/LocaleManager.gd` | i18n runtime: carica CSV da `locales/`; `t(key, params?)`, `t_or(key, fallback, params?)` |
| `GameState` | `scripts/core/GameState.gd` | Stato globale del run (livello, stats, mappa corrente, inventario, `character_faction_rep`, `character_faction_membership`, `faction_passive_flags`, `known_faction_members`). Campo tempo: `total_minutes: int = 480`; proprietà derivata `world_time` (`total_minutes % 1440`). |
| `WorldState` | `scripts/core/WorldState.gd` | Stato world-persistent fazioni (post station, safe houses, dungeon maps, servizi, village changes, `dungeon_archive`). Serializzato in `world.json` via `WorldSaveManager`. API completa: vedi sezione WorldState sotto. |
| `FactionActionsService` | `scripts/core/FactionActionsService.gd` | Azioni fazione world-persistent: `try_deposit_map()`, `try_build_post_station()`, `try_open_ambulatorio()`, `try_reduce_bounty_tsn()` (chiama `CrimeSystem.clear_crime(current_city_id)`). Trigger: tasti F5/F6/F7 + NPC `faction_action_id`. |
| `CrimeSystem` | `scripts/core/CrimeSystem.gd` | Autoload. Gestisce crimini nelle città. `register_crime(city_id)`, `arrest_player(city_id)`, `clear_crime(city_id)`, `is_crime_active(city_id)`, `has_witnesses(origin)`, `track_attacked_npc(npc)`, `get_criminal_record()`, `spawn_guards_debug(count)`, `apply_post_crime_rep_on_flee()`, `initialize_for_new_game()`. Costanti: `CRIME_FINE_PCT=0.25`, `CRIME_GUARD_COUNT=6`, `CRIME_GUARD_WAVE_TURNS=8`, `CRIME_GUARD_WAVE_SIZE=3`, `NPC_VIEW_RANGE=30`, `CRIME_NPC_REP_PENALTY=-50`, `CRIME_GUARD_MIN_HP=1`. |
| `FactionRegistry` | `scripts/core/FactionRegistry.gd` | Scan ricorsivo `data/factions/`; `get_faction(id)`, `get_all_factions()`, `get_factions_by_type/tier/tree()`, `get_relation(from,to)`, `are_enemies(a,b)`, `get_faction_children(parent)`, `get_siblings(id)` |
| `FactionReputation` | `scripts/core/FactionReputation.gd` | `get_rep(id)`, `set_rep(id,v)` (emette `faction_rep_changed`, `faction_state_changed`, `faction_supporter_gained/lost` + Notification al cambio soglia), `add_rep(id,delta,reason,propagate)` — gerarchica 10% (parent+figli diretti), laterale 30%×sign via matrice relazioni (soglia \|rel\|≥20), no cascade, delta<1 ignorato, log se `DEBUG_PROPAGATION`; `get_state_id(id)` → 6 stati |
| `FactionMembership` | `scripts/core/FactionMembership.gd` | `join_faction(id)` (chiama `FactionEffects.apply_join_passive()`), `leave_faction(id)` (-20 rep, chiama `remove_join_passive()`), `get_rank(id)`, `advance_rank(id)` (richiama passive), `is_member(id)`, `is_supporter(id)` (derivato), `wears_recognition_sign(id)` (controlla `recognition_item_id`/slot equipaggiato), `reapply_all_passives()` (chiamata al load) |
| `FactionDisplay` | `scripts/core/FactionDisplay.gd` | Helper i18n per fazioni: `get_display_name/desc/state/rank/passive_name/passive_desc/crime()` via `LocaleManager.t_or()` |
| `FactionEffects` | `scripts/core/FactionEffects.gd` | `apply_join_passive(id)` / `remove_join_passive(id)` — dispatch per 7 fazioni; `get_xp_multiplier(context)` — bonus XP Corporazione; `get_gold_multiplier(context)` — +25% oro Corrieri; `get_attack_mult(defender)` — moltiplicatore ATK Cacciatori; `has_active_passive(id)` — legge `faction_passive_flags` |
| `FactionEconomy` | `scripts/core/FactionEconomy.gd` | `get_price_multiplier(context)` — discount/rep/sign logic. `on_rest()` — deducte tasse periodiche per ogni fazione joined (chiamata da `Player._use_save_point()` prima del save). `collect_deposit_tax(base_reward)` — 20% sul reward deposito cartografi. `has_tax_restrictions(faction_id) -> bool` — true se `tax_debt >= 1`. Tasse per-fazione: camere 25g, rogna 10g, cartografi 20% deposito, ponti 15g (solo con stazioni), corrieri 10g, officine 10g, tavola 20g. |
| `TimeManager` | `scripts/core/TimeManager.gd` | Tempo di gioco. `advance(min)` — avanza `GameState.total_minutes`, emette i 4 segnali time. `get_slot()` → `"alba/mattina/pomeriggio/sera/notte"`. `format_time()` / `format_date()` / `format_date_from(min)` / `format_time_from(min)` — tutte via `LocaleManager.t()`. `get_action_cost(map_type, action_int)`. `get_vision_modifier(map_type)`. Registrato **dopo** `EventBus` e **prima** di `WorldManager`. |
| `DiseaseRegistry` | `scripts/core/DiseaseRegistry.gd` | Carica tutti i `data/diseases/*.json` in `_ready()` via `DirAccess`. `get_def(id) → Dictionary` (empty dict se non trovato). `get_all_defs() → Array`. 32 malattie definite in `data/diseases/`. |
| `NeedsManager` | `scripts/core/NeedsManager.gd` | Bisogni sopravvivenza (FASE 1-5). `tick(minutes, ctx)` — avanzamento bisogni, segmentato in passi ≤60 min. `consume(changes)` — modifiche istantanee. `rest(type)` — "save_point" (exh −30), "inn" (exh=0 temp=0), "camp" (exh −50 temp=0); chiama `_check_rest_cures(type)`. `add_disease(id)` / `cure_disease(id)` / `cure_all_diseases()` / `cure_diseases_matching_item(item_id)` (controlla cure_triggers item_use+item_tag) / `rebuild_modifiers()`. Cure automatiche: `_check_time_cure_triggers` (accumula `_cure_time_acc`), `_check_need_cure_triggers` (need_above), `_check_rest_cures` (rest_type), `_check_natural_recovery` (riduce stage_index, accumula `_nat_recovery_acc`). |
| `WorldManager` | `scripts/core/WorldManager.gd` | Mappa attiva, cambio mappa; `change_map()` aggiorna `GameState.current_location_faction_id` dalla signoria + `current_city_id`; applica flee penalty (`CrimeSystem.apply_post_crime_rep_on_flee()`) quando si esce da una città con crimine attivo; spawna guardie di pattuglia al rientro |
| `LocationRegistry` | `scripts/world/LocationRegistry.gd` | Registro stati per-mappa (fog, morti, porte, cadaveri) |
| `SaveManager` | `scripts/core/SaveManager.gd` | Entry point save/load; serializza `faction_rep`, `faction_membership`, `known_faction_members` nel save personaggio |
| `WorldSaveManager` | `scripts/core/WorldSaveManager.gd` | Serializza LocationRegistry + metadati mondo + `WorldState` in `world.json`. Traccia `character_timestamps` (dict `char_name → total_minutes`) nel meta per la continuità temporale multi-personaggio. |
| `TurnManager` | `scripts/core/TurnManager.gd` | Gestione turni giocatore/nemici |
| `CombatManager` | `scripts/combat/CombatManager.gd` | Attacchi, calcolo hit, FloatingText. Gate NPC attacks: richiede `amuleto_del_sangue` equipaggiato. Dopo colpo non-cancelled su player da nemico: `_check_disease_on_hit(attacker)` — legge `disease_on_hit` + `disease_on_hit_chance` (default 0.30) dal JSON nemico tramite `EnemyRegistry`, chiama `NeedsManager.add_disease()` se randf() < chance. |
| `DamagePipeline` | `scripts/combat/DamagePipeline.gd` | Catena di modificatori danno, chiama `take_damage()` |
| `EnemyRegistry` | *(autoload)* | Lookup dati nemici da JSON; `get_enemy_data(id)`, `get_display_name(id)` — i JSON nemici hanno ora campo `faction_id` |
| `AffixRegistry` | *(autoload)* | Lookup affissi nemici; `get_affix(id)`, `get_display_prefix(id)` |
| `ClassRegistry` | `scripts/classes/ClassRegistry.gd` | Lookup dati classi da JSON; `get_class_data(id)`, `get_display_name/desc/special_name/special_desc(id)` |
| `EventBus` | `scripts/core/EventBus.gd` | Tutti i signal globali |
| `LevelSystem` | *(autoload)* | XP, level-up; `add_xp(amount, context="")` — context `"quest"` applica moltiplicatore `FactionEffects.get_xp_multiplier()` |
| `QuestManager` | `scripts/dialogue/QuestManager.gd` | Quest attive/completate; reward `join_faction: String` → chiamato PRIMA di xp/gold/items; oro con `FactionEffects.get_gold_multiplier("quest")`; xp con `LevelSystem.add_xp(n, "quest")`; quest senza objectives segna ready/complete subito |
| `BalanceCombat` | `scripts/core/game_balance/BalanceCombat.gd` | Costanti di bilanciamento combattimento |
| `GameBalance` | *(autoload)* | FOV radius, memory alpha, ecc. |
| `ItemDB` | `scripts/items/ItemDB.gd` | Scan ricorsivo `data/items/`; `get_item(id)`, `get_by_type(t)`, `get_by_slot(s)`, `pick_random(cat, lv, min_quality)`, `get_display_name(id)`, `get_display_description(id)` |
| `ItemAffixDB` | `scripts/items/ItemAffixDB.gd` | Scan ricorsivo `data/item_affixes/`; `get_affix(id)`, `get_eligible(item_type, lv, quality)`, `get_display_name(id, gender)` |
| `LootTableDB` | `scripts/items/LootTableDB.gd` | Lazy load `data/loot/`; `get_enemy(class_id, tier, profile)`, `get_chest(class_id, tier)`, `get_ground(class_id, tier)`; fallback `class_id → archetypes/{archetype} → default` |
| `ItemGenerator` | `scripts/items/ItemGenerator.gd` | `drop(base_id, lv, rng, quality_bias)`, `identify(instance, lv)`, `resolve_stats(instance, lv)`, `get_quality_color(q)`, `get_id_threshold(q)` |
| `LootResolver` | `scripts/items/LootResolver.gd` | `resolve(ctx: Dictionary) → Array`; legge `drop_context`, risolve loot table, restituisce array di drop (item instance o `{type:"gold", amount:N}`) |
| `LootScreen` | `scripts/ui/LootScreen.gd` | CanvasLayer layer 80; si apre via `EventBus.loot_screen_open`; griglia con item, tooltip qualità, take-single, take-all, chiudi (Esc); blocca `_can_act` del player |
| `ItemTooltipBuilder` | `scripts/items/ItemTooltipBuilder.gd` | Classe statica. `build_instance(entry, qty)`, `build_instance_compare(entry, qty, compare_stats)`, `build_legacy(item_id, data, qty)`, `build_gold(amount)`, `build_empty_slot(slot_name)` → BBCode string per `RichTextLabel`. |
| `Inventory` | `scripts/items/Inventory.gd` | Autoload. `add_item(id, qty)`, `remove_item(id, qty)`, `has_item(id, qty)`, `add_item_instance(instance)`, `identify_instance(instance_id, lv)`, `use_item(id)` — dispatch su `effect.type`: `"needs"` → `NeedsManager.consume(changes)`, `"disease_cure"` → `cure_disease(id)`, `"disease_cure_by_item"` → `cure_diseases_matching_item(item_id)`; legacy keys (restore_hp/mp/stamina, restore_all, identify) sempre processate (supportano item ibridi) |
| `Equipment` | `scripts/items/Equipment.gd` | Autoload. `equip(item_id) → bool`, `unequip(slot)`, `is_equipped(id) → bool`, `get_equipped_slot(id)`, `get_stats(id)`, `get_base_data(id)`, `get_attack_bonus()`, `get_defense_bonus()` |

---

## Localizzazione (i18n)

### LocaleManager — `scripts/core/LocaleManager.gd`

Autoload. Primo in ordine di caricamento (disponibile quando tutti gli altri autoload inizializzano).

```gdscript
LocaleManager.t(key: String, params: Dictionary = {}) -> String
# Traduce key; usa String.format(params) se params non è vuoto.
# Emette warning in Output se key mancante, restituisce key.

LocaleManager.t_or(key: String, fallback: String, params: Dictionary = {}) -> String
# Come t() ma restituisce fallback senza warning se key mancante.
# Usato nei registry per auto-derivare chiavi senza toccare i JSON.
```

CSV caricati (in ordine):
```
locales/strings_ui.csv         — UI, HUD, menu + UI_FACTIONS_* (FactionScreen) + UI_FACTION_* (action feedback)
locales/strings_notifications.csv — notifiche generali + NOTIF_FACTION_* (stato/sostenitore/accesso) + NOTIF_TAX_* (tasse fazione) + NOTIF_CRIME_* (crimine, arresto, safe house)
locales/strings_data.csv       — tooltip stat, slot display, quality labels
locales/strings_dialogue.csv
locales/strings_classes.csv    — nomi/descrizioni delle 60 classi
locales/strings_items.csv      — nomi item base + affissi item (name_m/name_f)
locales/strings_enemies.csv    — nomi nemici, role/family label, affissi nemici
locales/strings_factions.csv   — nomi/desc fazioni (21 civili + 10 signorie + 8 nemici), stati rep, ranghi joinabili (0-5), passivi, tipi crimine
```

Formato CSV: `keys,it` come header; `#` come prima colonna = commento, riga ignorata.  
Valori con virgole vanno fra doppi apici: `CLASS_CAVALIERE_DESC,"Armatura pesante, disciplina totale."`

### Convenzione chiavi per sistema

| Sistema | Pattern chiave | Helper |
|---------|----------------|--------|
| Nemici — nome | `ENEMY_<ID_UPPER>_NAME` | `EnemyRegistry.get_display_name(id)` |
| Nemici — family | `ENEMY_FAMILY_<FAMILY_UPPER>` | `LocaleManager.t_or(…, raw.capitalize())` |
| Nemici — role | `ENEMY_ROLE_<ROLE_UPPER>` | `LocaleManager.t_or(…, raw.replace("_"," ").capitalize())` |
| Affissi nemici | `ENEMY_AFFIX_<ID_UPPER>_PREFIX` | `AffixRegistry.get_display_prefix(id)` |
| Classi — nome | `CLASS_<ID_UPPER>_NAME` | `ClassRegistry.get_display_name(id)` |
| Classi — desc | `CLASS_<ID_UPPER>_DESC` | `ClassRegistry.get_display_desc(id)` |
| Classi — special name | `CLASS_<ID_UPPER>_SPECIAL_NAME` | `ClassRegistry.get_display_special_name(id)` |
| Classi — special desc | `CLASS_<ID_UPPER>_SPECIAL_DESC` | `ClassRegistry.get_display_special_desc(id)` |
| Item base — nome | `ITEM_<ID_UPPER>_NAME` | `ItemDB.get_display_name(id)` |
| Item base — desc | `ITEM_<ID_UPPER>_DESC` | `ItemDB.get_display_description(id)` |
| Affissi item (masch.) | `ITEM_AFFIX_<ID_UPPER>_M` | `ItemAffixDB.get_display_name(id, "m")` |
| Affissi item (femm.) | `ITEM_AFFIX_<ID_UPPER>_F` | `ItemAffixDB.get_display_name(id, "f")` |
| Fazioni — nome | `FACTION_<ID_UPPER>_NAME` | `FactionDisplay.get_display_name(id)` |
| Fazioni — desc | `FACTION_<ID_UPPER>_DESC` | `FactionDisplay.get_display_desc(id)` |
| Fazioni — stato rep | `FACTION_STATE_<STATE_UPPER>` | `FactionDisplay.get_display_state(id)` — stati: `ENEMY_SWORN` `HOSTILE` `NEUTRAL` `FRIENDLY` `ALLIED` `TRUSTED` |
| Fazioni — rango | `FACTION_<ID_UPPER>_RANK_<n>` | `FactionDisplay.get_display_rank(id, n)` — n 0-indexed (0–5) |
| Passivi joinabili — nome | `PASSIVE_<join_passive_UPPER>_NAME` | `FactionDisplay.get_display_passive_name(id)` |
| Passivi joinabili — desc | `PASSIVE_<join_passive_UPPER>_DESC` | `FactionDisplay.get_display_passive_desc(id)` |
| Tipi crimine | `CRIME_<TYPE_UPPER>` | `FactionDisplay.get_display_crime(type)` |

`<ID_UPPER>` = `id.to_upper()` — gli underscore del campo `id` vengono preservati.  
Esempio: `cacciatore_anime` → `CLASS_CACCIATORE_ANIME_NAME`.

### Pattern registry con t_or

```gdscript
# Ogni registry espone helper che non richiedono modifiche ai JSON:
func get_display_name(id: String) -> String:
    var raw: String = str(_data.get(id, {}).get("name", id))
    return LocaleManager.t_or("PREFIX_" + id.to_upper() + "_NAME", raw)
# Se la chiave locale esiste → usa quella; altrimenti → raw dal JSON (graceful fallback).
```

---

## Sistema Item / Loot

### Schema item base (`data/items/**/*.json`)
```jsonc
{
  "id": "spada_corta", "name": "Spada Corta", "gender": "f", "icon": "/",
  "item_category": "weapon",      // weapon | armor | accessory | consumable | key_item | summon
  "item_type": "spada",           // vedi tabella tassonomia in plan_item_system.md
  "slot": "right_hand",           // slot principale
  "allowed_slots": ["right_hand", "left_hand"],  // solo per pugnale e anelli
  "tier": 1, "min_level": 1, "max_level": 12,
  "base_stats": { "attack_bonus": 3 },
  "scalable": false, "loot_weight": 25
}
```

### Schema item consumabile needs (`data/items/consumables/cibo/*.json`)
```jsonc
{
  "id": "pane_fresco", "name": "Pane Fresco", "gender": "m", "icon": "!",
  "item_category": "consumable", "item_subtype": "cibo",
  "effect": {
    "type": "needs",
    "changes": { "food": 20, "water": 2, "exhaustion": -3 },
    // Campi legacy opzionali (item ibridi come ambrosia):
    "restore_hp": 0, "restore_mp": 0
  },
  "stackable": true, "loot_weight": 18
}
// type: "disease_cure" → "disease_id": "veleno" (cura malattia specifica)
// type: "disease_cure_by_item" → cura malattie compatibili con il tag dell'oggetto (FASE 5)
// tag: ["alcohol"] → usato in futuro per effetti intossicazione
// tag: ["heat_source"] / ["cooling"] → usato in futuro per effetti ambientali
```

### Schema affisso item (`data/item_affixes/**/*.json`)
```jsonc
{
  "id": "affilato", "type": "prefix",
  "name_m": "Affilato", "name_f": "Affilata",   // localizzati via ITEM_AFFIX_AFFILATO_M/F
  "affix_category": "offensive",
  "allowed_item_types": ["spada", "ascia", ...],
  "min_level": 1, "allowed_tiers": ["magico", "raro", "epico"],
  "weight": 25, "bonuses": { "attack_bonus": 2 }
}
```
Nomi visualizzati sempre via `ItemAffixDB.get_display_name(id, gender)` — mai leggere `name_m`/`name_f` direttamente a display.

### drop_context (passato a `LootResolver.resolve()`)
```gdscript
var ctx = {
  "source_type":   "enemy",        # "enemy" | "chest" | "ground"
  "loot_profile":  "humanoid_low", # solo per enemy — corrisponde al file in enemies/
  "chest_variant": "comune",       # solo per chest — chiave in chest.json
  "player_class":  "guerriero",
  "player_level":  12,
  "floor":         2,
}
```

### Struttura loot tables (`data/loot/`)
```
data/loot/
  archetypes/
    martial/tier1/enemies/humanoid_low.json
    martial/tier1/chest.json          # contiene chiavi: comune, ricca, abbondante, boss, segreto
    martial/tier1/ground.json
  default/tier1/…
  {class_id}/tier1/…                  # override specifico per classe
```

### Inventory — formati nel `GameState.inventory`
- Stackabile: `{ "id": "pozione_piccola", "qty": 3 }` — usato da codice legacy e consumabili
- Istanza non identificata: `{ "instance_id": "...", "base_id": "spada_corta", "quality": "magico", "affix_seed": 12345, "identified": false, "name_unid": "??? spada magico" }`
- Istanza identificata: come sopra + `"name": "Spada Corta Affilata"`, `"affixes": ["affilato"]`, `"baked_stats": {"attack_bonus": 5}`
- NOTA: i JSON nuovi usano `item_category` (non `type`); leggere sempre con `data.get("type", data.get("item_category", ""))`; `weapon`/`armor`/`accessory` vanno normalizzati a `"equipment"` nei match
- **IMPORTANTE**: iterare `GameState.inventory` richiede guard `.get("id", "")` — le istanze non hanno "id". Usare `entry.get("id","")` e `entry.has("instance_id")` per distinguere i due formati.
- `Inventory.identify_instance(instance_id, player_level) → bool` — sostituisce l'entry in-place con versione identificata via `ItemGenerator.identify()`; emette `inventory_changed`. Consuma la pergamena separatamente con `remove_item()`.

### Budget loot (`DungeonLootBudget` / `FloorLootBudget`)

`DungeonLootBudget` (RefCounted) — cap per dungeon: `for_tier(tier)`, `equipment_ok()`, `consumable_ok()`, `unique_ok()`, `consume_*()`.  
`FloorLootBudget` (RefCounted) — cap per piano con slot separati chest/enemy/ground: `for_floor(dungeon_budget, floor_index, tier)`.  
Passati in `ctx["budget"]` al resolver come `Variant` (duck typing).

### EventBus — segnali loot
```gdscript
EventBus.loot_screen_open(drops: Array, source_label: String)
EventBus.loot_screen_closed(remaining: Array)   # remaining = drop non presi
```

### BaseMap — loot cadaveri
```gdscript
map.add_corpse(pos, color, loot_drops)   # loot_drops opzionale
map.has_corpse_at(pos) -> bool
map.get_corpse_loot_at(pos) -> Array
map.set_corpse_loot_at(pos, items)       # aggiorna loot rimasto sul cadavere
map.clear_corpse_loot_at(pos)
```

---

## Stato del giocatore — `GameState`

```
GameState.food                        # float 0–100 — fame; 100 = sazio
GameState.water                       # float 0–100 — idratazione; 100 = dissetato
GameState.exhaustion                  # float 0–100 — stanchezza; 100 = collasso
GameState.temperature                 # float −100…+100 — temperatura corporea; 0 = neutro
GameState.active_diseases             # Array di String (disease_id); gestiti da NeedsManager
GameState.needs_modifiers             # Dictionary — moltiplicatori derivati dai bisogni; ricreato da NeedsManager.rebuild_modifiers()
                                      # chiavi: atk_mult, dmg_taken_mult, action_cost_mult, int_mult, wil_mult,
                                      #         accuracy_penalty, vision_penalty, food_drain_mult_sum,
                                      #         exhaustion_gain_mult_sum, temp_zone (int −2..+2), temp_direction (String)
GameState.total_minutes               # int — contatore assoluto mai resettato; default 480 (= 08:00 del 1 Nevargento 472 C)
GameState.world_time                  # int — derivato: total_minutes % 1440; minuti nella giornata corrente (0–1439)
# Calendario e display sempre via TimeManager: format_time(), format_date(), get_slot(), is_night()
GameState.level                       # int, livello corrente
GameState.xp                          # int
GameState.current_map_id              # String, es. "dungeon_floor_1"
GameState.current_city_id             # String — root city ID stabile (es. "rivamola"); "" fuori da città; settato da WorldManager
GameState.current_location_faction_id # String — signoria del villaggio/città corrente; "" in dungeon/overworld
GameState.crime_state                 # {city_id: int} — livelli: 0=nessuno, 1=attivo, 2=arrestato; NON persiste nel save
GameState.criminal_record             # Array [{city_id, city_name, turn}] — persiste nel save
GameState.player_position             # Vector2i
GameState.player_stats                # {hp, max_hp, mp, max_mp, stamina, max_stamina, attack, defense, gold}
GameState.base_attributes             # {str, dex, int, vit, wil} — crescono con level-up
GameState.class_bonus                 # {str,…} — bonus fisso classe corrente (sostituito, mai accumulato)
GameState.effective_attributes        # base + class_bonus — usati dal gioco
GameState.current_class               # String, es. "warrior"
GameState.inventory                   # Array di item dict
GameState.equipped                    # {head, body, left_hand, right_hand, ring_1, ring_2, neck, feet, cloak, trinket, hands}
GameState.quick_slots                 # Array[String] di 3 item_id (slot rapidi consumabili)
GameState.world_flags                 # {intro_completed, dungeon_boss_defeated, …}
GameState.run_milestones              # {kills, deaths, save_points_used, …}
GameState.character_faction_rep       # Dictionary faction_id → int; fallback lazy a default_rep JSON
GameState.character_faction_membership # Dictionary faction_id → {rank: int, join_date: int, tax_debt: int}
                                      # tax_debt: 0=corrente, 1=in ritardo (warn+blocco rank), 2+=moroso (espulso)
GameState.faction_passive_flags       # Dictionary chiave → valore; DERIVATO, non persiste nel save
                                      # Ricreato da FactionMembership.reapply_all_passives() al load
GameState.known_faction_members       # {faction_id: {npc_id: display_name}} — NPC incontrati per fazione
GameState.record_known_member(faction_id, npc_id, name)  # helper che aggiorna known_faction_members
# Per leggere/scrivere rep usare sempre FactionReputation.get_rep/set_rep/add_rep
# Per membership usare sempre FactionMembership.is_member/join_faction/leave_faction
# Per check segno di riconoscimento: FactionMembership.wears_recognition_sign(faction_id)
```

### `GameState.recalculate_derived_stats()`

Chiamata da `apply_class()`, `LevelSystem.level_up()`, `NeedsManager._update_modifiers()` (ad ogni tick/consume/rest/disease change), e ogni volta che cambiano attributi o equipment. Ricalcola in questo ordine:

```gdscript
recalculate_effective_attributes()   # effective = base + class_bonus

max_hp      = vit * 5
# max_mp usa int_mult / wil_mult da needs_modifiers (FASE 2):
int_m   = 1.0 + needs_modifiers.get("int_mult", 0.0)
wil_m   = 1.0 + needs_modifiers.get("wil_mult", 0.0)
max_mp  = roundi((int * int_m + wil * wil_m) * 2.0)
max_stamina = (str + dex) * 2
attack      = 2 + int(str * 0.5)     # str guida il danno melee
defense     = int(vit * 0.25)        # vit guida la resistenza

# cap: hp/mp/stamina non superano il nuovo max
```

Equipment bonus (`Equipment.get_attack_bonus()` / `get_defense_bonus()`) sono aggiunti in `Player._refresh_stats()` quando le Entity fields vengono lette, **non** in `player_stats` direttamente.

### `Player._refresh_stats()`

Chiamata su `player_stats_changed` e `equipment_changed`. Sincronizza i campi Entity del player:

```gdscript
level   = GameState.level
dex     = GameState.effective_attributes["dex"]
hp      = GameState.player_stats["hp"]
max_hp  = GameState.player_stats["max_hp"]
attack  = GameState.player_stats["attack"] + Equipment.get_attack_bonus()
defense = GameState.player_stats["defense"] + Equipment.get_defense_bonus()
# mp e stamina vivono solo in GameState — nessun campo Entity corrispondente
```

**Nota**: `accuracy` e `evasion` su `Entity` sono sempre 0 per il player (non usati attivamente). I nemici li usano per specializzarsi (es. schivata).

---

---

## HUD — `scenes/ui/HUD.tscn` / `scripts/ui/HUD.gd`

`CanvasLayer` sempre visibile durante il gioco. Aggiornato via `EventBus`.

| Nodo | Percorso | Aggiornato da |
|------|----------|---------------|
| HP / MP / ST bar + val | `Panel/VBox/{HP,MP,ST}Row/*` | `player_stats_changed`, `equipment_changed` |
| XP bar + level tag | `Panel/VBox/XPRow/*` | `xp_gained`, `player_leveled_up` |
| GoldLabel | `Panel/VBox/GoldLabel` | `player_stats_changed` |
| StatsLabel | `Panel/VBox/StatsLabel` | `player_stats_changed`, `equipment_changed` |
| MapLabel | `Panel/VBox/MapLabel` | `map_changed` |
| QuestLabel | `Panel/VBox/QuestLabel` | `quest_started`, `quest_completed` |
| **TimeLabel** | **figlio diretto di HUD** (non dentro Panel) | **`time_advanced`** → `TimeManager.format_time()` |

`TimeLabel`: `offset (0,4)→(640,18)`, `font_size=11`, `horizontal_alignment=CENTER` — mostra la data e la fase del giorno (es. `"1 Nevargento 472 C — Giorno"`) in alto al centro dello schermo, sopra tutto l'HUD.

---

## Mappa e Mondo

### WorldManager — `scripts/core/WorldManager.gd`

```gdscript
WorldManager.change_map(location_id, spawn_position)  # salva stato corrente, carica nuova mappa
WorldManager.get_current_map() -> BaseMap
```

Flusso `change_map`:
1. `current_map.save_location_state()` → flush in LocationRegistry
2. `current_map.queue_free()`
3. `_update_city_id(location_id, data)` → aggiorna `GameState.current_city_id`; se si lascia una città con crimine attivo chiama `CrimeSystem.apply_post_crime_rep_on_flee()`; se si rientra in una città con crimine già attivo spawna guardie di pattuglia; se si entra in un edificio che è safe house TSN con crimine attivo e `tsn_black_market` passive → `CrimeSystem.clear_crime()`
4. `LocationRegistry.get_or_generate(location_id)` → genera se prima visita
5. `scene.instantiate()` → `populate(data, state)` → `add_child`

`current_city_id` logic:
- `village`/`city` → `current_city_id = location_id`
- `building` → usa `metadata.city_id` se presente; altrimenti mantiene il valore precedente
- `dungeon`/`overworld` → `current_city_id = ""`

### BaseMap — `scripts/world/BaseMap.gd`

Nodo radice di ogni mappa. Esteso da `DungeonMap`, `OverworldMap`, `VillageMap`, `BuildingMap`.

```gdscript
# Campi principali
_entities: Array           # tutti i nodi Entity figli
_entity_uids: Dictionary   # entity_node → spawn_uid
_blocked_tiles: Dictionary # Vector2i → true, O(1) walkability
_corpses: Array[Dictionary] # {pos: Vector2i, color: Color}
_save_point_positions: Array[Vector2i]
_visible_tiles: PackedByteArray   # FOV corrente (0/1)
_seen_tiles: PackedByteArray      # memoria fog-of-war (0/1)

# Sorgenti di luce (sistema notte)
_light_sources: Array[Dictionary]  # [{pos: Vector2i, radius: int, color: Color}]
_lights_active: bool               # true durante sera/notte (settato da _on_day_slot_changed)

# Metodi chiave
populate(data: MapData, state: LocationState)   # chiamato da WorldManager prima di add_child
save_location_state()                           # flush → LocationRegistry (chiamato prima di cambiare mappa o salvare)
get_entity_at(pos: Vector2i) -> Node
is_walkable(pos: Vector2i) -> bool
is_tile_visible(pos: Vector2i) -> int           # 1 = in FOV
is_tile_seen(pos: Vector2i) -> int              # 1 = mai visto
add_corpse(pos: Vector2i, color: Color)
respawn_non_boss_enemies()                      # chiamato da save point; svuota anche _corpses
has_line_of_sight(from: Vector2i, to: Vector2i) -> bool  # pubblico; usato da CrimeSystem e MapRenderer
toggle_lights()                                 # debug — inverte _lights_active e ricomputa FOV
```

`_light_sources` viene popolato in `_spawn_entity()` per ogni entità `kind == "light_source"` letta dal JSON.  
`_on_day_slot_changed(slot)` (connesso a `EventBus.day_slot_changed`) imposta `_lights_active = slot in ["sera","notte"]` e ricomputa il FOV.  
`_ready()` chiama `_on_day_slot_changed(TimeManager.get_slot())` subito dopo la connessione al signal, per inizializzare `_lights_active` dallo stato corrente al momento del load (senza questo, il bool resterebbe `false` e la mappa apparirebbe sempre di giorno al caricamento di un salvataggio notturno).

Il FOV in `_compute_fov()` usa `_cast_fov_from(origin, radius)` (Bresenham + `_is_opaque()`) sia per il player che per ogni luce attiva. `_get_player_fov_radius()` applica `vision_penalty` da `needs_modifiers` (es. −2 da cecità) oltre al modificatore giorno/notte di TimeManager; risultato sempre ≥ 1. `_is_opaque()` controlla `_blocked_tiles` e porte chiuse (`GameBalance.FOV_DOORS_BLOCK_SIGHT`).

### MapData — struttura dati mappa (`scripts/world/MapData.gd`)

Generata da tutti i generator (`DungeonGenerator`, `CityGenerator`, ecc.).

```gdscript
var id: String
var type: String          # "village" | "city" | "building" | "dungeon" | "ruin" | "overworld"
var width, height: int
var walls: Array[Vector2i]
var transitions: Array[Dictionary]   # {position, target_id, target_type, target_position}
var entity_defs: Array[Dictionary]   # {kind, uid, pos:{x,y}, params}
var metadata: Dictionary
var player_start: Vector2i           # spawn default quando si entra in questa mappa (default Vector2i(1,1))
```

### LocationState — `scripts/world/LocationState.gd`

Stato persistito per ogni mappa visitata.

```
dead_entity_uids: Array[String]    # UID nemici/chest morti
entity_positions: Dictionary       # uid → {x,y} per entità che si sono spostate
open_entity_uids: Array[String]    # uid porte aperte
fog_of_war: PackedByteArray        # seen tiles (hex-encoded su disco)
corpse_defs: Array[Dictionary]     # [{x,y,color:[r,g,b,a]}, …]
```

### LocationRegistry — `scripts/world/LocationRegistry.gd`

```gdscript
LocationRegistry.get_state(map_id) -> LocationState
LocationRegistry.set_state(map_id, state)
LocationRegistry.get_or_generate(map_id) -> MapData
LocationRegistry.respawn_non_boss_enemies_in_unloaded_floors(exclude_map_id)
# ↑ chiamato da save point — svuota dead_entity_uids e corpse_defs dei piani non caricati
```

---

## City Builder — Editor Plugin

Plugin Godot (`addons/city_builder/`). Si apre da **Progetto → Strumenti → City Builder…** in una finestra floating.

### File

| File | Ruolo |
|------|-------|
| `plugin.gd` | `EditorPlugin`; registra la voce di menu, crea la `Window` floating |
| `CityBuilderPanel.gd` | UI completa (~1100 righe): palette, canvas, proprietà, salvataggio |
| `CityCanvas.gd` | `Control` minimale che delega `_draw` e `_gui_input` al pannello |

### Encoding tile

```
valore_cella = categoria * 16 + variante   (0–255)
categoria = valore >> 4
variante  = valore & 0xF
```

| ID | Costante | Descrizione | Blocca mov? |
|----|----------|-------------|-------------|
| 0 | `CAT_FLOOR` | Pavimento (10 var) | no |
| 1 | `CAT_WALL_ST` | Muro pietra (10 var) | **sì** |
| 2 | `CAT_WALL_WD` | Muro legno (10 var) | **sì** |
| 3 | `CAT_FENCE` | Staccionata (10 var) | **sì** |
| 4 | `CAT_BARRICADE` | Barricata (10 var) | **sì** |
| 5 | `CAT_PATH` | Sentiero (10 var) | no |
| 6 | `CAT_SOLCO` | Solchi agricoltura (10 var) | no |
| 7 | `CAT_BUCA` | Buca / voragine (10 var) | **sì** |
| 8 | `CAT_ENTITY` | Categoria palette entità (non tile) | — |
| 9 | `CAT_MARKER` | Categoria palette marker (non tile) | — |
| 10–16 | `CAT_DECO_*` | Decorativi estetici (7 cat × 16 var = 112 item) | no |

`BLOCKED_CATS = [1, 2, 3, 4, 7]`

### Entità (`CAT_ENTITY`)

| kind | char | note |
|------|------|------|
| `npc` | `N` giallo-oro | dialogo, quest |
| `save_point` | `Ω` ciano | posizioni in `_save_point_positions` |
| `transition` | `>` arancio | porta verso un'altra mappa |
| `port` | `P` blu | porto, viaggio via mare |
| `door` | `+` marrone | porta apribile, params: locked, key_id |
| `plant` | `♣` verde | pianta, params: blocks_movement |
| `well` | `o` azzurro | pozzo |
| `item` | `?` oro | oggetto sul suolo |
| `light_source` | `*` (colore variante) | sorgente di luce notturna; 8 varianti colore; NON spawna un nodo Entity — viene registrata in `BaseMap._light_sources` |

**8 varianti `light_source`** (stesso `kind`, colore e raggio diversi):

| Label | Colore | Raggio default |
|-------|--------|----------------|
| Torcia | `(1.00, 0.72, 0.10)` | 2 |
| Lanterna | `(1.00, 0.90, 0.60)` | 3 |
| Candela | `(0.95, 0.85, 0.50)` | 1 |
| Braciere | `(1.00, 0.52, 0.10)` | 4 |
| Fiamma Bianca | `(1.00, 0.95, 0.90)` | 3 |
| Luce Magica | `(0.38, 0.68, 1.00)` | 3 |
| Luce Verde | `(0.28, 1.00, 0.48)` | 3 |
| Luce Viola | `(0.75, 0.28, 1.00)` | 3 |

Le sorgenti di luce sono visibili solo di notte (`sera`/`notte`) — di giorno il glyph `*` non viene renderizzato.  
Il colore e il raggio vengono iniettati nei `params` al momento del piazzamento (`CityBuilderPanel._place_entity()`):
```jsonc
{ "kind": "light_source", "params": { "color": [r, g, b], "radius": 3 } }
```

**Preview notturna nel City Builder**: pulsante "🕯 Luci notte" nel pannello palette.  
Attiva un overlay nero per tile con gradiente (0.0 al centro luce → 0.85 fuori raggio).  
Usa LOS Bresenham (`_preview_has_los()`) che rispetta `BLOCKED_CATS` (muri, staccionate, buche).  
`NPC`, `enemy`, `guard` (`NIGHT_HIDDEN_KINDS`) diventano invisibili se overlay ≥ 0.5.

### Marker editor-only (`CAT_MARKER`) — invisibili in gioco

| kind | char | note |
|------|------|------|
| `spawn_point` | `S` verde | → `MapData.player_start` |
| `event_trigger` | `E` viola | ignorato da CityGenerator (futuro) |
| `exit` | `X` ciano | → `MapData.add_transition()` verso overworld |

### Formato JSON salvato (`data/cities/*.json`)

```jsonc
{
  "id": "villaggio_nord",
  "name": "Villaggio del Nord",
  "type": "village",           // village | city | building | dungeon | ruin
  "floors": [
    {
      "label": "Piano Terra",
      "width": 40, "height": 30,
      "tiles": [[...], ...],   // [y][x] = cat*16+var
      "entities": [{ "kind": "npc", "x": 5, "y": 8, "uid": "npc_5_8", "params": {...} }]
    },
    { "label": "Primo Piano", ... }
  ]
}
```

Campi opzionali a livello city (Fase 8):
```jsonc
{
  "signoria": "signoria_almerici",          // ID signoria governante; setta GameState.current_location_faction_id
  "corporazioni_presenti": ["arte_ferri", "mano_campi"]  // fazioni attive in questo insediamento
}
```
Entrambi letti da `CityGenerator._from_json()` → `MapData.metadata["signoria"]` e `MapData.metadata["corporazioni_presenti"]`.

Formato legacy (piatto `tiles`/`entities` senza `floors`) supportato in lettura da `CityGenerator`.

### Multi-piano nel builder

- Riga di navigazione sotto l'header: `◀ Piano N/Tot — Label ▶  + Piano  🗑`
- Ogni piano ha dimensioni proprie (W/H spinbox applicano al piano corrente)
- `_save_current_floor()` / `_load_floor(idx)` sincronizzano stato live ↔ `_floors[i]`

---

## CityGenerator — `scripts/world/generators/CityGenerator.gd`

```gdscript
CityGenerator.generate({"id": "city_id", "floor": 0}) -> MapData
```

- Legge `res://data/cities/{id}.json`
- Supporta formato multi-piano (`floors` array) e legacy flat
- Tile bloccate: `(valore >> 4) in [1,2,3,4,7]` → `data.walls`
- `spawn_point` → `data.player_start`
- `exit` o `transition` → `data.add_transition(...)`
- `event_trigger` → ignorato (solo editor)
- Tutto il resto → `data.add_entity(kind, uid, pos, params)`
- `signoria` → `data.metadata["signoria"]` — ID signoria (stringa) o assente
- `corporazioni_presenti` → `data.metadata["corporazioni_presenti"]` — Array di faction_id

Registrato in `LocationRegistry` come tipo `"city"`.

---

## Save / Load

### Flusso salvataggio

```
SaveManager.save_game()
  └─ WorldSaveManager.save_world(world_name)      # serializza LocationRegistry
  └─ _save_character(world_name, char_name)
       └─ current_map.save_location_state()       # flush mappa corrente prima di serializzare
       └─ scrive {level, xp, stats, inventory, position, total_minutes, …} in user://saves/<world>/<char>.json
```

### Flusso save point (Player.gd `_use_save_point`)

```
map.respawn_non_boss_enemies()                              # 1. respawn + clear corpses mappa corrente
LocationRegistry.respawn_non_boss_enemies_in_unloaded_floors(...)  # 2. clear altri piani
HP/MP/stamina ripristinati
SaveManager.save_game()                                     # 3. salva
EventBus.save_point_used.emit()
```

### Flusso caricamento

```
SaveManager.load_game(world_name, char_name)
  └─ WorldSaveManager.load_world(world_name)    # ripristina LocationRegistry
  └─ _load_character(…)                         # ripristina GameState, incluso total_minutes
→ WorldManager.change_map(GameState.current_map_id, GameState.player_position)
     └─ BaseMap._ready() → _on_day_slot_changed(TimeManager.get_slot())  # lights init post-load
```

**Nuova partita in mondo esistente** — `Main._start_new_game()` legge `WorldSaveManager.get_world_max_minutes(world_name)` e calcola `start_minutes = (giorno_max + 1) * 1440 + 480`, passandolo a `_reset_game_state()`. Ogni nuovo personaggio parte alle 08:00 del giorno successivo al massimo tra tutti i personaggi salvati in quel mondo.

**Nuova partita in mondo nuovo** — `has_world` = false (nessun `world.json`), quindi `start_minutes = 480` (08:00 del giorno 1) e viene chiamato `generate_new_world`.

**`WorldSaveManager.save_world()`** legge i timestamp esistenti via `_read_character_timestamps()`, aggiorna l'entry del personaggio corrente (`GameState.character_name → GameState.total_minutes`) e scrive il dizionario `character_timestamps` nel meta. Viene chiamato solo da `save_game()` (save point esplicito) — mai al semplice ritorno al menù principale.

**`WorldSaveManager._read_character_timestamps(world_name) -> Dictionary`** — helper interno; legge `meta.character_timestamps` dal `world.json` senza caricare il resto. Restituisce `{}` se il file non esiste o il campo manca.

**`WorldSaveManager.get_world_max_minutes(world_name) -> int`** — restituisce il massimo tra tutti i valori in `character_timestamps`. Backward compat: se il campo è assente, legge il vecchio scalare `world_max_minutes`. Restituisce 0 se non c'è nulla (mondo mai salvato).

---

## Entità

### Gerarchia

```
Entity (scripts/entities/Entity.gd)           ← Node2D, classe base
  ├── Enemy       (scripts/entities/Enemy.gd)
  ├── Player      (scripts/entities/Player.gd)
  ├── Ally        (scripts/entities/Ally.gd)
  ├── NPC         (scripts/entities/NPC.gd)
  ├── Guard       (scripts/entities/Guard.gd)   # estende Enemy; is_guard=true; die() senza XP/loot/rep
  ├── Door        (scripts/entities/Door.gd)
  ├── Chest       (scripts/entities/Chest.gd)
  ├── PostStation (scripts/entities/PostStation.gd)   # ⚑ giallo, cura HP, iniettata da WorldState
  └── Ambulatorio (scripts/entities/Ambulatorio.gd)   # + rosso, cura HP, iniettata da WorldState
```

### Entity — campi rilevanti

```gdscript
grid_position: Vector2i
hp, max_hp: int
attack: int        # danno base (player: da player_stats + equipment)
defense: int       # riduzione danno (player: da player_stats + equipment)
dex: int           # stat destrezza (player: da effective_attributes.dex)
accuracy: int      # bonus flat all'accuratezza (sommato pesato in _calc_hit)
evasion: int       # bonus flat alla schivata (sommato pesato in _calc_hit)
level: int
is_dead: bool
faction: String          # "player" | "enemy" | "neutral"
entity_char: String      # carattere ASCII
entity_color: Color      # colore originale
display_name: String

take_damage(amount)      # chiama die() se hp <= 0
die()                    # imposta is_dead=true, queue_free()
_setup_visual(char, col) # crea Label figlio con il carattere ASCII
```

### NPC — campi extra

```gdscript
npc_id: String
primary_faction_id: String    # da "faction_id" in entity params; fallback a GameState.current_location_faction_id se vuoto
secondary_faction_ids: Array[String]
linked_quest_id: String
black_market: bool            # richiede tsn_black_market passive flag per interagire
safe_house: bool              # registra WorldState.register_safe_house() al primo incontro
faction_action_id: String     # "deposit_map" | "build_post_station" | "open_ambulatorio" | "reduce_bounty"
is_guard_npc: bool            # NPC con ruolo guardia (city builder: is_guard)
gender: String                # "" | "m" | "f"
is_child: bool
```

`interact()` applica filtro sociale su `primary_faction_id`: stato `enemy_sworn` → emette `Notification.faction_access_denied()` e blocca il dialogo. Stato `hostile` consente il dialogo (variazioni tono future).

Se `faction_action_id != ""` → chiama `FactionActionsService` via `get_node_or_null("/root/FactionActionsService")` e torna (non procede col dialogo).

### Door — campi extra

```gdscript
door_uid: String
is_open: bool
faction_requirement: Dictionary   # {faction_id: String, min_rep: int, min_rank: int}
                                   # min_rep = 0 → nessun check rep; min_rank = -1 → nessun check rango
                                   # min_rank = 0 → qualsiasi membro (get_rank() >= 0)
```

`interact()` chiama `_check_faction_access()`: se fallisce emette `Notification.faction_access_denied(fname)`.  
Impostato nel CityBuilder tramite i campi `faction_req_fid`, `req_min_rep` (0–100), `req_min_rank` (-1 a 5).

### Enemy — campi extra

```gdscript
enemy_data_id: String   # chiave in EnemyRegistry
affixes: Array          # lista affix id applicati
is_boss: bool
xp_reward: int
detection_range: int
```

`Enemy.die()` registra il cadavere sulla mappa (`map.add_corpse`) prima di `queue_free()`.

### Cadaveri

Quando un Enemy muore: `BaseMap.add_corpse(pos, entity_color.darkened(0.5))`.  
Visualizzati come `_` in `MapRenderer._draw_corpses()` con supporto FOV.  
Persistono in `LocationState.corpse_defs`. Vengono azzerati al save point.

---

## Combattimento

### TurnManager

```gdscript
TurnManager.is_active: bool
TurnManager.is_player_turn: bool
TurnManager.activate(enemies)        # avvia combattimento
TurnManager.deactivate()             # fine combattimento (tutti i nemici morti)
TurnManager.on_player_action_done()  # scatena turni alleati + nemici
TurnManager.unregister_enemy(enemy)  # rimosso da die()
```

### Player — integrazione Time System

```gdscript
enum Action { MOVE = 0, ATTACK = 1, USE_ITEM = 2, INTERACT = 3, WAIT = 4 }
var _last_action: int = Action.MOVE

func _action_done(override_cost: int = -1) -> void:
    # Legge map.map_type, chiama TimeManager.advance(cost) PRIMA di TurnManager.on_player_action_done()
    # cost = override_cost se >= 0, altrimenti TimeManager.get_action_cost(map_type, _last_action)
    # action_cost_mult da needs_modifiers applicato al cost finale (FASE 2)
    # Se _last_action == ATTACK: NeedsManager.consume({"exhaustion": 0.1}) — fatica attacco (FASE 2)

func _get_move_cost_overworld() -> int:
    # ceili(240.0 * terrain_mult * mount_mult) — terrain/mount = 1.0 placeholder
```

`_last_action` è settato immediatamente prima di ogni `_action_done()`:
- Movimento (non-overworld): `Action.MOVE` → costo da `get_action_cost`
- Movimento overworld: `Action.MOVE` → `_action_done(_get_move_cost_overworld())`
- Attacco nemico / NPC: `Action.ATTACK`
- Abilità di classe (anche con targeting/menu): `Action.ATTACK`
- Interazione NPC / loot cadavere: `Action.INTERACT`
- Fuga (tutte le branch): `Action.MOVE`

### CombatBar — integrazione Time System

Wait gestito interamente in `CombatBar._process()` (rimosso da `_unhandled_input`):
- **Tap R** (< 0.4s): `_on_quick_wait()` → `TimeManager.advance(get_action_cost(map_type, 4))` + `TurnManager.on_player_action_done()`
- **Hold R in esplorazione** (≥ 0.4s): `_wait_screen_open = true` + `_wait_screen.open()`; alla chiusura `wait_completed` → `_on_wait_screen_closed()` resetta il flag
- **Hold R in combattimento** (≥ 0.4s): quick wait normale (come tap)
- Guard: se `TurnManager.is_active and not is_player_turn` → reset timer, return
- Testo pulsante: `[R] Aspetta` (CSV aggiornato)
- `_wait_screen` recuperato in `_ready()` via `get_node_or_null("/root/Main/WaitScreen")`

### WaitScreen — `scenes/ui/WaitScreen.tscn` / `scripts/ui/WaitScreen.gd`

`CanvasLayer` layer=10 (sopra HUD). UI costruita a codice in `_ready()`. Aperta da `CombatBar` su hold R in esplorazione.

```gdscript
signal wait_completed           # emesso alla chiusura (sia conferma che annulla)
const WAIT_TICK_DELAY: float = 0.08   # secondi per ora simulata
const MAX_WAIT_HOURS:  int   = 8

func open() -> void             # apre la schermata; _start_minutes = GameState.total_minutes
func _on_wait_confirmed()       # disabilita input, avvia animazione
func _run_wait_animation()      # await loop: advance(60) per ora, aggiorna slider + NowLabel
func _finish()                  # Notification.wait_finished() + TurnManager.on_player_action_done() + hide() + emit wait_completed
func _on_cancel_pressed()       # solo se not _animating → hide() + emit wait_completed
```

**Fase selezione**: FromLabel "Da: [ora]", ToLabel "A: [ora target]", slider 1–8 ore, HoursLabel.  
**Fase animazione**: slider scorre da target→0, NowLabel "Ora: [ora corrente]" aggiornato ad ogni passo.  
ESC chiude durante la selezione (intercettato in `_unhandled_input`). Annulla disabilitato durante animazione.

---

## Combattimento — flusso completo

### Flusso attacco

```
CombatManager.attack(attacker, defender)
  └─ _calc_hit(attacker, defender) → {chance, is_dodge}
  └─ se mancato/schivato: combat_log + return
  └─ crea DamageContext; base_damage = attacker.attack
  └─ DamagePipeline.execute(ctx)
       ├─ ClassRuntime.on_before_player_attack(ctx)  [hook classi]
       ├─ StatusEffectManager: applica atk_mult effetti nemico se nemico attacca
       ├─ StatusEffectManager: applica dmg_taken_mult effetti difensore
       ├─ FactionEffects.get_attack_mult(defender)   [hook fazione]
       ├─ calcolo danno finale (vedi formula)
       ├─ guardie: cap danno a CRIME_GUARD_MIN_HP
       └─ ctx.defender.take_damage(final_damage)
```

### `DamageContext` — campi (`scripts/combat/DamageContext.gd`)

```gdscript
attacker:          Node    # entità attaccante
defender:          Node    # entità difensore
base_damage:       int     # = attacker.attack al momento del call
flat_bonus:        int     # bonus piatto (hook classi, default 0)
attack_multiplier: float   # moltiplicatore danno in uscita (default 1.0)
target_multiplier: float   # moltiplicatore danno ricevuto (default 1.0)
defense_bonus:     int     # bonus difesa temporaneo del difensore (default 0)
ignore_defense:    bool    # bypassa eff_def (default false)
damage_type:       String  # "physical" | "magic" | "pure"
tags:              Array   # tag extra per hook
min_damage:        int     # override al DAMAGE_MIN (default 1)
cancelled:         bool    # hook ha annullato l'attacco
instant_kill:      bool    # porta HP a 0 ignorando tutto
final_damage:      int     # valorizzato da pipeline, usato poi da take_damage
```

### Formula danno (`DamagePipeline`)

```
lf       = BalanceCombat.level_factor(attacker.level)   # = 2*level/5 + 2.0
out_mult = BalanceCombat.output_multiplier(attacker.level)

eff_def  = max(1.0, defender.defense + ctx.defense_bonus)
raw      = lf * (base_damage + flat_bonus) * attack_multiplier * target_multiplier / eff_def / DAMAGE_K
final    = max(DAMAGE_MIN, floor(raw * out_mult))
```

**Nota critica**: `max(1, eff_def)` — `defense=0` e `defense=1` producono lo stesso danno. Tenere `def_base` ≤ 2 nei nemici e usare `def_growth` per la progressione.

### `_calc_hit()` — accuratezza (`CombatManager`)

```gdscript
# Attaccante = player
match combat_type:  # letto da ClassRegistry.get_class_data(current_class)["combat_type"]
    "melee":  hit_stat = (effective_attributes["str"] + effective_attributes["dex"]) / 2.0
    "ranged": hit_stat = effective_attributes["dex"]
    "magic":  hit_stat = (effective_attributes["int"] + effective_attributes["wil"]) / 2.0
dodge_stat = defender.dex

# Attaccante = nemico
hit_stat   = attacker.dex
dodge_stat = effective_attributes["dex"]   # sempre dex del player

eff_hit   = hit_stat   + attacker.accuracy * BalanceCombat.accuracy_multiplier(attacker.dex)
eff_dodge = dodge_stat + defender.evasion  * BalanceCombat.accuracy_multiplier(defender.dex)

hit_chance = clamp(BASE_HIT_CHANCE + (eff_hit - eff_dodge) * ACCURACY_K, 0.10, 0.95)
is_dodge   = (eff_dodge > eff_hit)   # determina se il log dice "schivato" vs "mancato"
```

### Hook punti in DamagePipeline

| Quando | Campo modificato | Chi lo usa ora |
|--------|-----------------|----------------|
| Player attacca | `ctx.attack_multiplier *= mult` | FactionEffects, ClassRuntime |
| Nemico attacca player | `ctx.target_multiplier *= mult` | StatusEffectManager (dmg_taken_mult) |
| Qualsiasi | `ctx.flat_bonus += n` | ClassRuntime (ability bonus) |
| Qualsiasi | `ctx.defense_bonus += n` | ClassRuntime (Sentinella) |
| Qualsiasi | `ctx.cancelled = true` | ClassRuntime (schivata speciale) |
| Qualsiasi | `ctx.ignore_defense = true` | ClassRuntime (attacco puro) |

**Per i bisogni (FASE 2 — implementato)**: `atk_mult` da `needs_modifiers` applicato dopo FactionEffects su `attack_multiplier` (player attacca); `dmg_taken_mult` applicato su `target_multiplier` (player difende). Dopo `take_damage()`: se `final_damage * 10 > max_hp` → `NeedsManager.consume({"exhaustion": 0.2})`.

### Bilanciamento Combattimento

#### Costanti — `BalanceCombat` (`scripts/core/game_balance/BalanceCombat.gd`)

```gdscript
DAMAGE_K: float = 5.0
DAMAGE_MIN: int = 1
BASE_HIT_CHANCE: float = 0.75
ACCURACY_K: float = 0.02
MIN_HIT_CHANCE: float = 0.10
MAX_HIT_CHANCE: float = 0.95

level_factor(level) -> float           # = 2*level/5 + 2.0  (lf(1)=2.4)
output_multiplier(level) -> float      # scaling out danno per livello alto
accuracy_multiplier(dex) -> float      # peso dell'accuracy/evasion in base alla dex
```

#### Formule CombatSimulator (stima teorica)

```
lf          = level_factor(level)
hit_chance  = clamp(0.75 + (hit_stat - e_dex) * 0.02, 0.10, 0.95)
p_dmg       = max(1, floor(lf * p_atk / max(1.0, e_def) / DAMAGE_K))
e_hp_scaled = round(hp_base * lf / lf(1))
TTK         = ceil(e_hp_scaled / (hit_chance * p_dmg))
```

#### Target TTK per ruolo

| Ruolo | TTK min | TTK max |
|-------|---------|---------|
| swarm | 1 | 3 |
| skirmisher | 2 | 5 |
| soldier | 3 | 7 |
| glass_cannon | 2 | 5 |
| brute | 4 | 10 |
| tank | 5 | 12 |
| controller | 3 | 8 |
| assassin | 2 | 5 |
| elite | 6 | 12 |
| boss | 8 | 20 |

Testato a `zone_min_level`, profili primari: `melee_bruiser` e `caster_burst`.  
Eseguire `CombatSimulator.run_validation()` dal pulsante TTK Sim nel DebugScreen.

#### Profili classe (ClassCombatProfile — `scripts/tools/ClassCombatProfile.gd`)

| Profilo | atk_l1 | atk_growth | dex_l1 | dex_growth | tipo |
|---------|--------|-----------|--------|-----------|------|
| melee_bruiser | 6 | 0.45 | 5 | 0.04 | melee |
| caster_burst | 7 | 0.50 | 4 | 0.04 | magic |
| melee_tank | 4 | 0.30 | 3 | 0.02 | melee |
| evasion_based | 5 | 0.42 | 9 | 0.14 | melee |

---

## Dati Nemici — `data/enemies/tierN/*.json`

```jsonc
{
  "schema_version": 1,
  "id": "goblin",
  "name": "Goblin",
  "char": "g",
  "color": [r, g, b, 1.0],
  "family": "humanoid",   // humanoid | beast | undead | construct | dragon | demon | aberration
  "role": "skirmisher",   // vedi tabella TTK sopra
  "tier": 1,              // 1–6
  "tags": ["melee"],      // melee | magic | ranged | flying | large | slow | undead
  "biomes": ["cave"],
  "hp_base": 7,
  "atk_base": 3, "def_base": 0, "dex_base": 5,
  "atk_growth": 0.15, "def_growth": 0.05,
  "xp_reward": 15,
  "pressure_cost": 6,     // budget stanza
  "spawn_weight": 100,    // probabilità relativa spawn
  "min_floor": 1, "max_floor": 8,
  "zone_min_level": 1, "zone_max_level": 10,
  "detection": 5,
  "resistances": {},
  "abilities": [],
  "loot_profile": "humanoid_low"
}
```

30 nemici totali, organizzati in `data/enemies/tier1/` … `data/enemies/tier6/` (5 nemici per tier).  
`EnemyRegistry` scansiona ricorsivamente tutte le sottocartelle.  
Il campo `name` nel JSON è il fallback grezzo; a display usare sempre `EnemyRegistry.get_display_name(id)` (chiave `ENEMY_<ID_UPPER>_NAME`).  
Calibrazione TTK verificata con `CombatSimulator.run_validation()`.  
**`rep_on_kill` è popolato su tutti e 30 i nemici** (Fase 16): fuorilegge/non_morti/bestie −2, demoni/dragon_whelp/archlich −3, ancient_dragon −5, aberrazioni/costrutti −1.

---

## Rendering — `scripts/world/MapRenderer.gd`

- `z_index = -5` — disegna sotto i nodi Label delle entità (z=0)
- Trigger redraw: `enemy_died`, `player_moved`, `map_changed`, `turn_ended`, `day_slot_changed`
- `FOV_MEMORY_ALPHA`: moltiplicatore colore per tile viste ma fuori FOV (solo modalità dungeon)

### Modalità rendering

| Contesto | Modalità | Comportamento |
|----------|----------|---------------|
| `dungeon` | **FOV binario** | Tile mai viste = skip; tile viste fuori FOV = `FOV_MEMORY_ALPHA`; entità visibili solo se tile in FOV |
| `village`/`city` di giorno | **Tutto visibile** | Tile tutte al colore pieno; entità sempre visibili |
| `village`/`city` di notte (`_lights_active`) | **Night overlay** | **Tutti i tile sempre visibili** (nessun FOV/seen skip) + overlay nero per tile; entità mobili nascoste in zone buie (overlay ≥ 0.5) |

### Night overlay mode (village/city con `_lights_active = true`)

`_fill_overlay(map, overlay, origin, radius)` calcola per ogni tile raggiungibile via LOS da `origin`:  
`alpha = 0.85 * (distanza / radius)` → 0.0 al centro luce, 0.85 al bordo.  
Sorgenti: player (`GameBalance.FOV_RADIUS`) + ogni `_light_source` della mappa.  
Tile senza LOS da nessuna sorgente: overlay = 0.85 (massimo scuro).  
Più sorgenti sovrapposti: si prende il minimo alpha (unione degli aloni).

Il `has_line_of_sight()` di BaseMap viene chiamato per ogni tile in ogni raggio → stesso algoritmo usato dal FOV di gioco, muri e porte bloccano la luce.

### Entità in night overlay mode

| Tipo | Comportamento |
|------|---------------|
| `NPC`, `Enemy` (incluse Guard), `Ally` | `visible = false` se overlay ≥ 0.5 (oscurità totale) |
| `Door`, `Chest`, `PostStation`, `Ambulatorio` | Sempre visibili; `modulate` scurito proporzionalmente all'overlay |
| Sorgenti luce (`*`) | Disegnate in `_draw()` sul layer superiore, sempre al colore pieno |

`modulate` viene resettato a `Color.WHITE` al cambio modalità per evitare stale values.

### Ordine di rendering in `_draw()`

1. Background rect
2. Tile floor/wall (colore pieno)
3. Per-tile overlay rect `Color(0,0,0, alpha)` (solo night overlay mode)
4. `_draw_corpses()` — `_` con colore dimmed da overlay o FOV_MEMORY_ALPHA
5. `_draw_entities()` — visibilità e modulate per ogni entità
6. Glyph `*` sorgenti di luce (sopra tutto, mai overlaid)

---

## EventBus — signal chiave (`scripts/core/EventBus.gd`)

```gdscript
player_moved(pos: Vector2i)
map_changed(map_id: String)
turn_ended
combat_started / combat_ended
player_turn_started
enemy_died(entity: Entity)
player_stats_changed
save_point_used
damage_dealt(amount, source) / damage_taken(amount)
combat_log(text: String)
notification_shown(notif: Notification)

# Time System
time_advanced(minutes: int)          # emesso da TimeManager.advance() ad ogni avanzamento
day_changed(abs_day: int)            # emesso quando total_minutes supera un multiplo di 1440
day_slot_changed(slot: String)       # emesso al cambio slot interno ("alba","mattina","pomeriggio","sera","notte")
                                     # ↳ BaseMap._on_day_slot_changed() → aggiorna _lights_active + ricomputa FOV
                                     # ↳ MapRenderer._on_redraw_needed() → queue_redraw()
world_ticked(ticks: int, tick_size: int)  # emesso per avanzamenti ≥ 30 min; usato da WorldActor (futuro)

# Bisogni (FASE 1)
needs_changed                              # emesso da NeedsManager.tick() ad ogni aggiornamento
player_took_needs_damage(source: String, amount: int)  # fame/sete/malattia → Player.take_damage()
player_collapsed                           # esaurimento 100 → collasso; Main gestisce fade + penalità HP

# Fazioni (Fase 2–4)
faction_rep_changed(faction_id: String, old_val: int, new_val: int)
faction_state_changed(faction_id: String, old_state: String, new_state: String)
faction_supporter_gained(faction_id: String)   # rep attraversa +50 salendo
faction_supporter_lost(faction_id: String)     # rep attraversa +50 scendendo
faction_joined(faction_id: String)
faction_left(faction_id: String)
faction_world_action_completed(action: String, details: Dictionary)  # emesso da FactionActionsService
tax_collected(faction_id, amount) / tax_warning(faction_id) / tax_expelled(faction_id)
toggle_faction_screen()   # apre/chiude FactionScreen; emesso da PauseMenu.faction_screen_requested o tasto G
```

### Notification — tipi disponibili

```gdscript
Notification.faction_state(msg)           # giallo — cambio stato rep
Notification.faction_supporter_gained(msg)
Notification.faction_supporter_lost(msg)
Notification.faction_access_denied(fname) # rosso Color(0.9, 0.3, 0.25) — accesso negato
Notification.faction_action(msg)          # ciano Color(0.4, 0.85, 0.95) — azione faction world (F11+)
Notification.faction_rep_delta(name, delta) # verde/rosso — Δrep ≥5 senza cambio stato; durata 2s
Notification.wait_finished(hours, new_time) # azzurro — fine attesa; "Hai aspettato {hours} ore. {time}."
Notification.warning(msg)                 # arancio — warning generico
Notification.crime_committed()            # rosso — crimine commesso
Notification.player_arrested(fine)        # rosso — arrestato, mostra multa
Notification.crime_cleared()             # ciano — mandato cancellato
Notification.crime_safe_house()          # ciano — rifugio sicuro, mandato cancellato
```

### `data/factions/relations.json` — matrice laterale (Fase 16 completata)

Matrice **non simmetrica** faction_id → {faction_id → int}. Valori assenti = 0. Le relazioni Signorie (10 blocchi) e quelle civili principali (Milizia, Tavola, Fuorilegge) sono state completate nella Fase 16 con:
- Fazioni nemiche ↔ fazioni civili: `bestie`, `non_morti`, `demoni`, `cattedra_canone` (relazioni teologiche)
- Cross-corporazioni: `corrieri_sigillo ↔ compagnia_ponti`, `corporazione_camere ↔ milizia/banco`
- Fazioni bestie: `compagnia_bestie ↔ cacciatori_rogna`
- Natura: `mano_campi → natura`

Soglia propagazione laterale: `|rel_val| >= 20` (costante `LATERAL_THRESHOLD` in `FactionReputation.gd`).

### Schema JSON nemici — campi fazione

```jsonc
{
  "family": "humanoid",           // family biologica (non cambia)
  "faction_id": "fuorilegge",     // fazione nel sistema rep (può differire dalla family)
  "rep_on_kill": -2,              // delta diretto su faction_id al kill (default: 0); tutti e 30 i nemici popolati
  "rep_on_kill_targets": [        // effetti indiretti su altre fazioni al kill
    { "faction_id": "milizia_campane", "amount": 1 }
  ]
}
```

### Schema JSON quest — reward fazione

```jsonc
{
  "rewards": {
    "xp": 100,
    "join_faction": "corporazione_camere",  // chiama FactionMembership.join_faction()
    "faction_rep": [
      { "faction_id": "corporazione_camere", "amount": 10 }
    ]
  }
}
```

Quest senza objectives: se `"objectives": []` con `completion_mode: "turn_in"`, viene segnata ready subito al `start_quest()` (così richiede un secondo dialogo NPC per completarla).

### Schema JSON fazione joinabile — segno di riconoscimento

```jsonc
{
  "recognition_item_id": "patente_condotta",  // item_id da `data/items/factions/`
  "recognition_slot": "neck"                  // slot di GameState.equipped da controllare
}
```

Item segno (`data/items/factions/`): `loot_weight: 0` (non droppabile), `faction_sign: true`, `faction_id: <fazione>`. Item neutro senza `base_stats`.

`FactionMembership.wears_recognition_sign(id)` → `true` se membro E item corretto equipaggiato; se `recognition_item_id` è null → sempre `true`.

### Pattern passiva scalabile per rango (modello: `bestiari_della_rogna`)

`FactionEffects._apply_<passive>(rank)` è chiamata sia al join che ad ogni `advance_rank()`. Imposta sempre tutti i flag del rango corrente cancellando quelli dei ranghi superiori non ancora raggiunti. Questo garantisce che `GameState.faction_passive_flags` sia sempre consistente senza bisogno di confrontare il rank precedente.

**Convenzione flag** per fazione `<id>`:
- `<id>_flag_base: bool` — attivo dal rank 0
- `<id>_dmg_bonus_pct: int` — percentuale bonus danni
- `<id>_dmg_max_tier: int` — tier massimo nemico su cui si applica il bonus
- `<id>_improved_rewards: bool` — migliora qualità loot (via `quality_bias_bonus: 1` nel ctx LootResolver)
- `<id>_advanced_id: bool` — flag per identificazione avanzata (hook visivo futuro)

**Hook DamagePipeline** (`DamagePipeline.gd`): `FactionEffects.get_attack_mult(defender)` è chiamato prima del calcolo danno quando `player_attacks`. Legge `enemy_data_id` dal defender (via `Object.get()`), verifica il tier dal registro e restituisce il moltiplicatore.

**Hook LootResolver** (`LootResolver.gd`): il contesto può contenere `quality_bias_bonus: int`; viene sommato al `quality_bias` dei parametri della loot table. Impostato da `Enemy._generate_loot()` quando `rogna_improved_rewards` è attivo e il nemico è tier ≤ 2.

### WorldState — API world-persistent (`scripts/core/WorldState.gd`)

```gdscript
# 11.1 — Mappe dungeon depositate (collegio_cartografi)
WorldState.register_dungeon_map(map_id: String, floor_n: int)  # salva in registered_dungeon_maps
WorldState.has_registered_map(map_id: String) -> bool
WorldState.get_registered_map(map_id: String) -> Dictionary    # {floor_n, ...}
# Effetto: in BaseMap.populate(), se has_registered_map(map_id) → _seen_tiles.fill(1) (FOV bypass)

# 11.2 — Stazioni di posta (compagnia_ponti)
const POST_STATION_MIN_DIST: int = 30
WorldState.add_post_station(map_id: String, pos: Vector2i) -> bool  # false se troppo vicino
WorldState.get_post_stations_for_map(map_id: String) -> Array       # Array di {pos: {x,y}}
WorldState.has_post_station_near(map_id: String, pos: Vector2i, radius: int) -> bool

# 11.3 — Servizi convenzionati (congregazione_officine)
WorldState.open_service(location_id: String, service_type: String, data: Dictionary) -> bool
WorldState.has_service(location_id: String, service_type: String) -> bool
WorldState.get_service(location_id: String, service_type: String) -> Dictionary

# 11.4 — Safe house (tavola_senza_nome)
WorldState.register_safe_house(map_id: String, pos: Vector2i)  # emette Notification.faction_action()
WorldState.get_safe_houses_for_map(map_id: String) -> Array
WorldState.is_safe_house_location(map_id: String) -> bool
```

Tutto serializzato in `world.json` da `WorldSaveManager`. Le entity WorldState-derived (stazioni, ambulatori) vengono iniettate in `BaseMap._inject_world_persistent_entities()` chiamata al termine di `populate()`.

### FactionActionsService — azioni faction world (`scripts/core/FactionActionsService.gd`)

```gdscript
const MAP_DEPOSIT_GOLD_PER_FLOOR: int = 50
const POST_STATION_BUILD_COST:    int = 100
const AMBULATORIO_OPEN_COST:      int = 200

FactionActionsService.try_deposit_map() -> bool       # check carto_map_sellable; solo dungeon; reward oro
FactionActionsService.try_build_post_station() -> bool # check ponti_speed_bonus; 100g; distanza 30 tiles
FactionActionsService.try_open_ambulatorio() -> bool   # check officine_advanced_care; 200g; city/village
FactionActionsService.try_reduce_bounty_tsn() -> bool  # check tsn_bounty_reduction + 200g → CrimeSystem.clear_crime(city_id)
```

Trigger doppio: `Main._unhandled_input()` (F5/F6/F7) + `NPC.interact()` via `faction_action_id`.  
Acceduto via `get_node_or_null("/root/FactionActionsService")` per evitare errori LSP prima dell'indicizzazione.

### Fazioni joinabili — riepilogo implementate

| Fazione | Passive | Segno | Slot | Flag chiave | Hook deferred |
|---------|---------|-------|------|-------------|---------------|
| `corporazione_camere` | `patente_di_condotta` | `patente_condotta` | `neck` | `contract_access`, `camere_xp_bonus_pct` | UI archivio (Fase 15), tasse (Fase 12) |
| `cacciatori_rogna` | `bestiari_della_rogna` | `distintivo_cacciatore` | `trinket` | `rogna_dmg_bonus_pct`, `rogna_improved_rewards` | quirk infestation (Fase 10) |
| `collegio_cartografi` | `senso_cartografico` | `borsa_mappe` | `cloak` | `carto_fov_bonus`, `carto_map_purchase` | FOV hook, mappa world-persistent (Fase 10) |
| `compagnia_ponti` | `diritto_di_strada` | `spilla_strade` | `neck` | `ponti_speed_bonus`, `ponti_toll_discount` | overworld speed, stazioni posta (Fase 10) |
| `corrieri_sigillo` | `portatore_di_sigillo` | `anello_corrieri` | `ring_1` | `corrieri_quest_gold_bonus` | carovane, mount (Fase 10) |
| `congregazione_officine` | `arte_della_guarigione` | `fascia_officine` | `neck` | `officine_potion_discount`, `officine_hp_regen_bonus` | sconto NPC (Fase 12), regen hook |
| `tavola_senza_nome` | `rete_oscura` | `token_oscuro` | `trinket` | `tsn_black_market`, `tsn_bounty_reduction` | crime system (Fase 11) |

Item segni: tutti in `data/items/factions/`, `loot_weight: 0`, `faction_sign: true`. `token_oscuro` ha anche `faction_sign_hidden: true`.

---

### FactionScreen — `scripts/ui/FactionScreen.gd`

Pure-code `CanvasLayer` (layer=8), nessuna TSCN (stesso pattern di ClassPickerPanel/ClassRespecScreen).

- **Apertura**: `EventBus.toggle_faction_screen.emit()` oppure `PauseMenu.faction_screen_requested` → `Main._open_faction_screen()` → `FactionScreen.open()`; tasto G in Main._unhandled_input o in PauseMenu._unhandled_input
- **Tab**: Civili (`"civil"`) / Signorie (`"signoria"`) / Nemici (`"nemico"` + `"natura"` unificati)
- **Lista sinistra** (260 px, scrollabile): riga per fazione con nome, badge M/S se membro/supporter, stato colorato, barra ProgressBar rep -100…+100
- **Pannello dettaglio destra**: nome bold + stato + rep numerico, descrizione JSON, rango + passiva corrente (se membro), debito tasse (se presente), lista "Membri conosciuti" da `GameState.known_faction_members[fid]`
- **Chiusura**: G o Esc in `_unhandled_input`; `_go_to_main_menu()` forza `visible = false`
- **Colori stato** (costante `STATE_COLORS`): enemy_sworn=rosso scuro, hostile=arancio scuro, neutral=grigio, friendly=verde, allied=azzurro, trusted=oro

---

## Debug Tools

**DebugScreen** (`scripts/debug/DebugScreen.gd`) — accessibile in-game (tasto È).

Sezioni statiche (aggiornate ogni 0.5s da timer):
- **Sistema / ClassRegistry / GameState / ClassPicker / DamagePipeline / ClassRuntime / AbilityUseTracker / ClassSpecial / StatusEffects / Targeting / AllyManager / DruidForm / Milestones / Respec / LootDB / FactionDB / Time System**

`Time System` mostra: `total_minutes`, `world_time` (H:MM), `slot`, `display` (stringa localizzata), `abs_day`, data calendario (gg/mese/anno), `map_type` corrente, `action_costs` M/A/I/W, stato `WaitScreen` (se aperta), testo di `HUD/TimeLabel`.

Sezioni interattive (costruite una volta in `_build_*`, display aggiornato da `_refresh()`):
- **TTK Sim** → `CombatSimulator.run_validation()`
- **LootTools** — simula drop nemico/chest/ground, genera istanze, apre LootScreen, testa idempotenza identify, invalida cache
- **DevClassSwitch** — griglia per tier con bottoni per ogni classe (colore per tier, grigio = planned)
- **Validatori JSON** — esegue `validate_items/affixes/loot_tables/classes.gd` e mostra risultato inline
- **TimeTools** — `+1h` / `+8h` / `+1 giorno` (`TimeManager.advance(N)`) + `Reset` (`total_minutes = 480`); header collassabile azzurro
- **FactionTools** *(Fase 16)* — blocco collassabile viola:
  - *Rep table* (`_faction_rep_rtl`) — tutte le fazioni con rep numerica + colore per stato (`STATE_HEX`) + badge `M[rank]`/`S`
  - *Rep editor* — `OptionButton` (sorted) + delta ±10/±25/±50 + `CheckButton` propagazione + "Reset All Rep"
  - *Membership* — `_faction_member_rtl` ◆/★/○ per le 7 joinabili + bottoni Join/Leave/+Rank

**Costanti DebugScreen rilevanti:**
```gdscript
const STATE_HEX := { "enemy_sworn": "#d92525", "hostile": "#d97325", "neutral": "#aaaaaa",
                     "friendly": "#66d877", "allied": "#4db3ff", "trusted": "#e5cc33" }
const JOINABLE_FACTIONS: Array[String] = [
    "corporazione_camere", "cacciatori_rogna", "collegio_cartografi",
    "compagnia_ponti", "corrieri_sigillo", "congregazione_officine", "tavola_senza_nome" ]
```

**CombatSimulator** (`scripts/tools/CombatSimulator.gd`)  
Testa ogni nemico a `zone_min_level` contro i 4 profili classe.  
Verdict da profili primari (melee_bruiser, caster_burst) — secondari sono informativi.

### Validatori JSON (editor tool) — `scripts/tools/validators/`

Eseguire in Godot: apri il file → **File > Run Script**. Output nel pannello Output del motore. Non usano autoload: caricano i JSON direttamente via `FileAccess`/`DirAccess`.

| Script | Scansiona | Checks principali |
|--------|-----------|-------------------|
| `validate_items.gd` | `data/items/` + `items.json` | id unici, item_category/type validi, slot presente, scalable→scale+mode, consumable→effect, key_item→droppable/sellable false |
| `validate_affixes.gd` | `data/item_affixes/` | id unici, type prefix/suffix, allowed_item_types validi e non vuoti, allowed_tiers validi, bonuses non vuoto, weight > 0 |
| `validate_loot_tables.gd` | `data/loot/` | chest ha 5 varianti, level_bands senza gap, ultima a 999, item_id esistono, nothing weight ≤ 10 per chest |
| `validate_classes.gd` | `data/classes/` | noob ha noob_adaptability, non-noob hanno allowed_item_types non vuoto con tipi validi, loot_archetype → cartella esistente |

---

## Sistema Crimini — CrimeSystem

### Flusso crimine
1. Player attacca NPC → `CombatManager` controlla `amuleto_del_sangue` (slot neck via `Equipment.is_equipped()`)
2. Se equipaggiato: `CrimeSystem.track_attacked_npc(npc)` + check testimoni via `has_witnesses(player_pos)`
3. Se testimoni: `register_crime(city_id)` → rep -20 milizia, spawn 6 guardie, emette `crime_committed`
4. Guardie attaccano normalmente; se HP player ≤ 1 → `arrest_player(city_id)` → multa 25%, record, rep -10
5. Ondate: ogni 8 turni con crimine attivo → +3 guardie (via `EventBus.player_turn_started`)
6. Fuga dalla città (→overworld/dungeon) → `apply_post_crime_rep_on_flee()` → -50 rep a tutte le fazioni nel raggio 30 o attaccate
7. Rientro in città con crimine attivo → spawn nuova pattuglia

### Guard (`scripts/entities/Guard.gd`)
- `extends Enemy`, `is_guard: bool = true`
- `setup_guard(player_level)` → stats guerriero scalate
- `die()` → niente XP/loot/rep; solo `TurnManager.unregister_enemy + queue_free`

### Amuleto del Sangue
- File: `data/items/accessories/amulets/amuleto_del_sangue.json`
- Slot: `neck`, `loot_weight: 0` (non droppabile casualmente)
- Necessario per attaccare NPC; assenza → warning + blocco

### EventBus signals (crime)
```gdscript
EventBus.crime_committed(city_id: String)
EventBus.player_arrested(city_id: String, fine_amount: int)
EventBus.crime_cleared(city_id: String)
```

### Identificazione entità (duck typing)
- NPC: `node.get("npc_id") != null`
- Enemy (incluse guardie): `node.get("enemy_data_id") != null`
- Guard specifica: `node.get("is_guard") == true`

---

## Gotcha / Pattern importanti

- `Node.get(prop)` accetta **1 solo argomento** (diverso da `Dictionary.get(key, default)`)
- Duck-type check entità: `entity.get("enemy_data_id") != null`  
- `_draw_entities()` itera `map.get_children()` — NON `_entities` — quindi include anche porte/chest
- `BaseMap._entities` viene filtrato da `is_instance_valid` in `get_entity_at()` (lazy cleanup)
- Danno simulato usa `p_atk` raw per il calcolo, `hit_stat = floor((atk+dex)/2)` solo per l'accuratezza
- Enemy level nel gioco = `clamp(GameState.level + floor_bonus + (tier-3), zone_min, zone_max)`
- `lf(1) = 2.4` — usato come base per scalare hp_base a qualsiasi livello
- Coordinate griglia: `WorldManager.grid_to_world(pos)` = `pos * TILE_SIZE`
- Mouse → griglia: `camera_transform.affine_inverse() * screen_pos`, poi `/ CELL`

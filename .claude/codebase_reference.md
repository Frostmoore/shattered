# Shattered — Codebase Reference

Godot 4.4 · GDScript · roguelike ASCII turn-based · CELL = 16 px

---

## Autoload / Singleton

| Nome | File | Ruolo |
|------|------|-------|
| `LocaleManager` | `scripts/core/LocaleManager.gd` | i18n runtime: carica CSV da `locales/`; `t(key, params?)`, `t_or(key, fallback, params?)` |
| `GameState` | `scripts/core/GameState.gd` | Stato globale del run (livello, stats, mappa corrente, inventario) |
| `WorldManager` | `scripts/core/WorldManager.gd` | Mappa attiva, cambio mappa |
| `LocationRegistry` | `scripts/world/LocationRegistry.gd` | Registro stati per-mappa (fog, morti, porte, cadaveri) |
| `SaveManager` | `scripts/core/SaveManager.gd` | Entry point save/load |
| `WorldSaveManager` | `scripts/core/WorldSaveManager.gd` | Serializza LocationRegistry + metadati mondo |
| `TurnManager` | `scripts/core/TurnManager.gd` | Gestione turni giocatore/nemici |
| `CombatManager` | `scripts/combat/CombatManager.gd` | Attacchi, calcolo hit, FloatingText |
| `DamagePipeline` | `scripts/combat/DamagePipeline.gd` | Catena di modificatori danno, chiama `take_damage()` |
| `EnemyRegistry` | *(autoload)* | Lookup dati nemici da JSON; `get_enemy_data(id)`, `get_display_name(id)` |
| `AffixRegistry` | *(autoload)* | Lookup affissi nemici; `get_affix(id)`, `get_display_prefix(id)` |
| `ClassRegistry` | `scripts/classes/ClassRegistry.gd` | Lookup dati classi da JSON; `get_class_data(id)`, `get_display_name/desc/special_name/special_desc(id)` |
| `EventBus` | `scripts/core/EventBus.gd` | Tutti i signal globali |
| `LevelSystem` | *(autoload)* | XP, level-up |
| `QuestManager` | `scripts/dialogue/QuestManager.gd` | Quest attive/completate |
| `BalanceCombat` | `scripts/core/game_balance/BalanceCombat.gd` | Costanti di bilanciamento combattimento |
| `GameBalance` | *(autoload)* | FOV radius, memory alpha, ecc. |
| `ItemDB` | `scripts/items/ItemDB.gd` | Scan ricorsivo `data/items/`; `get_item(id)`, `get_by_type(t)`, `get_by_slot(s)`, `pick_random(cat, lv, min_quality)`, `get_display_name(id)`, `get_display_description(id)` |
| `ItemAffixDB` | `scripts/items/ItemAffixDB.gd` | Scan ricorsivo `data/item_affixes/`; `get_affix(id)`, `get_eligible(item_type, lv, quality)`, `get_display_name(id, gender)` |
| `LootTableDB` | `scripts/items/LootTableDB.gd` | Lazy load `data/loot/`; `get_enemy(class_id, tier, profile)`, `get_chest(class_id, tier)`, `get_ground(class_id, tier)`; fallback `class_id → archetypes/{archetype} → default` |
| `ItemGenerator` | `scripts/items/ItemGenerator.gd` | `drop(base_id, lv, rng, quality_bias)`, `identify(instance, lv)`, `resolve_stats(instance, lv)`, `get_quality_color(q)`, `get_id_threshold(q)` |
| `LootResolver` | `scripts/items/LootResolver.gd` | `resolve(ctx: Dictionary) → Array`; legge `drop_context`, risolve loot table, restituisce array di drop (item instance o `{type:"gold", amount:N}`) |
| `LootScreen` | `scripts/ui/LootScreen.gd` | CanvasLayer layer 80; si apre via `EventBus.loot_screen_open`; griglia con item, tooltip qualità, take-single, take-all, chiudi (Esc); blocca `_can_act` del player |
| `ItemTooltipBuilder` | `scripts/items/ItemTooltipBuilder.gd` | Classe statica. `build_instance(entry, qty)`, `build_instance_compare(entry, qty, compare_stats)`, `build_legacy(item_id, data, qty)`, `build_gold(amount)`, `build_empty_slot(slot_name)` → BBCode string per `RichTextLabel`. |
| `Inventory` | `scripts/items/Inventory.gd` | Autoload. `add_item(id, qty)`, `remove_item(id, qty)`, `has_item(id, qty)`, `add_item_instance(instance)`, `identify_instance(instance_id, lv)`, `use_item(id)` |
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
locales/strings_ui.csv         — UI, HUD, menu, notifiche generiche
locales/strings_notifications.csv
locales/strings_data.csv       — tooltip stat, slot display, quality labels
locales/strings_dialogue.csv
locales/strings_classes.csv    — nomi/descrizioni delle 60 classi
locales/strings_items.csv      — nomi item base + affissi item (name_m/name_f)
locales/strings_enemies.csv    — nomi nemici, role/family label, affissi nemici
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
GameState.level                  # int, livello corrente
GameState.xp                     # int
GameState.current_map_id         # String, es. "dungeon_floor_1"
GameState.player_position        # Vector2i
GameState.player_stats           # {hp, max_hp, mp, max_mp, stamina, attack, defense, gold}
GameState.base_attributes        # {str, dex, int, vit, wil} — crescono con level-up
GameState.class_bonus            # {str,…} — bonus fisso classe corrente (sostituito, mai accumulato)
GameState.effective_attributes   # base + class_bonus — usati dal gioco
GameState.current_class          # String, es. "warrior"
GameState.inventory              # Array di item dict
GameState.equipped               # {head, body, left_hand, right_hand, ring_1, ring_2, neck, feet, cloak, trinket, hands}
GameState.quick_slots            # Array[String] di 3 item_id (slot rapidi consumabili)
GameState.world_flags            # {intro_completed, dungeon_boss_defeated, …}
GameState.run_milestones         # {kills, deaths, save_points_used, …}
```

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
3. `LocationRegistry.get_or_generate(location_id)` → genera se prima visita
4. `scene.instantiate()` → `populate(data, state)` → `add_child`

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

# Metodi chiave
populate(data: MapData, state: LocationState)   # chiamato da WorldManager prima di add_child
save_location_state()                           # flush → LocationRegistry (chiamato prima di cambiare mappa o salvare)
get_entity_at(pos: Vector2i) -> Node
is_walkable(pos: Vector2i) -> bool
is_tile_visible(pos: Vector2i) -> int           # 1 = in FOV
is_tile_seen(pos: Vector2i) -> int              # 1 = mai visto
add_corpse(pos: Vector2i, color: Color)
respawn_non_boss_enemies()                      # chiamato da save point; svuota anche _corpses
```

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

Registrato in `LocationRegistry` come tipo `"city"`.

---

## Save / Load

### Flusso salvataggio

```
SaveManager.save_game()
  └─ WorldSaveManager.save_world(world_name)      # serializza LocationRegistry
  └─ _save_character(world_name, char_name)
       └─ current_map.save_location_state()       # flush mappa corrente prima di serializzare
       └─ scrive {level, xp, stats, inventory, position, …} in user://saves/<world>/<char>.json
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
  └─ _load_character(…)                         # ripristina GameState
→ WorldManager.change_map(GameState.current_map_id, GameState.player_position)
```

---

## Entità

### Gerarchia

```
Entity (scripts/entities/Entity.gd)       ← Node2D, classe base
  ├── Enemy  (scripts/entities/Enemy.gd)
  ├── Player (scripts/entities/Player.gd)
  ├── Ally   (scripts/entities/Ally.gd)
  ├── NPC    (scripts/entities/NPC.gd)
  ├── Door   (scripts/entities/Door.gd)
  └── Chest  (scripts/entities/Chest.gd)
```

### Entity — campi rilevanti

```gdscript
grid_position: Vector2i
hp, max_hp, attack, defense, dex: int
is_dead: bool
faction: String          # "player" | "enemy" | "neutral"
entity_char: String      # carattere ASCII (impostato in _setup_visual)
entity_color: Color      # colore originale (impostato in _setup_visual)
display_name: String

take_damage(amount)      # chiama die() se hp <= 0
die()                    # imposta is_dead=true, queue_free()
_setup_visual(char, col) # crea Label figlio con il carattere ASCII
```

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

### Flusso attacco

```
CombatManager.attack(attacker, defender)
  └─ _calc_hit() → {chance, is_dodge}
  └─ se hit: DamagePipeline.execute(DamageContext)
       └─ modifica base_damage attraverso la catena
       └─ ctx.defender.take_damage(final_damage)
            └─ Entity.die() se hp <= 0
```

### TurnManager

```gdscript
TurnManager.is_active: bool
TurnManager.is_player_turn: bool
TurnManager.activate(enemies)        # avvia combattimento
TurnManager.deactivate()             # fine combattimento (tutti i nemici morti)
TurnManager.on_player_action_done()  # scatena turni alleati + nemici
TurnManager.unregister_enemy(enemy)  # rimosso da die()
```

---

## Bilanciamento Combattimento

### Costanti — `BalanceCombat` (`scripts/core/game_balance/BalanceCombat.gd`)

```gdscript
DAMAGE_K: float = 5.0          # divisore danno
DAMAGE_MIN: int = 1            # danno minimo garantito
BASE_HIT_CHANCE: float = 0.75  # a parità di stat
ACCURACY_K: float = 0.02       # delta hit per punto di stat
MIN_HIT_CHANCE: float = 0.10
MAX_HIT_CHANCE: float = 0.95

level_factor(level) -> float   # = 2*level/5 + 2.0  (lf(1)=2.4)
```

### Formule danni (CombatSimulator)

```
lf       = level_factor(level)
p_atk    = class attack stat at level   (usato per il danno)
p_dex    = class dex stat at level
hit_stat = floor((p_atk + p_dex) / 2)  # melee/magic
         = p_dex                        # ranged

hit_chance = clamp(BASE_HIT_CHANCE + (hit_stat - e_dex) * ACCURACY_K, 0.10, 0.95)
p_dmg      = max(DAMAGE_MIN, floor(lf * p_atk / max(1.0, e_def) / DAMAGE_K))
e_hp_scaled = round(hp_base * lf / lf(1))
TTK        = ceil(e_hp_scaled / (hit_chance * p_dmg))
```

**Nota critica:** `max(1, def)` — def=0 e def=1 producono lo stesso danno.  
Il simulatore usa `def_base` raw (senza growth). Tenere `def_base` basso (≤ 2) e usare `def_growth` per la progressione.

### Target TTK per ruolo

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

### Profili classe (ClassCombatProfile — `scripts/tools/ClassCombatProfile.gd`)

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

---

## Rendering — `scripts/world/MapRenderer.gd`

- `z_index = -5` — disegna sotto i nodi Label delle entità (z=0)
- Trigger redraw: `enemy_died`, `player_moved`, `map_changed`, `turn_ended`
- FOV attivo per `dungeon` e `overworld`; village sempre illuminato
- Overworld: raggio variabile (base 15, modificato da bioma e classe), fog of war per-personaggio via `explored_tiles` bitmask in GameState (non in LocationState)
- `FOV_MEMORY_ALPHA`: moltiplicatore colore per tile viste ma fuori FOV

Ordine di rendering in `_draw()`:
1. Background rect
2. Tile floor/wall (con dim per memoria FOV)
3. `_draw_corpses()` — carattere `_` con `color.darkened(0.5)` dell'enemy
4. `_draw_entities()` — mostra/nasconde Label delle entità vive in base a FOV

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
```

---

## Debug Tools

**DebugScreen** (`scripts/debug/DebugScreen.gd`) — accessibile in-game (tasto È).

Sezioni:
- **TTK Sim** → `CombatSimulator.run_validation()` — stampa TTK per tutti i nemici
- **LootDB** — mostra item/affissi/cache caricati; si aggiorna ogni 0.5s
- **LootTools** — strumenti test loot:
  - *Simula nemico/chest/ground* — risolve una loot table e stampa i drop nell'Output
  - *Drop spada_corta* / *Drop unico* — genera un'istanza item e la identifica, stampa risultato
  - *Apri LootScreen* — apre la schermata loot con 6 item di test (incluso unico + oro)
  - *Test identificazione* — verifica che lo stesso `affix_seed` produca sempre gli stessi affissi
  - *Invalida cache loot* — svuota `LootTableDB._cache` per ricaricare i file JSON da disco
- **DevClassSwitch** — cambia classe al volo

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

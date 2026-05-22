# Shattered — Codebase Reference

Godot 4.4 · GDScript · roguelike ASCII turn-based · CELL = 16 px

---

## Autoload / Singleton

| Nome | File | Ruolo |
|------|------|-------|
| `GameState` | `scripts/core/GameState.gd` | Stato globale del run (livello, stats, mappa corrente, inventario) |
| `WorldManager` | `scripts/core/WorldManager.gd` | Mappa attiva, cambio mappa |
| `LocationRegistry` | `scripts/world/LocationRegistry.gd` | Registro stati per-mappa (fog, morti, porte, cadaveri) |
| `SaveManager` | `scripts/core/SaveManager.gd` | Entry point save/load |
| `WorldSaveManager` | `scripts/core/WorldSaveManager.gd` | Serializza LocationRegistry + metadati mondo |
| `TurnManager` | `scripts/core/TurnManager.gd` | Gestione turni giocatore/nemici |
| `CombatManager` | `scripts/combat/CombatManager.gd` | Attacchi, calcolo hit, FloatingText |
| `DamagePipeline` | `scripts/combat/DamagePipeline.gd` | Catena di modificatori danno, chiama `take_damage()` |
| `EnemyRegistry` | *(autoload)* | Lookup dati nemici da JSON |
| `AffixRegistry` | *(autoload)* | Lookup affissi nemici |
| `EventBus` | `scripts/core/EventBus.gd` | Tutti i signal globali |
| `LevelSystem` | *(autoload)* | XP, level-up |
| `QuestManager` | `scripts/dialogue/QuestManager.gd` | Quest attive/completate |
| `BalanceCombat` | `scripts/core/game_balance/BalanceCombat.gd` | Costanti di bilanciamento combattimento |
| `GameBalance` | *(autoload)* | FOV radius, memory alpha, ecc. |

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
GameState.equipped               # {helm, armor, left_hand, right_hand, ring_1, ring_2, amulet, boots, cloak, accessory}
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

### MapData — struttura dati mappa

Generata da `DungeonGenerator` / `VillageGenerator` / ecc.  
Contiene: `walls`, `transitions`, `entity_defs` (kind, pos, params, uid).

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
Calibrazione TTK verificata con `CombatSimulator.run_validation()`.

---

## Rendering — `scripts/world/MapRenderer.gd`

- `z_index = -5` — disegna sotto i nodi Label delle entità (z=0)
- Trigger redraw: `enemy_died`, `player_moved`, `map_changed`, `turn_ended`
- FOV attivo solo per mappe `dungeon`; overworld/village sempre illuminati
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

**DebugScreen** (`scripts/debug/DebugScreen.gd`) — accessibile in-game.

Pulsanti rilevanti:
- **TTK Sim** → `CombatSimulator.run_validation()` — stampa tabella TTK per tutti i nemici nell'Output panel
- **Map Info** — stato mappa corrente
- **Player Stats** — dump stats giocatore

**CombatSimulator** (`scripts/tools/CombatSimulator.gd`)  
Testa ogni nemico a `zone_min_level` contro i 4 profili classe.  
Verdict da profili primari (melee_bruiser, caster_burst) — secondari sono informativi.

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

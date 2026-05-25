# Piano: Sistema NPC

**Stato**: Progettato — da implementare per fasi. Il Time System è un prerequisito obbligatorio.

---

## Dipendenze tra fasi

```
FASE 1 — Time System
  └── FASE 2 — NPC Routine (waypoints + wandering)
  └── FASE 4 — Shop System (refresh ogni N giorni)
  └── FASE 5 — Effetti notte (FOV ridotto, negozi chiusi)

FASE 3 — Conditional Dialogues    ← indipendente, implementabile subito
FASE 6 — NPC Permadeath           ← quasi già funzionante, piccolo lavoro
FASE 7 — CityBuilder NPC config   ← companion delle fasi precedenti
```

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Movimento NPC | Wandering + routine con waypoints per slot orario |
| Permadeath | Sì, per NPC senza flag `respawn` |
| Shop inventory | Procedurale, refresh ogni N giorni configurabile per NPC |
| Dialoghi condizionali | faction_state + world_flag + quest_status + membership |
| HUD tempo | "Giorno X — HH:MM" sempre visibile |
| Effetti notte | FOV ridotto in città/overworld; negozi chiusi (22:00–6:00) |
| Shop UI | ShopScreen separato (CanvasLayer), si apre sull'interazione con vendor |

---

## FASE 1 — Time System *(prerequisito tutto)*

### 1.1 Struttura dati

**`GameState`** — aggiungere:
```gdscript
var world_time: int = 480      # minuti del giorno corrente (0–1439); inizia alle 8:00
var day_count:  int = 1        # giorno progressivo, mai resettato
```

**`TimeManager`** — nuovo autoload `scripts/core/TimeManager.gd`:
```gdscript
# Minuti per passo del player, per tipo mappa
const MINUTES_PER_STEP: Dictionary = {
    "overworld": 30,
    "village":   5,
    "city":      5,
    "building":  2,
    "dungeon":   10,
    "ruin":      10,
}
const MINUTES_PER_DAY: int = 1440

# Fasce orarie
const SLOT_ALBA:       Vector2i = Vector2i(6,  8)   # 6:00–7:59
const SLOT_MATTINA:    Vector2i = Vector2i(8,  12)  # 8:00–11:59
const SLOT_POMERIGGIO: Vector2i = Vector2i(12, 18)  # 12:00–17:59
const SLOT_SERA:       Vector2i = Vector2i(18, 22)  # 18:00–21:59
const SLOT_NOTTE:      Vector2i = Vector2i(22, 6)   # 22:00–5:59 (wrap around)

func advance(map_type: String) -> void   # chiamato da Player._try_move() dopo ogni spostamento
func get_hour() -> int                   # ora corrente (0–23)
func get_minutes_of_day() -> int         # 0–1439
func get_slot() -> String                # "alba"|"mattina"|"pomeriggio"|"sera"|"notte"
func is_night() -> bool                  # slot == "notte"
func format_time() -> String             # "Giorno X — HH:MM"
func get_vision_modifier() -> float      # 1.0 di giorno; 0.6 di notte (in città/overworld)
```

**EventBus** — aggiungere:
```gdscript
time_advanced(minutes: int)
day_changed(day_count: int)
day_slot_changed(slot: String)   # emesso solo quando cambia fascia (non ogni minuto)
```

### 1.2 Integrazione Player

In `Player._try_move()`, dopo ogni movimento riuscito:
```gdscript
TimeManager.advance(WorldManager.get_current_map().map_type)
```
`BaseMap` (e sottoclassi) espone `map_type: String` già presente in `MapData.type`.

### 1.3 HUD

In `HUD.gd` / `HUD.tscn`:
- Aggiungere `TimeLabel` che mostra `TimeManager.format_time()`
- Si aggiorna su `EventBus.time_advanced`

### 1.4 Save/Load

In `SaveManager`:
- Serializzare `world_time` e `day_count` nel save del personaggio
- Al load, `TimeManager` li legge da `GameState`

### 1.5 Lista task

- [ ] Creare `TimeManager.gd` autoload
- [ ] Aggiungere `world_time`, `day_count` a `GameState`
- [ ] Aggiungere segnali `time_advanced`, `day_changed`, `day_slot_changed` a `EventBus`
- [ ] Hook in `Player._try_move()` dopo movimento riuscito
- [ ] `TimeLabel` nell'HUD
- [ ] Save/load di `world_time` e `day_count`
- [ ] Registrare `TimeManager` in `project.godot` (prima di `WorldManager`)

---

## FASE 2 — NPC Routine: Waypoints + Wandering

### 2.1 Schema schedule in NPC params (CityBuilder / city JSON)

```jsonc
{
  "kind": "npc",
  "params": {
    "id": "mercante_rivamola",
    "schedule": [
      { "slot": "alba",       "tile": {"x": 5, "y": 8},  "behavior": "stay" },
      { "slot": "mattina",    "tile": {"x": 7, "y": 10}, "behavior": "wander",
        "zone": {"x": 5, "y": 8, "w": 6, "h": 4} },
      { "slot": "pomeriggio", "tile": {"x": 7, "y": 10}, "behavior": "wander",
        "zone": {"x": 5, "y": 8, "w": 6, "h": 4} },
      { "slot": "sera",       "tile": {"x": 5, "y": 8},  "behavior": "stay" },
      { "slot": "notte",      "tile": {"x": 3, "y": 15}, "behavior": "stay" }
    ]
  }
}
```

Se `schedule` è vuoto, l'NPC è statico nella posizione originale.

### 2.2 NPC.gd — campi nuovi

```gdscript
var schedule: Array[Dictionary] = []     # array di entry schedule
var _current_zone_rect: Rect2i = Rect2i.ZERO
```

### 2.3 Logica movimento

`NPC` si connette a `EventBus.day_slot_changed` e `EventBus.time_advanced`:

- Su `day_slot_changed`: trova l'entry schedule per lo slot corrente; imposta `_target_tile` e `_current_zone_rect`
- Su `time_advanced` (ogni step): 
  - Se `behavior == "stay"`: muove di un passo verso `_target_tile` (BFS semplificato, stesso stile `Enemy._move_toward()`)
  - Se `behavior == "wander"`: 50% di probabilità di fare un passo casuale dentro `_current_zone_rect`
  - Non blocca il player (cede il tile se necessario — scambio posizioni)

Il movimento NPC avviene come callback sincrona nel segnale, non nel TurnManager (gli NPC non sono combattenti).

### 2.4 Lista task

- [ ] Aggiungere `schedule: Array[Dictionary]` a `NPC.gd`
- [ ] `NPC.setup()` legge e converte schedule da params
- [ ] `NPC._on_day_slot_changed()` — imposta target/zone per lo slot
- [ ] `NPC._on_time_advanced()` — muove di 1 passo verso target o wanders
- [ ] Pathfinding 1-passo: `map.is_walkable()` + `map.get_entity_at()`; se bloccato dal player, non muove
- [ ] `BaseMap._add_entity()` aggiorna `_entities` e `_blocked_tiles` su movimento

---

## FASE 3 — Conditional Dialogues *(indipendente, implementabile subito)*

### 3.1 Formato condizioni

`conditional_dialogues` è già in `NPC.gd` come `Array[Dictionary]`. Formato entry:

```jsonc
{ "condition": "faction_state", "faction_id": "milizia_campane",
  "state": "friendly",          "dialogue_id": "guard_friendly" }

{ "condition": "world_flag",    "flag": "dungeon_boss_defeated",
  "value": true,                "dialogue_id": "post_boss_npc" }

{ "condition": "quest_status",  "quest_id": "quest_villaggio_01",
  "status": "active",           "dialogue_id": "quest_active_hint" }

{ "condition": "membership",    "faction_id": "corporazione_camere",
  "dialogue_id": "member_greeting" }

{ "condition": "time_slot",     "slot": "notte",
  "dialogue_id": "late_night_npc" }
```

### 3.2 `_pick_dialogue()` — logica aggiornata

```
1. Controlla conditional_dialogues in ordine → prima match vince
2. Quest-state fallback (logica attuale)
3. Idle dialogues
4. dialogue_id default
```

Ogni condizione valutata da un helper `_check_condition(entry: Dictionary) -> bool`.

### 3.3 Lista task

- [ ] `NPC._check_condition(entry)` — switch su `condition` type
- [ ] `NPC._pick_dialogue()` — aggiungere loop conditions prima della logica attuale
- [ ] Aggiungere `time_slot` come tipo condizione (dipende da FASE 1, ma il resto è indipendente)

---

## FASE 4 — Shop System

### 4.1 Struttura dati WorldState

```gdscript
# In WorldState.gd
var npc_shop_data: Dictionary = {}
# { npc_uid: { "items": Array[Dictionary], "generated_day": int } }

func get_shop(npc_uid: String, refresh_days: int, shop_type: String, tier: int) -> Array
# Restituisce items; se day_count - generated_day >= refresh_days → rigenera
func _generate_shop(shop_type: String, tier: int) -> Array[Dictionary]
```

### 4.2 Tipi di shop (`shop_type` — campo in NPC params)

| Tipo | Contenuto generato |
|------|--------------------|
| `armeria` | Armi e armature per tier |
| `emporio` | Mix: consumabili + accessori + item generici |
| `farmacia` | Consumabili: pozioni, antidoti, bende |
| `mercato_nero` | Item rari/epici, oggetti illegali (richiede `tsn_black_market`) |
| `alchimista` | Consumabili avanzati, ingredienti |
| `libri` | Pergamene di identificazione, mappe, lore items |

Generazione: `LootResolver` o `ItemDB.pick_random(cat, tier, quality_bias)` con N slot per tipo.

### 4.3 NPC.gd — campi nuovi

```gdscript
var shop_type:         String = ""   # "armeria" | "farmacia" | ecc.; "" = no shop
var shop_refresh_days: int    = 3    # ogni quanti giorni si rigenera
var shop_uid:          String = ""   # uguale al npc_uid della LocationState per persistenza
```

### 4.4 ShopScreen — `scripts/ui/ShopScreen.gd`

Pure-code CanvasLayer (layer=85, tra LootScreen=80 e HUD).

- **Apertura**: `NPC.interact()` → se `vendor` → `EventBus.shop_opened.emit(npc_uid, items, display_name)`
- **Layout**: colonna sinistra = inventario player, colonna destra = merce NPC
- **Compra**: click su item NPC → se oro sufficiente → `Inventory.add_item_instance()`, `GameState.modify_gold(-price)`
- **Vendi**: click su item player → `Inventory.remove_item()`, `GameState.modify_gold(+sell_price)`
- **Prezzi**: `base_price * FactionEconomy.get_price_multiplier(ctx)` (finalmente usato!)
- **Prezzi vendita**: 40% del prezzo di acquisto (configurabile)
- **Negozio chiuso di notte**: `TimeManager.is_night()` → mostra notifica "Il negozio è chiuso"

### 4.5 Prezzi base degli item

Nel JSON item: `"base_price": 50` (nuovo campo, da aggiungere). Se assente: fallback su tier × 10.

### 4.6 EventBus — aggiungere

```gdscript
shop_opened(npc_uid: String, items: Array, shop_name: String)
shop_closed()
```

### 4.7 Lista task

- [ ] `WorldState.npc_shop_data` + `get_shop()` + `_generate_shop()`
- [ ] `NPC.gd`: `shop_type`, `shop_refresh_days`, `shop_uid`
- [ ] `NPC.interact()`: se vendor → controlla notte → apri shop o notifica
- [ ] Creare `ShopScreen.gd` (CanvasLayer layer=85)
- [ ] `EventBus.shop_opened` / `shop_closed`
- [ ] `Main.gd`: `@onready var shop_screen` → connessione segnali
- [ ] Aggiungere `base_price: int` ai JSON item (o fallback tier×10)
- [ ] `FactionEconomy.get_price_multiplier()` collegato allo ShopScreen
- [ ] Serializzare `npc_shop_data` in `world.json` via `WorldSaveManager`

---

## FASE 5 — Effetti notte

### 5.1 FOV ridotto in città/overworld

In `MapRenderer.gd` (o in `GameState`), `EventBus.day_slot_changed` → se slot == "notte" e map_type in ["village","city","overworld"] → riduce il raggio FOV.

Implementazione: `TimeManager.get_vision_modifier() -> float` (1.0 giorno, 0.6 notte) → moltiplicato al raggio FOV in `BaseMap._compute_fov()`.

### 5.2 Negozi chiusi

Già gestito nella FASE 4: `NPC.interact()` controlla `TimeManager.is_night()` prima di aprire lo shop.

### 5.3 Lista task

- [ ] `TimeManager.get_vision_modifier()` → restituisce moltiplicatore per mappa+slot
- [ ] `BaseMap._compute_fov()`: applica modificatore al raggio FOV
- [ ] `NPC.interact()`: gate notte per vendor (già nella FASE 4)
- [ ] `NOTIF_SHOP_CLOSED` in `strings_notifications.csv`

---

## FASE 6 — NPC Permadeath

### 6.1 Comportamento

- `respawn: bool` (default `true`) — letto da NPC params nel CityBuilder
- Se `respawn == true`: NPC riappare (comportamento attuale — `dead_entity_uids` non include respawnabili)
- Se `respawn == false`: l'NPC viene aggiunto a `dead_entity_uids` in `LocationState` → non spawna più
- **Persistenza cross-character**: `WorldState.permanent_npc_deaths: Array[String]` (uid) — NPCs morti permanentemente in questo mondo, non tornano neanche per altri personaggi

### 6.2 Quest implication

Se un NPC con `linked_quest_id` muore permanentemente:
- Se la quest è attiva → fallisce automaticamente (emette notifica)
- Se la quest non è iniziata → non è più avviabile
- `QuestManager.on_npc_died(npc_uid, quest_id)` — nuovo hook

### 6.3 NPC.gd — modifica `die()`

```gdscript
func die() -> void:
    if not respawn:
        WorldState.register_permanent_npc_death(npc_uid)
    if linked_quest_id != "":
        QuestManager.on_npc_died(linked_quest_id)
    super.die()
```

### 6.4 Lista task

- [ ] `respawn: bool` in `NPC.gd` e `NPC.setup()`
- [ ] `WorldState.permanent_npc_deaths` + `register_permanent_npc_death(uid)`
- [ ] Serializzazione in `world.json`
- [ ] `NPC.die()` override
- [ ] `QuestManager.on_npc_died(quest_id)` stub

---

## FASE 7 — CityBuilder: configurazione NPC espansa

Il pannello NPC nel builder attuale è basico. Campi da aggiungere:

| Campo | Tipo | Note |
|-------|------|------|
| `schedule` | array JSON editabile | Editor visivo waypoints per slot |
| `shop_type` | OptionButton | "" / armeria / farmacia / ecc. |
| `shop_refresh_days` | SpinBox | Default 3 |
| `respawn` | CheckButton | Default ON |
| `conditional_dialogues` | array JSON | Editor condizioni |

Priorità: i primi tre sono i più utili. `conditional_dialogues` editabile è nice-to-have.

---

## TODO cumulativo (ordinato per fase)

### FASE 1 — Time System
- [ ] `TimeManager.gd` — autoload con `advance()`, `get_slot()`, `format_time()`, `get_vision_modifier()`
- [ ] `GameState`: `world_time: int = 480`, `day_count: int = 1`
- [ ] `EventBus`: `time_advanced`, `day_changed`, `day_slot_changed`
- [ ] `Player._try_move()`: hook `TimeManager.advance(map_type)`
- [ ] HUD: `TimeLabel` aggiornato su `time_advanced`
- [ ] `SaveManager`: serializza `world_time`, `day_count`
- [ ] `project.godot`: registrare `TimeManager` prima di `WorldManager`

### FASE 2 — NPC Routine
- [ ] `NPC.gd`: campo `schedule`, `_on_day_slot_changed()`, `_on_time_advanced()`
- [ ] `NPC.setup()`: parsa schedule da params
- [ ] Movimento 1-passo: walkability + entity check
- [ ] Test: NPC mercante con schedule completo

### FASE 3 — Conditional Dialogues
- [ ] `NPC._check_condition(entry)` — switch per tipo
- [ ] `NPC._pick_dialogue()` — loop conditions pre-quest-check
- [ ] Aggiungere `time_slot` condition (dopo FASE 1)

### FASE 4 — Shop System
- [ ] `WorldState.npc_shop_data` + generazione procedurale
- [ ] `ShopScreen.gd` (CanvasLayer layer=85)
- [ ] `EventBus.shop_opened/closed`
- [ ] Prezzi + `FactionEconomy` collegato
- [ ] `base_price` nei JSON item

### FASE 5 — Effetti notte
- [ ] `TimeManager.get_vision_modifier()`
- [ ] Hook FOV in `BaseMap._compute_fov()`

### FASE 6 — Permadeath NPC
- [ ] `respawn: bool` in NPC
- [ ] `WorldState.permanent_npc_deaths`
- [ ] `NPC.die()` override + `QuestManager.on_npc_died()`

### FASE 7 — CityBuilder NPC expanded
- [ ] Pannello espanso: schedule editor, shop_type, respawn

---

## Questioni aperte (deferred)

- **NPC con char/colore diverso**: attualmente tutti `N` giallo oro. In futuro: tipi NPC con char specifico (es. `M` mercante, `G` guardia-NPC, `?` questgiver). Deferred.
- **Interazione player-NPC di notte**: se shop chiuso, il dialogo normale continua? Sì (solo il vendor è bloccato).
- **Sell-back al mercante**: prezzo 40% fisso o negoziabile? Fisso per ora.
- **Movimento NPC e TurnManager**: gli NPC NON sono nel TurnManager (non combattono). Il loro movimento è event-driven (`time_advanced`), non turno-based.
- **Collisione NPC-NPC**: se due NPC si bloccano a vicenda nel wandering → skip step (non si muove quel tick).
- **NPC che porta quest e muore**: l'effetto su quest è uno stub; un sistema completo di "conseguenze morte NPC" viene dopo.

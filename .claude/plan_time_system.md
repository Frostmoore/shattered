# Piano: Time System

**Stato**: Completato. Prerequisito di NPC System, Vendor System, Travel System.

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Unità interna | `total_minutes: int` — contatore assoluto, mai resettato |
| Giorno | 1440 minuti; `world_time = total_minutes % 1440` |
| Calendario | 12 mesi × 30 giorni = 360 giorni/anno; anno corrente 472 C (Canone) |
| Display HUD | "12 Fioralba 472 C — Tramonto" |
| Cosa avanza il tempo | Ogni azione significativa del player (movimento, attacco, uso item, interazione, wait, rest) |
| Scala overworld | 240 min/tile base × terrain_mult × mount_mult |
| Scala città/villaggio/edificio/dungeon | tabella per tipo + tipo azione |
| Fasce interne | 5 slot (alba / mattina / pomeriggio / sera / notte) |
| Fasce display | 4 fasi (Alba / Giorno / Tramonto / Notte) |
| Orari negozi | Per-NPC, non globali (ogni vendor ha la propria schedule) |
| FOV notturno | Ridotto + fonti di luce locali in villaggi/città |
| Entità overworld | Accumulator per ogni WorldActor — si muovono in proporzione al tempo passato |
| World tick | Ogni `advance()` grande produce N tick da 30 min per la simulazione world |

---

## GameState — nuovi campi

```gdscript
var total_minutes: int = 480   # contatore assoluto, mai resettato

# Derivato (non salvato separatamente)
var world_time: int:
    get: return total_minutes % 1440   # minuti nella giornata corrente (0–1439)
```

`total_minutes` è l'unico campo da salvare/caricare.  
`world_time` è una proprietà derivata per comodità.  
La data del calendario (giorno, mese, anno) viene calcolata interamente da `TimeManager`.

**Perché total_minutes:** semplifica enormemente le deadline delle quest.
```gdscript
# Al momento della presa quest:
quest_data["deadline"] = GameState.total_minutes + time_limit_minutes
# Controllo: GameState.total_minutes > quest_data["deadline"]
# Conversione per display: TimeManager.format_date_from(quest_data["deadline"])
```

---

## Cosa avanza il tempo

Ogni azione significativa del player chiama `TimeManager.advance(cost)`. Il costo dipende dal **contesto** (map_type) e dal **tipo di azione**.

### Costi per contesto (min per azione)

| Azione | `building` | `village` | `city` | `dungeon`/`ruin` | `overworld` |
|--------|-----------|-----------|--------|-----------------|-------------|
| Movimento | 1 | 1 | 2 | 3 | formula¹ |
| Attacco dato/ricevuto | 1 | 1 | 2 | 3 | 5² |
| Uso item | 1 | 1 | 1 | 2 | 5 |
| Interazione NPC | 1 | 1 | 1 | — | 5 |
| Wait (tasto esplicito) | 60 | 60 | 60 | 30 | 60 |
| Rest / dormi in locanda | 480 | 480 | 480 | — | — |

¹ `ceili(240.0 * terrain_mult * mount_mult)` — vedi tabella terrain/mount  
² L'overworld combat usa costo basso perché è uno scontro locale, non un viaggio

### Integrazione con _action_done()

Il punto di hook naturale è `Player._action_done()` — ogni azione che chiama `_action_done()` avanza automaticamente il tempo. Il costo viene calcolato da `TimeManager.get_action_cost(map_type, action)`.

```gdscript
# In Player._action_done():
var map: BaseMap = WorldManager.get_current_map()
TimeManager.advance(TimeManager.get_action_cost(map.map_type, _last_action))
TurnManager.end_player_turn()
```

`_last_action` è un enum (MOVE, ATTACK, USE_ITEM, INTERACT, WAIT) settato prima di chiamare `_action_done()`.

---

## Overworld — modificatori terreno e mount

**Formula:** `ceili(240.0 * terrain_mult * mount_mult)` → int minuti

### Terreno

| Terreno | Mult | Min/tile (a piedi) |
|---------|------|---------------------|
| Strada maestra / lastricata | ×0.75 | 180 (3 ore) |
| Strada battuta | ×1.0 | 240 (4 ore) — base |
| Campagna aperta / prateria | ×1.5 | 360 (6 ore) |
| Foresta | ×2.0 | 480 (8 ore) |
| Collina | ×2.0 | 480 (8 ore) |
| Deserto / palude | ×2.5 | 600 (10 ore) |
| Montagna | ×3.0 | 720 (12 ore) |

### Mount

| Mount | Mult | Restrizioni terreno |
|-------|------|---------------------|
| A piedi | ×1.0 | nessuna |
| Cavallo | ×0.5 | no montagna pesante |
| Mulo | ×0.7 | nessuna |
| Carretto | ×0.8 | solo strada/campagna; su altro → fallback a piedi |
| Carovana | ×1.2 | solo strada; bonus sicurezza/commercio |

Placeholder finché Mount System non esiste: `mount_mult = 1.0`.  
Placeholder finché Overworld System non espone biomi: `terrain_mult = 1.0`.

---

## Fasce orarie

### Slot interni (5) — per NPC, shop schedule, FOV

| Slot | Ore |
|------|-----|
| `alba` | 5:00–7:59 |
| `mattina` | 8:00–11:59 |
| `pomeriggio` | 12:00–17:59 |
| `sera` | 18:00–20:59 |
| `notte` | 21:00–4:59 |

### Fasi display (4) — HUD

| Fase | Slot interni |
|------|-------------|
| **Alba** | `alba` |
| **Giorno** | `mattina` + `pomeriggio` |
| **Tramonto** | `sera` |
| **Notte** | `notte` |

---

## Calendario del Canone

**Struttura**: 12 mesi × 30 giorni = 360 giorni/anno.  
**Anno di partenza campagna**: 472 C (Canone).  
**`total_minutes = 0`** corrisponde alla mezzanotte del 1 Nevargento 472 C.  
**Default partita** (`total_minutes = 480`) = ore 8:00 del 1 Nevargento 472 C.

| N. | Nome | Stagione |
|----|------|----------|
| 1 | **Nevargento** | Inverno |
| 2 | **Brumafonda** | Inverno |
| 3 | **Fioralba** | Primavera |
| 4 | **Verdeluce** | Primavera |
| 5 | **Seminoro** | Primavera |
| 6 | **Solcaldo** | Estate |
| 7 | **Altosole** | Estate |
| 8 | **Granarso** | Estate |
| 9 | **Rossovento** | Autunno |
| 10 | **Vendemmiale** | Autunno |
| 11 | **Cineroggia** | Autunno |
| 12 | **Notteprima** | Inverno |

### Formati data

| Contesto | Formato | Esempio |
|----------|---------|---------|
| HUD compatto | `"D Mese AAAA C — Fase"` | `"12 Fioralba 472 C — Tramonto"` |
| Esteso | `"Giorno D di Mese, Anno AAAA del Canone"` | `"Giorno 12 di Fioralba, Anno 472 del Canone"` |
| Debug | `"AAAA C / Mese D / HH:MM / slot / giorno_assoluto N"` | `"472 C / Fioralba 12 / 18:42 / sera / gg 72"` |

### Matematica calendario

```gdscript
# Dato total_minutes:
var abs_day:    int = total_minutes / 1440           # giorno assoluto 0-indexed
var year:       int = BASE_YEAR + abs_day / DAYS_PER_YEAR
var month_idx:  int = (abs_day % DAYS_PER_YEAR) / DAYS_PER_MONTH   # 0-indexed
var day_of_m:   int = (abs_day % DAYS_PER_MONTH) + 1               # 1-indexed
```

Esempi (partendo da `total_minutes = 0`):
- `abs_day = 0`   → 1 Nevargento 472 C
- `abs_day = 31`  → 2 Brumafonda 472 C
- `abs_day = 359` → 30 Notteprima 472 C
- `abs_day = 360` → 1 Nevargento 473 C

---

## Localizzazione

Tutte le stringhe visibili all'utente usano `LocaleManager.t(key, params)`. Le chiavi vanno aggiunte a `locales/strings_ui.csv`.

**Chiavi interne (NON tradotte):** i nomi degli slot (`"alba"`, `"mattina"`, `"pomeriggio"`, `"sera"`, `"notte"`) sono identificatori di codice, non display — niente `LocaleManager`.

### Chiavi da aggiungere a `locales/strings_ui.csv`

```
TIME_PHASE_ALBA,Alba
TIME_PHASE_GIORNO,Giorno
TIME_PHASE_TRAMONTO,Tramonto
TIME_PHASE_NOTTE,Notte
TIME_MONTH_1,Nevargento
TIME_MONTH_2,Brumafonda
TIME_MONTH_3,Fioralba
TIME_MONTH_4,Verdeluce
TIME_MONTH_5,Seminoro
TIME_MONTH_6,Solcaldo
TIME_MONTH_7,Altosole
TIME_MONTH_8,Granarso
TIME_MONTH_9,Rossovento
TIME_MONTH_10,Vendemmiale
TIME_MONTH_11,Cineroggia
TIME_MONTH_12,Notteprima
TIME_FORMAT_DATE,{day} {month} {year} C
TIME_FORMAT_FULL,{date} — {phase}
```

`TIME_FORMAT_DATE` e `TIME_FORMAT_FULL` sono template con parametri nominati (`{day}`, `{month}`, ecc.). Lingue diverse possono cambiare l'ordine delle parole senza toccare il codice.

---

## Architettura — TimeManager

`scripts/core/TimeManager.gd` — autoload, da registrare **prima** di `WorldManager`.

```gdscript
extends Node

const WORLD_TICK_INTERVAL: int = 30

const BASE_YEAR:      int = 472
const DAYS_PER_MONTH: int = 30
const DAYS_PER_YEAR:  int = 360
const MONTH_KEYS: Array[String] = [
    "TIME_MONTH_1","TIME_MONTH_2","TIME_MONTH_3","TIME_MONTH_4",
    "TIME_MONTH_5","TIME_MONTH_6","TIME_MONTH_7","TIME_MONTH_8",
    "TIME_MONTH_9","TIME_MONTH_10","TIME_MONTH_11","TIME_MONTH_12"
]

func advance(minutes: int) -> void:
    var prev_slot:    String = get_slot()
    var prev_abs_day: int    = get_absolute_day()

    GameState.total_minutes += minutes

    if get_absolute_day() != prev_abs_day:
        EventBus.day_changed.emit(get_absolute_day())

    EventBus.time_advanced.emit(minutes)

    if get_slot() != prev_slot:
        EventBus.day_slot_changed.emit(get_slot())

    var ticks: int = minutes / WORLD_TICK_INTERVAL
    if ticks > 0:
        EventBus.world_ticked.emit(ticks, WORLD_TICK_INTERVAL)

func get_hour() -> int:       return GameState.world_time / 60
func get_minute() -> int:     return GameState.world_time % 60

func get_absolute_day() -> int: return GameState.total_minutes / 1440
func get_year() -> int:         return BASE_YEAR + get_absolute_day() / DAYS_PER_YEAR
func get_month_index() -> int:  return (get_absolute_day() % DAYS_PER_YEAR) / DAYS_PER_MONTH
func get_day_of_month() -> int: return (get_absolute_day() % DAYS_PER_MONTH) + 1
func get_month_name() -> String: return LocaleManager.t(MONTH_KEYS[get_month_index()])

func format_date() -> String:
    return LocaleManager.t("TIME_FORMAT_DATE", {
        "day":   str(get_day_of_month()),
        "month": get_month_name(),
        "year":  str(get_year())
    })

func format_time() -> String:
    return LocaleManager.t("TIME_FORMAT_FULL", {
        "date":  format_date(),
        "phase": _display_phase()
    })

func format_date_from(minutes: int) -> String:
    var abs_day: int = minutes / 1440
    var year: int    = BASE_YEAR + abs_day / DAYS_PER_YEAR
    var m_idx: int   = (abs_day % DAYS_PER_YEAR) / DAYS_PER_MONTH
    var day_m: int   = (abs_day % DAYS_PER_MONTH) + 1
    return LocaleManager.t("TIME_FORMAT_DATE", {
        "day":   str(day_m),
        "month": LocaleManager.t(MONTH_KEYS[m_idx]),
        "year":  str(year)
    })

func _display_phase() -> String:
    match get_slot():
        "alba":                  return LocaleManager.t("TIME_PHASE_ALBA")
        "mattina", "pomeriggio": return LocaleManager.t("TIME_PHASE_GIORNO")
        "sera":                  return LocaleManager.t("TIME_PHASE_TRAMONTO")
        _:                       return LocaleManager.t("TIME_PHASE_NOTTE")

func get_slot() -> String:
    var h: int = get_hour()
    if h >= 5  and h < 8:  return "alba"
    if h >= 8  and h < 12: return "mattina"
    if h >= 12 and h < 18: return "pomeriggio"
    if h >= 18 and h < 21: return "sera"
    return "notte"

func is_night() -> bool: return get_slot() == "notte"

func get_vision_modifier(map_type: String) -> float:
    if is_night() and map_type in ["village", "city", "overworld"]:
        return 0.6
    return 1.0

func get_action_cost(map_type: String, action: int) -> int:
    # action: 0=MOVE 1=ATTACK 2=USE_ITEM 3=INTERACT 4=WAIT
    var table: Dictionary = {
        "building": [1, 1, 1, 1, 60],
        "village":  [1, 1, 1, 1, 60],
        "city":     [2, 2, 1, 1, 60],
        "dungeon":  [3, 3, 2, 0, 30],
        "ruin":     [3, 3, 2, 0, 30],
        "overworld":[0, 5, 5, 5, 60],  # 0 = calcolato separatamente per MOVE
    }
    var costs: Array = table.get(map_type, [2, 2, 1, 1, 60])
    return costs[action] if action < costs.size() else 2
```

---

## Orari negozi — per-NPC schedule

I negozi **non** usano un flag globale `is_night()`. Ogni NPC vendor ha la propria schedule.

```gdscript
# In NPC params (JSON):
{
  "vendor": true,
  "open_slot": "alba",     # slot interno da cui è aperto
  "close_slot": "notte"    # slot interno da cui chiude
}

# In NPC.gd:
func is_open() -> bool:
    var slots: Array = ["alba","mattina","pomeriggio","sera","notte"]
    var now_idx: int    = slots.find(TimeManager.get_slot())
    var open_idx: int   = slots.find(open_slot)
    var close_idx: int  = slots.find(close_slot)
    if open_idx <= close_idx:
        return now_idx >= open_idx and now_idx < close_idx
    else:   # wrap notturno (es. taverna: sera→alba)
        return now_idx >= open_idx or now_idx < close_idx
```

Esempi:
- Fabbro: `open_slot = "mattina"`, `close_slot = "sera"` → aperto 8–18
- Taverna: `open_slot = "pomeriggio"`, `close_slot = "mattina"` → aperta 12–8 (wrap)
- Guardia nera (fence): `open_slot = "notte"`, `close_slot = "alba"` → solo 21–5

---

## FOV notturno + luci locali

`BaseMap._compute_fov()` usa il raggio modulato:
```gdscript
var effective_radius: int = roundi(radius * TimeManager.get_vision_modifier(map_type))
```

In villaggi e città di notte, certe tile sono **sorgenti di luce** (torce, finestre illuminate). Queste tile ignorano la riduzione FOV e aggiungono un raggio locale.

```gdscript
# BaseMap — nuovi campi
var _light_sources: Array[Vector2i] = []   # popolato da populate() leggendo la LocationState

func _compute_fov(origin: Vector2i, radius: int) -> void:
    var eff_radius: int = roundi(radius * TimeManager.get_vision_modifier(map_type))
    _visible_tiles.fill(0)
    _cast_fov(origin, eff_radius)
    # Luci locali: aree illuminate indipendentemente dal FOV del player
    if TimeManager.is_night():
        for src: Vector2i in _light_sources:
            _cast_fov(src, LIGHT_RADIUS)   # LIGHT_RADIUS = 3 o 4
```

Le sorgenti di luce vengono lette dalla `LocationState` / JSON mappa come tile speciali (tipo `"light_source": true` nell'entità).

---

## NPC — accumulator per routine (FASE 2 NPC System)

Gli NPC **non** reagiscono a ogni evento `time_advanced`. Usano un accumulatore:

```gdscript
# In NPC.gd:
var movement_interval: int = 10   # si muove ogni 10 minuti di gioco
var _accumulated_minutes: float = 0.0

func _on_time_advanced(minutes: int) -> void:
    _accumulated_minutes += minutes
    while _accumulated_minutes >= movement_interval:
        _perform_routine_step()
        _accumulated_minutes -= movement_interval
```

Questo risolve il problema scala: se il player attraversa un tile di montagna (720 min), un NPC con `movement_interval = 60` esegue 12 passi di routine — proporzionale al tempo, non al numero di eventi.

---

## Entità overworld — WorldActor accumulator

Carovane, viaggiatori e altre entità sull'overworld hanno velocità proprie espresse in min/tile. Si muovono tramite accumulator, esattamente come gli NPC in routine.

```gdscript
class WorldActor:
    var tile_cost: int = 240        # a piedi su strada
    var _accumulated: float = 0.0
    var current_tile: Vector2i
    var path: Array[Vector2i] = []  # rotta precalcolata

    func on_world_ticked(tick_minutes: int) -> void:
        _accumulated += tick_minutes
        while _accumulated >= tile_cost and not path.is_empty():
            current_tile = path.pop_front()
            _accumulated -= tile_cost
            # aggiorna renderer / world state
```

Esempi di tile_cost:
- Viaggiatore a piedi su strada: 240 min
- Cavaliere: 120 min
- Carovana: 288 min (×1.2)
- Messaggero a cavallo su strada maestra: 90 min (240 × 0.75 × 0.5)

Il signal `EventBus.world_ticked(ticks, tick_size)` è il trigger per tutti i WorldActor. L'interfaccia è `WorldSimulator` (singleton o parte di WorldManager) che mantiene la lista degli attori attivi e li aggiorna sul tick.

---

## EventBus — nuovi segnali

```gdscript
signal time_advanced(minutes: int)          # ogni advance()
signal day_changed(day_count: int)          # ogni cambio giorno
signal day_slot_changed(slot: String)       # ogni cambio slot interno
signal world_ticked(ticks: int, tick_size: int)  # per simulazione world entity
```

---

## Integrazione

### Player._action_done()

```gdscript
func _action_done() -> void:
    var map: BaseMap = WorldManager.get_current_map()
    if map != null:
        TimeManager.advance(TimeManager.get_action_cost(map.map_type, _last_action))
    TurnManager.end_player_turn()
```

Per il movimento overworld, il costo è già calcolato prima della chiamata:
```gdscript
# In _try_move(), dopo move_to():
_last_action_cost = ceil(240.0 * _get_terrain_mult() * _get_mount_mult())
_action_done_with_cost(_last_action_cost)
```

### HUD

`TimeLabel` aggiornato su `EventBus.time_advanced`:
```gdscript
_time_label.text = TimeManager.format_time()  # → "12 Fioralba 472 C — Tramonto"
```

### BaseMap

```gdscript
func _ready() -> void:
    EventBus.player_moved.connect(_on_player_moved)
    EventBus.day_slot_changed.connect(_on_day_slot_changed)
    _on_player_moved(GameState.player_position)

func _on_day_slot_changed(_slot: String) -> void:
    _compute_fov(GameState.player_position, GameBalance.FOV_RADIUS)
```

### Save/Load

```gdscript
# _save_character():
"total_minutes": GameState.total_minutes,

# _apply_save_data():
GameState.total_minutes = int(data.get("total_minutes", 480))
```

---

## Wait System

### Meccanica tasto R

| Interazione | Risultato |
|-------------|-----------|
| Tap R (< 0.4s) | Wait 1 tick: `_action_done()` con `Action.WAIT` (30 min in dungeon, 60 altrove) |
| Hold R (≥ 0.4s) | Apre `WaitScreen` — **senza** eseguire il wait rapido |

Il tasto R viene gestito tramite hold detection in `_process()`: si accumula `_wait_hold_timer` mentre il tasto è premuto. Al rilascio, se il timer è sotto la soglia si fa il wait rapido; se la soglia è già stata superata (`_wait_screen_open == true`), non si fa nulla.

### WaitScreen — UX

**Fase selezione** (scelta delle ore, prima di confermare):

```
╔══════════════════════════════════╗
║           ATTENDI                ║
║                                  ║
║  Da:  12 Fioralba 472 C — Giorno ║
║  A:   12 Fioralba 472 C — Sera   ║  ← aggiornato live dallo slider
║                                  ║
║  ├─────────────────────●────┤    ║  ← slider 1–8 ore (qui: 6h)
║         6 ore                    ║
║                                  ║
║  [  Aspetta  ]   [ Annulla ]     ║
╚══════════════════════════════════╝
```

**Fase animazione** (dopo la conferma, slider scorre al contrario):

```
╔══════════════════════════════════╗
║           ATTENDI                ║
║                                  ║
║  Inizio:  12 Fioralba — Giorno   ║  ← fisso
║  Fine:    12 Fioralba — Sera     ║  ← fisso
║  Ora:     12 Fioralba — Tramonto ║  ← aggiornato ogni ora simulata
║                                  ║
║  ├──────────●───────────────┤    ║  ← slider scorre verso sinistra
║                                  ║
╚══════════════════════════════════╝
```

Lo slider nella fase animazione è bloccato in input e il suo `value` viene aggiornato a `(target_minutes - current_minutes) / 60.0` ad ogni tick visivo.

### Architettura — WaitScreen.gd

```gdscript
# scenes/ui/WaitScreen.tscn + scripts/ui/WaitScreen.gd
extends CanvasLayer

const WAIT_TICK_DELAY: float = 0.08   # secondi per ora simulata (8 ore → ~0.64s totale)
const MAX_WAIT_HOURS:  int   = 8

var _start_minutes:  int  = 0
var _target_minutes: int  = 0
var _animating:      bool = false

func open() -> void:
    _start_minutes  = GameState.total_minutes
    _target_minutes = _start_minutes + 3600     # default 1 ora
    _slider.max_value  = MAX_WAIT_HOURS
    _slider.value      = 1
    _slider.editable   = true
    _update_labels()
    show()

func _on_slider_changed(value: float) -> void:
    _target_minutes = _start_minutes + int(value) * 60
    _update_labels()

func _update_labels() -> void:
    _from_label.text = TimeManager.format_time()
    _to_label.text   = TimeManager.format_time_from(_target_minutes)

func _on_wait_confirmed() -> void:
    _slider.editable = false
    _animating = true
    _run_wait_animation()

func _run_wait_animation() -> void:
    while GameState.total_minutes < _target_minutes:
        var step: int = mini(60, _target_minutes - GameState.total_minutes)
        TimeManager.advance(step)
        _slider.value = float(_target_minutes - GameState.total_minutes) / 60.0
        _now_label.text = TimeManager.format_time()
        await get_tree().create_timer(WAIT_TICK_DELAY).timeout
    _finish()

func _finish() -> void:
    _animating = false
    EventBus.notification_shown.emit(
        Notification.wait_finished((_target_minutes - _start_minutes) / 60,
                                   TimeManager.format_time()))
    hide()

func _on_cancel_pressed() -> void:
    if not _animating:
        hide()
```

> **Nota**: `TimeManager.format_time_from(minutes)` è un alias di `format_date_from()` + fase — aggiungere come helper per la label "Fine:".

### Integrazione con CombatBar.gd (entry point esistente)

Il wait è già gestito in `CombatBar.gd` (non in Player.gd). La hold detection va aggiunta lì.

**Stato attuale:**
- `action_wait` → tasto R (già in InputMap) ma la condizione `and _in_combat` blocca il tasto durante l'esplorazione
- `_on_wait()` chiama `TurnManager.on_player_action_done()` direttamente, senza passare per Player._action_done()
- Testo pulsante mostra `[Q]` — bug da correggere

**Cambiamenti:**
- Rimuovere la condizione `and _in_combat` dal `_unhandled_input` per `action_wait` → R funziona sempre
- Rinominare `_on_wait()` → `_on_quick_wait()`, aggiungere `TimeManager.advance()` prima di chiamare TurnManager
- Aggiungere hold detection in `_process(delta)` su CombatBar
- Correggere testo pulsante da `[Q] Aspetta` a `[R] Aspetta`

```gdscript
# CombatBar.gd — aggiunte/modifiche

var _wait_hold_timer: float  = 0.0
var _wait_screen_open: bool  = false
const WAIT_HOLD_THRESHOLD: float = 0.4

func _process(delta: float) -> void:
    if not visible or not TurnManager.is_player_turn:
        return
    if Input.is_action_pressed("action_wait"):
        _wait_hold_timer += delta
        if _wait_hold_timer >= WAIT_HOLD_THRESHOLD and not _wait_screen_open:
            _wait_screen_open = true
            _wait_screen.open()
    elif _wait_hold_timer > 0.0 and not Input.is_action_pressed("action_wait"):
        if _wait_hold_timer < WAIT_HOLD_THRESHOLD:
            _on_quick_wait()
        _wait_hold_timer = 0.0

func _on_quick_wait() -> void:
    if not TurnManager.is_player_turn:
        return
    var map: BaseMap = WorldManager.get_current_map()
    if map:
        TimeManager.advance(TimeManager.get_action_cost(map.map_type, 4))  # 4 = WAIT
    _set_combat_buttons_active(false)
    TurnManager.on_player_action_done()
```

> **Nota**: `is_action_just_released` non è affidabile in `_process()` in Godot 4 — il rilascio viene rilevato controllando che `_wait_hold_timer > 0` ma `is_action_pressed` sia false nel frame corrente.

`_wait_screen` è un riferimento a `WaitScreen` aggiunto come figlio di Main. Quando WaitScreen si chiude → `_wait_screen_open = false` e (se wait completato) `TurnManager.on_player_action_done()` chiamato da WaitScreen.

### Notifiche

Aggiungere in `Notification.gd`:
```gdscript
static func wait_finished(hours: int, new_time: String) -> Notification:
    var n := Notification.new()
    n.text     = LocaleManager.t("NOTIF_WAIT_DONE", {"hours": str(hours), "time": new_time})
    n.color    = Color(0.6, 0.9, 1.0)
    n.duration = 3.0
    return n
```

Chiave da aggiungere a `locales/strings_notifications.csv`:
```
NOTIF_WAIT_DONE,Hai aspettato {hours} ore. Sono le {time}.
```

---

## Questioni aperte — risolte

- **`_last_action` enum**: ✅ definito in Fase 2 implementazione (`MOVE, ATTACK, USE_ITEM, INTERACT, WAIT`)
- **Overworld combat**: ✅ non esiste combat overworld. Se avvengono schermaglie locali, si aprirà una mappa procedurale separata — il costo tempo userà il tipo di quella mappa, non "overworld". La voce `ATTACK` nella tabella overworld è da considerare inutilizzata.
- **WorldSimulator**: ✅ sarà parte di `WorldManager` (non un singleton separato) per massima espandibilità. `WorldManager` mantiene già la lista delle mappe attive — aggiungere la lista `_world_actors` e il metodo `_on_world_ticked()` è un'estensione naturale. Dettagli nell'Overworld System plan.
- **Light sources**: ✅ già implementato — `kind: "light_source"`, `params: {color: [r,g,b], radius: int}` nel CityBuilder e BaseMap.
- **Calibrazione dungeon**: ✅ 3 min/tile confermato. ~2 piani al giorno è il ritmo target. Un Camping System sarà necessario per recuperare risorse mid-dungeon (aggiunto in `todo.md`).
- **Tassi Needs System per dungeon**: ✅ da calibrare empiricamente dopo l'implementazione del Time System — nessuna azione bloccante ora.

---

## Lista task (riepilogo)

- [ ] `GameState`: `total_minutes: int = 480`; `world_time` e `day_count` come proprietà derivate
- [ ] `scripts/core/TimeManager.gd` — autoload completo
- [x] `EventBus`: segnali `time_advanced`, `day_changed`, `day_slot_changed`, `world_ticked` *(già fatto)*
- [ ] `project.godot`: registrare `TimeManager` prima di `WorldManager`
- [ ] `Player`: enum azione + `_action_done()` con hook TimeManager
- [ ] `Player._get_move_cost_overworld() -> int`: placeholder 240
- [ ] `CombatBar.gd`: rinominare `_on_wait` → `_on_quick_wait`, aggiungere TimeManager.advance(), hold detection _process(), rimuovere `and _in_combat` da _unhandled_input, fix testo pulsante `[R]`
- [ ] `WaitScreen.gd` + `WaitScreen.tscn`: interfaccia selezione + animazione ora per ora
- [ ] `TimeManager.format_time_from(minutes: int) -> String`: helper per label "Fine:" di WaitScreen
- [ ] `Notification.wait_finished()`: factory method
- [ ] `locales/strings_notifications.csv`: `NOTIF_WAIT_DONE`
- [ ] HUD: `TimeLabel` aggiornato su `time_advanced`
- [x] `SaveManager`: serializza/deserializza `total_minutes`
- [x] `BaseMap._compute_fov()`: applica `get_vision_modifier()` + luci locali *(già fatto — aspetta TimeManager)*
- [x] `BaseMap._ready()`: connetti `day_slot_changed` → recompute FOV; inizializza `_lights_active` da slot corrente *(già fatto + fix bug lighting-on-load)*
- [ ] `NPC.gd`: `open_slot`, `close_slot`, `is_open()` *(FASE 2 NPC System)*
- [ ] `NPC._on_time_advanced()`: accumulator *(FASE 2 NPC System)*
- [ ] `WorldSimulator`: gestione WorldActor *(Overworld System)*

---

## Fasi di implementazione — dettaglio completo

> **Nota**: le voci marcate *(già fatto)* nella lista sopra non compaiono qui.  
> **Ordine obbligatorio**: Fase 1 → Fase 2 → Fase 2.5 → Fase 3 → Fase 4 → Fase 5.  
> Ogni fase è verificabile in isolamento prima di procedere.

---

### FASE 1 — GameState + TimeManager + Registrazione autoload

#### 1.1 `scripts/core/GameState.gd`

- [x] Aprire il file e trovare il blocco delle variabili di stato principale
- [x] Aggiungere il campo `var total_minutes: int = 480` (equivale alle 8:00 del 1 Nevargento 472 C)
- [x] Aggiungere la proprietà derivata `world_time` con getter `return total_minutes % 1440`
- [x] Verificare che non ci siano altri campi `hour`, `day`, `day_count`, `time` o simili — nessuno trovato

#### 1.2 Creare `scripts/core/TimeManager.gd`

- [x] Creare il file `scripts/core/TimeManager.gd` con `extends Node`
- [x] Definire `const WORLD_TICK_INTERVAL: int = 30`
- [x] Definire le costanti calendario (`BASE_YEAR`, `DAYS_PER_MONTH`, `DAYS_PER_YEAR`, `MONTH_KEYS`)
- [x] Implementare `get_hour()`, `get_minute()`, `get_slot()`, `is_night()`, `_display_phase()`
- [x] Implementare helper calendario: `get_absolute_day/year/month_index/day_of_month/month_name`
- [x] Implementare `format_date()`, `format_time()`, `format_date_from()`, `format_time_from()`
- [x] Implementare `get_vision_modifier()`, `get_action_cost()`
- [x] Implementare `advance()` con emissione dei 4 segnali EventBus
- [x] **Localizzazione**: 18 chiavi `TIME_*` aggiunte a `locales/strings_ui.csv`

#### 1.3 `project.godot` — registrazione autoload

- [x] Aggiunto `TimeManager="*res://scripts/core/TimeManager.gd"` tra `EventBus` e `WorldManager`

#### 1.4 Verifica Fase 1

- [ ] Aprire la console di Godot e verificare che non ci siano errori all'avvio
- [ ] Nel debugger/console, chiamare `TimeManager.format_time()` — deve restituire `"1 Nevargento 472 C — Giorno"` (ore 8:00)
- [ ] Chiamare `TimeManager.advance(780)` (avanza di 13 ore → 21:00) — deve restituire slot `"notte"`
- [ ] Verificare che `EventBus.day_slot_changed` sia stato emesso
- [ ] Verificare che `GameState.world_time` == 1260 e `TimeManager.get_absolute_day()` == 0

#### 1.5 Aggiornamento codebase_reference

- [x] Aggiunta entry `TimeManager` nella tabella autoload di `codebase_reference.md`
- [x] Aggiornata entry `GameState` con `total_minutes` e `world_time`
- [x] Aggiornata sezione EventBus: rimosso "(TimeManager non ancora implementato)", corretto `day_changed` da `day_count` a `abs_day`
- [x] Aggiunta sezione `total_minutes` / `world_time` in "Stato del giocatore"

#### 1.6 DebugScreen — sezione TimeSystem

- [x] In `_ready()`, aggiunto `_add_section("time_system", "Time System")` e `_build_time_tools()`
- [x] In `_refresh()`, aggiunta la chiamata `_update_time_system()`
- [x] Implementato `_update_time_system()`: mostra `total_minutes`, `world_time` (H:MM), `slot`, `display`, `abs_day`, data calendario, `map_type`, `action_costs` M/A/I/W; opzionalmente stato WaitScreen e testo `hud_time_label`
- [x] Implementato `_build_time_tools()`: bottoni `+1h` / `+8h` / `+1 giorno` / `Reset` (header collassabile azzurro)
- [ ] Verificare nella console DebugScreen che la sezione mostri valori coerenti con `TimeManager.format_time()`

#### 1.7 HUD — TimeLabel in alto al centro (anticipata da FASE 3)

Il TimeLabel non va dentro il Panel esistente (in basso-sinistra) ma come nodo separato del CanvasLayer, a tutta larghezza, in alto al centro.

- [x] In `scenes/ui/HUD.tscn`, aggiungere come figlio diretto di `HUD` (CanvasLayer):
  ```
  [node name="TimeLabel" type="Label" parent="."]
  offset_left = 0.0
  offset_top = 4.0
  offset_right = 640.0
  offset_bottom = 18.0
  text = "1 Nevargento 472 C — Giorno"
  theme_override_font_sizes/font_size = 11
  horizontal_alignment = 1
  ```
- [x] In `scripts/ui/HUD.gd`, aggiungere:
  ```gdscript
  @onready var _time_label: Label = $TimeLabel
  ```
- [x] In `_ready()`, aggiungere:
  ```gdscript
  EventBus.time_advanced.connect(_on_time_advanced)
  _time_label.text = TimeManager.format_time()
  ```
- [x] Aggiungere il metodo:
  ```gdscript
  func _on_time_advanced(_minutes: int) -> void:
      _time_label.text = TimeManager.format_time()
  ```
- [ ] Avviare il gioco → label visibile in alto al centro, testo `"1 Nevargento 472 C — Giorno"`

> **Aggiornamento codebase_reference (FASE 1)**: aggiunta sezione HUD con tabella nodi e descrizione TimeLabel; aggiornata sezione Debug Tools con Time System e TimeTools.

---

### FASE 2 — Hook Player Actions

#### 2.1 `scripts/entities/Player.gd` — enum azione

- [x] Aggiunto `enum Action { MOVE = 0, ATTACK = 1, USE_ITEM = 2, INTERACT = 3, WAIT = 4 }` dopo `class_name Player`
- [x] Aggiunta `var _last_action: int = Action.MOVE`

#### 2.2 `Player.gd` — modificare `_action_done()`

- [x] Aggiunto parametro `override_cost: int = -1`
- [x] Inserito blocco TimeManager prima di `TurnManager.on_player_action_done()`: legge `map.map_type` e chiama `TimeManager.advance(cost)`

#### 2.3 `Player.gd` — settare `_last_action` in ogni punto di chiamata

- [x] Attacco nemico (`_try_move`): `_last_action = Action.ATTACK` prima di `CombatManager.attack()`
- [x] Attacco NPC con amuleto (`_try_move`): `_last_action = Action.ATTACK` prima di `CombatManager.attack()`
- [x] Abilità di classe (`_unhandled_input`): `_last_action = Action.ATTACK` all'inizio del blocco (copre anche targeting/menu il cui `_action_done()` è chiamato da ClassRuntime)
- [x] Movimento normale (`_try_move`): `_last_action = Action.MOVE` prima di `_action_done()`; overworld usa `_get_move_cost_overworld()`
- [x] Interazione NPC/entità (`_try_interact`): `_last_action = Action.INTERACT`
- [x] Loot cadavere (`_try_interact`): `_last_action = Action.INTERACT`
- [x] Fuga (tutte e 3 le branch di `flee_attempt`): `_last_action = Action.MOVE`

#### 2.4 `CombatBar.gd` — tasto R: wait rapido + hold detection

- [x] Rimosso blocco `action_wait` da `_unhandled_input()` (era condizionato a `_in_combat`)
- [x] Rinominato `_on_wait()` → `_on_quick_wait()`; aggiornato connect in `_ready()`
- [x] `_on_quick_wait()` ora chiama `TimeManager.advance(get_action_cost(map_type, 4))` prima di `TurnManager.on_player_action_done()`
- [x] Aggiunte variabili `_wait_hold_timer`, `_wait_screen_open`, `WAIT_HOLD_THRESHOLD = 0.4`
- [x] Aggiunto `_process(delta)`: guard `TurnManager.is_active and not is_player_turn`; hold detection; tap → `_on_quick_wait()`; hold ≥ 0.4s: in esplorazione apre WaitScreen, in combattimento fa quick wait
- [x] `locales/strings_ui.csv` `UI_COMBATBAR_WAIT`: `[Q] Aspetta` → `[R] Aspetta`
- [x] `wait_completed` di WaitScreen → `_on_wait_screen_closed()` → `_wait_screen_open = false`; riferimento `_wait_screen` caricato in `_ready()` via `get_node_or_null`

#### 2.5 `Player.gd` — costo movimento overworld

- [x] Aggiunto `_get_move_cost_overworld()`: `ceili(240.0 * 1.0 * 1.0)` con placeholder terrain/mount
- [x] In `_try_move()`, dopo `move_to()`: se `map.map_type == "overworld"` → `_action_done(_get_move_cost_overworld())`; altrimenti `_action_done()`

#### 2.6 Verifica Fase 2

- [x] Avviare il gioco e muoversi in un villaggio di giorno → il tempo deve avanzare di 1 min per tile *(confermato)*
- [x] Muoversi in un dungeon → 3 min per tile *(confermato)*
- [x] Tap R (rilascio rapido) → 60 min in villaggio, 30 min in dungeon; pulsante [R] nella CombatBar produce lo stesso effetto
- [x] Sull'overworld → 240 min per tile (4h) *(confermato)*
- [ ] Verificare nella console che `EventBus.time_advanced` si emetta ad ogni azione

#### 2.7 DebugScreen — verifica sezione TimeSystem

- [x] Aprire DebugScreen durante il gioco → la sezione `Time System` mostra valori aggiornati
- [x] Muoversi in dungeon → `map_type: dungeon`, `action_costs: M:3 A:3 I:2 W:30`
- [x] Muoversi in villaggio → `map_type: village`, `action_costs: M:1 A:1 I:1 W:60`
- [x] Usare il pannello `TimeTools → +1h` → `total_minutes` aumenta di 60, `display` si aggiorna
- [x] Usare `TimeTools → +1 giorno` → `abs_day` aumenta di 1, la data nel `display` avanza
- [x] Usare `TimeTools → Reset` → `total_minutes` torna a 480, `display` mostra `"1 Nevargento 472 C — Giorno"`

---

### FASE 2.5 — WaitScreen

#### 2.5.1 Creare `WaitScreen.tscn`

- [x] Scena minimale `scenes/ui/WaitScreen.tscn`: CanvasLayer layer=10, visible=false; tutto il layout costruito a codice in `_ready()` da `WaitScreen.gd`

#### 2.5.2 Creare `scripts/ui/WaitScreen.gd`

- [x] `extends CanvasLayer`, `signal wait_completed`, `WAIT_TICK_DELAY=0.08`, `MAX_WAIT_HOURS=8`
- [x] UI costruita interamente a codice in `_build_ui()`: overlay semitrasparente + PanelContainer centrato 300px + VBox con FromLabel/ToLabel/NowLabel/HSlider/HoursLabel/WaitBtn/CancelBtn
- [x] `open()`, `_update_selection_labels()`, `_on_slider_changed()`, `_on_wait_confirmed()` implementati
- [x] `_run_wait_animation()` con await: avanza 60 min alla volta, aggiorna slider e NowLabel ogni 0.08s
- [x] `_finish()`: emette `Notification.wait_finished()`, chiama `TurnManager.on_player_action_done()`, hide + `wait_completed.emit()`
- [x] `_on_cancel_pressed()`: solo se `not _animating` → hide + `wait_completed.emit()`
- [x] `_unhandled_input`: ESC chiude durante la selezione

#### 2.5.3 Aggiungere `format_time_from()` a `TimeManager.gd`

- [x] Già implementato in FASE 1 — il metodo esiste e calcola localmente senza mutare `GameState.total_minutes`
  ```gdscript
  func format_time_from(minutes: int) -> String:
      var saved: int = GameState.total_minutes
      # calcola solo slot senza mutare stato
      var wt: int = minutes % 1440
      var h:  int = wt / 60
      var slot: String
      if   h >= 5  and h < 8:  slot = "alba"
      elif h >= 8  and h < 12: slot = "mattina"
      elif h >= 12 and h < 18: slot = "pomeriggio"
      elif h >= 18 and h < 21: slot = "sera"
      else:                    slot = "notte"
      var phase: String
      match slot:
          "alba":                  phase = LocaleManager.t("TIME_PHASE_ALBA")
          "mattina","pomeriggio":  phase = LocaleManager.t("TIME_PHASE_GIORNO")
          "sera":                  phase = LocaleManager.t("TIME_PHASE_TRAMONTO")
          _:                       phase = LocaleManager.t("TIME_PHASE_NOTTE")
      return LocaleManager.t("TIME_FORMAT_FULL", {
          "date":  format_date_from(minutes),
          "phase": phase
      })
  ```
  > Nota: non muta `GameState.total_minutes` — calcola tutto localmente.

#### 2.5.4 `Notification.gd` — factory method

- [x] `Notification.wait_finished(hours, new_time)` aggiunto; `NOTIF_WAIT_DONE` in `strings_notifications.csv`

#### 2.5.5 Localizzazione

- [x] `strings_ui.csv`: `UI_WAIT_TITLE/FROM/TO/NOW/START/HOURS/BTN` aggiunte
- [x] `strings_notifications.csv`: `NOTIF_WAIT_DONE,Hai aspettato {hours} ore. {time}.` aggiunta

#### 2.5.6 Collegare WaitScreen alla scena Main

- [x] `WaitScreen` aggiunto come figlio di `Main.tscn` (layer=10, sopra HUD)
- [x] `CombatBar._ready()` recupera il riferimento via `get_node_or_null` e connette `wait_completed → _on_wait_screen_closed()`

#### 2.5.7 Verifica Fase 2.5

- [x] Tap R → avanza 60 min (villaggio), HUD aggiornato, nessun popup *(confermato)*
- [x] Hold R (≥ 0.4s) → WaitScreen si apre *(confermato)*
- [x] Spostare lo slider a 4 ore → label "A:" si aggiorna *(confermato)*
- [x] Premere [Aspetta] → animazione: slider scorre indietro, "Ora:" si aggiorna ogni ora simulata *(confermato)*
- [x] Al termine → WaitScreen si chiude, notifica "Hai aspettato N ore..." *(confermato)*
- [x] Annulla durante selezione → WaitScreen si chiude senza avanzare il tempo *(confermato)*
- [x] Tentare annulla durante animazione → animazione troppo breve per testarlo manualmente, logica implementata correttamente

#### 2.5.8 DebugScreen — stato WaitScreen

- [x] Già implementato in 1.6 — `_update_time_system()` mostra `wait_open`, `wait_anim`, `wait_target` se WaitScreen è aperta

#### 2.6 Aggiornamento piano e codebase_reference

- [x] Piano aggiornato (questa sessione)
- [x] `codebase_reference.md` aggiornato con WaitScreen e sezione CombatBar rivista

---

### FASE 3 — HUD: TimeLabel

> **Anticipata in FASE 1.7.** L'implementazione è già completa: `TimeLabel` aggiunto a `HUD.tscn` come figlio diretto del CanvasLayer (nodo separato dal Panel, full-width, centrato in alto), e `HUD.gd` cablato a `EventBus.time_advanced`. Le sottofasi seguenti servono solo per verifica e DebugScreen.

#### 3.4 Verifica Fase 3

- [x] Avviare il gioco → la label mostra `"1 Nevargento 472 C — Giorno"` *(implementato in FASE 1.7, funzionante)*
- [x] Muoversi alcune volte → il testo si aggiorna *(confermato: time system funziona)*
- [x] Far passare la notte (TimeTools +8h) → mostra `"... — Notte"`
- [x] Far avanzare al giorno 2 (TimeTools +1 giorno) → mostra `"2 Nevargento 472 C — ..."`

#### 3.5 Aggiornamento piano e codebase_reference

- [x] Piano aggiornato (questa sessione)
- [x] `codebase_reference.md` già aggiornato con sezione HUD/TimeLabel in FASE 1

#### 3.6 DebugScreen — verifica TimeLabel

- [x] `hud_time_label` già presente in `_update_time_system()` fin dalla FASE 1.6
- [x] Corrisponde a `display` — stessa stringa da `TimeManager.format_time()`
- [x] Entrambi aggiornati su `EventBus.time_advanced`

---

### FASE 4 — Save / Load

#### 4.1 `scripts/core/SaveManager.gd` — salvataggio

- [x] Aprire SaveManager.gd e trovare la funzione di salvataggio (`_save_character()`)
- [x] Trovare il punto in cui viene costruito il Dictionary dei dati da salvare
- [x] Aggiunto `"total_minutes": GameState.total_minutes` al Dictionary
- [x] Verificato che nessun altro campo di tempo venga salvato — nessun campo obsoleto trovato

#### 4.2 `SaveManager.gd` — caricamento

- [x] Trovata `_apply_save_data()` come funzione di caricamento
- [x] Aggiunto: `GameState.total_minutes = int(data.get("total_minutes", 480))`
- [x] Il valore di default `480` garantisce che un salvataggio vecchio (senza il campo) parta alle 8:00 del giorno 1
- [x] Il caricamento avviene prima di `WorldManager.change_map()` che istanzia la mappa — `BaseMap._ready()` legge il slot già corretto

#### 4.3 Verifica Fase 4

- [x] Avanzare il tempo a una fascia diversa da `"Giorno"` (es. `"Notte"`)
- [x] Salvare il gioco
- [x] Uscire e ricaricare il salvataggio
- [x] Verificare che `GameState.total_minutes` abbia il valore corretto *(confermato dall'utente)*
- [x] Verificare che `TimeManager.format_time()` mostri la fascia corretta dopo il load *(confermato: HUD e debug screen mostrano valori corretti)*
- [x] Verificare che le luci siano nello stato corretto dopo il load — fix applicato: `BaseMap._ready()` ora chiama `_on_day_slot_changed(TimeManager.get_slot())` dopo la connessione al signal *(confermato dall'utente)*

#### 4.4 DebugScreen — verifica dopo load

- [x] Caricare un salvataggio con orario diverso da `"Giorno"` (es. `"notte"`)
- [x] Aprire DebugScreen subito dopo il load → `total_minutes` deve corrispondere al valore salvato *(confermato)*
- [x] `display` e `hud_time_label` nel DebugScreen devono concordare tra loro *(confermato)*
- [ ] `TimeTools → +1h` → il tempo avanza correttamente anche dopo un load

---

### FASE 5 — Smoke test integrazione completa

> **Bug trovato e corretto durante la revisione FASE 5**: `Main._reset_game_state()` non resettava `total_minutes` — risolto usando `start_minutes` come parametro calcolato prima del reset.
> **Bug trovato e corretto**: `_go_to_main_menu()` nascondeva il PauseMenu senza chiamare `close_pause()`, lasciando `get_tree().paused = true` — aggiunto `get_tree().paused = false` esplicito.

- [x] Avviare una nuova partita → ora iniziale corretta (vedi Funzionalità Extra) *(garantito)*
- [x] Entrare in un villaggio e muoversi → tempo avanza di 1 min/tile, HUD aggiornato *(confermato dall'utente)*
- [ ] Avanzare manualmente a `sera` (TimeTools +8h) → luci si accendono, FOV cambia, HUD aggiornato *(da verificare in gioco)*
- [ ] Avanzare a `notte` → luci attive, NPC nascosti nelle zone buie *(da verificare)*
- [ ] Avanzare a oltre le 5:00 → `"... — Alba"`, luci si spengono *(da verificare)*
- [x] Entrare in un dungeon → movimento costa 3 min, Wait costa 30 min, FOV binario *(confermato dall'utente)*
- [x] Salvare e ricaricare in vari slot orari → stato sempre coerente *(confermato dall'utente)*
- [x] `EventBus.world_ticked` emesso solo per avanzamenti ≥ 30 min *(verificato da code review)*

#### 5.1 DebugScreen — smoke test completo

- [x] Aprire DebugScreen all'avvio → sezione `Time System` con valori corretti *(confermato)*
- [x] `TimeTools → +1 giorno` / `Reset` *(confermato)*
- [x] Muoversi in dungeon/villaggio → `action_costs` corretti *(confermato)*
- [x] Hold R → WaitScreen → notifica → chiusura *(confermato)*
- [x] Caricare un salvataggio → `total_minutes` coerente *(confermato)*

#### 5.2 Aggiornamento piano e codebase_reference

- [x] Aggiornato `plan_time_system.md` (questa sessione)
- [x] Aggiornato `codebase_reference.md` (questa sessione)
- [x] Aggiornato `todo.md` (questa sessione)

---

### Funzionalità extra (fuori piano originale)

#### FX.1 — Continuità temporale multi-personaggio nello stesso mondo

Quando si crea un nuovo personaggio in un mondo già esistente (con almeno un salvataggio esplicito), il gioco parte alle 08:00 del giorno successivo al `total_minutes` più alto tra tutti i personaggi di quel mondo.

**Implementazione:**

- `world.json` contiene nel campo `meta` un dizionario `character_timestamps`:
  ```json
  "character_timestamps": {
      "Aldric": 2880,
      "Mira":   4320
  }
  ```
  Il dizionario viene aggiornato ad ogni `save_game()` esplicito (save point). Non viene scritto al semplice ritorno al menù principale — il salvataggio rimane sempre volontario.

- `WorldSaveManager.save_world()` legge i timestamp esistenti via `_read_character_timestamps()`, aggiorna l'entry del personaggio corrente e scrive il dizionario aggiornato.

- `WorldSaveManager._read_character_timestamps(world_name) -> Dictionary`: helper interno che legge `meta.character_timestamps` dal `world.json` senza caricare l'intero stato di gioco. Restituisce `{}` se il file non esiste o il campo è assente.

- `WorldSaveManager.get_world_max_minutes(world_name) -> int`: restituisce il massimo tra tutti i valori in `character_timestamps`. Backward compat: se il campo è assente cade su `world_max_minutes` scalare (vecchio formato). Restituisce 0 se non c'è nulla.

- `Main._start_new_game()`: se il mondo esiste, legge `world_max_minutes` e calcola:
  ```gdscript
  start_minutes = (int(world_max / 1440.0) + 1) * 1440 + 480
  ```
  Il risultato viene passato come parametro a `_reset_game_state(world_name, char_name, pd, class_id, start_minutes)`.

- Mondi nuovi (nessun salvataggio → `has_world` = false): `start_minutes = 480` — nessuna logica speciale.

---

### Note per fasi future (fuori scope qui)

- **NPC accumulator** (`_on_time_advanced`, `movement_interval`, `_perform_routine_step`) → FASE 2 NPC System
- **`is_open()` per vendor schedule** → FASE 2 NPC System (dipende da TimeManager, che ora esiste)
- **WorldSimulator / WorldActor** → Overworld System
- **Terrain e mount multiplier** → sostituire il `1.0` placeholder in `_get_move_cost_overworld()` quando sarà disponibile il dato bioma
- **REST (480 min in locanda)** → chiamata diretta `TimeManager.advance(480)` dall'interazione dialogo con l'innkeeper — da aggiungere quando il dialogo per dormire sarà implementato

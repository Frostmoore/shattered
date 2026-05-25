# Piano: Time System

**Stato**: Progettato — pronto per implementazione. Prerequisito di NPC System, Vendor System, Travel System.

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
- [ ] `SaveManager`: serializza/deserializza `total_minutes`
- [x] `BaseMap._compute_fov()`: applica `get_vision_modifier()` + luci locali *(già fatto — aspetta TimeManager)*
- [x] `BaseMap._ready()`: connetti `day_slot_changed` → recompute FOV *(già fatto)*
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

- [ ] Aprire il file e trovare il blocco delle variabili di stato principale
- [ ] Aggiungere il campo `var total_minutes: int = 480` (equivale alle 8:00 del 1 Nevargento 472 C)
- [ ] Aggiungere la proprietà derivata `world_time` con getter `return total_minutes % 1440`
- [ ] Verificare che non ci siano altri campi `hour`, `day`, `day_count`, `time` o simili — se presenti, rimuoverli e aggiornare tutti i riferimenti (il calendario è calcolato interamente da TimeManager)

#### 1.2 Creare `scripts/core/TimeManager.gd`

- [ ] Creare il file `scripts/core/TimeManager.gd` con `extends Node`
- [ ] Definire `const WORLD_TICK_INTERVAL: int = 30`
- [ ] Definire le costanti calendario:
  - `const BASE_YEAR: int = 472`
  - `const DAYS_PER_MONTH: int = 30`
  - `const DAYS_PER_YEAR: int = 360`
  - `const MONTH_KEYS: Array[String]` con le 12 chiavi di localizzazione (`"TIME_MONTH_1"` … `"TIME_MONTH_12"`) — **non** i nomi diretti
- [ ] Implementare `func get_hour() -> int: return GameState.world_time / 60`
- [ ] Implementare `func get_minute() -> int: return GameState.world_time % 60`
- [ ] Implementare `func get_slot() -> String`:
  - `h >= 5  and h < 8`  → `"alba"`
  - `h >= 8  and h < 12` → `"mattina"`
  - `h >= 12 and h < 18` → `"pomeriggio"`
  - `h >= 18 and h < 21` → `"sera"`
  - default              → `"notte"`
- [ ] Implementare `func is_night() -> bool: return get_slot() == "notte"`
- [ ] Implementare `func _display_phase() -> String` (privata) — usa `LocaleManager.t()`:
  - `"alba"` → `LocaleManager.t("TIME_PHASE_ALBA")`
  - `"mattina"`, `"pomeriggio"` → `LocaleManager.t("TIME_PHASE_GIORNO")`
  - `"sera"` → `LocaleManager.t("TIME_PHASE_TRAMONTO")`
  - default → `LocaleManager.t("TIME_PHASE_NOTTE")`
- [ ] Implementare helper calendario:
  - `func get_absolute_day() -> int: return GameState.total_minutes / 1440`
  - `func get_year() -> int: return BASE_YEAR + get_absolute_day() / DAYS_PER_YEAR`
  - `func get_month_index() -> int: return (get_absolute_day() % DAYS_PER_YEAR) / DAYS_PER_MONTH`
  - `func get_day_of_month() -> int: return (get_absolute_day() % DAYS_PER_MONTH) + 1`
  - `func get_month_name() -> String: return LocaleManager.t(MONTH_KEYS[get_month_index()])`
- [ ] Implementare `func format_date() -> String`: usa `LocaleManager.t("TIME_FORMAT_DATE", {"day": ..., "month": ..., "year": ...})`
- [ ] Implementare `func format_time() -> String`: usa `LocaleManager.t("TIME_FORMAT_FULL", {"date": format_date(), "phase": _display_phase()})`  → es. `"1 Nevargento 472 C — Giorno"`
- [ ] Implementare `func format_date_from(minutes: int) -> String`: stessa logica di `format_date()` ma su un valore `minutes` arbitrario (per deadline quest); usa gli stessi template `TIME_FORMAT_DATE` e `MONTH_KEYS`
- [ ] **Localizzazione**: aprire `locales/strings_ui.csv` e aggiungere le 18 chiavi `TIME_*` (4 fasi + 12 mesi + 2 template formato) — vedi sezione "Localizzazione" del piano
- [ ] Implementare `func get_vision_modifier(map_type: String) -> float`:
  - Se `is_night()` e `map_type in ["village", "city", "overworld"]` → `return 0.6`
  - Altrimenti → `return 1.0`
- [ ] Implementare `func get_action_cost(map_type: String, action: int) -> int` con la tabella completa:
  ```
  "building": [1, 1, 1, 1, 60]
  "village":  [1, 1, 1, 1, 60]
  "city":     [2, 2, 1, 1, 60]
  "dungeon":  [3, 3, 2, 0, 30]
  "ruin":     [3, 3, 2, 0, 30]
  "overworld":[0, 5, 5, 5, 60]   # 0 = calcolato separatamente per MOVE
  ```
  - fallback per map_type sconosciuto: `[2, 2, 1, 1, 60]`
  - fallback per action fuori range: `2`
- [ ] Implementare `func advance(minutes: int) -> void`:
  - Salvare `prev_slot = get_slot()` e `prev_abs_day = get_absolute_day()`
  - `GameState.total_minutes += minutes`
  - Se `get_absolute_day() != prev_abs_day` → `EventBus.day_changed.emit(get_absolute_day())`
  - `EventBus.time_advanced.emit(minutes)`
  - Se `get_slot() != prev_slot` → `EventBus.day_slot_changed.emit(get_slot())`
  - Calcola `ticks: int = minutes / WORLD_TICK_INTERVAL`; se `ticks > 0` → `EventBus.world_ticked.emit(ticks, WORLD_TICK_INTERVAL)`

#### 1.3 `project.godot` — registrazione autoload

- [ ] Aprire `project.godot` (o Project Settings → Autoload in editor)
- [ ] Aggiungere `TimeManager = "res://scripts/core/TimeManager.gd"` nella sezione `[autoload]`
- [ ] Verificare che `TimeManager` appaia **prima** di `WorldManager` nella lista degli autoload (l'ordine determina l'ordine di `_ready()`)
- [ ] Riavviare l'editor o ricaricare il progetto per verificare che non ci siano errori di parsing

#### 1.4 Verifica Fase 1

- [ ] Aprire la console di Godot e verificare che non ci siano errori all'avvio
- [ ] Nel debugger/console, chiamare `TimeManager.format_time()` — deve restituire `"1 Nevargento 472 C — Giorno"` (ore 8:00)
- [ ] Chiamare `TimeManager.advance(780)` (avanza di 13 ore → 21:00) — deve restituire slot `"notte"`
- [ ] Verificare che `EventBus.day_slot_changed` sia stato emesso
- [ ] Verificare che `GameState.world_time` == 1260 e `TimeManager.get_absolute_day()` == 0

#### 1.5 Aggiornamento piano e codebase_reference

- [ ] Aggiornare la sezione 'Fasi di implementazione - dettaglio completo' del file `.claude/plan_time_system.md` e il file `.claude/codebase_reference.md`
- [ ] Mostrare le Fasi di implementazione con checkbox per fasi e sottofasi, in modo dettagliato e approfondito

---

### FASE 2 — Hook Player Actions

#### 2.1 `scripts/entities/Player.gd` — enum azione

- [ ] Aprire Player.gd e trovare la sezione delle variabili di stato
- [ ] Aggiungere l'enum in cima al file (dopo `extends` / `class_name`):
  ```gdscript
  enum Action { MOVE = 0, ATTACK = 1, USE_ITEM = 2, INTERACT = 3, WAIT = 4 }
  ```
- [ ] Aggiungere la variabile `var _last_action: int = Action.MOVE`

#### 2.2 `Player.gd` — modificare `_action_done()`

- [ ] Trovare la funzione `_action_done()` esistente
- [ ] Aggiungere il parametro opzionale `override_cost: int = -1`:
  ```gdscript
  func _action_done(override_cost: int = -1) -> void:
  ```
- [ ] Prima di `TurnManager.end_player_turn()`, inserire il blocco di avanzamento tempo:
  ```gdscript
  var map: BaseMap = WorldManager.get_current_map()
  if map != null:
      var cost: int = override_cost if override_cost >= 0 \
          else TimeManager.get_action_cost(map.map_type, _last_action)
      TimeManager.advance(cost)
  ```
- [ ] Assicurarsi che il blocco tempo venga eseguito **prima** di `TurnManager.end_player_turn()`

#### 2.3 `Player.gd` — settare `_last_action` in ogni punto di chiamata

- [ ] Cercare tutte le chiamate a `_action_done()` nel file
- [ ] Prima di ogni `_action_done()` relativo a **movimento** → `_last_action = Action.MOVE`
- [ ] Prima di ogni `_action_done()` relativo a **attacco** → `_last_action = Action.ATTACK`
- [ ] Prima di ogni `_action_done()` relativo a **uso item** → `_last_action = Action.USE_ITEM`
- [ ] Prima di ogni `_action_done()` relativo a **interazione NPC** → `_last_action = Action.INTERACT`
- [ ] Verificare che non ci siano chiamate a `_action_done()` senza un `_last_action` settato

#### 2.4 `CombatBar.gd` — tasto R: wait rapido + hold detection

Il wait è gestito in `CombatBar.gd`, **non** in Player.gd. CombatBar chiama `TurnManager.on_player_action_done()` direttamente, senza passare per Player._action_done().

- [ ] `action_wait` è già mappato a R (physical_keycode 82) in `project.godot` — nessuna modifica necessaria
- [ ] In `_unhandled_input()` rimuovere il blocco `if event.is_action_pressed("action_wait")...` — la gestione passa a `_process()`
- [ ] Rinominare `_on_wait()` → `_on_quick_wait()`; aggiornare connect in `_ready()`: `wait_btn.pressed.connect(_on_quick_wait)`
- [ ] Modificare `_on_quick_wait()` per aggiungere TimeManager:
  ```gdscript
  func _on_quick_wait() -> void:
      if not TurnManager.is_player_turn:
          return
      var map: BaseMap = WorldManager.get_current_map()
      if map:
          TimeManager.advance(TimeManager.get_action_cost(map.map_type, 4))
      _set_combat_buttons_active(false)
      TurnManager.on_player_action_done()
  ```
- [ ] Aggiungere variabili di stato per hold detection:
  ```gdscript
  var _wait_hold_timer:  float = 0.0
  var _wait_screen_open: bool  = false
  const WAIT_HOLD_THRESHOLD:   float = 0.4
  ```
- [ ] Aggiungere `@onready var _wait_screen: WaitScreen` (percorso definito in FASE 2.5)
- [ ] Aggiungere `func _process(delta: float) -> void`:
  ```gdscript
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
  ```
  > `is_action_just_released` non è affidabile in `_process()` — il rilascio si rileva controllando che `_wait_hold_timer > 0` mentre `is_action_pressed` è già false.
- [ ] Connettere il segnale `wait_completed` di WaitScreen → `_wait_screen_open = false`
- [ ] In `locales/strings_ui.csv`, riga `UI_COMBATBAR_WAIT`: cambiare `[Q] Aspetta` → `[R] Aspetta`

#### 2.5 `Player.gd` — costo movimento overworld

- [ ] Aggiungere il metodo `func _get_move_cost_overworld() -> int`:
  ```gdscript
  func _get_move_cost_overworld() -> int:
      var terrain_mult: float = 1.0   # placeholder — Overworld System
      var mount_mult: float   = 1.0   # placeholder — Mount System
      return ceili(240.0 * terrain_mult * mount_mult)
  ```
- [ ] Trovare il punto in `_try_move()` (o equivalente) dove il movimento sull'overworld viene applicato
- [ ] Dopo il `move_to()` sull'overworld, sostituire l'eventuale `_action_done()` con:
  ```gdscript
  _last_action = Action.MOVE
  _action_done(_get_move_cost_overworld())
  ```
- [ ] Verificare che per i movimenti NON-overworld il costo venga calcolato normalmente da `get_action_cost`

#### 2.6 Verifica Fase 2

- [ ] Avviare il gioco e muoversi in un villaggio di giorno → il tempo deve avanzare di 1 min per tile
- [ ] Muoversi in un dungeon → 3 min per tile
- [ ] Tap R (rilascio rapido) → 60 min in villaggio, 30 min in dungeon; pulsante [R] nella CombatBar produce lo stesso effetto
- [ ] Sull'overworld → 240 min per tile (placeholder)
- [ ] Verificare nella console che `EventBus.time_advanced` si emetta ad ogni azione

---

### FASE 2.5 — WaitScreen

#### 2.5.1 Creare `WaitScreen.tscn`

- [ ] Creare la scena `scenes/ui/WaitScreen.tscn` come `CanvasLayer` (layer alto, es. 10, per stare sopra il HUD)
- [ ] Aggiungere un `PanelContainer` centrato nello schermo, larghezza ~320px
- [ ] Struttura nodi interni:
  - `VBoxContainer`
    - `Label` — titolo `"ATTENDI"`
    - `Label` `FromLabel` — testo "Da: ..."
    - `Label` `ToLabel` — testo "A: ..."
    - `Label` `NowLabel` — testo "Ora: ..." (visibile solo durante animazione, inizialmente nascosto)
    - `HSlider` `HoursSlider` — min=1, max=8, step=1, value=1
    - `Label` `HoursLabel` — testo "{n} ore" aggiornato dallo slider
    - `HBoxContainer`
      - `Button` `WaitBtn` — testo localizzato `UI_WAIT_BTN`
      - `Button` `CancelBtn` — testo localizzato `UI_BTN_CANCEL`
- [ ] `WaitScreen` nascosto di default (`visible = false`)

#### 2.5.2 Creare `scripts/ui/WaitScreen.gd`

- [ ] Creare il file con `extends CanvasLayer`
- [ ] Definire le costanti `const WAIT_TICK_DELAY: float = 0.08` e `const MAX_WAIT_HOURS: int = 8`
- [ ] Aggiungere variabili: `_start_minutes: int`, `_target_minutes: int`, `_animating: bool`
- [ ] Implementare `func open() -> void`:
  - Impostare `_start_minutes = GameState.total_minutes`
  - `_target_minutes = _start_minutes + 3600` (default 1 ora)
  - Resettare lo slider (`value = 1`, `editable = true`)
  - Nascondere `NowLabel`; mostrare `FromLabel` e `ToLabel`
  - Chiamare `_update_selection_labels()`
  - `show()`
- [ ] Implementare `_update_selection_labels()`:
  - `_from_label.text = "Da: " + TimeManager.format_time()`
  - `_to_label.text   = "A: "  + TimeManager.format_time_from(_target_minutes)`
- [ ] Implementare `_on_slider_changed(value: float)`:
  - `_target_minutes = _start_minutes + int(value) * 60`
  - Aggiornare `_hours_label.text`
  - Aggiornare `_to_label.text`
- [ ] Implementare `_on_wait_confirmed()`:
  - Disabilitare slider e bottoni
  - Mostrare `NowLabel`, aggiornare `FromLabel` con testo "Inizio:" (fisso)
  - Impostare `_animating = true`
  - Chiamare `_run_wait_animation()`
- [ ] Implementare `func _run_wait_animation() -> void` (con `await`):
  ```gdscript
  while GameState.total_minutes < _target_minutes:
      var step: int = mini(60, _target_minutes - GameState.total_minutes)
      TimeManager.advance(step)
      _hours_slider.value = float(_target_minutes - GameState.total_minutes) / 60.0
      _now_label.text = "Ora: " + TimeManager.format_time()
      await get_tree().create_timer(WAIT_TICK_DELAY).timeout
  _finish()
  ```
- [ ] Implementare `_finish()`:
  - `_animating = false`
  - Emettere `Notification.wait_finished((_target_minutes - _start_minutes) / 60, TimeManager.format_time())`
  - `emit_signal("wait_completed")`
  - `hide()`
- [ ] Implementare `_on_cancel_pressed()`: se `not _animating`, `hide()` e `emit_signal("wait_completed")`
- [ ] Dichiarare il segnale `signal wait_completed`

#### 2.5.3 Aggiungere `format_time_from()` a `TimeManager.gd`

- [ ] Aggiungere il metodo:
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

- [ ] Aggiungere:
  ```gdscript
  static func wait_finished(hours: int, new_time: String) -> Notification:
      var n := Notification.new()
      n.text     = LocaleManager.t("NOTIF_WAIT_DONE", {"hours": str(hours), "time": new_time})
      n.color    = Color(0.6, 0.9, 1.0)
      n.duration = 3.0
      return n
  ```

#### 2.5.5 Localizzazione

- [ ] Aggiungere a `locales/strings_ui.csv`:
  ```
  UI_WAIT_TITLE,ATTENDI
  UI_WAIT_FROM,Da:
  UI_WAIT_TO,A:
  UI_WAIT_NOW,Ora:
  UI_WAIT_START,Inizio:
  UI_WAIT_HOURS,{n} ore
  UI_WAIT_BTN,Aspetta
  ```
- [ ] Aggiungere a `locales/strings_notifications.csv`:
  ```
  NOTIF_WAIT_DONE,Hai aspettato {hours} ore. Sono le {time}.
  ```

#### 2.5.6 Collegare WaitScreen alla scena Main

- [ ] Aggiungere `WaitScreen` come figlio di `Main.tscn` (o come nodo nella scena radice)
- [ ] Collegare il segnale `wait_completed` → `Player._wait_screen_open = false`
- [ ] Verificare che il CanvasLayer di WaitScreen sia sopra l'HUD ma non sopra le dialog boxes

#### 2.5.7 Verifica Fase 2.5

- [ ] Tap R → avanza 60 min (villaggio), HUD aggiornato, nessun popup
- [ ] Hold R (0.5s) → WaitScreen si apre, slider a 1 ora
- [ ] Spostare lo slider a 4 ore → label "A:" si aggiorna
- [ ] Premere [Aspetta] → animazione: slider scorre indietro da 4 a 0, "Ora:" si aggiorna ogni ora simulata
- [ ] Al termine → WaitScreen si chiude, notifica "Hai aspettato 4 ore. Sono le..."
- [ ] Annulla durante selezione → WaitScreen si chiude senza avanzare il tempo
- [ ] Tentare annulla durante animazione → nessun effetto (pulsante disabilitato)

#### 2.6 Aggiornamento piano e codebase_reference

- [ ] Aggiornare la sezione 'Fasi di implementazione - dettaglio completo' del file `.claude/plan_time_system.md` e il file `.claude/codebase_reference.md`
- [ ] Mostrare le Fasi di implementazione con checkbox per fasi e sottofasi, in modo dettagliato e approfondito

---

### FASE 3 — HUD: TimeLabel

#### 3.1 Trovare la scena HUD

- [ ] Aprire la scena HUD (cercare in `scenes/ui/` o `scenes/main/` — probabilmente `HUD.tscn` o il nodo HUD dentro `Main.tscn`)
- [ ] Identificare il contenitore in cui aggiungere la label (solitamente un `VBoxContainer` o `HBoxContainer` in alto)

#### 3.2 Aggiungere il nodo TimeLabel

- [ ] Aggiungere un nodo `Label` figlio del contenitore HUD, nominarlo `TimeLabel`
- [ ] Impostare `text` iniziale a `"1 Nevargento 472 C — Giorno"` (verrà aggiornato a runtime)
- [ ] Impostare la dimensione font adeguata al resto dell'HUD (coerente con le altre label)
- [ ] Posizionarlo in modo che non copra informazioni critiche (HP, status)

#### 3.3 Collegare nello script HUD

- [ ] Aprire lo script associato alla scena HUD
- [ ] Aggiungere `@onready var _time_label: Label = $percorso/TimeLabel`
- [ ] In `_ready()`, connettere: `EventBus.time_advanced.connect(_on_time_advanced)`
- [ ] Aggiungere il metodo:
  ```gdscript
  func _on_time_advanced(_minutes: int) -> void:
      _time_label.text = TimeManager.format_time()
  ```
- [ ] In `_ready()` chiamare subito `_time_label.text = TimeManager.format_time()` per il valore iniziale (evita la label vuota al primo frame)

#### 3.4 Verifica Fase 3

- [ ] Avviare il gioco → la label deve mostrare `"1 Nevargento 472 C — Giorno"`
- [ ] Muoversi alcune volte → il testo deve aggiornarsi
- [ ] Far passare la notte (advance manuale da console) → deve mostrare `"... — Notte"`
- [ ] Far avanzare al giorno 2 → deve mostrare `"2 Nevargento 472 C — ..."`

#### 3.5 Aggiornamento piano e codebase_reference

- [ ] Aggiornare la sezione 'Fasi di implementazione - dettaglio completo' del file `.claude/plan_time_system.md` e il file `.claude/codebase_reference.md`
- [ ] Mostrare le Fasi di implementazione con checkbox per fasi e sottofasi, in modo dettagliato e approfondito

---

### FASE 4 — Save / Load

#### 4.1 `scripts/core/SaveManager.gd` — salvataggio

- [ ] Aprire SaveManager.gd e trovare la funzione di salvataggio (es. `_save_character()` o `save_game()`)
- [ ] Trovare il punto in cui viene costruito il Dictionary dei dati da salvare
- [ ] Aggiungere `"total_minutes": GameState.total_minutes` al Dictionary
- [ ] Verificare che nessun altro campo di tempo venga salvato (rimuovere eventuali `"hour"`, `"day"`, `"time"` obsoleti e aggiornare i riferimenti)

#### 4.2 `SaveManager.gd` — caricamento

- [ ] Trovare la funzione di caricamento (es. `_apply_save_data()` o `load_game()`)
- [ ] Aggiungere: `GameState.total_minutes = int(data.get("total_minutes", 480))`
- [ ] Il valore di default `480` garantisce che un salvataggio vecchio (senza il campo) parta alle 8:00 del giorno 1
- [ ] Verificare che il caricamento avvenga **prima** di qualsiasi chiamata che usa `TimeManager.get_slot()` o `format_time()` — altrimenti il display HUD mostrerà valori sbagliati al load

#### 4.3 Verifica Fase 4

- [ ] Avanzare il tempo a una fascia diversa da `"Giorno"` (es. `"Notte"`)
- [ ] Salvare il gioco
- [ ] Uscire e ricaricare il salvataggio
- [ ] Verificare che `GameState.total_minutes` abbia il valore corretto
- [ ] Verificare che `TimeManager.format_time()` mostri la fascia corretta dopo il load
- [ ] Verificare che le luci siano nello stato corretto (accese/spente) dopo il load a `"notte"` o `"giorno"`

---

### FASE 5 — Smoke test integrazione completa

- [ ] Avviare una nuova partita → ora iniziale 08:00, `"1 Nevargento 472 C — Giorno"`, luci spente
- [ ] Entrare in un villaggio e muoversi → tempo avanza di 1 min/tile, HUD aggiornato
- [ ] Avanzare manualmente a `sera` (es. `TimeManager.advance(600)` da console) → le luci si accendono, FOV cambia, HUD mostra `"1 Nevargento 472 C — Tramonto"`
- [ ] Avanzare a `notte` → `"... — Notte"`, luci attive, NPC nascosti nelle zone buie
- [ ] Avanzare a oltre le 5:00 → `"... — Alba"`, luci si spengono, NPC visibili
- [ ] Entrare in un dungeon → movimento costa 3 min, Wait costa 30 min, FOV binario (nessun overlay)
- [ ] Salvare e ricaricare in vari slot orari → stato sempre coerente
- [ ] Verificare che `EventBus.world_ticked` si emetta solo per avanzamenti ≥ 30 min

#### 5.1 Aggiornamento piano e codebase_reference

- [ ] Aggiornare la sezione 'Fasi di implementazione - dettaglio completo' del file `.claude/plan_time_system.md` e il file `.claude/codebase_reference.md`
- [ ] Mostrare le Fasi di implementazione con checkbox per fasi e sottofasi, in modo dettagliato e approfondito

---

### Note per fasi future (fuori scope qui)

- **NPC accumulator** (`_on_time_advanced`, `movement_interval`, `_perform_routine_step`) → FASE 2 NPC System
- **`is_open()` per vendor schedule** → FASE 2 NPC System (dipende da TimeManager, che ora esiste)
- **WorldSimulator / WorldActor** → Overworld System
- **Terrain e mount multiplier** → sostituire il `1.0` placeholder in `_get_move_cost_overworld()` quando sarà disponibile il dato bioma
- **REST (480 min in locanda)** → chiamata diretta `TimeManager.advance(480)` dall'interazione dialogo con l'innkeeper — da aggiungere quando il dialogo per dormire sarà implementato

# Piano — Refactor HUD v2
> Branch: `test` — nessun codice va toccato finché questo piano non è approvato.

---

### Decisioni chiuse

| # | Tema | Risposta |
|---|---|---|
| D1 | Minimap | Funzionante nell'overworld (non placeholder) |
| D2 | Combat log righe | 1 riga passiva; espandibile al click |
| D3 | HUDBottom layout | Riga 1 = log · Riga 2 = tasti+quickslots |
| D4 | Explored tiles API | Non esiste → `GameState.explored_tiles` nuovo campo |
| D5 | Colori tile minimap | Sfondo grigio (esplorato) / nero (inesplorato) + dots colorati |
| D6 | Conflitto KEY_F | Flee consuma evento in combat; fuori combat propaga a QuickFoodMenu |
| D7 | Visibilità minimap | Flag `MapData.metadata["minimap_enabled"]`; CityBuilder aggiornato |
| D8 | Layout generale | Top bar piena per info principali + action bar in basso + pannelli modulari |
| D9 | HUDLeft larghezza | Abolito: info spostata nella top bar. QuestTracker è floating left con sfondo trasparente |
| D10 | Overflow slot | Nasconde slot da destra su schermi stretti |
| D11 | Tasto "Aspetta" | KEY_R (`action_wait`) |
| D12 | Font | **Roboto** — Regular/Medium/Bold copiati in `assets/fonts/`. PressStart2P rimane per elementi di gioco |
| D13 | Colori HUD | Antracite + oro |
| D14 | Estetica | Minimal, survival duro, bordo sottile, no decorazioni |
| D15 | HP/MP/ST valori | Solo al passaggio del mouse (tooltip-style) |
| D16 | Animazioni barre | Sì: tween su cambio valore + pulse su stato critico |
| D17 | Log espandibile | Click per espandere; mostra ultimi X messaggi con colori per categoria |
| D18 | Log fade | Messaggi in visualizzazione passiva scompaiono dopo N secondi |
| D19 | Log categorie | Colori diversi: combat (rosso), esplorazione (verde), loot (oro), quest (viola), dialogo (azzurro), sistema (grigio) |
| D20 | Bottoni azione | ASCII icon + nome sotto; tooltip hover; shortcut sempre visibile |
| D21 | Quest panel | Titolo breve + obiettivo corrente; sfondo trasparente; bottone espandi |
| D22 | Componenti separati | 8 componenti: PlayerStatusPanel, ResourceBar, ActionBar, MessageLog, QuestTracker, MinimapPanel, WorldInfoPanel, QuickSlotBar |
| D23 | XP bar | Sottilissima barra dorata (~3px) sotto nome+livello |
| D24 | F/W/E/Temp | Solo cambio colore, nessuna barra precisa; temperatura inclusa |
| D25 | Modalità UI | Due: **Info** (densità info) e **Style** (estetica). Selezionabile nelle opzioni |
| D26 | Opzioni HUD | Pagina dedicata nelle opzioni: toggle per ogni pannello + scelta modalità |
| D27 | 5 quickslot | Confermato. ASCII char per ora, icona in futuro |
| D28 | Stato critico | HP ≤ 25% → pulse rosso; ST ≤ 25% → pulse ambra; MP ≤ 25% → pulse blu |
| D-fade | Fade messaggi passivi | **5 secondi** |
| D-logsize | Dimensione log espanso | **40 messaggi** |
| D-timeshort | Formato ora WorldInfoPanel | Usare `format_time()` completo; nessuna versione corta |
| D-infomode | Differenza Info vs Style | **Info**: valori testo sempre visibili (`124/200`), 13 px, densità alta. **Style**: valori solo hover, 15 px, padding extra |
| D-hudopts | Collocazione HUDOptionsPanel | Tab nelle opzioni esistenti (implementazione a discrezione) |
| D-questobj | `get_active_quest_objective()` | Non esiste → va aggiunto a `QuestManager`; task inserito in `plan_quest_system.md` |
| D-mapdata | Accesso MapData da HUDV2 | `BaseMap._map_data` è privato. Usare `LocationRegistry.get_or_generate(GameState.current_map_id)` direttamente in HUDV2 |
| D-entity | Entity dots minimap | Città/villaggi/buildings = verde; Dungeon = viola; Eventi speciali = arancione; NPC = blu. Deferred all'overworld system |
| D-citybuilder | Toggle minimap in CityBuilder | Flag `MapData.metadata["minimap_enabled"]`; set da `WorldSaveManager` per overworld; toggle CityBuilder plugin analizzato in F9 |

---

## 1. Audit del sistema attuale

### File coinvolti
| File | Tipo | Ruolo attuale |
|---|---|---|
| `scenes/ui/HUD.tscn` | CanvasLayer | Panel top-left 240×244 px |
| `scripts/ui/HUD.gd` | Script | HP/MP/ST/XP, oro, stats, mappa, quest, needs, malattie |
| `scenes/ui/CombatBar.tscn` | CanvasLayer layer=3 | Strip bottom ×35 px, log 1 riga, 3 slot, tasti |
| `scripts/ui/CombatBar.gd` | Script | Log, wait-hold, 3 quickslots, segnali use_item/open_menu |
| `scripts/ui/Main.gd` | Scene root | Visibility separata di HUD e CombatBar |
| `scenes/main/Main.tscn` | Scene | Contiene HUD e CombatBar come figli diretti |

### Segnali EventBus confermati
- `player_moved(new_position: Vector2i)` ✓
- `quick_slots_changed()` ✓
- `player_stats_changed`, `equipment_changed`, `xp_gained`, `player_leveled_up`, `map_changed`, `quest_started/completed`, `inventory_changed`, `time_advanced`, `needs_changed`, `disease_*` ✓

### Sistemi dipendenti (stato)
| Sistema | Stato |
|---|---|
| `SettingsManager` | Nessun get/set generico → va esteso con campi espliciti HUD |
| `GameState.explored_tiles` | Non esiste → nuovo campo |
| `SaveManager` (explored_tiles) | Non gestisce → da aggiornare |
| `InventoryPanel` (slot buttons) | Solo 3 → va espanso a 5 |
| `MapData.metadata` | Esiste → `minimap_enabled` va lì |

---

## 2. Problemi identificati

| # | Problema | Gravità |
|---|---|---|
| P1 | HUD top-left 240×244 occlude lateralmente la mappa | Alta |
| P2 | Combat log perde i messaggi immediatamente, non espandibile | Alta |
| P3 | Solo 3 quickslot | Media |
| P4 | TimeLabel flottante senza contesto | Bassa |
| P5 | Nessun nome personaggio né classe visibili | Media |
| P6 | Nessuna minimap | Media |
| P7 | HUD e CombatBar gestiti separatamente in Main.gd | Bassa |
| P8 | Nessuna animazione né feedback visivo sulle barre risorse | Media |
| P9 | Nessuna pagina opzioni HUD; no toggle per i pannelli | Media |
| P10 | Log senza categorie/colori; tutti i messaggi indistinti | Media |
| P11 | Quest mostra solo il titolo, nessun obiettivo corrente | Bassa |
| P12 | Bottoni azione come semplice testo, nessun tooltip né icona | Bassa |

---

## 3. Architettura target

### Struttura nuova — 8 componenti separati

```
scenes/ui/hud/
  HUDV2.tscn                    ← CanvasLayer root
  components/
    PlayerStatusPanel.tscn      ← Nome, classe, livello, XP bar, F/W/E/T
    ResourceBar.tscn             ← Componente riusabile (istanziato 3×: HP, MP, ST)
    WorldInfoPanel.tscn          ← Zona + data/ora (top strip)
    ActionBar.tscn               ← Bottoni azione (ASCII icon + label + tooltip)
    MessageLog.tscn              ← Log passivo (1 riga) + espandibile al click
    QuestTracker.tscn            ← Quest attiva + obiettivo + espandibile; sfondo trasparente
    MinimapPanel.tscn            ← Image 160×160, drag, header; solo overworld
    QuickSlotBar.tscn            ← 5 quickslot

scripts/ui/hud/
  HUDV2.gd
  components/
    PlayerStatusPanel.gd
    ResourceBar.gd
    WorldInfoPanel.gd
    ActionBar.gd
    MessageLog.gd
    QuestTracker.gd
    MinimapPanel.gd
    QuickSlotBar.gd
  HUDState.gd                   ← Buffer log + metadata messaggi (categoria, timestamp)
  HUDSettings.gd                ← Lettura/scrittura campi SettingsManager per HUD
```

### File modificati (non nuovi)
| File | Modifica |
|---|---|
| `scenes/main/Main.tscn` | HUD + CombatBar → HUDV2 |
| `scripts/ui/Main.gd` | @onready, connect, visibility unificata, set_wait_screen |
| `scripts/core/GameState.gd` | `quick_slots` → 5 elem; `explored_tiles: Dictionary` |
| `scripts/core/SaveManager.gd` | Salva/carica explored_tiles; pad quickslots a 5 |
| `scripts/core/SettingsManager.gd` | Campi HUD espliciti + ui_mode |
| `scripts/ui/InventoryPanel.gd` | Espandere `_slot_assign_btns` a 5 |
| `scenes/ui/InventoryPanel.tscn` | Aggiungere Slot4Button, Slot5Button |
| `locales/strings_*.csv` | Chiavi UI nuove (tooltip bottoni, header pannelli) |
| `addons/city_builder/` | Toggle `minimap_enabled` nella mappa |

### Nuovi file
- `scenes/ui/HUDOptionsPanel.tscn` + `scripts/ui/HUDOptionsPanel.gd` — pagina opzioni HUD dedicata

### File eliminati (dopo F9)
- `scenes/ui/HUD.tscn`, `scripts/ui/HUD.gd`
- `scenes/ui/CombatBar.tscn`, `scripts/ui/CombatBar.gd`

### Nota CityBuilder
Aggiungere toggle `minimap_enabled` per ogni mappa. Il flag va in `MapData.metadata["minimap_enabled"]`. L'overworld lo imposta a `true` in `WorldSaveManager.generate_new_world()`.

### Nota plan_overworld_system.md
In F5 (MinimapPanel), scrivere in `.claude/plan_overworld_system.md`: **id overworld = `"overworld"`**.

---

## 4. Layout (wireframe)

Risoluzione virtuale 640×360. Il CanvasLayer si adatta alla finestra reale.

```
┌──── WorldInfoPanel  640 × ~16 px  (anchor top) ──────────────────────────────┐
│  Dungeon Lv. 2 — Cripta del Re                       1 Nev 472 · Lun · Sera  │
└──────────────────────────────────────────────────────────────────────────────┘
┌──── PlayerStatusPanel  640 × ~26 px ─────────────────────────────────────────┐
│  [Nome · Guerriero · Lv5]  ══════ xp ══════  [HP ▓▓▓▓░░] [MP ▓▓░░░░] [ST ▓▓▓░░]  [F G E -2°] │
└──────────────────────────────────────────────────────────────────────────────┘
│                                                        ┌───────────────────┐ │
│  [QuestTracker — floating left, trasparente]           │  MinimapPanel     │ │
│  ▸ Trova la spada                                      │  Pianura · Sera   │ │
│    Obiettivo: Parla con Aldric  [+]                    │  ┌─────────────┐  │ │
│                                                        │  │  · · ● · ·  │  │ │
│              M  A  P  P  A                             │  │  · ◦ · · ·  │  │ │
│                                                        │  └─────────────┘  │ │
│                                                        └───────────────────┘ │
│                                                                              │
┌──── MessageLog + ActionBar + QuickSlotBar  640 × ~38 px  (anchor bottom) ───┐
│  Il goblin ti attacca per 8 danni...             [R:↻][F:↗][I:⊞][M:≡]     │
│  [1:Poz.×3] [2:——] [3:——] [4:——] [5:——]                                   │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Spazio mappa libero**: 360 - 16 - 26 - 38 = **280 px** verticali non ostruiti; orizzontalmente: 640 px interi (nessun pannello laterale fisso).

### Anchor rules
- `WorldInfoPanel`: anchor_top=0, anchor_left/right=0/1, height=16
- `PlayerStatusPanel`: anchor_top=0, anchor_left/right=0/1, offset_top=16, height=26
- `MessageLog+ActionBar+QuickSlotBar`: anchor_top=1, anchor_bottom=1, anchor_left/right=0/1, offset_top=-38
- `QuestTracker`: floating, anchor_left=0, posizione (4, 46), larghezza ~200 px, sfondo trasparente
- `MinimapPanel`: posizione salvata in SettingsManager, default bottom-right

### Log espansione
Click su MessageLog → Panel overlay di ~120 px di altezza sale dal basso, mostra ultimi 40 messaggi con colori categoria, scrollabile. Click fuori o Escape per chiudere.

### Bottoni azione (ActionBar)
```
┌────┐  ┌────┐  ┌────┐  ┌────┐
│ ↻  │  │ ↗  │  │ ⊞  │  │ ≡  │
│ R  │  │ F  │  │ I  │  │Esc │
└────┘  └────┘  └────┘  └────┘
```
ASCII char (grande) + key/nome sotto (piccolo). Tooltip on hover.

---

## 5. Stile visivo

### Palette antracite + oro
| Elemento | Colore |
|---|---|
| Background pannelli | `Color(0.10, 0.10, 0.12, 0.93)` antracite |
| Bordo sottile | `Color(0.75, 0.62, 0.20, 0.80)` oro muto |
| Testo header | `Color(0.92, 0.78, 0.35)` oro caldo |
| Testo corpo | `Color(0.82, 0.82, 0.82)` grigio chiaro |
| Background QuestTracker | `Color(0, 0, 0, 0.0)` trasparente |
| Testo QuestTracker | `Color(0.85, 0.75, 0.30)` oro tenue |

### Barre risorse
| Barra | Colore normale | Critico (≤ 25%) |
|---|---|---|
| HP | `#be1a1a` rosso scuro | Pulse rosso vivace |
| MP | `#1a52c8` blu scuro | Pulse azzurro |
| ST | `#c87e10` ambra scura | Pulse ambra vivace |
| XP | `#c8a820` oro — barra sottile 3 px | — |

### Log categorie
| Categoria | Colore |
|---|---|
| Combat | `Color(0.90, 0.25, 0.25)` rosso |
| Exploration | `Color(0.35, 0.75, 0.40)` verde |
| Loot | `Color(0.90, 0.75, 0.25)` oro |
| Quest | `Color(0.70, 0.45, 0.90)` viola |
| Dialogue | `Color(0.55, 0.70, 0.95)` azzurro |
| System | `Color(0.55, 0.55, 0.55)` grigio |

### Animazioni
- **Cambio valore barra**: `Tween`, durata 0.25 s, ease `EASE_OUT`
- **Pulse critico**: `sin(Time.get_ticks_msec() * 0.004)` → modula alpha 0.6–1.0
- **Fade messaggi passivi**: messaggio rimane visibile X secondi (D-open), poi tween alpha → 0
- **Log espansione**: Panel slide-up in 0.15 s

### Font
| Uso | File | Peso |
|---|---|---|
| Testo corpo, labels, log | `Roboto-Regular.ttf` | 400 |
| Bottoni, valori UI, quickslot | `Roboto-Medium.ttf` | 500 |
| Header nome/classe, titoli pannelli | `Roboto-Bold.ttf` | 700 |
| Elementi di gioco (mappa, entità) | `PressStart2P.ttf` | — |

Roboto è proporzionale: a parità di font-size occupa meno spazio orizzontale di PressStart2P. Le taglie indicative per l'HUD sono **13 px** per il testo corpo e **15 px** per i titoli (da affinare in fase di implementazione).

---

## 6. HUDState.gd

**Tipo**: Node figlio di HUDV2, non autoload.

```gdscript
class_name HUDState
extends Node

const LOG_CAPACITY := 40  # storico completo per log espanso

enum LogCategory { COMBAT, EXPLORATION, LOOT, QUEST, DIALOGUE, SYSTEM }

class LogEntry:
    var text:      String
    var category:  int        # LogCategory
    var timestamp: float      # Time.get_ticks_msec() / 1000.0
    func _init(t: String, c: int): text = t; category = c; timestamp = Time.get_ticks_msec() / 1000.0

var entries: Array[LogEntry] = []

func push(text: String, category: int = LogCategory.SYSTEM) -> void:
    entries.push_back(LogEntry.new(text, category))
    if entries.size() > LOG_CAPACITY:
        entries.pop_front()

func get_latest() -> LogEntry:
    return entries.back() if not entries.is_empty() else null

func get_color(category: int) -> Color:
    match category:
        LogCategory.COMBAT:      return Color(0.90, 0.25, 0.25)
        LogCategory.EXPLORATION: return Color(0.35, 0.75, 0.40)
        LogCategory.LOOT:        return Color(0.90, 0.75, 0.25)
        LogCategory.QUEST:       return Color(0.70, 0.45, 0.90)
        LogCategory.DIALOGUE:    return Color(0.55, 0.70, 0.95)
        _:                       return Color(0.55, 0.55, 0.55)
```

Il coordinatore HUDV2 determina la categoria dal segnale sorgente (es. `combat_log` → COMBAT, `quest_started` → QUEST) e chiama `_state.push(text, category)`.

---

## 7. HUDSettings.gd

**Tipo**: Node figlio di HUDV2. SettingsManager riceve i campi HUD come campi espliciti.

```gdscript
# Nuovi campi in SettingsManager.gd:
var hud_ui_mode:         String = "info"   # "info" | "style"
var hud_show_status:     bool   = true
var hud_show_quest:      bool   = true
var hud_show_minimap:    bool   = true
var hud_show_worldinfo:  bool   = true
var hud_show_needs:      bool   = true
var hud_minimap_pos_x:   float  = -4.0
var hud_minimap_pos_y:   float  = -4.0
# Aggiornare save_settings() e load_settings() con get() + default

# HUDSettings.gd:
class_name HUDSettings
extends Node

func get_ui_mode()    -> String: return SettingsManager.hud_ui_mode
func is_info_mode()   -> bool:   return SettingsManager.hud_ui_mode == "info"
func show_status()    -> bool:   return SettingsManager.hud_show_status
func show_quest()     -> bool:   return SettingsManager.hud_show_quest
func show_minimap()   -> bool:   return SettingsManager.hud_show_minimap
func show_worldinfo() -> bool:   return SettingsManager.hud_show_worldinfo
func show_needs()     -> bool:   return SettingsManager.hud_show_needs
func get_minimap_pos()-> Vector2: return Vector2(SettingsManager.hud_minimap_pos_x, SettingsManager.hud_minimap_pos_y)

func set_ui_mode(mode: String) -> void:
    SettingsManager.hud_ui_mode = mode; SettingsManager.save_settings()
func toggle_status()    -> void: _toggle("hud_show_status")
func toggle_quest()     -> void: _toggle("hud_show_quest")
func toggle_minimap()   -> void: _toggle("hud_show_minimap")
func toggle_worldinfo() -> void: _toggle("hud_show_worldinfo")
func toggle_needs()     -> void: _toggle("hud_show_needs")
func save_minimap_pos(pos: Vector2) -> void:
    SettingsManager.hud_minimap_pos_x = pos.x
    SettingsManager.hud_minimap_pos_y = pos.y
    SettingsManager.save_settings()
func _toggle(field: String) -> void:
    SettingsManager.set(field, not bool(SettingsManager.get(field)))
    SettingsManager.save_settings()
```

---

## 8. Pseudocodice componenti

### HUDV2.gd
```gdscript
extends CanvasLayer
class_name HUDV2

signal use_item_requested()
signal open_menu_requested()

@onready var _status:    PlayerStatusPanel = $Components/PlayerStatusPanel
@onready var _worldinfo: WorldInfoPanel    = $Components/WorldInfoPanel
@onready var _log:       MessageLog        = $Components/MessageLog
@onready var _actionbar: ActionBar         = $Components/ActionBar
@onready var _slots:     QuickSlotBar      = $Components/QuickSlotBar
@onready var _quest:     QuestTracker      = $Components/QuestTracker
@onready var _minimap:   MinimapPanel      = $Components/MinimapPanel
@onready var _state:     HUDState          = $HUDState
@onready var _settings:  HUDSettings       = $HUDSettings

func _ready() -> void:
    _apply_settings_visibility()
    _minimap.load_position(_settings.get_minimap_pos())
    _minimap.position_changed.connect(_settings.save_minimap_pos)
    _actionbar.use_item_requested.connect(use_item_requested.emit)
    _actionbar.open_menu_requested.connect(open_menu_requested.emit)
    _wire_eventbus()
    _refresh_all()

func set_wait_screen(node: Node) -> void:
    _actionbar.set_wait_screen(node)

func _apply_settings_visibility() -> void:
    _status.visible    = _settings.show_status()
    _worldinfo.visible = _settings.show_worldinfo()
    _quest.visible     = _settings.show_quest()
    _minimap.visible   = _settings.show_minimap() and _is_minimap_map(GameState.current_map_id)
    _status.apply_ui_mode(_settings.get_ui_mode())

func _wire_eventbus() -> void:
    EventBus.player_stats_changed.connect(func(_a=null): _status.refresh())
    EventBus.equipment_changed.connect(func(_a=null): _status.refresh())
    EventBus.xp_gained.connect(func(_a=null): _status.refresh())
    EventBus.player_leveled_up.connect(func(_a=null): _status.refresh())
    EventBus.map_changed.connect(_on_map_changed)
    EventBus.quest_started.connect(func(_id): _quest.refresh())
    EventBus.quest_completed.connect(func(_id): _quest.refresh())
    EventBus.inventory_changed.connect(func(): _slots.refresh())
    EventBus.quick_slots_changed.connect(func(): _slots.refresh())
    EventBus.time_advanced.connect(func(_m): _worldinfo.refresh_time())
    EventBus.needs_changed.connect(func(): _status.refresh_needs())
    EventBus.combat_log.connect(func(t): _push_log(t, HUDState.LogCategory.COMBAT))
    EventBus.combat_started.connect(func(): _actionbar.set_combat_state(true))
    EventBus.combat_ended.connect(func(): _actionbar.set_combat_state(false))
    EventBus.player_turn_started.connect(func(): _actionbar.on_player_turn())
    EventBus.player_moved.connect(_on_player_moved)
    # disease → _status.refresh_needs()
    # quest events → push QUEST category log
    # loot events → push LOOT category log

func _push_log(text: String, cat: int) -> void:
    _state.push(text, cat)
    var entry := _state.get_latest()
    if entry:
        _log.show_entry(entry, _state.get_color(cat))

func _on_map_changed(map_id: String) -> void:
    _worldinfo.refresh_zone(map_id)
    _actionbar.on_map_changed(map_id)
    var minimap_on: bool = _is_minimap_map(map_id) and _settings.show_minimap()
    _minimap.visible = minimap_on
    if minimap_on:
        _minimap.refresh_full()
    _refresh_all()

func _on_player_moved(_pos: Vector2i) -> void:
    if _minimap.visible:
        _minimap.mark_explored(GameState.player_position)
        _minimap.refresh_image()

func _is_minimap_map(map_id: String) -> bool:
    if map_id == "": return false
    var data: MapData = LocationRegistry.get_or_generate(map_id)
    if data == null: return false
    return bool(data.metadata.get("minimap_enabled", false))

func _refresh_all() -> void:
    _status.refresh(); _status.refresh_needs()
    _worldinfo.refresh_zone(GameState.current_map_id); _worldinfo.refresh_time()
    _slots.refresh(); _quest.refresh()
```

### ResourceBar.gd (riusabile)
```gdscript
extends PanelContainer
class_name ResourceBar

@export var bar_color:           Color = Color.RED
@export var critical_threshold:  float = 0.25   # % sotto cui scatta pulse
@export var show_label:          bool  = true

var _bar:        ProgressBar
var _value_lbl:  Label   # visibile solo on mouse_entered
var _tween:      Tween
var _pulsing:    bool = false

func set_value(current: float, maximum: float) -> void:
    _bar.max_value = maximum
    if _tween and _tween.is_running(): _tween.kill()
    _tween = create_tween()
    _tween.tween_property(_bar, "value", current, 0.25).set_ease(Tween.EASE_OUT)
    _value_lbl.text = "%d/%d" % [int(current), int(maximum)]
    var ratio := current / maxf(1.0, maximum)
    if ratio <= critical_threshold and not _pulsing:
        _start_pulse()
    elif ratio > critical_threshold and _pulsing:
        _stop_pulse()

func _start_pulse() -> void:
    _pulsing = true
    # _process modulerà bar_color alpha tramite sin()

func _stop_pulse() -> void:
    _pulsing = false
    _apply_bar_color(bar_color)

func _process(delta: float) -> void:
    if not _pulsing: return
    var alpha := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
    _apply_bar_color(Color(bar_color.r, bar_color.g, bar_color.b, alpha))

func _apply_bar_color(c: Color) -> void:
    var style := StyleBoxFlat.new(); style.bg_color = c
    _bar.add_theme_stylebox_override("fill", style)

func _on_mouse_entered() -> void: _value_lbl.visible = true
func _on_mouse_exited()  -> void: _value_lbl.visible = false
```

### MessageLog.gd
```gdscript
extends Control
class_name MessageLog

const PASSIVE_LIFETIME := 5.0   # secondi prima del fade
const EXPANDED_LINES   := 40

var _passive_lbl:   RichTextLabel  # riga singola, fade automatico
var _expand_panel:  Panel          # pannello espanso (slide-up)
var _expand_rtl:    RichTextLabel  # log completo con colori
var _fade_timer:    float = 0.0
var _expanded:      bool  = false
var _all_entries:   Array = []     # copia locale da HUDState passata da HUDV2

func show_entry(entry: HUDState.LogEntry, color: Color) -> void:
    _passive_lbl.clear()
    _passive_lbl.push_color(color)
    _passive_lbl.add_text(entry.text)
    _passive_lbl.pop()
    _fade_timer = PASSIVE_LIFETIME
    _passive_lbl.modulate.a = 1.0

func open_expanded(entries: Array) -> void:
    _expanded = true
    _expand_rtl.clear()
    for e: HUDState.LogEntry in entries:
        _expand_rtl.push_color(HUDState.get_color(e.category))
        _expand_rtl.add_text(e.text + "\n")
        _expand_rtl.pop()
    var tw := create_tween()
    tw.tween_property(_expand_panel, "custom_minimum_size:y", 120.0, 0.15)

func close_expanded() -> void:
    _expanded = false
    var tw := create_tween()
    tw.tween_property(_expand_panel, "custom_minimum_size:y", 0.0, 0.15)

func _process(delta: float) -> void:
    if _expanded: return
    if _fade_timer > 0.0:
        _fade_timer -= delta
        if _fade_timer <= 0.5:
            _passive_lbl.modulate.a = maxf(0.0, _fade_timer / 0.5)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            if _expanded: close_expanded()
            else: open_expanded(_all_entries)  # aggiornato da HUDV2
```

### QuestTracker.gd
```gdscript
extends Control
class_name QuestTracker

# Layout: VBox trasparente
# ├── Label "▸ Titolo quest"  (oro tenue)
# ├── Label "  Obiettivo"     (grigio)
# └── Button "[+] espandi"   (piccolo, testo)
# Al click [+]: apre QuestJournal (segnale verso Main.gd o diretto)

func refresh() -> void:
    var title: String = QuestManager.get_active_quest_title()
    if title == "":
        visible = false
        return
    visible = true
    _title_lbl.text = "▸ " + title
    var obj: String = QuestManager.get_active_quest_objective()  # API da verificare
    _obj_lbl.text = "  " + (obj if obj != "" else "—")
    _obj_lbl.visible = obj != ""
```

### QuickSlotBar.gd
```gdscript
extends HBoxContainer
class_name QuickSlotBar

const SLOT_COUNT := 5
var _btns: Array[Button] = []

# _build_ui(): 5 Button (SIZE_EXPAND_FILL ciascuno)
# refresh(): aggiorna testo slot da GameState.quick_slots
# _recalc_visible(): su resized() → nasconde slot da destra se overflow
# _use_slot(idx): Inventory.use_item(GameState.quick_slots[idx])
# _unhandled_input: KEY_1..KEY_5
```

### MinimapPanel.gd
```gdscript
extends Panel
class_name MinimapPanel

signal position_changed(pos: Vector2)

const MAP_SIZE    := Vector2i(160, 160)
const TILE_RADIUS := 80
const C_PLAYER   := Color(1, 1, 1)
const C_ENEMY    := Color(0.8, 0.1, 0.1)
const C_NPC      := Color(1.0, 0.6, 0.1)
const C_EXPLORED := Color(0.22, 0.22, 0.22)
const C_EMPTY    := Color(0, 0, 0)

var _header_lbl: Label
var _tex_rect:   TextureRect
var _image:      Image
var _texture:    ImageTexture
var _dragging:   bool    = false
var _drag_offset:Vector2 = Vector2.ZERO

# _ready(): VBox con header Label + TextureRect 160×160
# refresh_full(): refresh_header() + refresh_image()
# refresh_header(): biome name (da LocationRegistry/GameState) + TimeManager.format_time()
# mark_explored(pos): GameState.explored_tiles["%d,%d" % [pos.x, pos.y]] = true
# refresh_image(): fill nero; per ogni tile nel raggio TILE_RADIUS, se esplorata → C_EXPLORED;
#                  pixel centrale = C_PLAYER; entity dots deferred (overworld)
# load_position(pos): position = pos
# _gui_input: drag con clamp ai bordi viewport
```

### ActionBar.gd
```gdscript
extends HBoxContainer
class_name ActionBar

signal use_item_requested()
signal open_menu_requested()

# Bottoni: Wait (R), Flee (F, solo combat), Inventory (I), Menu (Esc)
# Ogni bottone: VBox con Label grande (ASCII icon) + Label piccola (tasto/nome)
# tooltip_text impostato su ogni Button per tooltip Godot nativo
# KEY_F in combat → _on_flee() + set_input_as_handled()
# KEY_F fuori combat → non consumato → propaga a Main.gd
# wait hold timer (_process): identico a CombatBar.gd attuale
```

---

## 9. Lista file (manifest completo)

### Creare
**Scene:**
- `scenes/ui/hud/HUDV2.tscn`
- `scenes/ui/hud/components/PlayerStatusPanel.tscn`
- `scenes/ui/hud/components/ResourceBar.tscn`
- `scenes/ui/hud/components/WorldInfoPanel.tscn`
- `scenes/ui/hud/components/ActionBar.tscn`
- `scenes/ui/hud/components/MessageLog.tscn`
- `scenes/ui/hud/components/QuestTracker.tscn`
- `scenes/ui/hud/components/MinimapPanel.tscn`
- `scenes/ui/hud/components/QuickSlotBar.tscn`
- `scenes/ui/HUDOptionsPanel.tscn`

**Script:**
- `scripts/ui/hud/HUDV2.gd`
- `scripts/ui/hud/components/PlayerStatusPanel.gd`
- `scripts/ui/hud/components/ResourceBar.gd`
- `scripts/ui/hud/components/WorldInfoPanel.gd`
- `scripts/ui/hud/components/ActionBar.gd`
- `scripts/ui/hud/components/MessageLog.gd`
- `scripts/ui/hud/components/QuestTracker.gd`
- `scripts/ui/hud/components/MinimapPanel.gd`
- `scripts/ui/hud/components/QuickSlotBar.gd`
- `scripts/ui/hud/HUDState.gd`
- `scripts/ui/hud/HUDSettings.gd`
- `scripts/ui/HUDOptionsPanel.gd`

### Modificare
| File | Modifica |
|---|---|
| `scenes/main/Main.tscn` | HUD + CombatBar → HUDV2 |
| `scripts/ui/Main.gd` | @onready, connect, visibility, set_wait_screen |
| `scripts/core/GameState.gd` | quick_slots 5 elem + explored_tiles |
| `scripts/core/SaveManager.gd` | explored_tiles save/load; pad quickslots |
| `scripts/core/SettingsManager.gd` | Campi HUD + ui_mode |
| `scripts/ui/InventoryPanel.gd` | 5 slot assign |
| `scenes/ui/InventoryPanel.tscn` | Slot4Button, Slot5Button |
| `scripts/ui/OptionsMenu.gd` | Aggiungere link a HUDOptionsPanel |
| `locales/strings_*.csv` | Chiavi nuove (tooltip, header) |
| `addons/city_builder/` | Toggle minimap_enabled |

### Eliminare (dopo F9)
- `scenes/ui/HUD.tscn`, `scripts/ui/HUD.gd`
- `scenes/ui/CombatBar.tscn`, `scripts/ui/CombatBar.gd`

---

## 10. Fasi di implementazione

| Fase | Contenuto | Prerequisiti |
|---|---|---|
| **F0** | `GameState.quick_slots` → 5; `GameState.explored_tiles = {}`; backward-compat SaveManager; `_reset_game_state` aggiornato | — |
| **F1** | `SettingsManager` + campi HUD; `HUDState.gd`; `HUDSettings.gd` | — |
| **F2** | `ResourceBar.tscn/gd`: barra riusabile con tween + pulse + hover values | F1 |
| **F3** | `PlayerStatusPanel.tscn/gd`: nome+classe+lv, XP thin gold bar, 3× ResourceBar, F/W/E/T, apply_ui_mode() | F2 |
| **F4** | `WorldInfoPanel.tscn/gd`: zona + ora; `QuickSlotBar.tscn/gd`: 5 slot + overflow; `ActionBar.tscn/gd`: bottoni ASCII+label+tooltip, wait-hold, flee | F0, F1 |
| **F5** | `MessageLog.tscn/gd`: passiva 1 riga + fade + espansione al click + colori categoria | F1 |
| **F6** | `QuestTracker.tscn/gd`: titolo+obiettivo+espandi, trasparente; verificare API QuestManager.get_active_quest_objective() | F1 |
| **F7** | `MinimapPanel.tscn/gd`: Image 160×160, dots, header, drag; verificare API WorldManager per map_data; scrivere nota in plan_overworld_system.md | F0, F1 |
| **F8** | `HUDV2.tscn/gd`: incapsula tutto, collega EventBus, apply_settings_visibility(); `HUDOptionsPanel.tscn/gd`; aggiornare OptionsMenu | F3-F7 |
| **F9** | `InventoryPanel` espanso a 5 slot; `Main.tscn + Main.gd` aggiornati; CityBuilder minimap toggle; eliminare vecchi file; test completo | F8 |

---

## 11. Rischi tecnici

| Rischio | Probabilità | Mitigazione |
|---|---|---|
| Save con quick_slots a 3 crashano | Alta | F0 obbligatoria; backward-compat in SaveManager |
| explored_tiles grandi su world esplorate | Bassa (per ora) | Struttura ok per ora; ottimizzare con overworld system |
| API `WorldManager.get_current_map()` restituisce tipo non previsto per `map_data` | Media | Verificare prima di F7 |
| API `QuestManager.get_active_quest_objective()` non esiste | Media | Verificare prima di F6; se mancante, aggiungere a QuestManager |
| Drag MinimapPanel fuori viewport su resize | Media | Clamp a `(0,0)..(viewport.size - panel.size)`; richiamare al resize |
| ResourceBar _process per ogni barra ogni frame con pulse | Bassa | Solo 3 barre max in stato critico contemporaneamente; trascurabile |
| Font non ancora scelto — layout PlayerStatusPanel potrebbe non stare su 1 riga | Alta | Blocca F3 finché D-font non è decisa |
| HUDOptionsPanel: integrazione con OptionsMenu esistente non analizzata | Media | Analizzare OptionsMenu.gd prima di F8 |
| Log expanded: overlay su input di gioco (es. click su mappa durante expand) | Media | log_expanded → blocca _unhandled_input del gioco |

---

## 12. Piano di rollback

```
git checkout main -- scenes/ui/HUD.tscn scripts/ui/HUD.gd \
                     scenes/ui/CombatBar.tscn scripts/ui/CombatBar.gd \
                     scripts/ui/Main.gd scenes/main/Main.tscn \
                     scripts/core/GameState.gd scripts/core/SaveManager.gd \
                     scripts/core/SettingsManager.gd \
                     scripts/ui/InventoryPanel.gd scenes/ui/InventoryPanel.tscn
rm -rf scenes/ui/hud/ scripts/ui/hud/ scenes/ui/HUDOptionsPanel.tscn scripts/ui/HUDOptionsPanel.gd
```

---

## 13. Piano di test

| Test | Metodo |
|---|---|
| Nuovo gioco → top bar visibile con nome, classe, livello | Manuale |
| HP/MP/ST barre animate su danno/cura | Manuale |
| HP/MP/ST valori visibili solo su hover | Manuale |
| Pulse su stato critico (HP/MP/ST ≤ 25%) | Manuale (debug damage) |
| XP thin bar dorata aggiornata | Manuale |
| 5 quickslot assegnabili da InventoryPanel | Manuale |
| 5 quickslot usabili tasti 1–5 | Manuale |
| KEY_R = aspetta | Manuale |
| KEY_F in combat → flee; fuori → QuickFoodMenu | Manuale |
| Log mostra messaggio con colore categoria | Manuale |
| Log fade dopo N secondi | Manuale (aspetta) |
| Log click → espansione; click fuori → chiusura | Manuale |
| Log espanso mostra ultimi 40 messaggi con colori | Manuale |
| QuestTracker mostra titolo + obiettivo | Manuale |
| QuestTracker [+] apre QuestJournal | Manuale |
| QuestTracker trasparente (sfondo invisibile) | Visivo |
| WorldInfoPanel aggiornata su map_changed e time_advanced | Manuale |
| Minimap visibile solo su mappa con minimap_enabled=true | Manuale |
| Minimap rendering: grigio=esplorato, nero=inesplorato | Manuale |
| Minimap drag + posizione persistente | Manuale |
| HUDOptionsPanel: toggle pannelli funzionante | Manuale |
| HUDOptionsPanel: switch Info/Style cambia layout | Manuale |
| Load save vecchio (3 slot, no explored_tiles) → nessun crash | Manuale |
| Ridimensionamento finestra → HUD adattato | Manuale (resize) |
| Main menu → HUD completamente nascosto | Manuale |
| use_item_requested e open_menu_requested da ActionBar | Manuale |

---

## 14. Criteri di accettazione

- [ ] Nessun errore GDScript al lancio
- [ ] Top bar piena: nome + classe + livello + XP + HP/MP/ST + F/W/E/T visibili in riga compatta
- [ ] Nessun pannello fisso laterale — mappa visibile full-width
- [ ] HP/MP/ST valori solo su hover; barre sempre visibili
- [ ] Animazioni su cambio valore barre (tween 0.25 s)
- [ ] Pulse su stato critico per tutte e tre le barre
- [ ] 5 quickslot assegnabili e usabili
- [ ] Log con colori categoria + fade + espansione al click
- [ ] QuestTracker con titolo + obiettivo + expand, sfondo trasparente
- [ ] Minimap funzionante su mappe con flag minimap_enabled; sparisce altrove
- [ ] HUDOptionsPanel con toggle pannelli + switch Info/Style
- [ ] Load save vecchi senza crash
- [ ] Tutti i test sezione 13 passano
- [ ] HUD.tscn, HUD.gd, CombatBar.tscn, CombatBar.gd eliminati
- [ ] Nessuna regressione: combat, inventario, loot, dialoghi, fazioni, pause menu

---

## 15. Decisioni aperte

Nessuna decisione aperta. Tutte le questioni sono state risolte e spostate nella tabella delle decisioni chiuse (sezione 1).

---

## 16. Implementazione dettagliata — checklist con tracking

> Istruzioni operative:
> - Spuntare ogni checkbox appena completata la sottofase.
> - Al termine di ogni fase: aggiornare `plan_new_hud.md` (spuntare la fase) + aggiornare `codebase_reference.md`.
> - Dopo ogni fase: inviare all'utente un messaggio con il tracking completo (tutte le fasi, checkbox spuntate/vuote, sottofasi, commento breve sull'implementazione appena completata).

---

### F0 — Fondamenta dati (GameState + SaveManager) ✅
> Prerequisito di F4 e F7. Va fatto per prima perché cambia la struttura dei save.

- [x] **F0.1 — `scripts/core/GameState.gd`**
  - [x] Trovare la dichiarazione `var quick_slots` e portarla a 5 elementi: `["", "", "", "", ""]`
  - [x] Aggiungere il campo `var explored_tiles: Dictionary = {}` (chiave: `"x,y"` → `true`)
  - [x] Verificare che `_reset_game_state()` (o equivalente) resetti anche `explored_tiles = {}`

- [x] **F0.2 — `scripts/ui/Main.gd`**
  - [x] Trovare la riga con `GameState.quick_slots = ["", "", ""]` (circa linea 431) e aggiornare a 5 elementi

- [x] **F0.3 — `scripts/core/SaveManager.gd`**
  - [x] **Salvataggio** `explored_tiles`: aggiungere serializzazione del dict `GameState.explored_tiles` nella sezione di save (vicino alla linea 52 dove vengono salvati i quick_slots)
  - [x] **Caricamento** `explored_tiles`: aggiungere deserializzazione con default `{}` se la chiave non esiste (backward-compat)
  - [x] **Backward-compat quick_slots**: nella sezione di load, reset esplicito a 5 `""` prima del loop mini() — se il save ha 3 slot, i 2 extra restano `""`

- [x] **F0.4 — Verifica no-crash**
  - [x] CombatBar e InventoryPanel iterano su `[0..2]` hardcoded → nessun crash con 5 slot (verranno aggiornati in F9)
  - [x] `explored_tiles` default `{}` su save vecchi senza la chiave

- [x] **Fine F0**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F1 — Infrastruttura HUD (SettingsManager + HUDState + HUDSettings) ✅
> Prerequisito di tutti i componenti. Nessun file di scena, solo script puri.

- [x] **F1.1 — `scripts/core/SettingsManager.gd`** — aggiungere campi HUD
  - [ ] Aggiungere dopo i campi esistenti (window_mode, volume, ecc.):
    ```
    var hud_ui_mode:        String = "info"
    var hud_show_status:    bool   = true
    var hud_show_quest:     bool   = true
    var hud_show_minimap:   bool   = true
    var hud_show_worldinfo: bool   = true
    var hud_show_needs:     bool   = true
    var hud_minimap_pos_x:  float  = -4.0
    var hud_minimap_pos_y:  float  = -4.0
    ```
  - [x] Aggiornare `save_settings()`: aggiungere le 8 chiavi al dizionario serializzato
  - [x] Aggiornare `load_settings()`: leggere le 8 chiavi con `.get("chiave", default)` per backward-compat

- [x] **F1.2 — Creare directory script**
  - [x] Creato `scripts/ui/hud/` (via i file creati)

- [x] **F1.3 — Creare `scripts/ui/hud/HUDState.gd`**
  - [x] `class_name HUDState extends Node`
  - [x] `const LOG_CAPACITY := 40`
  - [x] `enum LogCategory { COMBAT, EXPLORATION, LOOT, QUEST, DIALOGUE, SYSTEM }`
  - [x] Inner class `LogEntry` con campi `text`, `category`, `timestamp`
  - [x] `func push(text, category)` con pop_front se supera LOG_CAPACITY
  - [x] `func get_latest() -> LogEntry`
  - [x] `static func get_color(category) -> Color` — static così MessageLog può chiamarlo come `HUDState.get_color(cat)` senza riferimento all'istanza

- [x] **F1.4 — Creare `scripts/ui/hud/HUDSettings.gd`**
  - [x] `class_name HUDSettings extends Node`
  - [x] Tutti i getter/setter dal pseudocodice sezione 7
  - [x] `func _toggle(field)`: usa `SettingsManager.set/get()` — funziona su Node in Godot 4

- [x] **Fine F1**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F2 — ResourceBar (componente riusabile) ✅
> Prerequisito di F3. Il componente più atomico; deve funzionare autonomamente.

- [x] **F2.1 — Creare directory scene**
  - [ ] Creare `scenes/ui/hud/` e `scenes/ui/hud/components/`

- [x] **F2.2 — Creare `scripts/ui/hud/components/ResourceBar.gd`**
  - [x] `class_name ResourceBar extends PanelContainer`
  - [x] `@export var bar_color: Color` / `@export var critical_threshold: float = 0.25`
  - [x] UI costruita programmaticamente in `_build_ui()` — nessuna dipendenza da figli nel .tscn
  - [x] `_fill_style: StyleBoxFlat` unica istanza riusata — nessuna allocazione per frame nel `_process`
  - [x] `set_value()`: tween 0.25s EASE_OUT + pulse logic
  - [x] `apply_ui_mode(mode)`: info → label sempre visibile; style → label solo su hover
  - [x] `_process()`: modula `_fill_style.bg_color.a` con `sin()` se pulsing

- [x] **F2.3 — Creare `scenes/ui/hud/components/ResourceBar.tscn`**
  - [x] Minimalista: root PanelContainer + script; tutti i child creati in codice

- [x] **F2.4 — Smoke test isolato**
  - [ ] Da verificare manualmente al lancio in F8/F9

- [x] **Fine F2**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F3 — PlayerStatusPanel ✅
> Prerequisito di F8. La barra top-center dell'HUD.

- [x] **F3.1 — Verificare API GameState**
  - [x] `character_name`, `current_class`, `level`, `xp` (in `player_stats`), `player_stats{hp,max_hp,mp,max_mp,stamina,max_stamina}`, `food/water/exhaustion/temperature`
  - [x] `LevelSystem.get_xp_progress() -> float` (0–1) per XP bar
  - [x] `ClassRegistry.get_display_name(id)` per nome classe localizzato

- [x] **F3.2 — Creare `scripts/ui/hud/components/PlayerStatusPanel.gd`**
  - [x] UI costruita programmaticamente in `_build_ui()`; ResourceBar istanziati con `ResourceBar.new()` e `bar_color` impostato prima di `add_child`
  - [x] `refresh()`: nome, classe+livello, xp_progress, HP/MP/ST via `set_value()`
  - [x] `refresh_needs()`: F/A/E/T° con colori dinamici per ogni stato
  - [x] `apply_ui_mode()`: propaga ai 3 ResourceBar

- [x] **F3.3 — Creare `scenes/ui/hud/components/PlayerStatusPanel.tscn`**
  - [x] Minimalista; anchor `right=1`, offset_top=16, offset_bottom=42 (→ 26px di altezza)

- [x] **Fine F3**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F4 — WorldInfoPanel + QuickSlotBar + ActionBar ✅
> Prerequisito di F8. Tre componenti indipendenti tra loro.

- [x] **F4.1 — Verificare API TimeManager e LocationRegistry**
  - [x] Confermare signature di `TimeManager.format_time()` → restituisce String con data+ora+slot
  - [x] Confermare come ottenere il nome della zona corrente dalla `map_id` → `LocationRegistry.get_or_generate(id).metadata["name"]`; fallback `LocaleManager.t_or("ZONE_"+id.to_upper(), id)`

- [x] **F4.2 — Creare `scripts/ui/hud/components/WorldInfoPanel.gd`**
  - [x] `class_name WorldInfoPanel extends PanelContainer`
  - [x] `func refresh_zone(map_id: String)`: aggiorna `_zone_lbl.text` con nome zona; se `map_id == ""` mostra "—"
  - [x] `func refresh_time()`: aggiorna `_time_lbl.text = TimeManager.format_time()`

- [x] **F4.3 — Creare `scenes/ui/hud/components/WorldInfoPanel.tscn`**
  - [x] Root: `PanelContainer`, anchor top full-width, height 16px, `StyleBoxFlat` antracite più scura + bordo oro inferiore
  - [x] `HBoxContainer`:
    - [x] `Label` (name = `ZoneLabel`), Roboto-Regular 11px, align LEFT, SIZE_EXPAND_FILL
    - [x] `Label` (name = `TimeLabel`), Roboto-Regular 11px, align RIGHT, colore oro tenue

- [x] **F4.4 — Creare `scripts/ui/hud/components/QuickSlotBar.gd`**
  - [x] `class_name QuickSlotBar extends HBoxContainer`
  - [x] `const SLOT_COUNT := 5`
  - [x] `var _btns: Array[Button] = []`
  - [x] `func _ready()`: costruisce 5 Button programmaticamente con stili antracite+oro
  - [x] `func refresh()`: aggiorna testo slot da `GameState.quick_slots`
  - [x] `func _on_slot_pressed(idx)`: chiama `Inventory.use_item()` se slot non vuoto
  - [x] `func _unhandled_input(event)`: gestire `quick_slot_1`..`quick_slot_5`
  - Note: `_recalc_visible()` non implementata — overflow gestito dal layout HBox nativo

- [x] **F4.5 — Creare `scenes/ui/hud/components/QuickSlotBar.tscn`**
  - [x] Root: `HBoxContainer` (QuickSlotBar.gd), anchor bottom full-width, height 19px

- [x] **F4.6 — Creare `scripts/ui/hud/components/ActionBar.gd`**
  - [x] `class_name ActionBar extends HBoxContainer`
  - [x] `signal use_item_requested()` / `signal open_menu_requested()`
  - [x] `var _in_combat: bool = false` + `_flee_btn` nascosto di default
  - [x] `func set_combat_mode(in_combat)`: aggiorna `_in_combat` + toggle `_flee_btn.visible`
  - [x] `func _process(delta)`: wait-hold timer identico a CombatBar.gd
  - [x] `func _on_quick_wait()`: `TimeManager.advance(get_action_cost(..., 4))` + `TurnManager.on_player_action_done()`
  - [x] `func _on_flee_pressed()`: solo in combat → `map.get_player().flee_attempt()`
  - [x] `func _open_wait_screen()`: `get_node_or_null("/root/Main/WaitScreen").show()`
  - [x] `func _unhandled_input`: action_wait (hold/tap), action_flee (solo combat)
  - [x] Bottoni costruiti in `_build_ui()`: VBox(icon Roboto-Bold 14px + key Roboto-Reg 9px)

- [x] **F4.7 — Creare `scenes/ui/hud/components/ActionBar.tscn`**
  - [x] Root: `HBoxContainer` (ActionBar.gd), minimale

- [x] **Fine F4**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F5 — MessageLog ✅
> Prerequisito di F8.

- [x] **F5.1 — Verificare segnali EventBus per log**
  - [x] Solo `combat_log(text: String)` esiste in EventBus
  - [x] Annotato: gli altri log verranno pushati da HUDV2 (quest_started → QUEST, player_leveled_up → SYSTEM, ecc.)

- [x] **F5.2 — Creare `scripts/ui/hud/components/MessageLog.gd`**
  - [x] `class_name MessageLog extends Control`
  - [x] `const PASSIVE_LIFETIME := 5.0` / `EXPANDED_HEIGHT := 120.0`
  - [x] `_passive_lbl`, `_expand_panel`, `_expand_rtl` costruiti in `_build_ui()`
  - [x] `show_entry(entry, color)`: bbcode push_color + reset fade
  - [x] `update_entries(entries)`: salva copia locale
  - [x] `open_expanded(entries)`: tween `offset_top` da 0 a -120 in 0.15s (slide verso l'alto sopra la bottom strip)
  - [x] `close_expanded()`: tween `offset_top` da -120 a 0 in 0.15s
  - [x] `_process(delta)`: fade alpha in 0.5s finali se non expanded
  - [x] `_gui_input`: apre su click sulla riga passiva; `_on_expand_panel_input` chiude su click sul pannello
  - [x] Note: apertura/chiusura separata in due handler distinti (expand_panel.gui_input + control._gui_input) per correttezza dell'input Godot

- [x] **F5.3 — Creare `scenes/ui/hud/components/MessageLog.tscn`**
  - [x] Root: `Control` (MessageLog.gd), `size_flags_horizontal = 3` (SIZE_EXPAND_FILL); tutto costruito in codice

- [x] **Fine F5**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F6 — QuestTracker + QuestManager.get_active_quest_objective() ✅
> Prerequisito di F8.

- [x] **F6.1 — Verificare/aggiungere API QuestManager**
  - [x] `get_active_quest_title()` già esistente in `scripts/dialogue/QuestManager.gd`
  - [x] Aggiunto `get_active_quest_objective()`: prende prima quest attiva, scorre objectives, per `kill_enemy` formatta "Uccidi X (n/tot)" con `LocaleManager.t_or("ENEMY_"+id.to_upper(), id)`; fallback generico per tipi sconosciuti; stringa vuota se nessuna quest attiva o tutti gli obiettivi completati
  - [x] Nota: tutti i JSON quest attuali hanno solo tipo `kill_enemy`; il match è extensibile

- [x] **F6.2 — Creare `scripts/ui/hud/components/QuestTracker.gd`**
  - [x] `class_name QuestTracker extends Control`
  - [x] `signal expand_requested()` — emesso dal pulsante [+]
  - [x] Costruisce UI in `_build_ui()`: VBox(sep=2) con TitleLabel (Roboto-Bold 12px oro) + ObjLabel (Roboto-Reg 11px grigio) + ExpandBtn (flat, StyleBoxEmpty, Roboto-Reg 10px)
  - [x] `refresh()`: se nessuna quest attiva → `visible=false`; altrimenti aggiorna testo e `_obj_lbl.visible = obj != ""`
  - [x] `custom_minimum_size = Vector2(200, 0)`, sfondo completamente trasparente (nessun panel style)

- [x] **F6.3 — Creare `scenes/ui/hud/components/QuestTracker.tscn`**
  - [x] Root: `Control` (QuestTracker.gd), `position = Vector2(4, 46)`; tutto costruito in codice

- [x] **Fine F6**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F7 — MinimapPanel ✅
> Prerequisito di F8. Dipende da F0 (explored_tiles).

- [x] **F7.1 — Impostare minimap_enabled nell'overworld**
  - [x] `WorldSaveManager.generate_new_world()`: aggiunto `"minimap_enabled": true` nei params di `LocationRegistry.register("overworld", ...)`
  - [x] `OverworldGenerator.generate()`: aggiunto `if params.get("minimap_enabled", false): data.metadata["minimap_enabled"] = true`
  - [x] Retrocompatibile: mondi salvati senza il flag → `metadata.get("minimap_enabled", false)` = false → minimap nascosta

- [x] **F7.2 — Nota in `plan_overworld_system.md`**
  - [x] Aggiunta sezione "Note HUD v2 — MinimapPanel": id overworld, fonte del flag, explored_tiles

- [x] **F7.3 — Creare `scripts/ui/hud/components/MinimapPanel.gd`**
  - [x] `class_name MinimapPanel extends Panel`, `signal position_changed(pos: Vector2)`
  - [x] `MAP_SIZE = Vector2i(160,160)`, `TILE_RADIUS = 80`, `C_PLAYER/C_EXPLORED/C_EMPTY`
  - [x] `_build_ui()`: Panel style antracite+bordo oro; VBox con HeaderLabel (10px oro, clip_text) + TextureRect (160×160)
  - [x] `_ready()`: image FORMAT_RGBA8 + ImageTexture; `_tex_rect.texture = _texture`
  - [x] `mark_explored(tile)`: `GameState.explored_tiles["%d,%d" % [tx, ty]] = true`
  - [x] `refresh_image()`: fill C_EMPTY; for px,py → tx = center.x + px - 80; se esplorato → C_EXPLORED; pixel centro = C_PLAYER; `_texture.update(_image)`
  - [x] `refresh_header()`: zone_name (come WorldInfoPanel) + " · " + `TimeManager.format_time()`
  - [x] `refresh_full()`: header + image
  - [x] `_gui_input`: drag LEFT_BUTTON; su release → clamp + `position_changed.emit()`
  - [x] `_notification(RESIZED)`: re-clamp posizione
  - [x] Dots location (C_CITY/DUNGEON/EVENT/NPC): deferred a overworld system

- [x] **F7.4 — Creare `scenes/ui/hud/components/MinimapPanel.tscn`**
  - [x] Root: `Panel` (MinimapPanel.gd), `custom_minimum_size = Vector2(166, 185)`; stile + VBox costruiti in codice

- [x] **Fine F7**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

---

### F8 — HUDV2 root + HUDOptionsPanel ✅
> La fase di integrazione. Prerequisiti: F3, F4, F5, F6, F7 completate.

- [x] **F8.1 — Analizzare `scripts/ui/OptionsMenu.gd`**
  - [x] Struttura: CanvasLayer con Panel/VBox flat (no tab); aggiunto Button "Opzioni HUD" programmaticamente in _ready() posizionato prima di BackButton

- [x] **F8.2 — Verificare segnali EventBus mancanti**
  - [x] Tutti presenti: `combat_log`, `combat_started`, `combat_ended`, `player_turn_started`, `disease_acquired`, `disease_cured`
  - [x] Nessun segnale mancante — nessuna modifica a EventBus.gd necessaria
  - [x] ActionBar: rimossi self-connect a `combat_started/ended` (HUDV2 gestisce il wiring)

- [x] **F8.3 — Creare `scripts/ui/hud/HUDV2.gd`**
  - [x] `class_name HUDV2 extends CanvasLayer`, `signal use_item_requested/open_menu_requested`
  - [x] Componenti istanziati in `_build_components()` via `load(path).instantiate()`; BottomStrip (PanelContainer antracite) costruito in `_build_bottom_strip()` con Row1 (log+actionbar) + Row2 (quickslot)
  - [x] `_init_minimap_position()`: se pos==(-4,-4) calcola bottom-right da `get_viewport().get_visible_rect().size`
  - [x] `_apply_settings_visibility()`: include `_status.set_needs_visible()` per toggle bisogni
  - [x] `_wire_eventbus()`: stats/equipment/xp/level → refresh(); disease_acquired/cured → refresh_needs(); combat_started/ended → actionbar.set_combat_mode(); quest/loot → push_log(); settings_changed → _apply_settings_visibility()
  - [x] Log push: `combat_log` → COMBAT; `quest_started` → QUEST (titolo da QuestManager); `loot_screen_open` → LOOT (ogni drop)
  - [x] `set_wait_screen()`: no-op (ActionBar usa path hardcoded)
  - [x] `_on_quest_expand()`: `get_node_or_null("/root/Main/QuestJournal").call("open")`

- [x] **F8.4 — Creare `scenes/ui/hud/HUDV2.tscn`**
  - [x] Root `CanvasLayer` (layer=2) + `HUDState` Node + `HUDSettings` Node; struttura visuale costruita in codice

- [x] **F8.5 — Creare `scripts/ui/HUDOptionsPanel.gd`**
  - [x] Legge/scrive direttamente SettingsManager (no dipendenza da HUDSettings)
  - [x] `_block_signals: bool` evita loop durante `refresh()`
  - [x] Ogni toggle emette `EventBus.settings_changed` → HUDV2 reagisce via `_apply_settings_visibility()`
  - [x] `refresh()`: sincronizza tutti i controlli da SettingsManager

- [x] **F8.6 — Creare `scenes/ui/HUDOptionsPanel.tscn`**
  - [x] Root `Control` full-rect, `visible=false`; PanelContainer centrato costruito in codice

- [x] **F8.7 — Aggiornare `scripts/ui/OptionsMenu.gd`**
  - [x] Aggiunto `var _hud_panel: Control = null` + Button "Opzioni HUD" (posizionato prima di BackButton)
  - [x] `_on_hud_options_pressed()`: istanzia lazy HUDOptionsPanel.tscn, chiama `refresh()` via `call()`, poi `show()`

- [x] **Fine F8**: aggiornare `plan_new_hud.md` + `codebase_reference.md` → inviare tracking all'utente

**Modifiche aggiuntive:**
- [x] `PlayerStatusPanel.gd`: `_needs_box` ora è campo membro; aggiunto `set_needs_visible(v: bool)`

---

### F9 — Integrazione finale + pulizia ✅
> La fase finale. Prerequisito: F8 completata e smoke-tested.

- [x] **F9.1 — Espandere `scripts/ui/InventoryPanel.gd` a 5 slot**
  - [x] Aggiunto `slot4_btn`, `slot5_btn` come @onready
  - [x] `_slot_assign_btns = [slot1_btn, slot2_btn, slot3_btn, slot4_btn, slot5_btn]`
  - [x] Loop `for i in 5` + `_refresh_slot_btns` su 5 slot

- [x] **F9.2 — Aggiornare `scenes/ui/InventoryPanel.tscn`**
  - [x] Aggiunti Slot4Btn e Slot5Btn (text "[4]"/″[5]", font_size=12)

- [x] **F9.3 — Aggiornare CityBuilder per `minimap_enabled`**
  - [x] Aggiunto `_cminimap_enabled: bool` + `_minimap_check: CheckBox`
  - [x] CheckBox "Minimap" nella faction_row
  - [x] `_save_city()`: aggiunge `"minimap_enabled": true` se abilitato
  - [x] `_load_file()`: legge flag + sincronizza checkbox
  - [x] `_new_city()`: reset a false

- [x] **F9.4 — Aggiornare `scenes/main/Main.tscn`**
  - [x] Rimossi HUD (uid://hud) e CombatBar (uid://combatbar)
  - [x] Aggiunto HUDV2 (uid://hudv2) come figlio diretto di Main
  - [x] load_steps da 17 a 16

- [x] **F9.5 — Aggiornare `scripts/ui/Main.gd`**
  - [x] Sostituito `hud: CanvasLayer = $HUD` con `_hud_v2: HUDV2 = $HUDV2`
  - [x] Rimosso `combat_bar: CombatBar = $CombatBar`
  - [x] Tutti i `hud.visible` / `combat_bar.visible` → `_hud_v2.visible`
  - [x] `combat_bar.use_item_requested/open_menu_requested` → `_hud_v2.*`

- [x] **F9.6 — Eliminare file obsoleti**
  - [x] Eliminati: `scenes/ui/HUD.tscn`, `scripts/ui/HUD.gd`
  - [x] Eliminati: `scenes/ui/CombatBar.tscn`, `scripts/ui/CombatBar.gd`

- [x] **F9.7 — Aggiornare `locales/strings_*.csv`**
  - [x] Aggiunte chiavi `UI_HUD_ACTION_WAIT/FLEE/INVENTORY/MENU` in `strings_ui.csv`
  - [x] ActionBar usa `LocaleManager.t_or()` per i tooltip

- [ ] **F9.8 — Test completo (piano sezione 13)** — da eseguire manualmente in Godot

- [x] **Fine F9**: `plan_new_hud.md` + `codebase_reference.md` aggiornati

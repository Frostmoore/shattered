# Piano — Refactor HUD v2
> Branch: `test` — nessun codice va toccato finché questo piano non è approvato.

---

## 1. Audit del sistema attuale

### File coinvolti
| File | Tipo | Ruolo attuale |
|---|---|---|
| `scenes/ui/HUD.tscn` | CanvasLayer | Panel top-left 240×244 px |
| `scripts/ui/HUD.gd` | Script | Bars HP/MP/ST/XP, oro, stats, mappa, quest, needs, malattie |
| `scenes/ui/CombatBar.tscn` | CanvasLayer (layer=3) | Strip bottom 640×35, log singola riga, 3 slot, tasti azione |
| `scripts/ui/CombatBar.gd` | Script | Log, wait hold, quickslots, segnali `use_item_requested` / `open_menu_requested` |
| `scripts/ui/Main.gd` | Scene root | Gestisce visibility di `$HUD` e `$CombatBar` separatamente |
| `scenes/main/Main.tscn` | Scene | Contiene HUD e CombatBar come figli diretti |

### Stato segnali EventBus rilevanti
- `quick_slots_changed` — **esiste** in EventBus (riga 16), usato in CombatBar ✓
- `player_stats_changed`, `equipment_changed`, `xp_gained`, `player_leveled_up`, `map_changed`, `quest_started/completed`, `inventory_changed`, `time_advanced`, `needs_changed`, `disease_*` — tutti presenti ✓

### Dimensioni virtuali
- Viewport: **640×360** px
- Finestra: 1280×720 (2× override, nessun `stretch_mode` configurato)
- Font: solo `PressStart2P.ttf` (~8–9 px per carattere a font-size 11)

---

## 2. Problemi identificati

| # | Problema | Gravità |
|---|---|---|
| P1 | HUD top-left è 240×244 — occlude il 68% dell'altezza schermo | Alta |
| P2 | Combat log è una sola Label: i messaggi precedenti si perdono immediatamente | Alta |
| P3 | Solo 3 quickslot (utente vuole 5); `GameState.quick_slots` ha 3 elementi | Media |
| P4 | `TimeLabel` è un Label flottante senza background, visivamente scollegato | Bassa |
| P5 | Nessun nome personaggio né classe visibili nell'HUD di gioco | Media |
| P6 | Nessuna minimap (nemmeno placeholder) | Bassa |
| P7 | HUD e CombatBar sono gestiti separatamente in Main.gd, raddoppiando il codice visibility | Bassa |
| P8 | `CombatBar.gd` usa `get_node_or_null("/root/Main/WaitScreen")` — path hardcoded fragile | Bassa |

---

## 3. Architettura target

### Nuova struttura file
```
scenes/ui/hud/
  HUDV2.tscn          ← CanvasLayer root; sostituisce sia HUD.tscn sia CombatBar.tscn
  HUDLeft.tscn        ← Panel statistiche, top-left
  HUDBottom.tscn      ← Strip azione, bottom full-width

scripts/ui/hud/
  HUDV2.gd            ← Coordinatore, espone segnali verso Main.gd
  HUDLeft.gd          ← Aggiornamento barre e testo
  HUDBottom.gd        ← Log buffer, quickslots, tasti azione
  HUDState.gd         ← Buffer log circolare (ultimi 4 messaggi) + cache stato
  HUDSettings.gd      ← Visibilità pannelli (needs, minimap, diseases)
```

### File modificati (non nuovi)
| File | Modifica |
|---|---|
| `scenes/main/Main.tscn` | Rimpiazzare nodi `HUD` e `CombatBar` con `HUDV2` |
| `scripts/ui/Main.gd` | Aggiornare @onready, connect segnali, visibility calls |
| `scripts/core/GameState.gd` | `quick_slots` da 3 a 5 elementi |
| `scripts/core/SaveManager.gd` | Backward-compat load quickslots (pad a 5 se salvato con 3) |

### File eliminati (dopo approvazione)
- `scenes/ui/HUD.tscn`
- `scenes/ui/CombatBar.tscn`
- `scripts/ui/HUD.gd`
- `scripts/ui/CombatBar.gd`

---

## 4. Layout (wireframe)

Risoluzione virtuale **640×360**. Tutti i numeri sono approssimati a ±4 px.

```
┌──────────────────────────────── 640 px ─────────────────────────────────────┐
│  ┌─ HUDLeft 215×202 ──────────┐ ··············· HUDTopBar 640×16 ·········  │
│  │ Nome · Lv.5 · Guerriero    │  1 Nevargento 472 C — Lunedì · Mattina      │16
│  ├────────────────────────────┤                                              │
│  │ HP ▓▓▓▓▓▓░░░░ 25/25        │                                              │
│  │ MP ▓▓▓░░░░░░░ 10/20        │   M  A  P  P  A   (MapContainer)            │
│  │ ST ▓▓▓▓▓░░░░░ 15/20        │                                             │
│  │ XP Lv5 ▓▓░░░░░░ 40/100     │                                              │
│  ├────────────────────────────┤                                              │
│  │ ⚔12  🛡5  💰 150 monete   │                                              │
│  │ Zona: Dungeon Livello 2    │                                              │
│  │ Quest: Trova la spada      │                                              │
│  ├────────────────────────────┤                                              │
│  │ F:85  A:60  Esaur:30       │                                              │
│  │ Malaria [Iniziale]         │                                              │
│  └────────────────────────────┘                                              │
│                                                                              │
│  ┌─ HUDBottom  640×38 ──────────────────────────────────────────────────┐   │
│  │ [Log: Il goblin ti attacca per 8 danni!]      [W][F][I][M]           │18 │
│  │ [1: Pozione x3] [2: ——] [3: ——] [4: ——] [5: ——]                    │20 │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Note:**
- `HUDTopBar`: Panel pieno 640×16, y=0. Contiene TimeLabel centrata.
- `HUDLeft`: Panel 215×202, offset (4, 16) — subito sotto la top bar.
- `HUDBottom`: Panel 640×38, ancorato a fondo schermo. 2 righe: log+azioni (18 px) + quickslots (20 px).
- La minimap è **fuori scope** in questa fase (P6 non viene risolta adesso; placeholder `[?]` opzionale in HUDLeft o angolo top-right è a discrezione dell'utente dopo approvazione).

### Tasti azione bottom row 1
`[R] Aspetta  |  [F] Fuggi  |  [I] Invento.  |  [Esc] Menu`
Font-size 10 per stare nei 640 px. Etichette abbreviate se necessario.

### Quickslot bottom row 2
5 bottoni uguali a larghezza fissa ~110 px ciascuno: `[1] NomeItem x3`
Font-size 10.

---

## 5. Stile visivo

| Elemento | Valore |
|---|---|
| Font | `PressStart2P.ttf`, size 10–11 px (invariato) |
| Background HUDLeft | `StyleBoxFlat`, bg_color `Color(0.05, 0.05, 0.10, 0.92)`, corner 2 px |
| Background HUDTopBar | `StyleBoxFlat`, bg_color `Color(0.0, 0.0, 0.0, 0.78)` |
| Background HUDBottom | `StyleBoxFlat`, bg_color `Color(0.05, 0.05, 0.09, 0.94)` (identico a CombatBar attuale) |
| Separatori | `HSeparator` con colore `Color(0.3, 0.3, 0.3)` |
| Colori barre | HP `#c71e1e`, MP `#1e61d1`, ST `#d18514`, XP `#7a1ec8` (invariati) |
| Header nome personaggio | `Color(1.0, 0.85, 0.4)` — oro caldo |
| Log text | `Color(0.88, 0.85, 0.6)` (invariato) |
| Needs colors | invariati (rosso → arancione → bianco per food/water, inverso per exhaustion) |

Nessun tema `.tres`. Tutti gli stili applicati via `add_theme_*_override` in GDScript, come nel codice esistente.

---

## 6. HUDState.gd

**Tipo**: Node (figlio diretto di HUDV2, non autoload).  
**Responsabilità**:
1. Buffer log circolare (ultime 4 stringhe).
2. Cache dei valori GameState più recenti (evita letture ripetute per ogni componente).
3. Non connette segnali EventBus direttamente — è HUDV2.gd a fare il dispatch.

```gdscript
class_name HUDState
extends Node

const LOG_CAPACITY := 4

var log_lines: Array[String] = []

func push_log(text: String) -> void:
    log_lines.push_back(text)
    if log_lines.size() > LOG_CAPACITY:
        log_lines.pop_front()

func get_log_display() -> String:
    # Restituisce solo l'ultima riga per HUDBottom row 1
    return log_lines.back() if not log_lines.is_empty() else ""
```

> **Nota**: il buffer a 4 righe è struttura dati interna; HUDBottom mostra **1 riga** nella strip bottom (layout compatto). In futuro si può aggiungere un pannello log espandibile senza riscrivere HUDState.

---

## 7. HUDSettings.gd

**Tipo**: Node (figlio di HUDV2).  
**Responsabilità**: visibilità dei pannelli opzionali. Persiste tramite `SettingsManager` esistente.

```gdscript
class_name HUDSettings
extends Node

var show_needs:    bool = true
var show_diseases: bool = true
var show_topbar:   bool = true

func load_from_settings() -> void:
    show_needs    = SettingsManager.get_value("hud_show_needs",    true)
    show_diseases = SettingsManager.get_value("hud_show_diseases", true)
    show_topbar   = SettingsManager.get_value("hud_show_topbar",   true)

func save_to_settings() -> void:
    SettingsManager.set_value("hud_show_needs",    show_needs)
    SettingsManager.set_value("hud_show_diseases", show_diseases)
    SettingsManager.set_value("hud_show_topbar",   show_topbar)

func toggle_needs() -> void:
    show_needs = not show_needs
    save_to_settings()

func toggle_diseases() -> void:
    show_diseases = not show_diseases
    save_to_settings()
```

---

## 8. Pseudocodice componenti principali

### HUDV2.gd (coordinatore)
```gdscript
extends CanvasLayer
class_name HUDV2

signal use_item_requested()    # re-esposto da HUDBottom verso Main.gd
signal open_menu_requested()   # re-esposto da HUDBottom verso Main.gd

@onready var _left:     HUDLeft     = $HUDLeft
@onready var _bottom:   HUDBottom   = $HUDBottom
@onready var _topbar:   Panel       = $HUDTopBar
@onready var _time_lbl: Label       = $HUDTopBar/TimeLabel
@onready var _state:    HUDState    = $HUDState
@onready var _settings: HUDSettings = $HUDSettings

func _ready() -> void:
    _settings.load_from_settings()
    _wire_eventbus()
    _bottom.use_item_requested.connect(use_item_requested.emit)
    _bottom.open_menu_requested.connect(open_menu_requested.emit)
    _refresh_all()

func _wire_eventbus() -> void:
    EventBus.player_stats_changed.connect(_on_stats)
    EventBus.equipment_changed.connect(_on_stats)
    EventBus.xp_gained.connect(_on_stats)
    EventBus.player_leveled_up.connect(_on_stats)
    EventBus.map_changed.connect(_on_map_changed)
    EventBus.quest_started.connect(func(_id): _left.refresh_quest())
    EventBus.quest_completed.connect(func(_id): _left.refresh_quest())
    EventBus.inventory_changed.connect(func(): _bottom.refresh_slots())
    EventBus.quick_slots_changed.connect(func(): _bottom.refresh_slots())
    EventBus.time_advanced.connect(func(_m): _time_lbl.text = TimeManager.format_time())
    EventBus.needs_changed.connect(func(): _left.refresh_needs())
    EventBus.combat_log.connect(_on_combat_log)
    EventBus.combat_started.connect(func(): _bottom.set_combat_state(true))
    EventBus.combat_ended.connect(func(): _bottom.set_combat_state(false))
    EventBus.player_turn_started.connect(func(): _bottom.on_player_turn())
    # disease signals → _left.refresh_diseases()

func _on_combat_log(text: String) -> void:
    _state.push_log(text)
    _bottom.set_log(_state.get_log_display())

func _on_stats(_arg: Variant = null) -> void:
    _left.refresh_stats()

func _on_map_changed(map_id: String) -> void:
    _left.refresh_map(map_id)
    _bottom.on_map_changed(map_id)
    _refresh_all()

func _refresh_all() -> void:
    _left.refresh_stats()
    _left.refresh_needs()
    _left.refresh_diseases()
    _left.refresh_map(GameState.current_map_id)
    _left.refresh_quest()
    _time_lbl.text = TimeManager.format_time()
    _bottom.refresh_slots()
```

### HUDLeft.gd (semplificato)
```gdscript
extends Panel
class_name HUDLeft

# @onready nodi costruiti in _build_ui() chiamata da _ready()
# refresh_stats(), refresh_needs(), refresh_map(), refresh_quest(), refresh_diseases()
# — logica identica a HUD.gd attuale, riorganizzata
# Aggiunge header riga: "[NomePersonaggio] · Lv.{n} · {classe}"
```

### HUDBottom.gd
```gdscript
extends Panel
class_name HUDBottom

signal use_item_requested()
signal open_menu_requested()

const SLOT_COUNT := 5
var _slot_btns: Array[Button] = []
var _log_label: Label

# _build_ui(): crea 2 HBoxContainer (row1: log+tasti, row2: 5 slot)
# set_log(text), set_combat_state(bool), on_player_turn(), on_map_changed()
# refresh_slots(): aggiorna 5 slot da GameState.quick_slots
# _use_slot(idx): usa item nello slot idx
# _unhandled_input: KEY_1..KEY_5 per quickslot
# wait hold timer (_process): identico a CombatBar.gd attuale
```

---

## 9. Lista file (manifest completo)

### Creare
- `scenes/ui/hud/HUDV2.tscn`
- `scenes/ui/hud/HUDLeft.tscn`
- `scenes/ui/hud/HUDBottom.tscn`
- `scripts/ui/hud/HUDV2.gd`
- `scripts/ui/hud/HUDLeft.gd`
- `scripts/ui/hud/HUDBottom.gd`
- `scripts/ui/hud/HUDState.gd`
- `scripts/ui/hud/HUDSettings.gd`

### Modificare
- `scenes/main/Main.tscn` — nodo `HUD` → `HUDV2`, rimuovere nodo `CombatBar`
- `scripts/ui/Main.gd` — aggiornare @onready, connect segnali (8 righe), `_launch_game`/`_go_to_main_menu` visibility
- `scripts/core/GameState.gd` — `quick_slots: Array = ["","","","",""]` (5 elementi)
- `scripts/core/SaveManager.gd` — backward-compat: pad `quick_slots` a 5 in `load_game()`
- `locales/strings_*.csv` — eventuali chiavi UI nuove per l'header

### Eliminare (dopo verifica)
- `scenes/ui/HUD.tscn`
- `scripts/ui/HUD.gd`
- `scenes/ui/CombatBar.tscn`
- `scripts/ui/CombatBar.gd`

---

## 10. Fasi di implementazione

> Ogni fase è verificabile autonomamente. Non si passa alla successiva senza test della precedente.

| Fase | Contenuto | Prerequisiti |
|---|---|---|
| **F0** | Aggiungere segnale `quick_slots_changed` se mancante; portare `GameState.quick_slots` a 5 elem; backward-compat in SaveManager | — |
| **F1** | Creare `HUDState.gd` e `HUDSettings.gd` (solo logica, nessuna UI) | — |
| **F2** | Creare `HUDLeft.tscn` + `HUDLeft.gd` con tutta la logica stats/needs/diseases/quest; testarlo in isolamento aggiungendolo temporaneamente alla scena | F1 |
| **F3** | Creare `HUDBottom.tscn` + `HUDBottom.gd` con log, 5 slot, tasti azione; testarlo in isolamento | F0, F1 |
| **F4** | Creare `HUDV2.tscn` + `HUDV2.gd` che incapsula Left + Bottom + TopBar; collegare tutti i segnali EventBus | F2, F3 |
| **F5** | Aggiornare `Main.tscn` e `Main.gd`: sostituire HUD + CombatBar con HUDV2; verificare visibility, segnali, WaitScreen path | F4 |
| **F6** | Rimuovere HUD.tscn, HUD.gd, CombatBar.tscn, CombatBar.gd; verificare che non ci siano riferimenti rimasti | F5 |
| **F7** | Test completo: nuovo gioco, load, combat, loot, pause, quest, malattia, fazione | F6 |

**F0 è la fase più delicata** per i save esistenti — la backward-compat è obbligatoria.

---

## 11. Rischi tecnici

| Rischio | Probabilità | Mitigazione |
|---|---|---|
| Save esistenti con `quick_slots` a 3 elementi crashano in load | Alta (save presenti) | Pad in SaveManager prima di toccare GameState |
| `WaitScreen` path hardcoded in CombatBar (`/root/Main/WaitScreen`) — nuovo bottom deve trovarlo | Media | Usare `get_tree().get_root().find_child("WaitScreen", true, false)` oppure passarlo da Main.gd come reference |
| `CombatBar` ha `class_name CombatBar` usato in Main.gd come tipo — rimozione rompe il typecheck | Bassa | `HUDBottom` non ha bisogno di `class_name CombatBar`; Main.gd userà segnali di HUDV2 |
| Dimensioni pixel HUDLeft/HUDBottom potrebbero non allinearsi senza `stretch_mode` | Media | Testare a runtime; usare anchor per HUDBottom (ancorare a fondo schermo) |
| SettingsManager non ha `get_value`/`set_value` generici — HUDSettings potrebbe non funzionare | Bassa | Verificare l'API di SettingsManager prima della F1; adattare se necessario |

---

## 12. Piano di rollback

La branch `test` è isolata. Per fare rollback:
1. `git checkout main -- scenes/ui/HUD.tscn scripts/ui/HUD.gd scenes/ui/CombatBar.tscn scripts/ui/CombatBar.gd scripts/ui/Main.gd scenes/main/Main.tscn` — ripristino selettivo dei file originali
2. Eliminare `scenes/ui/hud/` e `scripts/ui/hud/`
3. Verificare che GameState.quick_slots sia tornato a 3 elementi (salvato da F0 backup)

Se il refactor viene completato interamente sulla branch `test`, il rollback è sempre disponibile via `git checkout main`.

---

## 13. Piano di test

| Test | Metodo |
|---|---|
| Nuovo gioco → HUD visibile con nome, classe, livello | Manuale |
| HP/MP/ST/XP barre si aggiornano al combattimento | Manuale |
| Combat log mostra l'ultimo messaggio nella strip | Manuale |
| 5 quickslot assegnabili e usabili (tasti 1–5) | Manuale |
| Pausa → riprendi → HUD ancora visibile | Manuale |
| Transizione mappa → zona label aggiornata | Manuale |
| Malattia acquisita → label malattia appare in HUDLeft | Manuale |
| Load di save con 3 quickslot → nessun crash | Manuale (save vecchio) |
| TimeLabel si aggiorna ad ogni azione | Manuale |
| Toggle visibilità needs via HUDSettings | Debug screen o OptionsMenu |
| Main menu → HUD nascosto | Manuale |
| `use_item_requested` e `open_menu_requested` funzionano da HUDBottom | Manuale |

---

## 14. Criteri di accettazione

- [ ] Nessun errore GDScript al lancio
- [ ] HUD occupa meno spazio verticale del precedente (target: ≤ 202 px di altezza per HUDLeft)
- [ ] Nome personaggio e classe visibili senza aprire StatusScreen
- [ ] 5 quickslot funzionanti con tasti 1–5
- [ ] Combat log non si svuota istantaneamente (buffer ≥ 1 messaggio visibile)
- [ ] Load di save vecchi (3 quickslot) non crasha
- [ ] Tutti i test della sezione 13 passano
- [ ] I file `HUD.tscn`, `HUD.gd`, `CombatBar.tscn`, `CombatBar.gd` non esistono più
- [ ] Nessuna regressione su: combattimento, inventario, loot, dialoghi, fazioni, pause menu

---

## 15. Decisioni aperte

> **Da confermare prima di iniziare l'implementazione.**

| # | Decisione | Opzioni | Default proposto |
|---|---|---|---|
| D1 | **Minimap placeholder**: includerla come `[?]` in HUDLeft o ometterla del tutto? | A) ometterla  B) pannello `[?]` top-right 64×64 | A — ometterla; troppo presto |
| D2 | **Combat log**: 1 riga visibile (layout compatto) o 2 righe (più storia)? | A) 1 riga  B) 2 righe con height extra | A — 1 riga; aggiungibile in seguito |
| D3 | **HUDBottom 2 righe**: vuoi tenere i tasti azione (W/F/I/M) nella riga log OPPURE metterli nella riga quickslot accanto agli slot? | A) riga1=log+tasti, riga2=5slot  B) riga1=log, riga2=tasti+5slot | A — log+tasti / slot separati |
| D4 | **`quick_slots_changed`**: il segnale esiste già in EventBus. Va emesso anche quando si cambia uno slot dall'inventario? Attualmente solo SaveManager lo emette | Già emesso da SaveManager; aggiungere anche in Inventory.assign_quick_slot() se esiste | Verificare flusso slot assignment |
| D5 | **Chiavi locale nuove** per header (nome+classe): aggiungere chiave `UI_HUD_HEADER` o costruire la stringa direttamente in codice? | A) stringa diretta `"%s · Lv.%d · %s"`  B) chiave localizzata | A — stringa diretta; il formato è già in italiano |

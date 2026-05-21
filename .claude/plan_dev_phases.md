# Piano di Sviluppo — Sistema Classi (Fasi A–L)
> Documento di riferimento per l'implementazione. Ogni fase cita le righe esatte di
> `plan_class_system.md` (abbreviato **PCS**). Usare i checkbox in fondo per il tracking.

---

## Grafico dipendenze

```
0 (debug screen) ← nessuna dipendenza — aggiornata in ogni fase successiva
A (data layer)  ──┬──► B (class picker)  ──┐
                  │                         ├──► D (MVP classi)
                  ├──► C (DamagePipeline) ──┘
                  │         │
                  │         ├──► E (AbilityUseTracker + active_key)
                  │         ├──► F (StatusEffectManager + debuff)
                  │         │         │
                  │         └──► G (TargetingOverlay) ──► H (AllyManager)
                  │
                  └──► I (MilestoneTracker)  ← può partire subito dopo A
                            │
                  A + B + I ├──► J (ClassRespecService)
                            │
               tutto stable ├──► K (UI complesse / item system)
               tutto stable └──► L (Tier 4-5-6)
```

Fonte: PCS righe **1696–1709**

---

## FASE 0 — Debug Screen
**Dipendenze:** nessuna. Va creata per prima, prima ancora di Fase A.
**Aggiornata incrementalmente in:** ogni fase successiva (A–L).

### Obiettivo
Pannello debug accessibile in qualsiasi momento con il tasto **`è`**, sovrapposto al gioco.
Mostra lo stato interno di tutti i sistemi in tempo reale. Non visibile in build release.
Ogni fase aggiunge le proprie sezioni — a Fase L il pannello copre l'intero sistema classi.

### Passi dettagliati

#### 0.1 — Creare `DebugScreen.tscn/.gd`
- Path: `scenes/debug/DebugScreen.tscn` + `scripts/debug/DebugScreen.gd`
- `CanvasLayer` con `layer = 100` (sempre sopra a tutto, anche a pause menu)
- Pannello semi-trasparente (`StyleBoxFlat` con alpha 0.85), dimensioni ~65% schermo,
  centrato, scrollabile (`ScrollContainer` interno)
- Toggle visibilità con tasto `è`:
  ```gdscript
  func _input(event: InputEvent) -> void:
      if event is InputEventKey and event.pressed and not event.echo:
          if event.keycode == KEY_EGRAVE:
              visible = not visible
              if visible: _refresh()
  ```
- `Timer` auto-refresh ogni 0.5s quando `visible = true` (si ferma quando nascosto)
- **Solo debug build**: in `_ready()`:
  ```gdscript
  if not OS.is_debug_build():
      queue_free()
      return
  ```

#### 0.2 — Creare componente `DebugSection.gd`
- Path: `scripts/debug/DebugSection.gd` — script per un `PanelContainer` riutilizzabile
- Header `Button` cliccabile che collassa/espande il body `VBoxContainer`
- `Label` con `autowrap_mode = AUTOWRAP_WORD` per il contenuto
- Metodo `update(lines: Array[String])` — aggiorna il testo senza ricreare nodi

#### 0.3 — Registrare nel gioco
- Aggiungere `DebugScreen` come ultimo figlio di `Main.tscn`
- Non usare Autoload: se `OS.is_debug_build()` è falso, il nodo non esiste proprio
  in build release (nessun overhead)

#### 0.4 — InputMap per tasto `è`
- In `ProjectSettings → InputMap`: aggiungere action `"debug_toggle"` mappata al
  tasto fisico `è` (`KEY_EGRAVE`)
- Usare `Input.is_action_just_pressed("debug_toggle")` nel codice invece del keycode
  diretto — più robusto su layout tastiera diversi

#### 0.5 — Sezione iniziale `[Sistema]`
Prima di qualsiasi altra fase, la schermata mostra solo:
```
[Sistema]
FPS: 60
Godot: 4.4.x
Build: debug
Piattaforma: Windows / Android
Risoluzione: 1920×1080
```

### Tabella aggiornamenti per fase

| Fase | Sezione aggiunta | Dati mostrati |
|------|-----------------|---------------|
| A | `[ClassDB]` | Classi caricate per tier, errori validator |
| A | `[GameState]` | base_attrs, class_bonus, effective_attrs, current_class, HP/MP |
| B | `[ClassPicker]` | Ultima classe scelta, n. classi disponibili/totali |
| C | `[DamagePipeline]` | Ultimo DamageContext: base→final, cancelled, instant_kill, tags |
| C | `[ClassRuntime]` | active_special_id, contatore hook chiamati per tipo |
| D | `[AbilityUseTracker]` | uses_remaining, cooldown_turns_left, reset_type |
| D | `[ClassSpecial]` | Stato interno abilità attiva (es: HP ratio, dodge%, backstab flag) |
| E | `[ActiveBuffs]` | Buff attivi sul player: id, value, turns_remaining |
| F | `[StatusEffects]` | Stati per player + ogni nemico in vista (id, stacking, turns) |
| G | `[Targeting]` | Overlay attivo sì/no, tile valide count, ultima tile cliccata |
| H | `[AllyManager]` | Permanent allies (id, hp, pos), temporary (id, hp, turns_left) |
| H | `[DruidForm]` | Forma attiva (lupo/umano), location type corrente |
| I | `[Milestones]` | Tutti i contatori global_milestones, classi sbloccate (n/60) |
| J | `[Respec]` | respec_count, base_attrs vs class_bonus vs effective_attrs tabella |
| L | `[Tier4-6]` | Lich: skeletons/max — Paradox: effetti attivi — Divinità: flag stato |

### Criticità Fase 0
1. **KEY_EGRAVE**: il keycode `è` varia su layout non-italiani. Usare `InputMap` con
   action `"debug_toggle"` è la soluzione corretta — se si cambia tasto basta aggiornare
   il ProjectSettings senza toccare il codice.
2. **Solo debug build**: non dimenticare `OS.is_debug_build()` check. Senza di esso
   il pannello appare anche nell'APK/EXE rilasciato agli utenti finali.
3. **Refresh performance**: `_refresh()` deve aggiornare solo il testo dei Label esistenti,
   non fare `clear()` + ricreazione nodi ogni 0.5s (causa flickering e GC pressure).
   Creare le sezioni una volta sola in `_ready()`, aggiornarle con `update()`.
4. **Visibilità durante pausa**: il `CanvasLayer` con `layer = 100` è visibile anche
   quando il gioco è in pausa. Questo è desiderato — si può debuggare lo stato di pausa.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scenes/debug/DebugScreen.tscn` |
| Creare | `scripts/debug/DebugScreen.gd` |
| Creare | `scripts/debug/DebugSection.gd` |
| Modificare | `scenes/main/Main.tscn` (aggiunge DebugScreen come ultimo figlio) |
| Modificare | `project.godot` (InputMap: action `debug_toggle` → KEY_EGRAVE) |

### Output atteso
Premendo `è` appare/scompare il pannello debug con la sezione `[Sistema]`.
Non appare in build release. Ogni fase successiva aggiunge le proprie sezioni.

---

## FASE A — Data Layer + GameState
**Dipendenze:** nessuna. Base di tutto.
**Ref PCS:** righe **1494–1508**

### Obiettivo
Caricare i dati delle 60 classi a runtime, ristrutturare `GameState` per il modello
attributi non-cumulativo, aggiornare `SaveManager` e `LevelSystem`.
Nulla è ancora visibile nel gioco.

### Passi dettagliati

#### A1 — Creare i 60 file JSON (PCS 1497–1498)
- Struttura directory (PCS righe **1353–1421**):
  ```
  data/classes/
    tier1/  (12 file)
    tier2/  (10 file)
    tier3/  (22 file)
    tier4/  (10 file)
    tier5/  (5 file)
    tier6/  (1 file — divinita.json)
  ```
- Schema JSON per ogni classe (PCS righe **56–82**):
  ```json
  {
    "id": "guerriero",
    "name": "Guerriero",
    "desc": "...",
    "tier": 1,
    "primary": ["str", "vit"],
    "growth": {"str":3, "dex":0, "int":0, "vit":2, "wil":1},
    "respec_bonus": {"str":12, "dex":0, "int":0, "vit":8, "wil":3},
    "special_id": "warrior_fury",
    "special_type": "passive",
    "special_name": "Furia del Guerriero",
    "special_desc": "...",
    "unlock": {
      "type": "always",
      "trigger_scope": "global",
      "reward_scope": "global"
    },
    "implementation": {
      "status": "planned"
    }
  }
  ```
- Classi **Tier 1** (12 classi): PCS righe **85–243** — noob, guerriero, mago, ladro,
  ranger, paladino, negromante, monaco, barbaro, alchimista, bardo, druido
- Classi **Tier 2** (10 classi): PCS righe **247–379** — cavaliere, assassino, stregone,
  sacerdote, biomante, gladiatore, sciamano, templare, inventore, cacciatore_di_taglie
- Classi **Tier 3** (22 classi): PCS righe **383–671** — piromante … esploratore
- Classi **Tier 4** (10 classi): PCS righe **675–807** — lich, arcimago, cacciatore_anime,
  colosso, maestro_tempo, spettro, campione, dio_guerra, dominatore, arcicacciatore
- Classi **Tier 5** (5 classi): PCS righe **811–879** — eletto, specchio_abisso, vuoto,
  morte_incarnata, paradosso
- Classe **Tier 6** (1 classe): PCS righe **883–907** — divinita
  - Flag speciali: `"invincible": true`, `"fov_disabled": true`, `"damage_override": 1`
  - Unlock: `{type: "all_classes_completed", scope: "global"}`

Per ora impostare `"status": "planned"` su tutto tranne le 5 MVP:
**noob, guerriero, monaco, ladro, paladino** → `"status": "implemented"`.

#### A2 — Creare `ClassDB.gd` (PCS 1499)
- Path: `res://scripts/classes/ClassDB.gd`
- Scansione ricorsiva di `data/classes/tier1/` → `tier6/` via `DirAccess`
- API minima:
  ```gdscript
  func get_class(id: String) -> Dictionary
  func get_all() -> Array[Dictionary]
  func get_by_tier(tier: int) -> Array[Dictionary]
  func get_unlocked() -> Array[Dictionary]  # filtra su GlobalMilestoneTracker
  ```
- Registrare come **Autoload** (PCS riga **1479**)

#### A3 — Creare `ClassValidator.gd` (PCS 1500)
- Path: `res://scripts/classes/ClassValidator.gd`
- Chiamato a startup da `ClassDB`
- Controlla (PCS righe **1774–1776**):
  - `id` univoco tra tutti i file
  - `growth` e `respec_bonus` hanno tutti e 5 gli attributi (str/dex/int/vit/wil)
  - `special_type` ∈ {passive, active_key, active_target, passive_and_active, toggle}
  - `unlock.type` è un valore riconosciuto
- Stampa errori leggibili su console (`push_error()` con path file)

#### A4 — Ristrutturare `GameState` (PCS 1501–1504)
Sostituire il singolo dizionario `attributes` con il modello non-cumulativo
(PCS righe **924–938**):
```gdscript
var base_attributes  := {"str":5, "dex":5, "int":5, "vit":5, "wil":5}
var class_bonus      := {"str":0, "dex":0, "int":0, "vit":0, "wil":0}
var effective_attributes := {}

func recalculate_effective_attributes() -> void:
    for attr in base_attributes:
        effective_attributes[attr] = base_attributes[attr] + class_bonus.get(attr, 0)
```
- Aggiungere `current_class: String = "noob"`
- Aggiungere `run_milestones: Dictionary = {}` (PCS riga **1503**)
- Aggiornare `recalculate_derived_stats()` per usare `effective_attributes` (PCS riga **1504**)

**Criticità A4**: ogni sistema che legge `GameState.attributes` deve essere aggiornato
a leggere `effective_attributes`. Fare una grep di `GameState.attributes` prima di
procedere per non dimenticare nessun riferimento.

#### A5 — Aggiornare `SaveManager` (PCS 1505)
- Salvare/caricare: `current_class`, `base_attributes`, `class_bonus`, `run_milestones`
- Mantenere retrocompatibilità: se un save vecchio non ha `current_class`, default `"noob"`

#### A6 — Aggiornare `LevelSystem` (PCS 1506)
- `_apply_level_up()` legge `growth` da `ClassDB.get_class(GameState.current_class)`
- Incrementa `base_attributes[attr] += growth[attr]` (non `effective_attributes`)
- Chiama `GameState.recalculate_effective_attributes()` dopo

#### A-DBG — Aggiorna DebugScreen (sezione [ClassDB] + [GameState])
- Sezione `[ClassDB]`: classi caricate per tier (`Tier1: 12/12`, `Tier2: 10/10`, ecc.),
  lista errori validator (se vuota: `"Validator: OK"`)
- Sezione `[GameState]`: `base_attributes`, `class_bonus`, `effective_attributes` (tutti
  e 5 gli attributi), `current_class`, HP correnti/max, MP correnti/max

### Criticità Fase A
1. **Ordine scrittura vs lettura**: `ClassDB` deve essere Autoload di tipo primario (caricato
   prima di qualsiasi scena). Se caricato dopo, le scene che dipendono da esso crashano.
2. **Path su Windows vs Export**: usare `"res://data/classes/tier1/"` non path assoluti.
   Verificare che i file JSON siano inclusi nell'export di Godot (progetto → export → includi).
3. **Il Validatore deve girare in `_ready()` di ClassDB**, non come tool separato, così gli
   errori si vedono subito all'avvio in qualsiasi ambiente.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare (×60) | `data/classes/tier{1-6}/{class_id}.json` |
| Creare | `scripts/classes/ClassDB.gd` |
| Creare | `scripts/classes/ClassValidator.gd` |
| Modificare | `scripts/GameState.gd` |
| Modificare | `scripts/SaveManager.gd` |
| Modificare | `scripts/LevelSystem.gd` |
| Modificare | `project.godot` (Autoload ClassDB) |

### Output atteso
Il gioco si avvia, `ClassDB` carica 60 classi, il validator non stampa errori, `GameState`
ha la struttura corretta. Save/load funziona. Nulla è ancora visibile per il giocatore.

---

## FASE B — Class Picker + Selezione Iniziale
**Dipendenze:** Fase A completata.
**Ref PCS:** righe **1512–1523**

### Obiettivo
Permettere al giocatore di scegliere la classe all'inizio di ogni run. Per ora mostra
solo Noob (sempre sbloccata). Il panel è pronto per aggiungere classi man mano.

### Passi dettagliati

#### B1 — Creare `ClassPickerPanel.tscn/.gd` (PCS 1515–1518)
- Path: `scenes/ui/ClassPickerPanel.tscn` + `scripts/ui/ClassPickerPanel.gd`

**Layout**: griglia di `ClassCard` (quadrati, `GridContainer` con colonne configurabili).
Nessun pannello dettaglio fisso — le informazioni appaiono nel tooltip al mouseover.

**ClassCard** — componente `scenes/ui/ClassCard.tscn`:
- Quadrato fisso (es. 80×80 px), bordo arrotondato
- Sfondo colorato per tier (costante in `ClassCard.gd`):
  ```
  Tier 1 → #808080 (grigio)    Tier 4 → #9C27B0 (viola)
  Tier 2 → #4CAF50 (verde)     Tier 5 → #FF5722 (arancione)
  Tier 3 → #2196F3 (blu)       Tier 6 → #FFD700 (oro)
  ```
- **Icona placeholder**: `Label` centrato con la prima lettera del nome classe
  (es. "M" per Mago), font bold, colore bianco — sostituibile in futuro con `TextureRect`
- Nome classe sotto l'icona (`Label` piccolo, `clip_text = true`)
- Metodo `setup(class_data: Dictionary)` chiamato da ClassPickerPanel

**Tooltip al mouseover** (PCS struttura dati righe **56–82**):
Usare un `PanelContainer` custom posizionato via `_gui_input` / `mouse_entered`, non
il `tooltip_text` built-in di Godot (non è stilizzabile).
Contenuto del tooltip:
```
[Nome Classe]  •  Tier N
──────────────────────────
Descrizione breve della classe.

Attributi principali: STR, VIT
Crescita/livello: STR+3, VIT+2, WIL+1

──────────────────────────
[Tipo: Passiva / Attiva / Toggle]
Nome Abilità
Descrizione abilità speciale.

Sblocco: <condizione in chiaro>
         o "Sempre disponibile"
```
- `Tipo` si legge da `special_type` del JSON
- `Crescita/livello` si legge da `growth` (mostra solo attrs con value > 0)
- `Sblocco` si legge da `unlock.type` + `unlock.value` e viene tradotto in testo
  (es. `{type: kills_total, value: 100}` → `"Uccidi 100 nemici in totale"`)

**Filtro**: mostrare **solo** classi che soddisfano **entrambe** le condizioni:
1. `implementation.status == "implemented"` (gestito da ClassDB)
2. Classe sbloccata in `GlobalMilestoneTracker.unlocked_classes` (oppure `unlock.type == "always"`)

Le classi non ancora sbloccate **non appaiono** nella griglia.

**Conferma**: bottone "Scegli [Nome Classe]" in basso, abilitato solo quando una card
è selezionata (click). Emette `class_selected(class_id: String)`.

**Nota Fase B**: il filtro GlobalMilestoneTracker è un TODO — fino a Fase I, mostrare
tutte le `implemented` come sbloccate. Aggiungere commento `# TODO Fase I`.

#### B1b — Creare `ClassCard.tscn/.gd`
- Path: `scenes/ui/ClassCard.tscn` + `scripts/ui/ClassCard.gd`
- Metodi: `setup(data: Dictionary)`, `set_selected(value: bool)` (bordo evidenziato),
  `_on_mouse_entered()` → mostra tooltip, `_on_mouse_exited()` → nasconde tooltip
- Il tooltip è un nodo singleton in `ClassPickerPanel`, non uno per ogni card
  (performance: una sola istanza riposizionata al mouse)

#### B2 — Integrare in `NewGamePanel` (PCS 1519)
- Aggiungere step "Scegli classe" dopo l'inserimento del nome personaggio
- Al confirm, salva `class_id` scelto in `GameState.current_class`
- Applicare `class_bonus` della classe: `GameState.class_bonus = ClassDB.get_class(id).respec_bonus`
- Chiamare `GameState.recalculate_effective_attributes()`

**Criticità B2**: il `class_bonus` deve essere applicato con `=` non `+=` — è una
sostituzione, non un accumulo. Vedi modello non-cumulativo in PCS righe **924–938**.

#### B3 — Aggiornare `StatusScreen` (PCS 1520)
- Mostrare nome classe corrente (`ClassDB.get_class(GameState.current_class).name`)
- Mostrare `special_name` e `special_desc` in un riquadro dedicato

#### B4 — Aggiornare `_reset_game_state()` in Main.gd (PCS 1521)
- Leggere la classe scelta da `GameState.current_class`
- Applicare `class_bonus` come in B2

#### B-DBG — Aggiorna DebugScreen (sezione [ClassPicker])
- Sezione `[ClassPicker]`: ultima classe selezionata (id + nome), n. classi
  `implemented` + sbloccate vs totale (es: `1/60`), `status` della classe corrente

### Criticità Fase B
1. **Prima run senza save**: se il giocatore non ha mai giocato, `current_class` default
   a `"noob"`. ClassPickerPanel deve gestire questo caso.
2. **Unlock non ancora implementato** (viene in Fase I): mostrare tutte le `"implemented"`
   classi come sbloccate finché MilestoneTracker non è pronto. Aggiungere un flag/commento
   `# TODO: collegare a GlobalMilestoneTracker in Fase I`.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scenes/ui/ClassPickerPanel.tscn` |
| Creare | `scripts/ui/ClassPickerPanel.gd` |
| Creare | `scenes/ui/ClassCard.tscn` |
| Creare | `scripts/ui/ClassCard.gd` |
| Modificare | `scenes/ui/NewGamePanel.tscn` |
| Modificare | `scripts/ui/NewGamePanel.gd` |
| Modificare | `scripts/ui/StatusScreen.gd` |
| Modificare | `scripts/ui/Main.gd` |

### Output atteso
Si può iniziare una run scegliendo Noob dalla griglia. Hovering sulla card mostra il tooltip
con attributi e abilità. Il picker è pronto per aggiungere classi man mano che si sbloccano.

---

## FASE C — DamagePipeline
**Dipendenze:** Fase A. **Obbligatoria prima di qualsiasi classe che modifica il danno.**
**Ref PCS:** righe **1527–1536** e architettura righe **1744–1751**

### Obiettivo
Centralizzare tutto il calcolo del danno in un'unica pipeline. Senza questo, ogni
classe modificherebbe il danno in modo indipendente e incompatibile.

### Passi dettagliati

#### C1 — Creare `DamagePipeline.gd` con `DamageContext` (PCS 1530, 1744–1751)
- Path: `res://scripts/combat/DamagePipeline.gd`
- Struttura `DamageContext` (class interna o Resource):
  ```gdscript
  class DamageContext:
      var attacker         # Node
      var defender         # Node
      var base_damage: int
      var flat_bonus:  int = 0
      var attack_multiplier:  float = 1.0
      var target_multiplier:  float = 1.0
      var ignore_defense: bool = false
      var damage_type: String = "physical"  # physical, magic, pure
      var tags: Array[String] = []
      var cancelled: bool = false
      var instant_kill: bool = false
      var final_damage: int = 0
  ```
- Ordine di esecuzione (PCS riga **1750**):
  1. Crea `DamageContext`
  2. Hook `before_player_attack(ctx)` / `before_enemy_attack(ctx)` → ClassRuntime dispatch
  3. Calcola `final_damage = (base_damage + flat_bonus) × attack_multiplier × target_multiplier`
  4. Se non `ignore_defense`: sottrai DEF del difensore
  5. Se `cancelled`: return senza applicare
  6. Se `instant_kill`: porta HP a 0
  7. Applica `final_damage` al difensore
  8. Hook `after_player_attack(ctx)` / `after_enemy_attack(ctx)`
  9. Se nemico morto: hook `on_enemy_killed(ctx)`

- **Divinità**: il danno finale = 1 viene applicato in step 3, DOPO tutti i moltiplicatori
  (PCS righe **902–906**). Non è una riduzione ma un override fisso.

#### C2 — Refactorare `CombatManager` (PCS 1531)
- Sostituire il calcolo danno inline con una chiamata a `DamagePipeline.execute(ctx)`
- Verificare che tutte le formule esistenti siano preservate come `base_damage` + modificatori

#### C3 — Esporre gli hook (PCS 1532)
Gli hook devono essere chiamati esplicitamente da `CombatManager` nei punti giusti:
- `ClassRuntime.on_before_player_attack(ctx)` → prima del calcolo
- `ClassRuntime.on_after_player_attack(ctx)` → dopo l'applicazione
- `ClassRuntime.on_before_player_damaged(ctx)` → quando il player sta per ricevere danno
- `ClassRuntime.on_after_player_damaged(ctx)` → dopo aver ricevuto danno
- `ClassRuntime.on_enemy_killed(ctx)` → dopo la morte del nemico

#### C4 — Creare `ClassRuntime.gd` (PCS 1533, 1741–1742)
- Path: `res://scripts/classes/ClassRuntime.gd`
- Registry: dizionario `special_id → ClassSpecial instance`
- Preloada tutti gli script da `res://scripts/classes/specials/`
- Metodi: `set_active_class(class_id)`, hook dispatch (`on_before_player_attack` ecc.)
- Gestisce l'abilità Q: `use_active_key()` e `use_targeted(tile)`

#### C5 — Creare `ClassSpecial.gd` (PCS 1534, 1724–1742)
- Path: `res://scripts/classes/specials/ClassSpecial.gd`
- `extends RefCounted`
- Tutti i metodi come virtual hook vuoti:
  ```gdscript
  func on_before_player_attack(ctx: DamageContext) -> void: pass
  func on_after_player_attack(ctx: DamageContext) -> void: pass
  func on_before_player_damaged(ctx: DamageContext) -> void: pass
  func on_after_player_damaged(ctx: DamageContext) -> void: pass
  func on_enemy_killed(ctx: DamageContext) -> void: pass
  func on_turn_end() -> void: pass
  func on_floor_changed() -> void: pass
  func use_active() -> void: pass
  func use_targeted(tile: Vector2i) -> void: pass
  func is_valid_target(tile: Vector2i) -> bool: return false
  ```

#### C-DBG — Aggiorna DebugScreen (sezione [DamagePipeline] + [ClassRuntime])
- Sezione `[DamagePipeline]`: ultimo `DamageContext` eseguito — `base_damage`,
  `flat_bonus`, `attack_multiplier`, `target_multiplier`, `final_damage`, `cancelled`,
  `instant_kill`, `tags`, `damage_type`
- Sezione `[ClassRuntime]`: `active_special_id`, contatore invocazioni per hook
  (`before_attack: N`, `after_attack: N`, `on_kill: N`, ecc.) — resettato ogni piano

### Criticità Fase C
1. **Non rompere il combattimento esistente**: il refactor di CombatManager deve produrre
   esattamente lo stesso comportamento prima di aggiungere i hook. Testare una run completa.
2. **Divinità damage=1 override**: va implementato DOPO tutti i moltiplicatori. Se messo
   troppo presto, i moltiplicatori lo riportano sopra 1.
3. **ctx.cancelled**: se una classe annulla l'attacco, il danno non deve essere applicato
   ma gli hook `after` devono comunque girare (potrebbero avere effetti propri).

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/combat/DamagePipeline.gd` |
| Creare | `scripts/classes/ClassRuntime.gd` |
| Creare | `scripts/classes/specials/ClassSpecial.gd` |
| Modificare | `scripts/combat/CombatManager.gd` |

### Output atteso
CombatManager usa la pipeline. ClassRuntime può intercettare il combattimento.
Le classi speciali possono ora sovrascrivere gli hook senza toccare CombatManager.

---

## FASE D — Prime Classi MVP (Passive Semplici)
**Dipendenze:** Fase B + Fase C completate.
**Ref PCS:** righe **1540–1558**

### Obiettivo
Implementare 5 classi che coprono tutti i casi tecnici base: passive hook, hook combat,
stato temporaneo, active_key con AbilityUseTracker. Sistema testabile end-to-end.

### Classi MVP da implementare

#### D1 — Noob (`noob_adaptability`) — PCS righe **1046–1048**
- Tipo: `passive` — nessun hook combat
- Logica: +1 a tutti gli attributi ogni 2 livelli (implementato in LevelSystem)
- File: `scripts/classes/specials/NoobAdaptability.gd`

#### D2 — Guerriero (`warrior_fury`) — PCS righe **1050–1053**
- Tipo: `passive` — hook `on_before_player_attack`
- Logica: se `player.current_hp < player.max_hp * 0.5` → `ctx.attack_multiplier *= 1.5`
- File: `scripts/classes/specials/WarriorFury.gd`

#### D3 — Monaco (`monk_dodge`) — PCS righe **1082–1084**
- Tipo: `passive` — hook `on_before_player_damaged`
- Logica: probabilità schivata = DEX/200 → se schiva: `ctx.cancelled = true`
- File: `scripts/classes/specials/MonkDodge.gd`

#### D4 — Ladro (`rogue_backstab`) — PCS righe **1061–1064**
- Tipo: `passive` con stato temporaneo
- Logica: tiene flag `_first_attack_this_combat: bool` → se true e il player attacca
  per primo: danno ×3 + reset flag
- File: `scripts/classes/specials/RogueBackstab.gd`

#### D5 — Paladino (`paladin_lay_on_hands`) — PCS righe **1072–1075**
- Tipo: `active_key` — **richiede AbilityUseTracker**
- Logica: Q → recupera VIT×2 HP, usabile 1 volta per piano
- File: `scripts/classes/specials/PaladinLayOnHands.gd`

#### D6 — Creare `AbilityUseTracker.gd` (PCS 1553, 1757–1763)
- Path: `res://scripts/classes/AbilityUseTracker.gd`
- Legge config dal JSON della classe:
  ```json
  "usage": {"limit": 1, "reset": "floor"}
  "usage": {"cooldown_turns": 5}
  ```
- Metodi: `can_use() -> bool`, `record_use()`, `on_floor_changed()`, `on_turn_end()`
- `ClassRuntime` istanzia un `AbilityUseTracker` per la classe attiva

#### D-DBG — Aggiorna DebugScreen (sezione [AbilityUseTracker] + [ClassSpecial])
- Sezione `[AbilityUseTracker]`: `can_use: true/false`, `uses_remaining`,
  `cooldown_turns_left`, `reset_type` (floor/combat/run)
- Sezione `[ClassSpecial]`: stato interno dell'abilità attiva classe per classe:
  `warrior: hp_ratio=0.42, fury=ACTIVE` — `monk: dodge_chance=12%` —
  `ladro: first_attack=true` — `paladino: uses_this_floor=0/1`

### Criticità Fase D
1. **AbilityUseTracker prima del Paladino**: il tracker deve essere pronto e funzionante
   prima di testare `paladin_lay_on_hands`. Non implementare Paladino senza di esso.
2. **Stato temporaneo di Ladro**: il flag `_first_attack_this_combat` deve essere resettato
   all'inizio di ogni combattimento (hook `on_combat_start`). Aggiungere questo hook a
   `ClassSpecial.gd` se non presente.
3. **Impostare `"status": "implemented"`** nei 5 file JSON al termine, non prima.
   ClassPickerPanel mostrerà le classi solo dopo.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/classes/AbilityUseTracker.gd` |
| Creare | `scripts/classes/specials/NoobAdaptability.gd` |
| Creare | `scripts/classes/specials/WarriorFury.gd` |
| Creare | `scripts/classes/specials/MonkDodge.gd` |
| Creare | `scripts/classes/specials/RogueBackstab.gd` |
| Creare | `scripts/classes/specials/PaladinLayOnHands.gd` |
| Modificare | `data/classes/tier1/noob.json` (status → implemented) |
| Modificare | `data/classes/tier1/guerriero.json` (status → implemented) |
| Modificare | `data/classes/tier1/monaco.json` (status → implemented) |
| Modificare | `data/classes/tier1/ladro.json` (status → implemented) |
| Modificare | `data/classes/tier1/paladino.json` (status → implemented) |

### Output atteso
5 classi giocabili. Il sistema è testabile end-to-end: selezione classe, combattimento
con meccaniche attive, abilità Q con cooldown per piano.

---

## FASE E — AbilityUseTracker + Active Key Avanzate
**Dipendenze:** Fase C + Fase D (`AbilityUseTracker` già creato in D).
**Ref PCS:** righe **1562–1577**

### Obiettivo
Implementare le classi `active_key` che non richiedono entità alleate né status effect
su nemici. Stabilizzare `AbilityUseTracker`.

### Classi da implementare (PCS 1567–1574)

| Classe | special_id | Note |
|--------|-----------|------|
| Bardo | `bard_song` | Buff temporaneo al player (ATK+20% per 3 turni) — PCS righe **1098–1100** |
| Guardiano | `guardian_shield` | Aggiunge `shield_hp` locale, assorbito in `before_player_damaged` |
| Incantaspade | `spellblade_enchant` | Counter locale, hook `after_player_attack` |
| Stregone | `warlock_dark_pact` | Modifica HP/MP diretta + `attack_multiplier` |

**Barbaro** (`barbarian_warcry` — PCS righe **1086–1090**): toccherebbe i nemici con
debuff ATK → **rimandare a Fase F** quando StatusEffectManager è pronto (PCS riga **1575**).

#### E-DBG — Aggiorna DebugScreen (sezione [ActiveBuffs])
- Sezione `[ActiveBuffs]`: lista buff attivi sul player con `id`, `value`, `turns_remaining`
  (es: `bard_song: ATK+20%, 2t rimanenti`) — oppure `"Nessun buff attivo"` se vuota

### Criticità Fase E
1. **Buff temporanei al player** (Bardo): gestire con un dizionario locale in `GameState`
   tipo `active_buffs: [{id, value, turns_remaining}]`. Non usare StatusEffectManager per
   i buff-su-player finché F non è pronto; un sistema minimale locale è sufficiente.
2. **`shield_hp` del Guardiano**: deve essere sottratto PRIMA degli HP reali in
   `on_before_player_damaged`. Il valore deve persistere tra i turni (salvarlo nell'istanza
   ClassSpecial).

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/classes/specials/BardSong.gd` |
| Creare | `scripts/classes/specials/GuardianShield.gd` |
| Creare | `scripts/classes/specials/SpellbladeEnchant.gd` |
| Creare | `scripts/classes/specials/WarlockDarkPact.gd` |
| Modificare | `data/classes/tier{N}/{classe}.json` (status → implemented) |

### Output atteso
Classi `active_key` funzionanti. `AbilityUseTracker` stabile con reset-per-piano e cooldown-turni.

---

## FASE F — StatusEffectManager + Debuff
**Dipendenze:** Fase C completata.
**Ref PCS:** righe **1581–1594** e architettura righe **1753–1755**

### Obiettivo
Sistema centralizzato per stati alterati (debuff, buff, veleno, stun, ecc.) su player e nemici.
Obbligatorio prima di tutte le classi che applicano stati ai nemici.

### Passi dettagliati

#### F1 — Creare `StatusEffectManager.gd` (PCS 1584, 1753–1755)
- Path: `res://scripts/combat/StatusEffectManager.gd`
- Struttura di ogni stato:
  ```gdscript
  class StatusEffect:
      var id: String
      var source: String  # class_id che l'ha applicato
      var duration_turns: int   # -1 = permanente
      var stacking: String      # "replace" | "refresh" | "stack" | "ignore" | "unique"
      var data: Dictionary      # parametri specifici (es: {atk_mult: 0.5})
  ```
- Metodi: `apply(target, effect: StatusEffect)`, `tick(target)`, `remove(target, id)`,
  `has_effect(target, id) -> bool`, `get_effect(target, id) -> StatusEffect`
- `tick()` chiamato da `CombatManager` a ogni turno, decrementa `duration_turns` e rimuove
  quelli scaduti
- Ogni nemico (`Enemy.gd`) ha un `active_effects: Array[StatusEffect]`
- `Enemy.take_turn()` legge `active_effects` per modificare comportamento (es: stordito → salta turno)

#### F2 — Implementare classi che usano StatusEffectManager (PCS 1586–1592)
Ora è possibile implementare:
- **Barbaro** (`barbarian_warcry`): AoE su nemici visibili, applica debuff ATK -30% per 3 turni
- **Corsaro** (`corsair_dirty_hit`): passivo, ogni attacco ha 20% stun 1 turno
- **Berserker** (`berserker_frenzy`): passivo, +50% ATK ma blocco uso oggetti (PCS riga **1590**)
  - Implementare notifica esplicita quando tenta uso item (PCS decisioni, riga **29 memory**)
- **Sentinella** (`sentinel_guard`): guard_stacks come stato locale (PCS riga **1591**)

**Classi con targeting** (applicano debuff su nemico target) → rimandare a Fase G:
- `witch_curse`, `chrono_slow`, `pyromancer_fireball` (burn)

#### F-DBG — Aggiorna DebugScreen (sezione [StatusEffects])
- Sezione `[StatusEffects]`: per ogni entità (player + nemici visibili) mostra gli
  stati attivi nel formato `entity_id: [effect_id(Nt), ...]`
  (es: `goblin_3: [stun(1t), atk_down(2t)]` — `player: [berserker_frenzy(∞)]`)
- Mostrare anche le regole di stacking applicate nell'ultimo `apply()`:
  `"witch_curse → refresh (era 3t, ora 5t)"`

### Criticità Fase F
1. **Stacking rules**: ogni stato deve dichiarare la sua `stacking` policy. Se non definita,
   usare `"refresh"` come default sicuro.
2. **Berserker notifica**: quando il player (con classe berserker) tenta di aprire inventario/
   usare item, mostrare popup "Il Berserker non può usare oggetti in berserk". Agganciare
   alla logica dell'inventario.
3. **Performance**: se molti nemici hanno molti stati, `tick()` su tutti può essere lento.
   Limitare a max 10 stati per entità per ora.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/combat/StatusEffectManager.gd` |
| Creare | `scripts/classes/specials/BarbarianWarcry.gd` |
| Creare | `scripts/classes/specials/CorsairDirtyHit.gd` |
| Creare | `scripts/classes/specials/BerserkerFrenzy.gd` |
| Creare | `scripts/classes/specials/SentinelGuard.gd` |
| Modificare | `scripts/combat/CombatManager.gd` (chiama tick) |
| Modificare | `scripts/entities/Enemy.gd` (active_effects, take_turn modifica) |

### Output atteso
Sistema debuff/buff stabile. Base per tutte le classi di controllo del combattimento.

---

## FASE G — TargetingOverlay + Active Target
**Dipendenze:** Fase C + Fase F completate.
**Ref PCS:** righe **1598–1613**

### Obiettivo
Implementare la modalità di targeting con click del mouse per le classi `active_target`.
Senza questo, le classi che richiedono un bersaglio non possono funzionare.

### Passi dettagliati

#### G1 — Creare `TargetingOverlay.tscn/.gd` (PCS 1601–1605)
- Path: `scenes/ui/TargetingOverlay.tscn` + `scripts/ui/TargetingOverlay.gd`
- `CanvasLayer` sempre sopra al dungeon
- Attivato da `ClassRuntime.use_active()` quando `special_type = active_target`
- Mostra highlight delle tile valide (`ClassSpecial.is_valid_target(tile)`)
- Click su tile valida → `ClassRuntime.use_targeted(tile)`
- Tasto ESC → cancella senza effetto
- Cursore/glyph diverso quando overlay è attivo

#### G2 — Implementare `is_valid_target` per ogni classe (PCS 1605)
Ogni `ClassSpecial` con targeting sovrascrive:
```gdscript
func is_valid_target(tile: Vector2i) -> bool:
    # es: tile visibile + ha un nemico
    return GameState.is_visible(tile) and has_enemy_at(tile)
```

#### G3 — Implementare classi `active_target` (PCS 1607–1611)
- **Mago** (`mage_arcane_bolt`): PCS righe **1055–1059** — tile con nemico visibile,
  danno INT×3 + ignora DEF
- **Ranger** (`ranger_companion`): PCS righe **1066–1070** — tile vuota adiacente (Fase H)
- **Piromante** (`pyromancer_fireball`): AoE 3×3, applica burn (StatusEffectManager)
- **Strega** (`witch_curse`): debuff VIT/2 per 5 turni
- **Cronoturgo** (`chrono_slow`): rallenta nemico target (2× turni per muoversi)
- **Cacciatore di Taglie** (`bounty_hunter_mark`): +50% danno su bersaglio marcato
- **Inquisitore** (`inquisitor_analyze`): rivela statistiche del nemico target
- **Sciamano** (`shaman_totem`): piazza entità su tile (Fase H per AllyManager)
- **Inventore** (`inventor_trap`): piazza trappola su tile (effetto su passaggio nemico)
- **Geomante** (`geo_wall`): crea muro temporaneo su tile
- **Illusionista** (`illusionist_double`): crea decoy su tile (Fase H per AllyManager)
- **Dominatore** (`dominator_control`): prende controllo nemico target per N turni

**Nota Ranger e Sciamano e Illusionista**: richiedono `AllyManager` (Fase H). Implementare
il targeting in G ma lasciare l'azione commentata con `# TODO Fase H`.

#### G-DBG — Aggiorna DebugScreen (sezione [Targeting])
- Sezione `[Targeting]`: `overlay_active: true/false`, `valid_tiles: N`,
  `last_selected: (x, y)`, `last_ability_used: class_id/special_id`,
  `was_cancelled: true/false` (l'ultimo uso è stato cancellato con ESC?)

### Criticità Fase G
1. **Tile valide vs selezionate**: evidenziare con colori distinti (verde = valido,
   giallo = hover, rosso = non valido). Non confondere il giocatore.
2. **Annullamento**: il giocatore deve sempre poter premere ESC. Non consumare l'abilità
   se si annulla (AbilityUseTracker non incrementa).
3. **Targeting su mobile**: il click è un tap su touchscreen — verificare che le tile
   abbiano dimensioni sufficienti per essere tappabili (PCS decisione riga **26 memory**).

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scenes/ui/TargetingOverlay.tscn` |
| Creare | `scripts/ui/TargetingOverlay.gd` |
| Creare | `scripts/classes/specials/MageArcaneBolt.gd` |
| Creare | `scripts/classes/specials/PyromancerFireball.gd` |
| Creare | `scripts/classes/specials/WitchCurse.gd` |
| Creare | `scripts/classes/specials/ChronoSlow.gd` |
| Creare | `scripts/classes/specials/BountyHunterMark.gd` |
| Creare | `scripts/classes/specials/InquisitorAnalyze.gd` |
| Creare | `scripts/classes/specials/InventorTrap.gd` |
| Creare | `scripts/classes/specials/GeomancerWall.gd` |
| Creare | `scripts/classes/specials/DominatorControl.gd` |
| Modificare | `scripts/classes/ClassRuntime.gd` (dispatch use_targeted) |

### Output atteso
Targeting mode mouse funzionante. Tutte le classi a bersaglio implementabili.

---

## FASE H — AllyManager + Entità Alleate
**Dipendenze:** Fase C + Fase G completate.
**Ref PCS:** righe **1617–1632** e architettura righe **1765–1767**

### Obiettivo
Gestire le entità alleate (pet, summon, totem, decoy) con distinzione netta tra
permanenti (salvate, respawnano) e temporanee (non salvate, rimosse a cambio piano).

### Passi dettagliati

#### H1 — Creare `AllyManager.gd` (PCS 1620, 1765–1767)
- Path: `res://scripts/combat/AllyManager.gd`
- Due liste distinte:
  - `permanent_allies: Array` — salvate in `GameState`, respawnano a inizio piano
  - `temporary_allies: Array` — non salvate, rimosse su `floor_changed`
- Metodi: `spawn_ally(ally_data, permanent: bool)`, `remove_ally(id)`,
  `on_floor_changed()` (rimuove temporanei, respawna permanenti),
  `get_all_allies() -> Array`
- Ogni ally ha: `id`, `type`, `hp`, `atk`, `team: "player"`, `position: Vector2i`
- Gli ally agiscono dopo il player nel turno (o come configurato)

#### H2 — Implementare Druido — Forma Mannaro (PCS decisioni riga **30 memory**)
- **Forma lupo** attiva in: dungeon (inclusi falò / save point)
- **Forma umana** in: overworld, buildings, villaggi
- `DruidShapeshift.gd`: hook `on_floor_changed()` o `on_location_changed()` per toggle automatico
- PCS righe **1102–1108** per la meccanica shapeshift completa

#### H3 — Implementare classi con entità (PCS 1621–1630)
| Classe | permanent | Note |
|--------|----------|------|
| Ranger | `ranger_companion` — sì | Spawna a inizio dungeon, respawna al piano, PCS **1066–1070** |
| Negromante | `necro_raise_dead` — no | Turni contati (WIL/2) |
| Demonista | `demonist_summon` — no | Turni contati |
| Sciamano | `shaman_totem` — no | Entità su tile, attacca nemici adiacenti |
| Illusionista | `illusionist_double` — no | Decoy, attira nemici, hp=1 |
| Evocatore | `summoner_elemental` — no | 3 tipi (mini-menu in Fase K) |
| Lich | `liche_army` — sì | Spawn da ogni kill (max INT/4), hp=1 |

**Mannaro** va implementato in H anche se non usa AllyManager — condivide il
`on_floor_changed()` hook.

#### H-DBG — Aggiorna DebugScreen (sezione [AllyManager] + [DruidForm])
- Sezione `[AllyManager]`: permanent allies elencati con `id, hp, pos(x,y)`;
  temporary allies con `id, hp, turns_left`; totale entità attive
- Sezione `[DruidForm]`: forma attiva (`lupo` / `umano`), location type corrente
  (`dungeon` / `overworld` / `building` / `village`), flag `at_savepoint`

### Criticità Fase H
1. **Save dei permanenti**: `permanent_allies` deve essere serializzabile in JSON per
   `SaveManager`. Usare un formato semplice `{type, hp, atk}`.
2. **Respawn al piano**: i permanenti respawnano in posizione valida (tile vuota adiacente
   al player). Non nella posizione salvata (potrebbe essere occupata da un muro nel
   nuovo piano generato proceduralmente).
3. **Evocatore (mini-menu)**: rimandare il menu di selezione tipo a Fase K. Per ora
   spawna sempre il tipo di default (fuoco) con `# TODO Fase K — mini-menu tipo`.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/combat/AllyManager.gd` |
| Creare | `scripts/classes/specials/RangerCompanion.gd` |
| Creare | `scripts/classes/specials/NecroRaiseDead.gd` |
| Creare | `scripts/classes/specials/DemonistSummon.gd` |
| Creare | `scripts/classes/specials/ShamanTotem.gd` |
| Creare | `scripts/classes/specials/IllusionistDouble.gd` |
| Creare | `scripts/classes/specials/DruidShapeshift.gd` |
| Modificare | `scripts/SaveManager.gd` (salva permanent_allies) |
| Modificare | `scripts/GameState.gd` (permanent_allies) |

### Output atteso
Entità alleate funzionanti. Distinzione permanent/temporary corretta. Druido cambia forma
automaticamente in base alla location.

---

## FASE H1 — Ally Entity System (entità alleate visive sulla mappa)
**Dipendenze:** Fase H completata. Prerequisito per AllyManager funzionale.
**Motivazione:** attualmente gli alleati esistono solo come dati astratti in AllyManager —
non appaiono sulla mappa, non si muovono, non hanno sprite. Questa fase li trasforma in
vere entità come i nemici.

### Obiettivo
Gli alleati del player (lupo del Ranger, non-morti del Negromante, demone del Demonista,
elementale dell'Evocatore, ecc.) devono essere entità reali sulla mappa con:
- Sprite/glyph ASCII visibile (come i nemici)
- Posizione sulla griglia
- Turni propri (si muovono verso i nemici e attaccano)
- HP tracciati, muoiono se a 0
- Permanenti che respawnano al piano successivo

### Architettura

#### H1.1 — Creare `Ally.gd` + `Ally.tscn`
- Path: `scripts/entities/Ally.gd` + `scenes/entities/Ally.tscn`
- `extends Entity` (come Enemy.gd)
- Proprietà: `ally_type: String`, `atk_mult: float`, `permanent: bool`, `turns_left: int`
- Metodo `setup(data: Dictionary)` — configura da ally_data come Enemy.setup()
- Metodo `take_turn()` — AI: move toward nearest enemy, attack if adjacent
- `faction = "ally"` (terza fazione oltre player/enemy)
- Visuale: glyph e colore configurabili per tipo

#### H1.2 — Aggiornare `AllyManager`
- Invece di `_allies: Array[Dictionary]`, gestisce `_ally_nodes: Array[Node]`
- `spawn_ally(data, map)`: istanzia Ally.tscn, chiama setup(), aggiunge al map
  - Trova tile libera adiacente al player per lo spawn
- `despawn_all_temp()`: su floor_changed, rimuove i nodi temporanei dalla mappa
- `respawn_permanent(map)`: su floor_changed, respawna i permanenti vivi con HP pieno
- `get_ally_nodes() -> Array[Node]`
- Mantiene `GameState.permanent_allies` come Array di dati per il save (non nodi)

#### H1.3 — Integrare con TurnManager
- `TurnManager.activate()` riceve anche gli alleati
- Ordine turni: player → alleati → nemici
- Modificare `_run_enemy_turns()` → `_run_npc_turns()`: prima ally, poi enemies
- `TurnManager.register_ally(ally: Node)` e `unregister_ally(ally: Node)`
- `Ally.take_turn()` cerca il nemico più vicino, si avvicina o attacca

#### H1.4 — AI Ally.take_turn()
```gdscript
func take_turn() -> void:
    if is_dead: return
    var map = WorldManager.get_current_map()
    var enemies = TurnManager.get_enemies()  # nuovo metodo pubblico
    var target = _nearest_enemy(enemies)
    if not target: EventBus.turn_ended.emit(self); return
    var dist = _manhattan(grid_position, target.grid_position)
    if dist <= 1:
        CombatManager.attack(self, target)
    else:
        _move_toward(target.grid_position, map)
    # Tick durata alleati temporanei
    if turns_left >= 0:
        turns_left -= 1
        if turns_left <= 0:
            die()
    EventBus.turn_ended.emit(self)
```

#### H1.5 — Glyph per tipo
| Tipo | Glyph | Colore |
|------|-------|--------|
| wolf | w | verde chiaro |
| undead | z | viola |
| demon | d | rosso scuro |
| elemental_fire | f | arancione |
| totem | T | giallo |
| skeleton | s | grigio |

#### H1.6 — Save/Load permanenti
- `GameState.permanent_allies` resta come `Array[Dictionary]` (dati puri, non nodi)
- Al load: AllyManager.restore_permanent() spawna i nodi sul map corrente
- La map deve essere caricata prima di restore_permanent() → chiamare dopo WorldManager.change_map()

### Criticità H1
1. **Tile libera per spawn**: trovare una tile adiacente al player che sia walkable e senza entità.
   Se non trovata entro 4 tile, usare una tile casuale nelle vicinanze.
2. **TurnManager con 3 fazioni**: l'ordine player→ally→enemy deve essere rispettato per evitare
   che gli alleati attacchino nemici già morti in quel turno.
3. **Permanent ally death**: se il lupo del Ranger muore in combattimento, AllyManager lo
   rimuove dai nodi ma mantiene il dato in GameState. Alla floor_changed, respawna con HP pieno.
4. **Combat log**: usare `EventBus.combat_log` per le azioni degli alleati (già in uso per nemici).

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scenes/entities/Ally.tscn` |
| Creare | `scripts/entities/Ally.gd` |
| Modificare | `scripts/combat/AllyManager.gd` (da Dictionary ad Ally nodes) |
| Modificare | `scripts/core/TurnManager.gd` (player→ally→enemy order) |
| Modificare | `scripts/core/SaveManager.gd` (spawn alleati dopo load) |

### Output atteso
Premendo Q con Evocatore/Ranger/Negromante, l'alleato appare fisicamente sulla mappa,
si muove autonomamente verso i nemici, li attacca a turni alterni con il player, muore
se a 0 HP, e (se permanente) respawna al piano successivo.

---

## FASE I — GlobalMilestoneTracker + Sistema Sblocco
**Dipendenze:** Solo Fase A. **Può girare in parallelo con Fasi D–H.**
**Ref PCS:** righe **1636–1646** e righe **961–1009**

### Obiettivo
I contatori di milestone persistono tra le run. Le classi si sbloccano giocando.

### Passi dettagliati

#### I1 — Creare `GlobalMilestoneTracker.gd` (PCS 1639, 961–1009)
- Path: `res://scripts/GlobalMilestoneTracker.gd`
- Registrare come **Autoload** (PCS riga **1481**)
- Load/save atomico di `user://saves/global_milestones.json` (PCS righe **961–997**)

> **Perché `user://` garantisce la persistenza globale**
> In Godot 4, `user://` mappa alla directory dati utente dell'OS, **indipendente da
> qualsiasi save file di personaggio o mondo**:
> - Windows: `%APPDATA%/Roaming/Godot/app_userdata/<nome_gioco>/`
> - Android: directory privata dell'app
>
> I save dei personaggi/mondi stanno in `user://saves/<world_id>/character.json`.
> `global_milestones.json` sta in `user://saves/global_milestones.json` — **è un file
> unico per installazione**, non per personaggio né per mondo.
>
> **Conseguenza**: sblocchi una classe con il personaggio A nel mondo 1 →
> `completed_classes` si aggiorna → la classe appare nella griglia per qualsiasi nuovo
> personaggio in qualsiasi nuovo mondo, su quella stessa installazione del gioco.
> Questo è esattamente il comportamento desiderato.
- Struttura del JSON (PCS righe **968–978**):
  ```json
  {
    "kills_total": 0,
    "kills_boss": 0,
    "dungeons_completed": 0,
    "dungeons_completed_no_death": 0,
    "deaths_total": 0,
    "completed_classes": [],
    "unlocked_classes": ["noob"],
    "class_respec_count": 0,
    "damage_dealt_total": 0,
    "damage_taken_total": 0,
    "scrolls_collected": 0,
    ...
  }
  ```
- Contatori **per-run** (PCS righe **998–1009**): tenuti in `GameState.run_milestones`,
  copiati/aggregati in global al termine della run
- Metodo `increment(key, amount)` con **write atomico** (scrivi su temp → rename)

#### I2 — Aggiungere segnali a `EventBus` (PCS 1640)
Segnali mancanti necessari per i contatori:
- `enemy_killed(enemy_data: Dictionary, class_id: String)`
- `boss_killed(boss_data: Dictionary, class_id: String)`
- `chest_opened()`
- `damage_dealt(amount: int, source: String)`
- `damage_taken(amount: int)`
- `game_completed(class_id: String)` — per `completed_classes`
- `item_collected(item_id: String)`

#### I3 — `GlobalMilestoneTracker` ascolta i segnali (PCS 1641)
- Si connette a `EventBus` in `_ready()`
- Incrementa i contatori appropriati
- Emette `milestone_updated(key, new_value)` dopo ogni incremento

#### I4 — `ClassUnlockService.gd` (PCS 1642)
- Path: `res://scripts/classes/ClassUnlockService.gd`
- Controlla le condizioni di sblocco dopo ogni `milestone_updated`
- Confronta `trigger_scope` (global vs run) con i contatori giusti
- Se condizione raggiunta: imposta classe come sbloccata in `GlobalMilestoneTracker`
  (`unlocked_classes: []`)
- Emette `class_unlocked(class_id)` su EventBus

#### I5 — Toast sblocco (PCS 1643)
- Ascolta `class_unlocked` su EventBus
- Mostra toast "Classe sbloccata: [Nome]!" per 3 secondi

#### I6 — `ClassPickerPanel` si aggiorna (PCS 1644)
- Collegare `ClassPickerPanel` a `GlobalMilestoneTracker` per filtrare le classi
  (`get_unlocked()` in ClassDB chiama GlobalMilestoneTracker)
- Rimuovere il `# TODO Fase I` aggiunto in Fase B

#### I-DBG — Aggiorna DebugScreen (sezione [Milestones])
- Sezione `[Milestones]`: tutti i contatori di `global_milestones.json` in lista
  (kills_total, deaths_total, dungeons_completed, ecc.), classi sbloccate `(N/60)`,
  `run_milestones` correnti (contatori della run in corso), ultimo segnale ricevuto

### Criticità Fase I
1. **Write atomico**: non scrivere direttamente sul file JSON — scrivere su `.tmp` e
   rinominarlo. Previene corruzione se il gioco crasha durante il salvataggio.
2. **trigger_scope**: alcune condizioni di sblocco usano contatori **per-run** (es: kills
   nella run corrente), altre globali. Leggere dal posto giusto (PCS righe **998–1009**).
3. **`all_classes_completed`** (Divinità): controllare che `completed_classes` contenga
   tutti i 59 altri `class_id`. Implementare il segnale `game_completed` nel boss finale.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/GlobalMilestoneTracker.gd` |
| Creare | `scripts/classes/ClassUnlockService.gd` |
| Modificare | `scripts/EventBus.gd` (nuovi segnali) |
| Modificare | `scripts/ui/ClassPickerPanel.gd` (filtro sbloccate) |
| Modificare | `project.godot` (Autoload GlobalMilestoneTracker) |

### Output atteso
Le classi si sbloccano giocando. I contatori persistono tra le run. Toast di sblocco visibile.

---

## FASE J — ClassRespecService + Licenza di Classe
**Dipendenze:** Fase A + Fase B + Fase I completate.
**Ref PCS:** righe **1650–1660** e righe **910–957**

### Obiettivo
Il giocatore può cambiare classe durante una run usando l'item raro "Licenza di Classe".
Il cambio usa il modello non-cumulativo per non rompere il bilanciamento.

### Passi dettagliati

#### J1 — Aggiungere `class_license` agli item (PCS 1653)
- Aggiungere voce in `items.json` (o file separato) per l'item "Licenza di Classe"
- Rarità: molto raro (drop solo da boss)
- Effetto: apre `ClassRespecScreen`

#### J2 — Creare `ClassRespecService.gd` (PCS 1654–1656)
- Path: `res://scripts/classes/ClassRespecService.gd`
- Metodo `respec(new_class_id: String)`:
  ```gdscript
  func respec(new_class_id: String) -> void:
      var new_class = ClassDB.get_class(new_class_id)
      GameState.current_class = new_class_id
      GameState.class_bonus = new_class.respec_bonus.duplicate()  # = non +=
      GameState.recalculate_effective_attributes()
      GlobalMilestoneTracker.increment("class_respec_count", 1)
      ClassRuntime.set_active_class(new_class_id)
  ```
- **Critico**: usare `=` non `+=` per `class_bonus` (PCS righe **924–938**, **1655**)

#### J3 — Creare `ClassRespecScreen.tscn/.gd` (PCS 1657)
- Path: `scenes/ui/ClassRespecScreen.tscn` + `scripts/ui/ClassRespecScreen.gd`
- Uguale a `ClassPickerPanel` ma esclude la classe corrente dalla lista
- Mostra solo classi implementate e sbloccate

#### J4 — Connettere l'item alla schermata (PCS 1658)
- Quando il player usa "Licenza di Classe" dall'inventario:
  → apre `ClassRespecScreen`
  → se confermata nuova classe: chiama `ClassRespecService.respec(new_id)`
  → consuma l'item dall'inventario

#### J-DBG — Aggiorna DebugScreen (sezione [Respec])
- Sezione `[Respec]`: tabella comparativa a 3 colonne:
  `attr | base | class_bonus | effective` per tutti e 5 gli attributi
- `class_respec_count` totale — utile per verificare che il contatore milestone
  sia corretto
- Ultima classe prima del respec + nuova classe scelta (storico dell'ultima operazione)

### Criticità Fase J
1. **`=` non `+=`**: la criticità principale. Se si usa `+=` il giocatore può farmmare
   statistiche infinitamente con il respec. Il Validator dovrebbe segnalare se si tenta
   di fare un respec cumulativo (aggiungere un check a `ClassRespecService`).
2. **Respec in dungeon**: il giocatore cambia classe a metà dungeon. Gli effetti della
   vecchia classe (stati attivi, entità temporanee) devono essere rimossi. Chiamare
   `ClassRuntime.deactivate_current()` prima di `set_active_class()`.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/classes/ClassRespecService.gd` |
| Creare | `scenes/ui/ClassRespecScreen.tscn` |
| Creare | `scripts/ui/ClassRespecScreen.gd` |
| Modificare | `data/items.json` (aggiunge class_license) |

### Output atteso
Il player può cambiare classe con la Licenza di Classe senza exploit. Il bilanciamento
rimane corretto.

---

## FASE K — Classi Complesse con UI Dedicata
**Dipendenze:** Tutto stabile + sistema oggetti avanzato (plan_item_system.md).
**Ref PCS:** righe **1664–1676**

### Obiettivo
Implementare le classi che richiedono mini-UI propria o dipendono dal sistema oggetti.

### Classi in questa fase (PCS 1667–1673)

| Classe | special_id | Dipendenza |
|--------|-----------|-----------|
| Alchimista | `alchemist_brew` | Sistema oggetti avanzato (crafting) |
| Evocatore | `summoner_elemental` | Mini-menu selezione tipo elementale |
| Druido | druid_shapeshift esteso | Già fattibile dopo Fase C (anticipare se utile) |
| Oracolo | `oracle_foresight` | Passiva + active_key, fattibile dopo Fase C |
| Esploratore | `explorer_sense` | Rivelazione mappa, fattibile dopo Fase C |

**Nota**: druido, oracolo ed esploratore **non richiedono sistema oggetti** (PCS riga **1675**).
Possono essere anticipati a Fase E/F se si vuole evitare di aspettare il sistema oggetti.

#### K-DBG — Aggiorna DebugScreen (sezioni esistenti)
- Nessuna sezione nuova. Verificare che le sezioni `[ClassSpecial]`, `[AbilityUseTracker]`
  e `[AllyManager]` mostrino correttamente i dati delle classi complesse:
  alchemist recipe attiva, summoner tipo selezionato, oracle foresight turns_ahead

### Criticità Fase K
1. **Alchimista**: dipende da `plan_item_system.md` — non iniziare finché il sistema
   oggetti non ha le ricette implementate.
2. **Mini-menu Evocatore**: deve essere una UI leggera (popup modale) che non rompa il
   flusso del turno. L'abilità è considerata "non usata" finché non si conferma il tipo.

### File da creare/modificare
| Operazione | Path |
|-----------|------|
| Creare | `scripts/classes/specials/AlchemistBrew.gd` |
| Creare | `scripts/classes/specials/SummonerElemental.gd` (estende H) |
| Creare | `scenes/ui/SummonerTypeMenu.tscn` |
| Creare | `scripts/classes/specials/OracleForesight.gd` |
| Creare | `scripts/classes/specials/ExplorerSense.gd` |

### Output atteso
Tutte le classi Tier 1-3 implementate e giocabili. Sistema oggetti e classi allineati.

---

## FASE L — Tier 4, 5, 6
**Dipendenze:** Tutte le fasi precedenti stabili e testate.
**Ref PCS:** righe **1680–1693**

### Obiettivo
Implementare le classi degli tier superiori in ordine di complessità crescente.
Non iniziare finché i sistemi base non sono stabili.

### Ordine consigliato (PCS 1686–1692)

#### L1 — Tier 4 semplici (PCS 1687)
- **Colosso** (`colossus_mass`): passivo, STR/5 aggiunto come DEF fissa
- **Arcicacciatore** (`archunter_pierce`): passivo, ignora DEF + DEX/4 all'ATK
- **Dio della Guerra** (`wargod_arena`): passivo, bonus ATK ogni kill nel piano
- **Spettro** (`specter_phase`): passivo, probabilità attraversare muri (DEX/300)

#### L2 — Tier 4 medi (PCS 1688)
- **Cacciatore di Anime** (`soul_hunter`): raccoglie "anime" da kill, Q li spende per buff
- **Campione** (`champion_glory`): crescita ATK permanente ogni boss kill (nella run)
- **Maestro del Tempo** (`time_master_rewind`): Q annulla ultimi 2 turni (richiede history turni)
- **Dominatore** (`dominator_control`): vedi Fase G — se rimandato, completare qui

#### L3 — Tier 4 complessi (PCS 1689)
- **Lich** (`liche_army`): scheletri permanenti da kill (AllyManager, già parzialmente in H)
- **Arcimago** (`archmage_repertoire`): cicla tra incantesimi + scroll rari
  (PCS riga **701** — dipende da sistema scroll in `plan_item_system.md`)

#### L4 — Tier 5 (PCS 1690)
- **Morte Incarnata** (`death_incarnate`): ogni kill ripristina HP max; PCS righe **1329–1331**
- **Specchio dell'Abisso** (`abyss_mirror`): 100% danno riflesso; PCS riga **838**
- **Il Vuoto** (`void_erasure`): toglie def/res nemici e proprie
- **L'Eletto** (`chosen_one`): tutti attributi a 10 start + crescita×2; PCS righe **1340–1343**
- **Paradosso** (`paradox_chaos`): effetto casuale ogni turno da pool di 12; PCS righe **1333–1338**
  - Pool 12 effetti da definire (questione aperta, PCS riga **1715**)

#### L5 — Tier 6 — Divinità (PCS 1691)
- `god_mode`: tre flag distinti (PCS righe **902–906**):
  1. `player.invincible = true` → in `Player.take_damage()`: return
  2. FOV renderer mostra sempre tutte le tile
  3. In `DamagePipeline`: danno finale = 1, DOPO tutti i moltiplicatori
- Sblocco: controllare `GlobalMilestoneTracker.completed_classes` ha 59 entry

#### L-DBG — Aggiorna DebugScreen (sezione [Tier4-6])
- Sezione `[Tier4-6]`: stato specifico per ogni meccanica ad alto tier attiva:
  - Lich: `skeletons: N/max (INT/4)`, lista posizioni scheletri
  - Maestro del Tempo: `history_depth: N turns`, `rewind_available: true/false`
  - Paradox: lista effetti attivi questo turno con durata
  - Divinità: `invincible: true`, `fov_disabled: true`, `damage_override: 1`,
    `completed_classes: N/59` (sblocco progress)

### Criticità Fase L
1. **Maestro del Tempo**: richiede una history degli stati di gioco degli ultimi N turni.
   Struttura dati non banale — pianificare prima di implementare.
2. **Arcimago + scroll**: non implementare finché `plan_item_system.md` non ha i rari
   che insegnano incantesimi (questione aperta, PCS riga **1718**).
3. **Paradosso**: i 12 effetti del pool devono essere decisi con valori esatti (questione
   aperta, PCS riga **1715**). Non implementare alla cieca.
4. **Divinità unlock**: assicurarsi che `game_completed` sia emesso con il `class_id` corretto
   dal boss finale. Il check su 59 classi deve escludere la Divinità stessa.

### File da creare/modificare
_(Un file `ClassSpecial` per ogni nuova classe + aggiornamento JSON status)_

### Output atteso
Tutte le 60 classi implementate e giocabili. Il gioco è completo per il sistema classi.

---

## Note architetturali di riferimento rapido
> Per dettagli completi: PCS righe **1722–1781**

- **ClassSpecial** (base class): PCS **1724–1742** — hook vuoti, una sottoclasse per special_id
- **DamagePipeline** (ordine): PCS **1744–1751** — ctx → before → calcola → applica → after → effetti
- **StatusEffectManager** (stacking): PCS **1753–1755** — replace/refresh/stack/ignore/unique
- **AbilityUseTracker** (config JSON): PCS **1757–1763** — limit+reset oppure cooldown_turns
- **AllyManager** (permanent vs temporary): PCS **1765–1767** — permanent salvato, temporary rimosso
- **MVP test rapido**: PCS **1769–1772** — Noob, Guerriero, Mago, Ladro, Paladino
- **ClassValidator** (startup): PCS **1774–1776** — id univoco, attributi completi, type validi
- **balance_category**: PCS **1778–1780** — normal/strong/endgame/legendary_broken/joke/challenge

---

---

# Tracking Completamento Fasi

> Spuntare la casella quando la fase è **completata e testata**. Aggiungere note di
> implementazione sotto ogni voce (data, build, problemi incontrati, decisioni prese).

---

## Fase 0 — Debug Screen
- [ ] 0.1 — `DebugScreen.tscn/.gd` creato (CanvasLayer layer=100, toggle `è`)
- [ ] 0.2 — `DebugSection.gd` creato (collassabile, metodo `update()`)
- [ ] 0.3 — DebugScreen aggiunto come figlio di `Main.tscn`
- [ ] 0.4 — InputMap: action `debug_toggle` → `KEY_EGRAVE`
- [ ] 0.5 — Sezione `[Sistema]` visibile (FPS, Godot version, build, piattaforma)
- [ ] Verifica: `queue_free()` in release build (non appare nell'APK/EXE)
- [ ] **FASE 0 COMPLETA** — pannello appare/scompare con `è`, solo in debug

**Note implementazione Fase 0:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase A — Data Layer + GameState
- [ ] A1 — 60 file JSON creati in `data/classes/tier{1-6}/`
- [ ] A2 — `ClassDB.gd` creato e registrato come Autoload
- [ ] A3 — `ClassValidator.gd` creato, nessun errore a startup
- [ ] A4 — `GameState` ristrutturato (base_attributes + class_bonus + effective_attributes)
- [ ] A5 — `SaveManager` aggiornato (save/load current_class, base_attributes, class_bonus)
- [ ] A6 — `LevelSystem` aggiornato (incrementa base_attributes con growth da ClassDB)
- [ ] A-DBG — DebugScreen: sezioni `[ClassDB]` e `[GameState]` aggiunte e funzionanti
- [ ] **FASE A COMPLETA** — il gioco si avvia senza errori

**Note implementazione Fase A:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase B — Class Picker + Selezione Iniziale
- [ ] B1 — `ClassPickerPanel.tscn/.gd` creato (griglia di ClassCard)
- [ ] B1b — `ClassCard.tscn/.gd` creato (quadrato colorato per tier, lettera placeholder)
- [ ] B1c — Tooltip hover funzionante (nome, attributi, abilità, sblocco in chiaro)
- [ ] B1d — Solo classi `implemented` + sbloccate mostrate nella griglia
- [ ] B2 — Integrato in `NewGamePanel` (step dopo nome personaggio)
- [ ] B3 — `StatusScreen` mostra nome classe e special_desc
- [ ] B4 — `_reset_game_state()` applica class_bonus della classe scelta
- [ ] B-DBG — DebugScreen: sezione `[ClassPicker]` aggiunta
- [ ] **FASE B COMPLETA** — griglia con tooltip funzionante, si sceglie Noob

**Note implementazione Fase B:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase C — DamagePipeline
- [ ] C1 — `DamagePipeline.gd` creato con `DamageContext`
- [ ] C2 — `CombatManager` refactorato per usare la pipeline (stesso comportamento)
- [ ] C3 — Hook esposti (before/after attack, before/after damaged, on_enemy_killed)
- [ ] C4 — `ClassRuntime.gd` creato (registry + dispatch hook)
- [ ] C5 — `ClassSpecial.gd` base class creata (hook vuoti)
- [ ] Test: una run completa con Noob senza differenze nel comportamento
- [ ] C-DBG — DebugScreen: sezioni `[DamagePipeline]` e `[ClassRuntime]` aggiunte
- [ ] **FASE C COMPLETA** — pipeline attiva, ClassRuntime pronto

**Note implementazione Fase C:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase D — Prime Classi MVP
- [ ] D6 — `AbilityUseTracker.gd` creato
- [ ] D1 — `NoobAdaptability.gd` implementato, status JSON = implemented
- [ ] D2 — `WarriorFury.gd` implementato, status JSON = implemented
- [ ] D3 — `MonkDodge.gd` implementato, status JSON = implemented
- [ ] D4 — `RogueBackstab.gd` implementato, status JSON = implemented
- [ ] D5 — `PaladinLayOnHands.gd` implementato, status JSON = implemented
- [ ] Test: run completa con ciascuna delle 5 classi MVP
- [ ] D-DBG — DebugScreen: sezioni `[AbilityUseTracker]` e `[ClassSpecial]` aggiunte
- [ ] **FASE D COMPLETA** — 5 classi giocabili, sistema testabile end-to-end

**Note implementazione Fase D:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase E — AbilityUseTracker + Active Key Avanzate
- [ ] E1 — `BardSong.gd` implementato (buff temporaneo player)
- [ ] E2 — `GuardianShield.gd` implementato (shield_hp in before_player_damaged)
- [ ] E3 — `SpellbladeEnchant.gd` implementato (counter locale)
- [ ] E4 — `WarlockDarkPact.gd` implementato (HP→MP + attack_multiplier)
- [ ] AbilityUseTracker stabile (cooldown turni + reset per piano)
- [ ] E-DBG — DebugScreen: sezione `[ActiveBuffs]` aggiunta
- [ ] **FASE E COMPLETA** — classi active_key funzionanti

**Note implementazione Fase E:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase F — StatusEffectManager + Debuff
- [ ] F1 — `StatusEffectManager.gd` creato (apply/tick/remove + stacking rules)
- [ ] F1 — `Enemy.gd` aggiornato (active_effects, take_turn legge stati)
- [ ] F2 — `BarbarianWarcry.gd` implementato (AoE debuff ATK)
- [ ] F2 — `CorsairDirtyHit.gd` implementato (stun passivo 20%)
- [ ] F2 — `BerserkerFrenzy.gd` implementato (ATK+50%, blocco item + notifica)
- [ ] F2 — `SentinelGuard.gd` implementato (guard_stacks)
- [ ] Test: notifica Berserker quando tenta di usare item
- [ ] F-DBG — DebugScreen: sezione `[StatusEffects]` aggiunta
- [ ] **FASE F COMPLETA** — sistema debuff/buff stabile

**Note implementazione Fase F:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase G — TargetingOverlay + Active Target
- [ ] G1 — `TargetingOverlay.tscn/.gd` creato (highlight tile, click, ESC)
- [ ] G2 — `is_valid_target` implementato per ogni classe con targeting
- [ ] G3 — `MageArcaneBolt.gd` implementato
- [ ] G3 — `PyromancerFireball.gd` implementato (AoE + burn)
- [ ] G3 — `WitchCurse.gd` implementato
- [ ] G3 — `ChronoSlow.gd` implementato
- [ ] G3 — `BountyHunterMark.gd` implementato
- [ ] G3 — `InquisitorAnalyze.gd` implementato
- [ ] G3 — `InventorTrap.gd` implementato
- [ ] G3 — `GeomancerWall.gd` implementato
- [ ] G3 — `DominatorControl.gd` implementato
- [ ] Test: targeting con click, ESC non consuma abilità
- [ ] G-DBG — DebugScreen: sezione `[Targeting]` aggiunta
- [ ] **FASE G COMPLETA** — targeting mode funzionante

**Note implementazione Fase G:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase H — AllyManager + Entità Alleate
- [ ] H1 — `AllyManager.gd` creato (permanent/temporary, floor_changed, respawn)
- [ ] H2 — `DruidShapeshift.gd` implementato (lupo dungeon/falò, umano overworld)
- [ ] H3 — `RangerCompanion.gd` implementato (permanent, respawn al piano)
- [ ] H3 — `NecroRaiseDead.gd` implementato (temporary, turni contati)
- [ ] H3 — `DemonistSummon.gd` implementato (temporary)
- [ ] H3 — `ShamanTotem.gd` implementato (entità su tile)
- [ ] H3 — `IllusionistDouble.gd` implementato (decoy)
- [ ] H3 — `SaveManager` aggiorna permanent_allies
- [ ] Test: ranger companion sopravvive a cambio piano; summon sparisce
- [ ] H-DBG — DebugScreen: sezioni `[AllyManager]` e `[DruidForm]` aggiunte
- [ ] **FASE H COMPLETA** — entità alleate funzionanti

**Note implementazione Fase H:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase H1 — Ally Entity System
- [ ] H1.1 — `Ally.gd` + `Ally.tscn` creati (extends Entity, faction="ally", setup(), take_turn())
- [ ] H1.2 — `AllyManager` aggiornato (spawn nodi, despawn temp, respawn permanent)
- [ ] H1.3 — `TurnManager` aggiornato (ordine player→ally→enemy)
- [ ] H1.4 — AI Ally.take_turn() (move toward nearest enemy, attack if adjacent, tick duration)
- [ ] H1.5 — Glyph per tipo (wolf=w, undead=z, demon=d, fire=f)
- [ ] H1.6 — Save/Load permanenti aggiornato
- [ ] H1-DBG — DebugScreen: [AllyManager] aggiornato con posizioni nodi e HP
- [ ] **FASE H1 COMPLETA** — alleati visibili sulla mappa, combattono autonomamente

**Note implementazione Fase H1:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase I — GlobalMilestoneTracker + Sistema Sblocco
- [ ] I1 — `GlobalMilestoneTracker.gd` creato e Autoload registrato
- [ ] I1 — Write atomico a `user://saves/global_milestones.json`
- [ ] I2 — Nuovi segnali aggiunti a `EventBus`
- [ ] I3 — GlobalMilestoneTracker connesso ai segnali e aggiorna contatori
- [ ] I4 — `ClassUnlockService.gd` creato (controlla condizioni sblocco)
- [ ] I5 — Toast "Classe sbloccata: [Nome]!" implementato
- [ ] I6 — `ClassPickerPanel` collegato a GlobalMilestoneTracker (rimosso TODO)
- [ ] Test: sbloccare una classe giocando, verificare che persista tra le run
- [ ] I-DBG — DebugScreen: sezione `[Milestones]` aggiunta
- [ ] **FASE I COMPLETA** — sblocchi funzionanti e persistenti

**Note implementazione Fase I:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase J — ClassRespecService + Licenza di Classe
- [ ] J1 — `class_license` aggiunto agli item (drop da boss)
- [ ] J2 — `ClassRespecService.gd` creato (usa `=` non `+=` per class_bonus)
- [ ] J3 — `ClassRespecScreen.tscn/.gd` creato (esclude classe corrente)
- [ ] J4 — Uso item → apre ClassRespecScreen → chiama respec → consuma item
- [ ] Test: respec multipli non aumentano stats oltre il limite
- [ ] J-DBG — DebugScreen: sezione `[Respec]` aggiunta (tabella base/class_bonus/effective)
- [ ] **FASE J COMPLETA** — respec funzionante senza exploit

**Note implementazione Fase J:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase K — Classi Complesse con UI Dedicata
- [ ] K1 — `OracleForesight.gd` implementato (anticipabile a Fase E/F)
- [ ] K1 — `ExplorerSense.gd` implementato (anticipabile a Fase E/F)
- [ ] K2 — `SummonerTypeMenu.tscn` creato + `SummonerElemental.gd` aggiornato
- [ ] K3 — `AlchemistBrew.gd` implementato (richiede item system avanzato)
- [ ] K-DBG — DebugScreen: sezioni esistenti verificate con classi complesse
- [ ] **FASE K COMPLETA** — tutte le classi Tier 1-3 implementate

**Note implementazione Fase K:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Fase L — Tier 4, 5, 6
- [ ] L1 — Tier 4 semplici: Colosso, Arcicacciatore, Dio della Guerra, Spettro
- [ ] L2 — Tier 4 medi: Cacciatore di Anime, Campione, Maestro del Tempo, Dominatore
- [ ] L3 — Tier 4 complessi: Lich (AllyManager), Arcimago (scroll system)
- [ ] L4 — Tier 5: Morte Incarnata, Specchio Abisso, Il Vuoto, L'Eletto
- [ ] L4 — Paradosso (dopo aver definito i 12 effetti del pool)
- [ ] L5 — Divinità: invincible + fov_disabled + damage_override=1
- [ ] L5 — Sblocco Divinità: completed_classes con 59 entry
- [ ] Test: run completa con Divinità (1 danno per attacco, mappa visibile, immortale)
- [ ] L-DBG — DebugScreen: sezione `[Tier4-6]` aggiunta (lich/paradox/divinità state)
- [ ] **FASE L COMPLETA** — 60 classi implementate e giocabili

**Note implementazione Fase L:**
```
Data: ___________
Build: ___________
Note: 




```

---

## Questioni Aperte (da decidere prima di implementare)
> PCS righe **1713–1718**

- [ ] **Paradosso — pool 12 effetti**: definire i 12 effetti con valori esatti e durata.
  Da decidere prima di implementare `paradox_chaos` in Fase L4.
- [ ] **Arcimago — scroll rari**: definire quali scroll insegnano incantesimi nuovi.
  Da fare quando si implementa `plan_item_system.md` per i rari.

---

*Documento generato nella sessione del 2026-05-20. Aggiornare le note di implementazione
man mano che si completa ciascuna fase.*

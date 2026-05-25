# Piano — Crime System

> **Scope**: sistema minimo ma coerente. Un crimine = attaccare un NPC civile.
> La risposta locale è immediata (guardie ostili → 1HP → multa + libertà).
> Le altre città non reagiscono attivamente — la fedina è visibile solo in UI.

---

## Decisioni di design

### Amuleto del Sangue
- Attaccare un NPC civile è **impossibile senza l'Amuleto del Sangue** equipaggiato
- Senza amuleto: tentare di attaccare un NPC civile non fa nulla (o mostra messaggio bloccante)
- L'amuleto è un oggetto equipaggiabile — slot da definire (suggerimento: `neck` o slot dedicato)
- La Tavola Senza Nome è il gate narrativo ovvio per ottenerlo

### Crimini
- L'unico trigger iniziale è **attaccare un NPC non-nemico** con l'Amuleto del Sangue equipaggiato
- Il crimine è valido **solo in mappe di tipo `"village"`, `"city"`, `"building"`** — non in dungeon, overworld, rovine
- Il crimine è **locale** (per `city_id`): le guardie di Città A non inseguono il player in Città B
- Il crimine persiste finché non viene risolto (arresto) o rimosso (Tavola Senza Nome)
- Il player può scappare dalla città prima dell'arresto — le guardie non lo seguono fuori

### Comportamento NPC durante il crimine
- NPC non attaccati: mantengono la loro rep normale, non combattono
- NPC attaccati: diventano **ostili** (combattono il player) fino al termine del crimine
- Testimoni (NPC con LOS) non diventano ostili — chiamano solo le guardie (crimine registrato)
- Al termine del crimine (arresto o fuga): gli NPC attaccati tornano alla rep normale ma il danno reputazionale è fatto

### Penalità rep post-crimine
- Quando il crimine termina: **-50 rep** con la faction di ogni NPC che era nel raggio di 30 tile O che è stato attaccato durante il crimine
- La penalità si applica una volta per faction unica (non stacked per ogni NPC della stessa faction)
- `milizia_campane` riceve sempre la penalità indipendentemente dalla distanza

### View range NPC
- Raggio massimo di visibilità degli NPC: **30 tile** (costante `NPC_VIEW_RANGE = 30`)
- Usato per: rilevamento testimoni, calcolo penalità rep post-crimine

### Guardie
- Le guardie sono **NPC standard** con `faction: milizia_campane` piazzati nel CityBuilder
- Quando il crimine è attivo in una città, le guardie entrano in modalità ostile locale
- Le guardie attaccano il player ma si fermano a **1 HP** e poi arrestano (non uccidono)
- Il comportamento "ferma a 1HP" è implementato come override sul danno letale in CombatManager

### Arresto
- Conseguenza: **multa = 25% dell'oro corrente** (floor, minimo 0g)
- Il player viene lasciato libero nella stessa mappa — nessuna cella
- Il crimine passa dallo stato "attivo" a "risolto" (fedina aggiunta, guardie ritirano)
- Rep globale `milizia_campane` cala anche all'arresto (-10 aggiuntivi)

### Fedina penale
- Lista di arresti (città, turno approssimativo) in `GameState`, persistita nel save
- Visibile solo in UI (StatusScreen o FactionScreen) — nessun effetto meccanico in altre città
- Le guardie nelle altre città **non reagiscono** alla fedina
- La fedina non si cancella mai (è storia del personaggio) — il crimine attivo sì

### Livelli crimine per città

| Livello | Significato |
|---------|-------------|
| `0` | Nessun crimine — guardie normali |
| `1` | Crimine attivo — guardie ostili, inseguimento in corso |
| `2` | Arrestato — crimine risolto, guardie normali, fedina aggiunta |

### Costi e bilanciamento

| Costante | Valore | Note |
|----------|--------|------|
| `CRIME_FINE_PCT` | `0.25` | 25% dell'oro corrente |
| `CRIME_REP_HIT_CRIME` | `-20` | Rep `milizia_campane` al momento del crimine |
| `CRIME_REP_HIT_ARREST` | `-10` | Rep aggiuntiva all'arresto |
| `CRIME_GUARD_MIN_HP` | `1` | HP minimo lasciato dalle guardie |
| `CRIME_GUARD_COUNT` | `6` | Guardie spawned al primo crimine |
| `CRIME_GUARD_WAVE_TURNS` | `8` | Turni tra un'ondata e l'altra |
| `CRIME_GUARD_WAVE_SIZE` | `3` | Guardie per ondata successiva |
| `NPC_VIEW_RANGE` | `30` | Tile massime di visibilità NPC (testimoni + penalità rep) |
| `CRIME_NPC_REP_PENALTY` | `-50` | Penalità rep post-crimine per faction nel raggio |

---

## Piano di implementazione

> **Legenda**: ✓ implementato · ✗ non implementato · ⚠ parziale

---

### FASE 1 — Dati e autoload ✓

#### 1.1 `GameState` — estensioni crimine
- ✓ Rimosso `active_bounty` — sostituito da `crime_state` + `criminal_record`
- ✓ `crime_state: Dictionary` — `{city_id: int}` (0=nessuno, 1=attivo, 2=arrestato); NON persiste
- ✓ `criminal_record: Array` — `[{city_id, city_name, turn}]`; persistito nel save
- ✓ `current_city_id: String = ""` — root city ID stabile, settato da WorldManager
- ✓ `GameState.get_crime_level(city_id) -> int`
- ✓ `GameState.set_crime_level(city_id, crime_level: int)` — rimuove chiave se 0
- ✓ `GameState.add_arrest_to_record(city_id, city_name)`
- ✓ `criminal_record` aggiunto a `SaveManager` — serialize + deserialize

#### 1.2 `CrimeSystem.gd` — autoload
- ✓ `scripts/core/CrimeSystem.gd` creato, registrato in `project.godot`
- ✓ Tutte le costanti implementate
- ✓ `_attacked_npcs`, `_guard_wave_timer`, `_witness_check_result`
- ✓ Connessione a `EventBus.player_turn_started` → wave countdown
- ✓ `register_crime()`, `arrest_player()`, `clear_crime()`, `is_crime_active()`, `get_criminal_record()`, `track_attacked_npc()`, `initialize_for_new_game()`

#### 1.3 `EventBus` — nuovi segnali
- ✓ `crime_committed(city_id)`, `player_arrested(city_id, fine_amount)`, `crime_cleared(city_id)`

---

### FASE 2 — Trigger crimine ⚠

#### 2.1 Gate — Amuleto del Sangue
- ✓ Item creato: `data/items/accessories/amulets/amuleto_del_sangue.json` (slot neck, loot_weight 0)
- ✓ Gate in `CombatManager.attack()` — blocca con warning + mostra notifica

#### 2.2 Hook in `CombatManager` — trigger crimine
- ✓ `track_attacked_npc()` + `has_witnesses()` + `register_crime()` su attacco NPC con amuleto
- ✗ **Restrizione map_type non implementata** — il gate non controlla se la mappa è village/city/building; si attiva anche in mappe prive di `current_city_id` (ma in quel caso `city_id == ""` e `register_crime` richiede city_id valido)

#### 2.3 `CrimeSystem.has_witnesses()` e `BaseMap.has_line_of_sight()`
- ✓ `has_witnesses(origin)` implementato — itera NPC, distanza ≤30, LOS check
- ✓ `BaseMap.has_line_of_sight()` aggiunto come wrapper pubblico di `_has_line_of_sight()`

#### 2.4–2.5 Tracking NPC + hook cambio mappa
- ✓ `_attacked_npcs` tracking
- ✓ `WorldManager._update_city_id()` — aggiorna `current_city_id`, chiama flee penalty, spawna pattuglia al rientro
- ✓ `Notification.gd` — aggiunta `crime_committed()`, `player_arrested()`, `crime_cleared()`
- ✓ Chiavi localizzazione in `strings_notifications.csv`

---

### FASE 3 — Comportamento guardie ✓

#### 3.1 `Guard.gd`
- ✓ `scripts/entities/Guard.gd` creato — estende Enemy, `is_guard = true`
- ✓ `setup_guard(player_level)` — stat scalate per livello
- ✓ `die()` override — niente XP/loot/rep; solo unregister + queue_free

#### 3.2 Spawn guardie
- ✓ `CrimeSystem._spawn_guards(count)` — usa `map._add_entity()` + `TurnManager.register_enemy()`
- ✓ Spawn a ondate via `_on_player_turn()`
- ✓ `_find_spawn_pos()` in raggio 3–5 tile

#### 3.3 Arresto a 1HP
- ✓ `_check_guard_arrest()` in `CombatManager` — controlla HP ≤ CRIME_GUARD_MIN_HP dopo danno

---

### FASE 4 — Logica arresto ✓

- ✓ `arrest_player()` — multa 25%, livello 2, record, rep penalty, rimuove guardie
- ✓ `_apply_post_crime_rep_penalty()` — -50 rep a faction nel raggio + attaccati; milizia_campane sempre
- ✓ `_remove_all_guards()` chiamata da `arrest_player()` e `clear_crime()`

---

### FASE 5 — UI fedina penale ✓

- ✓ `StatusScreen._setup_crime_section()` — separator + status label + record label
- ✓ `StatusScreen._refresh_crime_section()` — mostra stato wanted + lista arresti
- ✓ Aggiornata a ogni `player_arrested`, `crime_committed`, `crime_cleared`
- ✓ Chiavi UI in `strings_ui.csv`: `UI_STATUS_WANTED`, `UI_STATUS_CLEAN`, `UI_STATUS_CLEAN_RECORD`, `UI_STATUS_ARREST_HEADER`, `UI_STATUS_ARREST_ENTRY`, `WARN_NEED_AMULETO`

---

### FASE 6 — Integrazione Tavola Senza Nome ✓

- ✓ `FactionActionsService.try_reduce_bounty_tsn()` implementato — chiama `CrimeSystem.clear_crime()`
- ✓ Prerequisito: `tsn_black_market` flag + crimine attivo
- ✓ **Costo 200g implementato** — `BOUNTY_REDUCE_COST = 200`, check gold + `modify_gold(-200)` prima di clear
- ✓ NPC con `faction_action_id = "reduce_bounty"` già predisposto e collegato

---

### FASE 7 — Debug Screen ✓

- ✓ `_add_section("crime", "CrimeSystem")` aggiunto
- ✓ `_update_crime()` — mostra city_id, stato crimine, witness_cached, wave timer, record
- ✓ `_build_crime_tools()` — bottoni "Registra crimine", "Arresta", "Cancella crimine", "Pulisci fedina", "Spawn N guardie" (1/3/6)
- ✓ **Witness test button** — "Check testimoni" in row3, chiama `has_witnesses(player_position)` + refresh
- ✓ **Amuleto toggle button** — "Equip/Rimuovi amuleto" in row3, toggle equip slot neck + `_update_amuleto_btn()`
- ✗ SpinBox per spawn count personalizzato (usati 3 pulsanti fissi 1/3/6 — design scelto come sufficiente)

---

### Extra — City Builder (aggiunto fuori piano)
- ✓ NPC params: `is_guard: bool`, `gender: String (""|"m"|"f")`, `is_child: bool`
- ✓ UI controlli in "— Tipo NPC —": checkbox is_guard, checkbox is_child, dropdown gender
- ✓ `NPC.gd` legge `is_guard_npc`, `gender`, `is_child` dal data dict

---

## Dipendenze inter-sistema

| Feature | Dipende da |
|---------|-----------|
| Trigger crimine da attacco | NPC non-nemici ricevono danno da player (deve esistere) |
| Guardie che combattono | NPC partecipano al loop di combattimento (vedi Fase 3.2 nota) |
| Sconto taglia Tavola | Membership `tavola_senza_nome` (Fase 7.5 factions — già implementato) |
| Tavola sblocca crimini (omicidio/furto/minaccia) | Fuori scope di questo piano; definire separatamente |
| Propagazione rep milizia su crimine | `FactionReputation.add_rep()` con propagazione — già implementato |
| Visualizzazione fedina in FactionScreen | FactionScreen esistente (Fase 15 factions — già implementato) |

---

## Fuori scope (non implementare in questo piano)

- Furto, minaccia, omicidio come meccaniche distinte → da aggiungere solo dopo che questo sistema di base funziona
- Pena detentiva (cella, turni di attesa) → design scelto: solo multa
- Effetti meccanici fedina nelle altre città → design scelto: solo UI
- `milizia_campane` come attori attivi nel mondo (pattuglie, eventi) → dipende da NPC AI system
- Crimini testimoniali vs non testimoniali → fuori scope; tutti i crimini in città sono sempre registrati
- Interazione con il sistema classi (negromante, ranger, druido) → fuori scope

---

## Aggiornamenti a codebase_reference.md

Da fare a fine sistema:
- Aggiungere `CrimeSystem` alla tabella autoload
- Documentare `crime_state` e `criminal_record` in GameState
- Documentare `current_city_id` in GameState
- Documentare costanti crime in CrimeSystem
- Documentare segnali EventBus crime
- Documentare pattern NPC guard stance override

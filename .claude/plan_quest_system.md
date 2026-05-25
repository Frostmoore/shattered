# Piano: Quest System

**Stato**: Bozza — sistema base già implementato; questo piano descrive le espansioni.

**Dipendenze**: NPC System (FASE 1-3) ✗ per le espansioni più complesse.

---

## Stato attuale

Già implementato e funzionante:
- `QuestManager` autoload: `start_quest()`, `complete_quest()`, `check_kill_objective()`
- Quest objectives: tipo `KILL` (target + required + current counter)
- Rewards: `xp`, `gold`, `faction_rep`, `join_faction`, `items`
- Stati: `active_quests`, `ready_quests`, `completed_quests` in GameState
- Quest Journal UI (tasto J)
- NPC: `dialogue_id_quest_active/done`, `linked_quest_id`
- Quest senza objectives: segna `ready` subito all'avvio

---

## Tipi di objective da aggiungere

| Tipo | Descrizione | Dipendenze |
|------|-------------|------------|
| `FETCH` | Porta X unità di item Y | nessuna |
| `VISIT` | Raggiungi la location X | Overworld System |
| `TALK` | Parla con l'NPC X | NPC System |
| `SURVIVE` | Sopravvivi N giorni | Time System |
| `ESCORT` | Accompagna NPC X a location Y | NPC System + movimento NPC |
| `CRAFT` | Craft item X (futuro) | Crafting System |

Aggiunta: i tipi vengono letti dal JSON quest e dispatchati in `QuestManager`.

### Schema JSON quest (attuale + esteso)

```jsonc
{
  "id": "quest_villaggio_01",
  "title": "La Mappa Perduta",
  "description": "Recupera la mappa dal dungeon e consegnala al cartografo.",
  "giver_npc_id": "cartografo_rivamola",
  "objectives": [
    { "type": "FETCH",  "item_id": "mappa_antica",  "required": 1, "current": 0 },
    { "type": "TALK",   "npc_id": "cartografo_rivamola" }
  ],
  "completion_mode": "turn_in",
  "rewards": {
    "xp": 200,
    "gold": 100,
    "faction_rep": [{ "faction_id": "collegio_cartografi", "amount": 15 }]
  },
  "time_limit_days": 0,
  "on_fail": { "world_flag": "quest_mappa_fallita" },
  "chain_next": "quest_mappa_02"
}
```

---

## Nuove feature

### 1. Quest FETCH

`FETCH` objective check: `QuestManager.check_fetch_objective(quest_id, obj_index)` — verifica `Inventory.has_item(item_id, required)`.  
Completamento: il turn-in rimuove automaticamente l'item (`Inventory.remove_item()`).

### 2. Quest VISIT

`VISIT` objective: completato quando `GameState.current_map_id == target_location_id`.  
Hook in `WorldManager._on_map_changed()` → `QuestManager.check_visit_objectives(location_id)`.

### 3. Quest TALK

`TALK` objective: completato quando il player interagisce con l'NPC specificato.  
Hook in `NPC.interact()` → `QuestManager.check_talk_objectives(npc_id)`.

### 4. Quest a catena (`chain_next`)

Quando una quest viene completata, se ha `chain_next`, la prossima viene avviata automaticamente (o resa disponibile all'NPC).  
`QuestManager.complete_quest()` → se `chain_next != ""` → `start_quest(chain_next)` oppure setta flag `quest_chain_ready`.

### 5. Quest con scadenza (`time_limit_days`)

Se `time_limit_days > 0`:
- Al `start_quest()` → salva `deadline_day = GameState.day_count + time_limit_days` nel dict quest
- Su `EventBus.day_changed` → `QuestManager._check_deadlines()` → se `day_count > deadline_day` → `fail_quest(quest_id)`

### 6. Fallimento quest (`fail_quest`)

```gdscript
func fail_quest(quest_id: String) -> void:
    active_quests.erase(quest_id)
    failed_quests.append(quest_id)   # nuovo Array in GameState
    var quest: Dictionary = _get_quest_data(quest_id)
    _apply_on_fail(quest.get("on_fail", {}))
    EventBus.quest_failed.emit(quest_id)
    EventBus.notification_shown.emit(Notification.quest_failed(quest.title))
```

`on_fail` può contenere:
- `{ "world_flag": "flag_id" }` — setta un GameState.world_flag
- `{ "faction_rep": [{ "faction_id": "...", "amount": -10 }] }` — penalità rep

### 7. NPC death → quest failure

`QuestManager.on_npc_died(quest_id: String)` — chiamato da `NPC.die()` se l'NPC ha `linked_quest_id` e la quest è attiva.

### 8. Quest Journal — aggiornamenti UI

- Aggiungere sezione "FALLITE" in `QuestJournal.gd`
- Mostrare scadenza per quest con `time_limit_days`
- Obiettivi `FETCH`/`VISIT`/`TALK` con testo localizzato

### 9. Localizzazione nuovi objective

```
UI_QUEST_OBJECTIVE_FETCH,Porta {item}: {current}/{required}
UI_QUEST_OBJECTIVE_VISIT,Raggiungi: {location}
UI_QUEST_OBJECTIVE_TALK,Parla con: {npc}
UI_QUEST_OBJECTIVE_SURVIVE,Sopravvivi: {current}/{required} giorni
UI_QUEST_FAILED,Quest fallita: {title}
UI_QUEST_SECTION_FAILED,FALLITE
```

---

## GameState — nuovi campi

```gdscript
var failed_quests:  Array[String] = []
# Per ogni quest attiva con scadenza: salvata come { quest_id, deadline_day } nell'array active_quests
```

---

## EventBus — nuovi segnali

```gdscript
quest_failed(quest_id: String)
```

---

## Lista task

### Immediato (senza dipendenze esterne)

- [ ] `QuestManager`: aggiungere `check_fetch_objective(quest_id, obj_idx)`
- [ ] `QuestManager.complete_quest()`: gestione `chain_next`
- [ ] `GameState.failed_quests: Array[String]`
- [ ] `QuestManager.fail_quest(quest_id)` + `_apply_on_fail()`
- [ ] `EventBus.quest_failed`
- [ ] Quest Journal UI: sezione "FALLITE"
- [ ] Localizzazione: `UI_QUEST_OBJECTIVE_FETCH`, `UI_QUEST_FAILED`, `UI_QUEST_SECTION_FAILED`
- [ ] SaveManager: serializza/deserializza `failed_quests`

### Dopo NPC System

- [ ] `QuestManager.check_talk_objectives(npc_id)` — hook in `NPC.interact()`
- [ ] `QuestManager.on_npc_died(quest_id)` — hook in `NPC.die()`

### Dopo Overworld / Travel System

- [ ] `QuestManager.check_visit_objectives(location_id)` — hook in `WorldManager._on_map_changed()`

### Dopo Time System

- [ ] `QuestManager._check_deadlines()` — hook in `EventBus.day_changed`
- [ ] Salvataggio `deadline_day` per quest attive con scadenza
- [ ] Quest Journal: mostra scadenza

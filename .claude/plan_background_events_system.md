# Piano: Background Events System

**Stato**: Scheletro — da progettare in dettaglio dopo l'implementazione degli altri sistemi.

**Dipendenze**: Time System ✗, NPC System ✗, Quest System ✗, Overworld System ✗

---

## Cos'è

Il Background Events System gestisce eventi che avvengono **indipendentemente dalle azioni dirette del player**: il mondo continua a esistere e cambiare mentre il player esplora. Gli eventi si attivano per il passaggio del tempo, per trigger di stato (quest completata, NPC morto, fazione in guerra), o per condizioni ambientali.

---

## Tipi di evento previsti

### 1. Temporali (trigger: `EventBus.day_changed`)

- Raid di banditi su un villaggio → NPC muoiono, edifici danneggiati
- Carestia → prezzi dei venditori aumentano temporaneamente
- Festa cittadina → NPC con dialoghi speciali per N giorni
- Stagioni → cambio di bioma (futuro, molto lontano)
- Scadenza quest → già in Quest System

### 2. Di stato (trigger: segnali esistenti)

- NPC chiave muore → quest fallisce, mondo_flag settato, altri NPC reagiscono
- Fazione diventa `enemy_sworn` → guardie NPC diventano ostili nel loro territorio
- Boss di dungeon sconfitto → il dungeon cambia stato (più debole, riorganizzato)
- Quest completata → NPC cambiano dialogo, location cambia aspetto

### 3. Procedurali (trigger: `ProximityGenerator`)

- Evento casuale all'ingresso di una location (trappola, incontro, lore)
- Gruppo di banditi che accampa su una rotta commerciale
- Dungeon con un "evento speciale" al piano più profondo

### 4. Fazione-driven

- Guerra tra signorie → cambia `FactionReputation` globalmente, spawna nemici su certi tile
- Alleanza → certe porte si aprono, certe si chiudono
- Evento di fazione speciale per i membri (convocazione, missione urgente)

---

## Architettura ipotetica

```
EventScheduler (autoload)
  ├── _pending_events: Array[Dictionary]   # {event_id, trigger_day, params}
  ├── check_day_events(day_count)          # chiamato da EventBus.day_changed
  ├── trigger_event(event_id, params)      # dispatcha all'handler corretto
  └── register_event(event_id, day, params)

EventHandlers/ (handlers per tipo)
  ├── RaidHandler
  ├── FactionWarHandler
  ├── FestivalHandler
  └── ...
```

Gli eventi persistono in `WorldState.scheduled_events: Array[Dictionary]`.

---

## Questioni aperte (tutto da decidere)

- Quali eventi sono scriptati (definiti in JSON) vs procedurali (generati a runtime)?
- Come si manifesta visivamente un evento (NPC con dialogo speciale? tile cambiato? notifica?)
- Gli eventi hanno una durata? Come vengono "spenti"?
- I eventi si accumulano o uno prevale sull'altro nella stessa location?
- Come si salva lo stato degli eventi attivi in `world.json`?

---

## Piano di lavoro

**Non pianificabile in dettaglio ora.** Verrà progettato dopo che:
1. Time System è stabile (trigger temporali)
2. NPC System è stabile (NPC con stati, morte, routine)
3. Quest System è espanso (on_fail, world_flags)
4. Overworld System è stabile (location, biomi)

A quel punto si aprirà una sessione di design dedicata per definire il primo tipo di evento da implementare (probabilmente: raid di banditi su villaggio, come il più narrativamente rilevante).

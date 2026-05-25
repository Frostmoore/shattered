# Piano: Travel System

**Stato**: Bozza — da raffinare dopo l'implementazione di Overworld System e Time System.

**Dipendenze**: Time System ✗, Overworld System ✗, Needs System ✗

---

## Cos'è

Il Travel System gestisce gli spostamenti tra location lontane in modo **astratto** (non tile-by-tile): viaggi via mare tra porti, viaggio rapido (fast travel) via terra tra location conosciute. Il movimento tile-by-tile sull'overworld è gestito dall'Overworld System — questo sistema copre solo i salti astratti.

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Viaggio via mare | Astratto: selezione porto → destinazione → giorni passano, risorse consumate |
| Fast travel via terra | Astratto: tra location conosciute; costo in giorni (distanza Manhattan × costo bioma medio) |
| Risorse | Placeholder per ora; hook per sistema bisogni futuro |
| Mount | Moltiplicatore velocità (0.5 = metà giorni); architettura predisposta |
| UI | Popup di selezione destinazione su porto / da location visitata |

---

## Componenti

### 1. TravelService — `scripts/world/TravelService.gd`

Autoload o Node accessibile via `get_node_or_null("/root/TravelService")`.

```gdscript
# Restituisce lista di porti raggiungibili da un dato porto
func get_sea_routes(from_port_id: String) -> Array[String]

# Calcola i giorni di viaggio mare (configurato nei JSON porto)
func travel_days_sea(from: String, to: String) -> int

# Restituisce location conosciute raggiungibili via terra da posizione overworld
func get_land_destinations(from_pos: Vector2i) -> Array[Dictionary]
# → [{location_id, name, days, pos}]

# Calcola i giorni di viaggio terra (distanza × costo bioma medio sul percorso)
func travel_days_land(from_pos: Vector2i, to_pos: Vector2i) -> int

# Esegue il viaggio: avanza il tempo, consuma risorse, teletrasporta il player
func execute_travel(destination_id: String, days: int) -> void
```

### 2. TravelScreen — `scripts/ui/TravelScreen.gd`

CanvasLayer (layer=88). Si apre quando il player interagisce con un porto o attiva il fast travel da una location conosciuta.

Layout:
- Lista destinazioni a sinistra (scrollabile)
- Pannello dettaglio a destra: destinazione, giorni, costo risorse (placeholder)
- Bottone "Parti" — conferma e chiama `TravelService.execute_travel()`

### 3. Integrazione porti

Nel City Builder, l'entità `port` ha params:
```jsonc
{
  "kind": "port",
  "params": {
    "id": "porto_rivamola",
    "name": "Porto di Rivamola",
    "routes": [
      { "destination": "porto_nordest", "days": 3 },
      { "destination": "porto_sud",     "days": 7 }
    ]
  }
}
```

L'NPC porto (o l'entità porto stessa) triggera `TravelScreen.open_sea(port_id)` all'interazione.

### 4. Fast Travel via terra

Attivabile da una location conosciuta (villaggio / città / dungeon visitato). Il player interagisce con un NPC o un marker speciale e sceglie una destinazione già visitata. Costo calcolato da `TravelService.travel_days_land()`.

---

## Flusso viaggio

```
1. Player interagisce con porto / marker fast travel
2. TravelScreen.open(destinations) — lista destinazioni con giorni e costo
3. Player seleziona destinazione → "Parti"
4. TravelService.execute_travel(destination_id, days):
   a. TimeManager.advance(days * 1440)   ← tempo avanza
   b. _consume_resources(days)           ← placeholder (no-op per ora)
   c. WorldManager.change_map(destination_id, spawn_pos)  ← teletrasporto
5. Notifica "Arrivato a {nome} dopo {days} giorno/i"
```

### Moltiplicatore mount

```gdscript
func execute_travel(destination_id: String, days: int) -> void:
    var actual_days: int = ceili(days * _get_speed_multiplier())
    # NeedsManager.tick() viene chiamato automaticamente dentro TimeManager.advance()
    TimeManager.advance(actual_days * 1440)
    # → fame/sete/fatica calano proporzionalmente ai giorni di viaggio
    ...

func _get_speed_multiplier() -> float:
    # Placeholder: 1.0; con mount → 0.5
    return 1.0
```

---

## Integrazione con Overworld System

- Il viaggio terra NON richiede che il player cammini effettivamente sull'overworld tile-by-tile — è un'astrazione.
- Le destinazioni disponibili sono quelle in `WorldData.spawned_locations` già visitate.
- "Visitata" = location in cui il player è entrato almeno una volta (tracciata in `GameState.visited_locations: Array[String]`).

---

## Questioni aperte (deferred)

- **Sistema bisogni**: `_consume_resources(days)` è un no-op finché il sistema bisogni non esiste. L'hook è già previsto.
- **Rischio durante viaggio**: incontri casuali durante il fast travel? Per ora no. Future: "Durante il viaggio vieni attaccato da banditi" (evento background).
- **Costo oro del viaggio**: i viaggi via mare hanno un costo fisso? Da decidere quando il sistema economico NPC sarà più maturo.
- **Rotte land dinamiche**: per ora le destinazioni terra sono tutte le location visitate. In futuro si può restringere a quelle raggiungibili via strade (compagnia_ponti).

---

## Lista task

- [ ] `GameState.visited_locations: Array[String]` — aggiornato da `WorldManager.change_map()`
- [ ] `scripts/world/TravelService.gd` — autoload o singleton
  - [ ] `get_sea_routes(port_id)`
  - [ ] `get_land_destinations(from_pos)`
  - [ ] `travel_days_land(from, to)` — distanza Manhattan × costo bioma medio
  - [ ] `execute_travel(destination_id, days)` — avanza tempo + change_map
  - [ ] `_get_speed_multiplier()` — placeholder 1.0
  - [ ] `_consume_resources(days)` — placeholder no-op
- [ ] `scripts/ui/TravelScreen.gd` — CanvasLayer layer=88
  - [ ] `open_sea(port_id)` — lista rotte porto
  - [ ] `open_land(from_pos)` — lista location visitate raggiungibili
  - [ ] Pannello dettaglio + bottone "Parti"
- [ ] `EventBus.travel_started(destination, days)` / `travel_completed(location_id)`
- [ ] Porto NPC / entità: `interact()` → `TravelScreen.open_sea(port_id)`
- [ ] Notifica arrivo: `NOTIF_TRAVEL_ARRIVED` in `strings_notifications.csv`

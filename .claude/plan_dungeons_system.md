# Piano: Dungeons System

**Stato**: Da implementare — refactor del sistema dungeon esistente + supporto multi-dungeon.  
**Dipendenze**: WorldSaveManager ✓, LocationRegistry ✓, FloorGenerator ✓, CampingSystem (usa dungeon_id).

---

## Obiettivo

Trasformare il sistema dungeon da "un solo dungeon fisso `dungeon_01`" a un sistema che supporta **più dungeon per mondo**, ognuno con un **ID univoco**, salvato e persistito correttamente nel mondo. Ogni dungeon ha tema, difficoltà e numero di floor variabili.

---

## Stato attuale (da refactorare)

| Aspetto | Stato |
|---------|-------|
| Numero dungeon per mondo | 1 (hardcoded `dungeon_01`) |
| ID dungeon | Stringa fissa `"dungeon_01"` in WorldSaveManager.gd:18 |
| Posizione overworld | Hardcoded `Vector2i(18, 14)` |
| Floor ID | `dungeon_01_floor_N` (formato corretto, da mantenere) |
| Persistenza floor | MapData serializzata in world.json (OK, da mantenere) |
| LocationState per floor | Già implementato (OK, da mantenere) |
| Boss tracking | `GameState.world_flags["dungeon_boss_defeated"]` — un solo flag, non per dungeon |

---

## Formato ID dungeon

Il formato corrente `dungeon_01_floor_N` va bene. Si estende a:

```
{dungeon_id}_floor_{N}

dungeon_id = "{tipo}_{indice:02d}"
```

Esempi:
- `cave_01`, `cave_01_floor_1` … `cave_01_floor_5`
- `ruin_02`, `ruin_02_floor_1` … `ruin_02_floor_3`
- `crypt_01`, `crypt_01_floor_1` … `crypt_01_floor_7`

**Estrazione dungeon_id da floor_id** (usata dal CampingSystem):
```gdscript
static func get_dungeon_id_from_floor(floor_id: String) -> String:
    var parts: PackedStringArray = floor_id.split("_floor_")
    return parts[0] if parts.size() > 1 else floor_id
```

---

## Tipi di dungeon

| Tipo | Tema | Floor range | Difficoltà | Bioma preferito |
|------|------|-------------|------------|-----------------|
| `cave` | Grotta naturale | 3–5 | Bassa | Foresta, Pianura |
| `ruin` | Rovine antiche | 3–6 | Media | Qualsiasi |
| `crypt` | Cripta/tomba | 5–8 | Media-Alta | Palude, Neve |
| `dungeon` | Dungeon classico | 6–10 | Alta | Qualsiasi |
| `tower` | Torre del mago | 4–7 | Alta | Qualsiasi |
| `lair` | Tana del boss | 2–3 | Molto Alta | Montagna, Deserto |

Ogni tipo ha parametri di generazione diversi (densità nemici, tipo nemici, reward).

---

## Struttura dati dungeon

### In world.json (WorldSaveManager)

```json
{
  "meta": { ... },
  "dungeons": [
    {
      "id": "cave_01",
      "type": "cave",
      "floor_count": 4,
      "seed": 12345678,
      "overworld_tile": {"x": 18, "y": 14},
      "overworld_return_tile": {"x": 17, "y": 14},
      "danger_rating": 1.2,
      "enemy_balance": { ... },
      "boss_defeated": false
    },
    {
      "id": "ruin_02",
      "type": "ruin",
      ...
    }
  ],
  "locations": { ... }
}
```

### In GameState.gd

```gdscript
# Rimpiazza world_flags["dungeon_boss_defeated"]
var dungeon_bosses_defeated: Dictionary = {}  # dungeon_id → bool
```

### In WorldState.gd

Nessuna modifica necessaria — `dungeon_archive` già esiste per dati Corporazione Camere.

---

## Numero di dungeon per mondo

Generato proceduralmente in `WorldSaveManager.generate_new_world()` in base al seed:

```gdscript
var dungeon_count: int = meta_rng.randi_range(2, 4)  # 2–4 dungeon per mondo
```

Ogni dungeon viene piazzato su una tile overworld vuota, non troppo vicina alle città e non sovrapposta ad altri dungeon. Le posizioni vengono registrate in `OverworldGenerator` o passate come parametri.

---

## Modifiche ai sistemi esistenti

### WorldSaveManager.gd

- Rimuovere `var dungeon_id: String = "dungeon_01"` hardcoded
- Aggiungere `_generate_all_dungeons(seed, meta_rng, player_level)` che:
  1. Decide numero e tipo di dungeon
  2. Per ognuno chiama `_generate_dungeon_floors()` con il proprio ID e seed
  3. Piazza le entrate overworld in posizioni valide
  4. Serializza tutto in `"dungeons"` array in world.json
- `load_world()`: deserializza `"dungeons"` array e registra tutti i floor come prebuilt

### OverworldGenerator.gd

- Attualmente piazza l'entrata dungeon in posizione hardcoded
- Dovrà ricevere lista di `dungeon_positions: Array[Vector2i]` e piazzare un tile `dungeon_entrance` per ognuna
- Ogni tile entrance porta dati `{target_id: "cave_01_floor_1", ...}`

### LocationRegistry.gd

- Nessuna modifica strutturale — già gestisce ID arbitrari
- Aggiungere helper `get_all_dungeon_ids() -> Array[String]` per iterare i dungeon

### GameState.gd

```gdscript
# Aggiungere:
var dungeon_bosses_defeated: Dictionary = {}  # dungeon_id → bool

# Rimuovere da world_flags:
# "dungeon_boss_defeated": false  ← rimpiazzato dal dict sopra
```

### SaveManager.gd

```gdscript
# Aggiungere al save:
"dungeon_bosses_defeated": GameState.dungeon_bosses_defeated.duplicate(),

# Al load:
GameState.dungeon_bosses_defeated = data.get("dungeon_bosses_defeated", {})
```

### BaseMap.gd

- `_spawn_entity()` per boss: controllare `GameState.dungeon_bosses_defeated[dungeon_id]` invece di `world_flags["dungeon_boss_defeated"]`
- Quando boss muore: settare `GameState.dungeon_bosses_defeated[dungeon_id] = true`

### CampingSystem (plan_camping_system.md)

```gdscript
# Estrae dungeon_id da current_map_id
static func _get_dungeon_id() -> String:
    return GameState.current_map_id.split("_floor_")[0]
```

---

## Generazione posizioni overworld

Le entrate dungeon devono:
1. Non sovrapporsi a città, villaggi, o altri dungeon
2. Non essere adiacenti tra loro (distanza minima 5 tile)
3. Trovarsi su tile camminabili (non acqua, non montagna invalicabile)
4. Preferibilmente in zone con bioma tematicamente coerente

```gdscript
func _pick_dungeon_positions(rng: RandomNumberGenerator, count: int,
        forbidden: Array[Vector2i]) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    var attempts: int = 0
    while result.size() < count and attempts < 200:
        var pos: Vector2i = Vector2i(rng.randi_range(5, MAP_WIDTH - 5),
                                     rng.randi_range(5, MAP_HEIGHT - 5))
        if _is_valid_dungeon_pos(pos, forbidden + result):
            result.append(pos)
        attempts += 1
    return result
```

---

## Respawn nemici per dungeon

**Attuale**: `LocationRegistry.respawn_non_boss_enemies_in_unloaded_floors(current_map_id)` — già funziona per floor_id.

**Da aggiornare**: assicurarsi che il boss non venga resettato se `dungeon_bosses_defeated[dungeon_id] = true`, anche dopo respawn. Attualmente usa `is_boss` flag su nemico — da verificare che sia robusto.

---

## Questioni aperte

- **Temi nemici per tipo dungeon**: ogni tipo ha una lista di enemy_id preferiti? O si usa il bioma dell'overworld circostante?
- **Reward tematici**: crypt → oggetti non-morti, cave → minerali, tower → pergamene magiche?
- **Dungeon visibili dalla mappa**: la UI mostra i dungeon disponibili nell'area?
- **Dungeon scoperti vs non scoperti**: il player deve "scoprire" un'entrata prima di potervi entrare?
- **Livello minimo consigliato**: ogni dungeon mostra un livello consigliato al player?
- **Dungeon unici (named)**: alcuni dungeon hanno nome proprio e storia (es. "La Cripta di Morvain")?

---

## Lista task

### Fase 1 — ID e struttura dati
- [ ] Aggiungere `dungeon_bosses_defeated: Dictionary` a `GameState.gd`
- [ ] Rimuovere `world_flags["dungeon_boss_defeated"]` e aggiornare tutti i riferimenti
- [ ] Aggiungere helper `DungeonUtils.get_dungeon_id_from_floor(floor_id)` (usato da CampingSystem e BaseMap)
- [ ] Aggiornare `SaveManager.gd` save/load per `dungeon_bosses_defeated`

### Fase 2 — Multi-dungeon generation
- [ ] Parametrizzare `WorldSaveManager._generate_dungeon_floors()` per accettare tipo dungeon e posizione overworld
- [ ] Implementare `_generate_all_dungeons()` con conteggio procedurale (2–4 per mondo)
- [ ] Implementare `_pick_dungeon_positions()` con validazione posizioni
- [ ] Aggiornare `OverworldGenerator` per piazzare tile entrance per ogni dungeon
- [ ] Aggiornare world.json schema con array `"dungeons"`
- [ ] Aggiornare `load_world()` per deserializzare array multi-dungeon

### Fase 3 — Tipi dungeon
- [ ] Definire parametri per ogni tipo (cave, ruin, crypt, dungeon, tower, lair) in GameBalance o JSON
- [ ] Aggiornare `FloorGenerator` per accettare tipo dungeon e variare la generazione
- [ ] Definire pool nemici per tipo dungeon

### Fase 4 — Integrazione sistemi
- [ ] Aggiornare boss death handler in `Enemy.gd` / `BaseMap.gd`
- [ ] Collegare CampingSystem al nuovo `get_dungeon_id_from_floor()`
- [ ] Aggiornare eventuali quest che referenziano `world_flags["dungeon_boss_defeated"]`

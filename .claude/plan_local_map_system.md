# Piano: Local Map System (Mappe Locali)

**Stato**: Bozza — da implementare dopo Overworld System (che espone biomi e tile events).

**Dipendenze**: Overworld System (trigger spawn e tile tipo), Time System ✓, Enemy System ✓, Loot System ✓

---

## Obiettivo

Generare piccole mappe procedurali contestuali quando il player:
1. **Entra in un'area visibile** sull'overworld (accampamento bandit, tana, rovine)
2. **Subisce un incontro casuale** durante il viaggio (imboscata, pattuglia, creatura)

Queste mappe usano la stessa infrastruttura di `BaseMap` / `MapData` / `LocationRegistry` ma hanno ciclo di vita e generazione propri.

---

## Tipi di mappa locale

| Tipo | ID pattern | Dimensione | Contenuto | Visibile sull'overworld |
|------|-----------|-----------|-----------|------------------------|
| `clearing` | `enc_clearing_<seed>` | 20×15 | 1–3 nemici, loot sparso | No — incontro casuale |
| `bandit_camp` | `enc_camp_<x>_<y>` | 30×20 | Tende/fuoco, 4–8 bandit + leader | Sì — tile `C` |
| `creature_lair` | `enc_lair_<x>_<y>` | 25×18 | Grotta, 3–6 bestie/non-morti | Sì — tile `L` |
| `caravan_ruins` | `enc_ruins_<x>_<y>` | 20×12 | Pochi o nessun nemico, loot abbondante | Sì — tile `R` |
| `wilderness_camp` | `enc_wcamp_<x>_<y>` | 15×10 | Save point temporaneo (Camping System) | No — piazzato dal player |

---

## Persistenza

| Tipo | Persistenza | Logica |
|------|------------|--------|
| Incontri casuali (`clearing`) | **Non persistente** — esiste solo per la durata dell'incontro; non salvato in LocationRegistry | Dopo l'uscita viene scartato |
| Aree visibili sull'overworld (camp, lair, ruins) | **Persistente** — registrata in LocationRegistry con ID stabile `enc_<tipo>_<x>_<y>` | Rimane fino alla fine della partita; nemici morti restano morti (LocationState) |
| Accampamento player (`wilderness_camp`) | **Temporaneo** — persiste finché il player non parte; può essere rimontato | Scartato quando il player lascia l'overworld tile |

---

## Trigger sull'overworld

### Aree visibili (Fase 1)
Tile speciali dell'overworld mostrano un glyph:
- `C` (arancio scuro) — bandit_camp
- `L` (rosso scuro) — creature_lair
- `R` (grigio chiaro) — caravan_ruins

Il player ci si muove sopra e preme Interazione → transizione nella mappa locale (come per villaggi/dungeon).

Spawn di queste tile: `WorldSaveManager.generate_new_world()` le piazza proceduralmente in base a bioma e seed. Ogni area ha coordinate overworld fisse per la durata del world.

### Incontri casuali (Fase 2)
Durante ogni movimento overworld, c'è una chance di incontro (dipende da bioma e ora del giorno):

```gdscript
# In Player._try_move() dopo move_to() su overworld:
if _should_trigger_encounter():
    var enc_id: String = "enc_clearing_" + str(randi())
    WorldManager.change_map(enc_id, Vector2i(10, 7))  # spawn centrato
```

`_should_trigger_encounter()`:
- Base chance: 5% per tile
- Modificatori: bioma (foresta 10%, strada 2%), ora (notte +5%), fazione attiva (fuorilegge +3%)
- Cooldown: mai due volte di fila sullo stesso tile

---

## Generatore — `EncounterGenerator.gd`

`scripts/world/generators/EncounterGenerator.gd`

```gdscript
static func generate(type: String, rng: RandomNumberGenerator,
        player_level: int, params: Dictionary) -> MapData:
    match type:
        "clearing":      return _gen_clearing(rng, player_level, params)
        "bandit_camp":   return _gen_camp(rng, player_level, params)
        "creature_lair": return _gen_lair(rng, player_level, params)
        "caravan_ruins": return _gen_ruins(rng, player_level, params)
    push_error("EncounterGenerator: tipo sconosciuto: " + type)
    return MapData.new()
```

### Struttura comune a tutti i tipi

- `map_type = "encounter"` — nuovo tipo mappa (aggiunto a BaseMap e MapRenderer)
- Almeno una `transition` verso overworld (uscita)
- Spawn player vicino all'uscita (lato sud o est)
- Nessun save point (eccetto `wilderness_camp`)
- `MapData.metadata["encounter_type"] = type`
- `MapData.metadata["overworld_pos"] = Vector2i(x, y)` — per aree persistenti

### Rendering `encounter`

`MapRenderer._get_theme("encounter")`: stessa palette di `dungeon` ma con floor_char variabile per tipo (`"·"` clearing, `"."` lair, `","` camp).

Visibilità entità: **sempre visibili di giorno** (come village), **FOV di notte** (come village).

---

## Integrazione LocationRegistry

```gdscript
# In LocationRegistry.get_or_generate(map_id):
if map_id.begins_with("enc_"):
    var parts = map_id.split("_")
    var type  = parts[1]           # "clearing", "camp", "lair", "ruins", "wcamp"
    var rng   = RandomNumberGenerator.new()
    rng.seed  = map_id.hash()
    var data  = EncounterGenerator.generate(type, rng, GameState.level, {})
    data.id   = map_id
    return data
```

Gli incontri non-persistenti (`clearing`) non vengono mai salvati su disco: la `LocationState` viene scartata quando il player esce. La `LocationRegistry` non tiene `definition` per questi ID — li rigenera ogni volta (uguale al seed).

Le aree persistenti (`camp`, `lair`, `ruins`) vengono salvate in `LocationRegistry` come qualsiasi altra mappa: `LocationState` registra i nemici morti e il loot prelevato.

---

## Uscita dalla mappa locale

Ogni mappa locale ha una o più transizioni di tipo `"overworld"`:

```gdscript
data.add_transition({
    "position":        exit_tile,
    "target_id":       "overworld",
    "target_type":     "overworld",
    "target_position": params.get("overworld_pos", Vector2i(5, 5)),
    "stair_type":      "up"
})
```

Il player usa la transizione come una qualsiasi scala — esce sul tile overworld di origine.

Per gli incontri casuali che iniziano "nel mezzo" del combattimento: il player può uscire dalla transizione anche durante il combat (come in un dungeon — `WorldManager.change_map` non è bloccato dal TurnManager).

---

## Tempo

- Entrare in un'area locale costa `TimeManager.advance(15)` — 15 minuti (breve esplorazione in loco)
- Il tempo avanza normalmente durante l'esplorazione (3 min/tile, come dungeon)
- Un incontro casuale breve (3–4 turni) costa ~30–40 minuti totali
- Per aree grandi (camp, lair): costo proporzionale alle tile attraversate

---

## Nemici nelle mappe locali

I nemici sono definiti in `entity_defs` di `MapData` con `kind = "enemy"` come per i dungeon. `EncounterGenerator` usa `EnemyRegistry` + i biomi/fazione per scegliere il pool appropriato:

- `clearing`: nemici generici del bioma (bestie o fuorilegge)
- `bandit_camp`: `faction_id = "fuorilegge"`, famiglia `humanoid`
- `creature_lair`: familia `beast` o `undead` in base al bioma
- `caravan_ruins`: facoltativi (1–2 predatori o nessuno)

Il livello dei nemici segue la stessa formula del dungeon: `clamp(GameState.level + bioma_bonus, zone_min, zone_max)`.

---

## Loot

Stesso meccanismo del dungeon: `LootResolver.resolve(ctx)` con `source_type = "ground"` o `"chest"` per casse/sacchi. Il `EncounterGenerator` piazza entity `"item"` o `"chest"` con il profilo loot appropriato.

---

## EventBus — nuovi segnali

```gdscript
encounter_triggered(enc_type: String)   # quando si entra in un incontro casuale
encounter_cleared(enc_type: String)     # quando tutti i nemici sono morti e il player esce
```

---

## Integrazione con sistemi futuri

| Sistema | Hook |
|---------|------|
| **Overworld System** | Espone bioma del tile → EncounterGenerator usa bioma per pool nemici e chance incontro |
| **Camping System** | Usa `wilderness_camp` come mappa locale temporanea con save point |
| **Travel System** | Incontri casuali durante viaggio fast-travel → `clearing` obbligatorio prima di arrivare |
| **Needs System** | Clearing/camp possono contenere cibo/acqua come loot ground |

---

## Questioni aperte (da decidere all'implementazione)

- **Glyph overworld per camp/lair**: `C`, `L`, `R` o qualcosa di più evocativo?
- **Quante aree persistenti per mondo?**: 3–5 camp + 2–3 lair + 1–2 ruins sembra ragionevole
- **Incontri nel dungeon**: i dungeon hanno già i nemici nelle stanze — gli incontri casuali esistono solo sull'overworld?
- **Ricompensa clearing**: solo loot, o anche XP/rep per aver "ripulito" un'area?
- **Leader del campo**: il leader bandit è sempre un nemico elite o boss mini?
- **Cooldown incontri**: dopo aver liberato un camp, il tile overworld cambia glyph o sparisce?

---

## Lista task

### FASE 1 — Aree visibili sull'overworld

- [ ] Aggiungere `map_type = "encounter"` a `BaseMap` e `MapRenderer._get_theme()`
- [ ] `EncounterGenerator.gd`: schema base + generatori `bandit_camp`, `creature_lair`, `caravan_ruins`
- [ ] `LocationRegistry.get_or_generate()`: riconoscere prefisso `enc_` e chiamare `EncounterGenerator`
- [ ] `WorldSaveManager.generate_new_world()`: spawn di 3–5 aree persistenti con coordinate fisse
- [ ] `MapRenderer`: glyph `C`/`L`/`R` sull'overworld per le aree
- [ ] `OverworldMap`: transizioni verso le aree locali (come village_01 → overworld)
- [ ] Verifica: entrare in un camp → combattere → uscire → camp è svuotato (LocationState)

### FASE 2 — Incontri casuali

- [ ] `Player._try_move()` overworld: chiamare `_should_trigger_encounter()` dopo ogni move
- [ ] `EncounterGenerator.generate("clearing", ...)`: mappa piccola con 1–3 nemici
- [ ] Incontri non-persistenti: skip della serializzazione in `LocationRegistry`
- [ ] `EventBus.encounter_triggered` / `encounter_cleared`
- [ ] Verifica: trigger casuale → clearing → kill → exit → back to overworld

### FASE 3 — Bilanciamento e integrazione

- [ ] Chance incontro modulata per bioma (dipende da Overworld System)
- [ ] Pool nemici per bioma (dipende da Overworld System)
- [ ] Cooldown incontri (flag su tile o su timer)
- [ ] `encounter_cleared`: aggiorna il glyph overworld se area persistente è pulita

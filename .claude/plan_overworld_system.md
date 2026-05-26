# Piano: Sistema Overworld

**Stato**: Design in corso — domande aperte ancora da risolvere prima di implementare.

---

## Requisiti confermati

- Dimensioni: **5000×5000 tile**
- Generazione: procedurale da seed, deterministica (stesso seed = stesso mondo)
- Il mondo viene creato una volta; i personaggi ci camminano dentro
- Tile-by-tile movement, consuma cibo e acqua
- ASCII tile-based (poi grafica pixel)
- Biomi: pianura, foresta, montagna, deserto, palude
- Villaggi: spawnano in tutti i biomi
- Dungeon: spawnano ovunque, preferenza bordo montagna, rovine, bordo foreste impenetrabili
- Location generate on-demand entro raggio 15 tile dal player, poi persistenti
- Il player inizia sempre nello stesso villaggio (garantito vicino al centro/spawn)
- Nebbia di guerra: senso — la mappa è troppo grande per vederla tutta
- FOV/scoperta: dungeon e rovine appaiono solo quando il player è nel raggio 15

---

## Domande aperte

Nessuna — tutte risolte.

## Decisioni di design

**A. Viewport**: stessa del dungeon, player al centro.

**B. Città manuali nel mondo procedurale**
Ogni city JSON ha una proprietà `biome_tags` (es. `["mountain"]`, `["plains", "forest"]`).
`ProximityGenerator` determina il bioma del tile candidato, poi pesca una città compatibile
da `data/cities/` che non sia già stata piazzata nel mondo.
Il layout è fatto a mano col City Builder; la posizione nel mondo è procedurale.

**C. Salvataggio mondo**: il mondo è già separato dal personaggio nel sistema di save esistente.
WorldData seguirà lo stesso pattern — persiste tra una morte e l'altra.

---

## Architettura prevista

### WorldData (nuova classe)
- Array piatto di biomi: `biome_map: PackedByteArray` — 1 byte/tile, 1000×1000 = 1 MB
- `spawned_locations: Dictionary` — `Vector2i → location_id` (location già generate e registrate)
- `explored_tiles: PackedByteArray` — nebbia di guerra (1 bit/tile o 1 byte/tile)
- Separato da `MapData` — non usa walls array, struttura completamente diversa

### WorldGenerator
- Usa `FastNoiseLite` (Godot 4 built-in) per elevation + moisture → biome
- Elevation alta → montagna; bassa + umidità alta → palude; bassa + secca → deserto; media → pianura/foresta
- Piazza il villaggio iniziale: cerca una pianura valida vicino al centro della mappa
- Gira una volta sola alla creazione del mondo, risultato salvato in WorldData

### ProximityGenerator
- Chiamato ogni volta che il player si sposta sull'overworld
- Per ogni tile nel raggio 15 non ancora esplorato per location:
  - `hash(world_seed + x * 7919 + y * 6271)` → decide se c'è una location e di che tipo
  - Applica biome rules (vedi sotto)
  - Se positivo e non ancora in `spawned_locations`: genera, registra in LocationRegistry, segna in WorldData
- Deterministico: stessa posizione = stessa location, sempre

### Biome rules per dungeon spawn
```
montagna (bordo):    peso alto  → dungeon standard, dungeon nani
pianura:             peso basso → rovine, accampamenti bandit
foresta (bordo):     peso medio → rovine elfiche, dungeon natura
palude:              peso medio → rovine, cripte
deserto:             peso basso → rovine antiche, tombe
```

### OverworldController (aggiornamento OverworldGenerator esistente)
- Genera una MapData "finestra" centrata sul player — solo i tile visibili nella viewport
- I tile fuori viewport non esistono come MapData; vengono rigenerati on-the-fly dal WorldData
- Le transizioni verso dungeon/villaggi esistono solo dove WorldData dice che c'è una location

---

## Integrazione col resto del gioco

- **LocationRegistry**: riceve le location via ProximityGenerator con `register()` normale
- **CityGenerator**: già funzionante — legge JSON da `data/cities/`
- **Salvataggi**: WorldData serializzato nel save file (o file separato `data/world.json`)
- **Manifest città manuali**: da decidere con domanda B

---

## Piano di lavoro dettagliato

---

### Fase 0 — City Builder: biome_tags
*Prerequisito per tutto il resto. Senza biome_tags il ProximityGenerator non sa dove piazzare le città.*

- Aggiungere `biome_tags: Array[String]` al formato JSON delle città
- Aggiungere UI nel plugin: checkboxes o campo CSV per `plains / forest / mountain / desert / swamp / coast`
- Aggiungere tipo entità **porto** (`port`) al City Builder — spawnabile solo su città costiere
- Aggiungere `biome_tags` alla logica save/load del plugin
- CityGenerator: leggere e propagare `biome_tags` nei metadata del MapData

**Decisione:** il villaggio iniziale è una città fissa creata col City Builder (`village_start` o nome simile). WorldGenerator la piazza sempre in una plains vicino al centro. È l'ancora narrativa del gioco — da lì partono le quest principali.

---

### Fase 1 — WorldData
*La struttura dati che rappresenta il mondo. Nessuna logica, solo storage.*

- `world_seed: int`
- `width: int`, `height: int`
- `biome_map: PackedByteArray` — flat array `[y * width + x]`, 1 byte = bioma
- `spawned_locations: Dictionary` — `Vector2i → location_id` (location già generate)
- `explored_tiles: PackedByteArray` — nebbia di guerra, 1 byte/tile (0 = inesplorato, 1 = visto)
- `player_start: Vector2i` — posizione del villaggio iniziale
- `serialize()` / `from_dict()` — integrazione col save system esistente

**Decisioni:**
- `explored_tiles` è **per-personaggio**, non per-mondo — ogni nuovo pg ricomincia con il mondo al buio. Vive nel save del personaggio, non in WorldData.
- WorldData (terreno + location generate) vive nel save del mondo, separato dal personaggio.
- Formato `explored_tiles`: **bitmask** (1 bit/tile) — a 5000×5000 = 25M tile, 1 byte/tile fa 25 MB per personaggio, inaccettabile. Bitmask = ~3 MB, gestibile.
- Raggio visibilità: **base 15 tile**, modificato da bioma/altitudine e dalla classe del personaggio:
  ```
  mountain_dense: +8    plains:  0 (base)    forest: -5
  mountain:       +5    desert: +3           swamp:  -5
  coast:           0
  ```
  Le classi avranno un modificatore dedicato (hook dal sistema classi → calcolo visibilità overworld).
- Tile scoperti restano visibili per sempre (per quel personaggio).
- **Minimappa**: HUD sovrapposto in alto a destra nella viewport overworld. Mostra l'area esplorata in formato ridotto con simboli bioma e location. Implementata come Control separato sopra la scena overworld.
- Scala temporale: **1 tile = 1 giorno di cammino**. Con mount: **1 tile = mezza giornata**.
- Le mount sono un sistema futuro ma l'architettura di movement deve già prevedere un moltiplicatore di velocità.

---

### Fase 2 — WorldGenerator
*Genera il biome_map da seed. Gira una volta sola alla creazione del mondo.*

- Due `FastNoiseLite`: **elevation** + **moisture**
- Lookup table elevation × moisture → bioma:
  ```
  elevation molto alta (picchi)         → mountain_dense  (impassabile)
  elevation alta (pendici)              → mountain        (passabile, costoso ~3 giorni/tile)
  elevation bassa + moisture alta       → swamp
  elevation bassa + moisture bassa      → desert
  elevation media + moisture alta       → forest
  elevation media + moisture bassa      → plains
  zone forest isolate ad alta densità   → dense_forest    (impassabile)
  elevation sotto livello mare          → sea             (impassabile a piedi)
  sea adiacente a terra                 → coast           (tag interno, spawn porti)
  ```
- Le montagne funzionano per densità: picchi isolati = passabili, cluster densi = impassabili.
  Il noise naturalmente crea pendici (mountain) intorno ai picchi (mountain_dense).
  Nessun tag artificiale "mountain_border" — emerge dalla soglia di elevation.
- Piazzamento villaggio iniziale: cerca cluster di `plains` vicino al centro, sceglie tile valido
- Output: `WorldData` con `biome_map` e `player_start` popolati

### Temperatura per bioma (integrazione Sistema Bisogni)

Ogni bioma ha un `temperature_target` — il valore di equilibrio verso cui si avvicina la temperatura del player — e un `approach_rate k` usati da `NeedsManager._get_temperature_target()` e `_get_approach_rate()`. Il modello è `lerpf(temperature, target, k * minutes)`: la temperatura si stabilizza, non cresce indefinitamente.

| Bioma | `temperature_target` | `k` (per minuto) | Note |
|-------|---------------------|-----------------:|------|
| `plains` | 0 | 0.007 | Temperatura neutra |
| `forest` | −5 | 0.006 | Leggermente più fresco (ombra) |
| `dense_forest` | −10 | 0.006 | Fresco e umido |
| `mountain` | −40 | 0.010 | Freddo d'alta quota |
| `mountain_dense` | −55 | 0.012 | Gelido — picchi impassabili |
| `desert` | +60 | 0.012 | Caldo intenso |
| `swamp` | +30 | 0.008 | Caldo afoso |
| `coast` | +10 | 0.007 | Mite |
| `sea` | −15 | 0.008 | Freddo marino (viaggio astratto) |

Range temperature: −100 (gelo assoluto) … +100 (ustionante). Soglie malattia: ipotermia ≤ −75, ipertermia ≥ +85.
Valori da bilanciare in Fase 10. Definiti come costanti in `WorldData.gd` o in `data/world/biome_defs.json`.

`NeedsManager` riceve il bioma corrente come `context["biome"]` — passato da `OverworldMap` / `WorldManager` tramite `TimeManager.advance()` ad ogni movimento overworld.

**Decisioni:**
- Mountain dense: impassabili. Mountain (pendici): passabili, costose (~3 giorni/tile).
- Dense forest: impassabili.
- Il mare esiste. I tile sea sono impassabili a piedi.
- **Viaggio via mare: astratto** — il player arriva a un porto, sceglie destinazione porto, paga risorse/giorni, arriva. Nessun movimento tile per tile in mare.
- **Quick travel: astratto** — stesso sistema, tra location conosciute (villaggi visitati, porti). Giorni passano, risorse consumate.
- Scala noise: da testare empiricamente in Fase 8.
- Dungeon sottomarini: non previsti per ora.

---

### Fase 3 — Rendering overworld
*Come appare al player. Stessa viewport del dungeon, player al centro.*

Mappa ASCII per bioma (riutilizzare simboli già in uso nel gioco dove possibile, aggiungere quelli mancanti, verificare colori con il sistema di rendering esistente in fase di implementazione):
```
plains        →  .   Color(0.55, 0.70, 0.35)   verde chiaro
forest        →  T   Color(0.13, 0.45, 0.13)   verde scuro
dense_forest  →  #   Color(0.08, 0.28, 0.08)   verde molto scuro (impassabile)
mountain      →  ^   Color(0.60, 0.60, 0.60)   grigio
mountain_dense→  ▲   Color(0.40, 0.40, 0.40)   grigio scuro (impassabile)
desert        →  ~   Color(0.85, 0.78, 0.40)   giallo sabbia
swamp         →  %   Color(0.30, 0.45, 0.20)   verde/marrone
sea           →  ~   Color(0.15, 0.35, 0.70)   blu
coast         →  .   Color(0.75, 0.75, 0.45)   sabbia chiara
villaggio     →  V   Color(1.00, 1.00, 0.80)   bianco caldo
città         →  C   Color(1.00, 1.00, 1.00)   bianco
dungeon       →  D   Color(0.80, 0.20, 0.20)   rosso
rovina        →  R   Color(0.75, 0.55, 0.25)   arancione/marrone
porto         →  P   Color(0.30, 0.70, 1.00)   azzurro
player        →  @   Color(1.00, 1.00, 1.00)   bianco brillante
tile inesplorato → spazio o · Color(0.10,0.10,0.10) quasi nero
```

**Decisioni:**
- Le location appaiono sulla mappa **appena generate** (raggio 15) — coincide con il raggio di visibilità. Il player le vede in lontananza mentre si avvicina.
- Tile esplorati ma fuori viewport attuale: mostrati con colore dimezzato (memoria).
- Tile mai esplorati: neri / vuoti.
- Simboli definitivi scelti in implementazione verificando quelli già usati nel rendering esistente.

---

### Fase 4 — Movement overworld
*Come il player si muove e cosa consuma.*

- Stessa logica input del dungeon, ma sull'overworld
- Ogni step consuma risorse (integrazione con sistema bisogni futuro — per ora solo placeholder)
- **Costi di movimento per bioma** (turni per tile):
  ```
  plains:          1 turno
  forest:          2 turni
  mountain_border: 3 turni
  desert:          2 turni
  swamp:           2 turni
  mountain:        impassabile (o 5+ turni — da decidere)
  dense_forest:    impassabile
  ```
- Camminare su un tile con location attiva → trigger transizione (come nel dungeon)

**Decisioni:**
- Sistema bisogni: **placeholder** per ora. Il movimento funziona, il consumo di risorse è disabilitato. Il sistema bisogni arriverà come feature separata con impatto su overworld, dungeon e villaggi.
- L'architettura del movement deve già prevedere un moltiplicatore di velocità (per mount) e un hook per il consumo risorse (per il sistema bisogni futuro).

---

### Fase 5 — ProximityGenerator
*Il cuore del sistema. Genera location on-demand nel raggio 15 dal player.*

Algoritmo per ogni tile `(x, y)` nel raggio 15 non ancora controllato:
```
1. base_chance = hash(world_seed, x, y) % 1000
2. biome = WorldData.biome_map[y * width + x]
3. spawn_table = BIOME_SPAWN_RULES[biome]  → lista di (tipo, peso, soglia)
4. Se base_chance < soglia → candidato per quella location
5. Check distanza minima da altre location (es. no dungeon a meno di 8 tile)
6. Genera location:
   - villaggio → pesca da data/cities/ con biome_tags compatibile non ancora usata
   - dungeon   → DungeonGenerator.generate() con params da bioma
   - rovina    → BuildingGenerator (o nuovo RuinGenerator)
7. LocationRegistry.register(id, type, params)
8. WorldData.spawned_locations[pos] = id
```

Spawn rules per bioma (valori di esempio, da bilanciare):
```
plains:          villaggio 3%, dungeon 1%, rovina 1%
forest:          villaggio 2%, dungeon 2%, rovina 2%
mountain_border: villaggio 1%, dungeon 5%, rovina 3%
desert:          villaggio 1%, dungeon 2%, rovina 4%
swamp:           villaggio 1%, dungeon 3%, rovina 2%
```

**Decisioni:**
- Villaggi e città: **solo quelli fatti a mano** col City Builder. Nessun fallback procedurale. Il mondo ha un numero finito di insediamenti — esauriti quelli, in quel bioma non ne spawnano altri.
- **Rovine**: dungeon a **singolo piano**, generati proceduralmente. Possono contenere scale che portano a un villaggio sotterraneo/nascosto (opzionale, definito nei params al momento della generazione). Usano DungeonGenerator con `floors: 1` e un flag `surface_ruin: true`.

**Decisioni:**
- Distanza minima dungeon/rovine: **5 tile** tra l'una e l'altra.
- Distanza minima villaggi/città: **100 tile** tra l'uno e l'altro.

---

### Fase 6 — Nebbia di guerra
*I tile vengono scoperti man mano che il player li esplora.*

- `explored_tiles` in WorldData: aggiornato ogni volta che il player si muove
- Raggio di visibilità sull'overworld: da definire (5 tile? 10 tile? dipende dal bioma?)
- Tile esplorati ma non visibili al frame corrente: mostrati in grigio scuro (memoria)
- Tile mai visti: neri o carattere neutro

**Questioni aperte:**
- Il raggio di visibilità sull'overworld è fisso o dipende dalla posizione (montagna vede lontano, foresta vede poco)?
- La nebbia di guerra è per-personaggio o per-mondo? (Se muori, il nuovo personaggio vede il mondo già esplorato dal precedente?)

---

### Fase 7 — Save/load integration
*WorldData entra nel sistema di salvataggio esistente.*

- `WorldData.serialize()` → integrazione con `SaveManager` / `GameState` esistente
- WorldData salvato separatamente dal personaggio (file `world.sav` o slot dedicato)
- Al caricamento: `WorldData.from_dict()` → rigenera LocationRegistry + ProximityGenerator state

---

### Fase 8 — Balance e polish
*Dopo che tutto funziona, bilanciare la distribuzione.*

- Tuning density spawn (percentuali Fase 5)
- Tuning noise scale (Fase 2) per biomi visivamente credibili
- Garantire che il raggio iniziale intorno allo spawn abbia almeno 1 dungeon e 1 altra location
- Test con seed diversi
- Simboli ASCII / colori definitivi

---

## Decisioni architetturali

- **WorldData a runtime**: vive come campo `world_data: WorldData` in `WorldSaveManager` (già autoload, già responsabile del save mondo). Nessun nuovo autoload necessario. Accesso: `WorldSaveManager.world_data`.
- **explored_tiles**: `PackedByteArray` bitmask in `GameState` (per-personaggio). Salvato nel file personaggio, non in WorldData né in LocationState.
- **OverworldMap**: va riprogettato per leggere `WorldData` direttamente invece di ricevere un `MapData`. L'approccio MapData non scala a 5000×5000.
- **OverworldGenerator**: da rimuovere/svuotare. Sostituito da `WorldGenerator` + rendering da `WorldData`.
- **MapRenderer**: esteso con percorso `type == "overworld"` per biomi, fog of war variabile, minimap.

---

## Dipendenze

- **Sistema bisogni** (cibo/acqua): placeholder in Fase 4, implementazione futura separata
- **Sistema bisogni — temperatura**: ogni bioma espone `temperature_target` e `approach_rate k` (tabella in Fase 2 WorldGenerator). `NeedsManager` li legge da `context["biome"]` passato via `TimeManager.advance()` durante il movimento overworld.
- **City Builder plugin**: già funzionante; va esteso in Fase 0 con biome_tags e porto
- **LocationRegistry**: già funzionante, nessuna modifica necessaria
- **CityGenerator**: già funzionante, nessuna modifica necessaria

---

## Tracking implementazione

### Fase 0 — City Builder: biome_tags + porto
- [ ] Aggiungere campo `biome_tags: Array` al formato JSON città
- [ ] Aggiungere UI biome_tags nel plugin (checkboxes: plains / forest / mountain / desert / swamp / coast)
- [ ] Aggiornare save/load JSON del plugin per biome_tags
- [ ] Aggiungere tipo entità `port` al City Builder
  - [ ] Aggiungere `"port"` a `ENT_CHARS` e `ENT_COLS`
  - [ ] Aggiungere `"port"` a `TOOL_DEFS` con tool dedicato
  - [ ] Aggiungere params default porto in `_default_params()` (id, name, dialogue_id, routes)
  - [ ] Aggiungere `"port"` a `_rebuild_props()` con i suoi campi
- [ ] CityGenerator: leggere `biome_tags` e propagarli in `MapData.metadata`

---

### Fase 1 — WorldData
- [ ] Creare `scripts/world/WorldData.gd`
  - [ ] Campo `world_seed: int`
  - [ ] Campi `width: int`, `height: int`
  - [ ] Campo `biome_map: PackedByteArray` — flat `[y*width+x]`, 1 byte = bioma
  - [ ] Enum/const biomi: PLAINS, FOREST, DENSE_FOREST, MOUNTAIN, MOUNTAIN_DENSE, DESERT, SWAMP, SEA, COAST
  - [ ] Campo `spawned_locations: Dictionary` — `Vector2i → location_id`
  - [ ] Campo `used_city_ids: Array[String]` — città manuali già piazzate nel mondo
  - [ ] Campo `player_start: Vector2i`
  - [ ] Metodo `serialize() → Dictionary`
  - [ ] Metodo statico `from_dict(d) → WorldData`
- [ ] Aggiungere `world_data: WorldData` a `WorldSaveManager`
- [ ] Aggiornare `WorldSaveManager.save_world()` per serializzare WorldData
- [ ] Aggiornare `WorldSaveManager.load_world()` per deserializzare WorldData
- [ ] Aggiungere `explored_tiles: PackedByteArray` a `GameState` (bitmask per-personaggio)
- [ ] Aggiornare `SaveManager._save_character()` per includere explored_tiles
- [ ] Aggiornare `SaveManager._load_character()` per ripristinare explored_tiles

---

### Fase 2 — WorldGenerator
- [ ] Creare `scripts/world/generators/WorldGenerator.gd`
  - [ ] Setup `FastNoiseLite` elevation (seed, frequency, octaves)
  - [ ] Setup `FastNoiseLite` moisture (seed derivato, frequency diversa)
  - [ ] Lookup table elevation × moisture → bioma byte (tutti i casi)
  - [ ] Soglia mountain vs mountain_dense (peak detection)
  - [ ] Rilevamento dense_forest (cluster ad alta densità)
  - [ ] Rilevamento coast (tile terra adiacenti a sea)
  - [ ] Loop 5000×5000 → popola `biome_map`
  - [ ] Piazzamento villaggio iniziale: cerca cluster plains vicino al centro, sceglie tile valido
  - [ ] Output: `WorldData` con `biome_map` e `player_start` popolati
  - [ ] Definire tabella `temperature_target` + `approach_rate` per bioma (costanti in `WorldData.gd` o `data/world/biome_defs.json`)
- [ ] Aggiornare `TimeManager.advance()` / `OverworldMap` per passare `{"biome": biome_id}` nel context durante movimento overworld (necessario per `NeedsManager._get_temperature_target()`)
- [ ] Rimuovere / svuotare `OverworldGenerator.gd` (sostituito)
- [ ] Aggiornare `LocationRegistry._generate()`: rimuovere o reindirizzare il caso `"overworld"`

---

### Fase 3 — Redesign OverworldMap + MapRenderer
- [ ] Redesign `OverworldMap.gd`
  - [ ] Rimuovere dipendenza da `MapData` per tiles
  - [ ] Aggiungere riferimento a `WorldSaveManager.world_data`
  - [ ] Override `is_walkable(pos)`: mountain_dense / dense_forest / sea → false
  - [ ] Override `get_tile_char(pos)` e `get_tile_color(pos)` da bioma
  - [ ] `populate()`: non più da MapData; piazza solo entità (player spawn, location markers)
  - [ ] Chiamata a `ProximityGenerator.scan_around()` ad ogni movimento player
- [ ] Estendere `MapRenderer.gd` per percorso overworld
  - [ ] Rendering biomi: carattere + colore per tipo (tabella in Fase 3 del piano)
  - [ ] Fog of war overworld: tile non in `explored_tiles` → neri
  - [ ] Tile esplorati fuori FOV corrente: colore dimezzato
  - [ ] Tile location da `WorldData.spawned_locations`: simbolo sovrapposto al bioma
  - [ ] Rimuovere assunzione "FOV solo dungeon" — percorso dedicato per `type == "overworld"`

---

### Fase 4 — Movimento overworld
- [ ] Aggiornare `Player.gd` per logica overworld
  - [ ] Rilevamento `current_map.type == "overworld"`
  - [ ] Costi movimento per bioma (Dictionary biome → int giorni)
    - [ ] plains: 1, forest: 2, mountain: 3, desert: 2, swamp: 2, coast: 1
  - [ ] Hook moltiplicatore velocità (metodo `_get_speed_multiplier()` — default 1.0, mount: 0.5)
  - [ ] Hook consumo risorse (metodo `_consume_travel_resources()` — placeholder vuoto)
  - [ ] Aggiornamento `explored_tiles` ad ogni passo (raggio visibilità calcolato)
- [ ] Calcolo raggio visibilità dinamico
  - [ ] Base: 15
  - [ ] Modificatori bioma: mountain_dense +8, mountain +5, desert +3, forest -5, swamp -5
  - [ ] Modificatore classe: hook su `GameState.current_class` (da popolare con i dati classi)
- [ ] Trigger transizione su tile con location (da `WorldData.spawned_locations`)

---

### Fase 5 — ProximityGenerator
- [ ] Creare `scripts/world/ProximityGenerator.gd`
  - [ ] Metodo `scan_around(player_pos: Vector2i, world_data: WorldData)`
  - [ ] Hash deterministico: `hash(world_data.world_seed ^ x * 7919 ^ y * 6271) % 1000`
  - [ ] Biome spawn rules: Dictionary biome → Array[{type, weight, threshold}]
    - [ ] plains: villaggio 3%, dungeon 1%, rovina 1%
    - [ ] forest: villaggio 2%, dungeon 2%, rovina 2%
    - [ ] mountain: dungeon 5%, rovina 3%, villaggio 1%
    - [ ] desert: rovina 4%, dungeon 2%, villaggio 1%
    - [ ] swamp: dungeon 3%, rovina 2%, villaggio 1%
    - [ ] coast: villaggio 3% (con porto), nessun dungeon
  - [ ] Check distanza minima: dungeon 5 tile, villaggio/città 100 tile
  - [ ] Spawn villaggio: scan `data/cities/` per biome_tags compatibili, escludi `used_city_ids`
  - [ ] Spawn dungeon: `DungeonGenerator.generate()` con params bioma (floors 1–3 random)
  - [ ] Spawn rovina: `DungeonGenerator.generate()` con `floors:1, surface_ruin:true`
  - [ ] `LocationRegistry.register()` per ogni location generata
  - [ ] Aggiornamento `WorldData.spawned_locations` e `used_city_ids`
- [ ] Scanner manifesto città: carica tutti i JSON in `data/cities/` all'avvio, indicizza per biome_tags

---

### Fase 6 — Fog of war (bitmask)
- [ ] Helpers bitmask in `WorldData` (o classe utility)
  - [ ] `get_explored(x, y) → bool`
  - [ ] `set_explored(x, y)` su `GameState.explored_tiles`
  - [ ] Index: `(y * width + x) // 8`, bit: `(y * width + x) % 8`
- [ ] Inizializzazione `explored_tiles` a nuovo personaggio: PackedByteArray vuota (tutti 0)
- [ ] Aggiornamento explored_tiles nel movimento player (tutti i tile nel raggio visibilità)

---

### Fase 7 — Minimap HUD
- [ ] Creare `scripts/ui/OverworldMinimap.gd` (Control, overlay HUD)
  - [ ] Posizione: top-right, es. 120×120 pixel
  - [ ] Rendering: itera area esplorata intorno al player (scala 1 pixel = N tile)
  - [ ] Colori bioma semplificati (una tinta per tipo)
  - [ ] Simbolo player al centro (dot bianco)
  - [ ] Simboli location da `WorldData.spawned_locations` (punto colorato per tipo)
  - [ ] Aggiornamento su signal `player_moved`
  - [ ] Toggle visibilità (tasto da definire)
- [ ] Aggiungere `OverworldMinimap` alla scena overworld come CanvasLayer

---

### Fase 8 — Viaggio astratto (mare + quick travel)
- [ ] Creare `scripts/world/TravelSystem.gd`
  - [ ] `get_sea_routes(from_port_id) → Array[port_id]` — porti raggiungibili
  - [ ] `travel_by_sea(from, to) → int` — calcola giorni di viaggio
  - [ ] `get_land_routes(from_location_id) → Array[location_id]` — location conosciute raggiungibili
  - [ ] `travel_by_land(from, to) → int` — calcola giorni (distanza Manhattan × costo bioma medio)
  - [ ] Consumo risorse astratto (placeholder, hook per sistema bisogni)
- [ ] UI selezione destinazione (popup su porto o location conosciuta)

---

### Fase 9 — Save/Load integration
- [ ] Test salvataggio: WorldData + explored_tiles scritti correttamente
- [ ] Test caricamento: WorldData + explored_tiles ripristinati
- [ ] Test nuovo personaggio nello stesso mondo: explored_tiles reset, WorldData invariato
- [ ] Test permadeath: nuovo pg vede mondo al buio, location già generate presenti

---

### Fase 10 — Balance e polish
- [ ] Tuning frequenza noise per biomi credibili a 5000×5000
- [ ] Tuning spawn density (percentuali ProximityGenerator)
- [ ] Garantire area iniziale: almeno 1 dungeon e 1 location entro 30 tile dallo spawn
- [ ] Test con 5 seed diversi
- [ ] Simboli ASCII e colori definitivi verificati in-game

---

## Note HUD v2 — MinimapPanel (aggiunto in F7)

- **ID overworld**: `overworld` costante usata da WorldSaveManager, WorldManager
- **minimap_enabled**: flag MapData.metadata["minimap_enabled"] = true impostato da OverworldGenerator quando i params includono minimap_enabled:true
- **Fonte del flag**: WorldSaveManager.generate_new_world() passa minimap_enabled:true nei params di registrazione overworld
- **Mondi precedenti**: flag assente -> metadata.get("minimap_enabled", false) = false -> minimap nascosta; nessuna regressione
- **Explored tiles**: GameState.explored_tiles (x,y->true) aggiornato da MinimapPanel.mark_explored(); persistito da SaveManager (F0)


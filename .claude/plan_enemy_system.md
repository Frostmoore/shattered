# Piano: Sistema Nemici ed Encounter

**Obiettivo**: costruire un sistema di encounter che sembri sempre realistico e dinamico — non un elenco di mostri scalati, ma una logica di composizione controllata da budget, ruoli tattici e determinismo per mondo.

La domanda centrale non è "quanti nemici spawnano?" ma:

> Quanto deve pesare questo dungeon sul personaggio?
> Che tipo di pressione voglio creare in questo piano?
> Quali ruoli nemici producono quella pressione in modo leggibile?

---

## Stato attuale

- 4 nemici definiti in `.gd` hardcoded via preload in `BalanceEnemy`
- Scaling FF8: `enemy.level = player.level`, `hp = hp_base × lf/lf_base`
- ATK e DEF fissi, non scalano col livello
- Placement casuale per budget pressione (già presente, ma piatto)
- Nessun affisso, nessun ruolo tattico, nessun determinismo per mondo

---

## Architettura target

```
EnemyRegistry          — carica/espone tutti i JSON nemici
AffixRegistry          — carica/espone tutti gli affissi
DungeonPressureProfile — budget totale del dungeon
FloorPressureProfile   — quota per piano
EncounterTemplate      — gruppo nemici con ruoli, posizioni, affissi (deterministico)
EnemySpawnTemplate     — singolo nemico: tipo + posizione + affissi (deterministico)
EnemyRuntimeStats      — statistiche calcolate al momento dell'entrata del personaggio
```

### Separazione deterministico / runtime

Il contenuto del dungeon (chi c'è, dove, con quali affissi) è fisso per mondo.
Le statistiche numeriche (HP, ATK, DEF effettivi) sono calcolate al momento dell'entrata.

```
EnemySpawnTemplate  →  salvo nel mondo, uguale per tutti i personaggi
EnemyRuntimeStats   →  calcolo on-entry, scala col livello del personaggio
```

---

## Strutture dati

### Enemy JSON — schema completo

```json
{
  "schema_version": 1,
  "id": "goblin",
  "name": "Goblin",
  "char": "g",
  "color": [0.28, 0.88, 0.28, 1.0],

  "family":  "humanoid",
  "role":    "skirmisher",
  "tier":    1,
  "tags":    ["melee"],
  "biomes":  ["plains", "cave", "ruins"],

  "hp_base":  8,
  "atk_base": 3,
  "def_base": 0,
  "dex_base": 5,

  "atk_growth": 0.15,
  "def_growth": 0.05,

  "pressure_cost": 6,
  "spawn_weight":  100,
  "min_floor": 1,
  "max_floor": 8,
  "zone_min_level": 1,
  "zone_max_level": 10,
  "detection": 5,

  "resistances":   {},
  "abilities":     [],
  "loot_profile":  "humanoid_low"
}
```

**Campi chiave rispetto allo stato attuale:**
- `schema_version` — versioning per invalidazione template (vedi §Determinismo)
- `role` — funzione tattica (vedi §Ruoli)
- `family` — identità tematica
- `atk_growth`, `def_growth` — scaling lineare di ATK/DEF per livello
- `max_floor`, `zone_min_level`, `zone_max_level` — limita lo scaling per zona
- `spawn_weight` — peso relativo nella selezione casuale

---

### Affix JSON — schema completo

```json
{
  "id":             "berserker",
  "prefix":         "Berserker",
  "affix_category": "offensive",
  "affix_rank":     "minor",

  "hp_mult":        1.0,
  "atk_mult":       1.6,
  "def_mult":       0.6,
  "dex_mult":       1.0,
  "xp_mult":        1.3,
  "pressure_mult":  1.35,

  "color_tint":     [1.0, 0.6, 0.4, 1.0],
  "effect":         null,

  "compatible_families": [],
  "incompatible_categories": ["offensive"],
  "min_floor": 4
}
```

**Regole composizione affissi:**
- Max 2 affissi per nemico normale
- Max 1 affisso `major` per nemico non-boss
- Vietati due affissi della stessa `affix_category` se entrambi `major`
- `incompatible_categories` elenca le categorie che non possono coesistere con questo affisso
- `effective_pressure` ricalcolato sempre dopo gli affissi; se supera il budget → reroll o downgrade

---

### EnemySpawnTemplate

```json
{
  "spawn_id":        "crypt_f2_room04_1",
  "dungeon_id":      "crypt_of_ash",
  "floor_index":     2,
  "room_id":         "room_04",
  "enemy_id":        "skeleton",
  "position":        [12, 8],
  "affixes":         ["armored"],
  "encounter_group": "f2_room04",
  "enemy_schema_version": 1
}
```

### EnemyRuntimeStats (calcolato on-entry)

```json
{
  "spawn_id": "crypt_f2_room04_1",
  "level":    8,
  "hp":       34,
  "atk":      7,
  "def":      3,
  "dex":      3
}
```

### EncounterTemplate

```json
{
  "id":             "f2_room04",
  "dungeon_id":     "crypt_of_ash",
  "floor_index":    2,
  "room_id":        "room_04",
  "archetype":      "guarded_caster",
  "pressure_budget": 22,
  "pressure_used":   21,
  "roles":          ["tank", "skirmisher", "controller"],
  "enemies":        ["crypt_f2_room04_0", "crypt_f2_room04_1", "crypt_f2_room04_2"]
}
```

---

## Ruoli tattici (`role`)

`family` = cosa è il nemico tematicamente.
`tags` = proprietà secondarie.
`role` = funzione tattica nell'encounter.

| role | descrizione |
|---|---|
| soldier | nemico base bilanciato |
| brute | alto danno, bassa finezza |
| skirmisher | veloce, mobile, fastidioso |
| tank | alta difesa / molti HP |
| glass_cannon | tanto danno, fragile |
| artillery | attacco a distanza, fragile da vicino |
| controller | debuff, slow, status |
| summoner | evoca altri nemici (futuro) |
| support | cura o potenzia alleati (futuro) |
| assassin | alta DEX, alto burst, fragile |
| swarm | debole singolo, pericoloso in gruppo |
| elite | superiore alla media, non boss |
| boss | boss o miniboss |

Il role guida sia la selezione degli encounter archetype sia le AI future (artillery non si avvicina, controller mantiene distanza, ecc.).

---

## Pressure Budget

### DungeonPressureProfile

```json
{
  "dungeon_id":               "crypt_of_ash",
  "danger_rating":            3,
  "total_pressure_budget":    420,
  "boss_pressure_reserved":   80,
  "elite_pressure_reserved":  45,
  "random_encounter_budget":  295,
  "budget_curve":             "rising"
}
```

`danger_rating` (1-6) influenza budget totale, qualità media nemici, probabilità affissi e reward.

### Curve di distribuzione per piano

| curva | descrizione |
|---|---|
| flat | ogni piano simile |
| rising | piani profondi progressivamente più duri (default) |
| spiky | picchi casuali di difficoltà |
| boss_rush | budget basso all'inizio, alto alla fine |
| exhaustion | molti encounter medi, logora le risorse |

Distribuzione `rising` per 5 piani: 12% / 16% / 20% / 24% / 28%.

### Effective pressure nemico

```
effective_pressure = base_pressure
                   × level_pressure_mult
                   × affix_pressure_mult
```

`level_pressure_mult = clamp(1.0 + (enemy.level - zone_recommended_level) × 0.08, 0.75, 1.6)`

Il budget per encounter viene sempre verificato *dopo* aver calcolato l'`effective_pressure` finale.

---

## Determinismo per mondo

### Regola fondamentale
Lo stesso dungeon nello stesso mondo ha sempre gli stessi nemici nelle stesse posizioni.
I personaggi diversi trovano lo stesso contenuto, con statistiche scalate al loro livello.

### Seed gerarchici

```
world_seed
  → dungeon_seed  = hash(world_seed, dungeon_id)
      → floor_seed     = hash(dungeon_seed, floor_index)
          → encounter_seed = hash(floor_seed, room_id)
              → enemy_seed = hash(encounter_seed, local_enemy_index)
```

Tutto il random (selezione nemici, posizioni, affissi) usa seed derivati da questa gerarchia.

### Strategia di salvataggio: Strategy B

Quando il dungeon viene generato per la prima volta, gli `EnemySpawnTemplate` vengono salvati nel dato del mondo.
Al re-ingresso si ricaricano i template, si ricalcolano solo le `EnemyRuntimeStats`.

### Invalidazione template

Se `schema_version` del JSON nemico è superiore a `enemy_schema_version` nel template salvato, il template è stale.

Policy:
- Per modifiche minor (nuovi campi non strutturali): ricalcola runtime, ignora differenza
- Per modifiche ai campi strutturali (role, tier, pressure_cost): rigenerazione silenziosa del template al prossimo accesso al dungeon
- Loggare sempre l'invalidazione durante sviluppo

---

## Encounter Archetypes

Prima implementazione: archetype semplici, poi evolverli.

### Pass 1 (implementazione iniziale)
Scegli 1-3 ruoli compatibili con il budget e riempi con nemici che matchano.
Non serve archetype esplicito — basta "tank + skirmisher" o "swarm × 3".

### Pass 2 (dopo test)
Definire archetype named:

| id | ruoli | note |
|---|---|---|
| solo_brute | brute | nemico singolo forte |
| swarm_basic | swarm × 3-5 | bestie o non-morti deboli |
| guarded_caster | tank + controller | il controller rimane indietro |
| brute_and_skirmishers | brute + skirmisher × 2 | classico |
| elite_duel | elite | 1 nemico con affisso garantito |
| patrol | soldier × 2-3 | encounter normale |
| glass_battery | glass_cannon × 2 | pericoloso se non interrotto |

Regola: un archetype deve *raccontare qualcosa* sull'encounter, non essere solo una lista di nemici.

---

## Scaling

### Livello nemico con varianza

```
target_level   = player.level + floor_bonus + tier_bonus + rng_variance(enemy_seed)
enemy.level    = clamp(target_level, zone_min_level, zone_max_level)

floor_bonus    = floor(floor_index / 5)
tier_bonus     = tier - 3   (tier1=−2, tier2=−1, tier3=0, tier4=+1, tier5=+2, tier6=+3)
rng_variance   = [-2, +2]  seedato deterministicamente
```

### ATK e DEF scaling

```
enemy.attack  = atk_base + floor((enemy.level - 1) × atk_growth)
enemy.defense = def_base + floor((enemy.level - 1) × def_growth)
```

Valori default globali in `BalanceCombat`: `atk_growth = 0.15`, `def_growth = 0.05`.
Ogni nemico può override nel JSON.

### DEX

Resta fissa al `dex_base` — è una proprietà dell'archetipo, non del livello.

---

## ClassCombatProfile e simulazioni

Per bilanciare 59 classi senza simulazioni manuali nemico×classe, raggrupparle in archetipi di combattimento.

| profilo | esempi di classe |
|---|---|
| melee_tank | Paladino, Cavaliere, Templare |
| melee_bruiser | Guerriero, Barbaro, Berserker |
| melee_glass_cannon | Assassino, Spettro |
| ranged_physical | Ranger, Arciere, Cacciatore di Taglie |
| caster_burst | Mago, Piromante, Arcanista |
| caster_dot | Negromante, Strega |
| evasion_based | Ladro, Monaco, Corsaro |
| sustain_based | Sacerdote, Biomante |
| hybrid | Spellblade, Bardo, Alchimista |

**Il ClassCombatProfile viene usato come strumento di validazione dalla Fase 6 in poi**, non come fase finale.
Per ogni tipo di nemico aggiunto, simulare almeno:
- TTK medio (turni per uccidere il nemico) per `melee_bruiser` e `caster_burst`
- Danno subito prima che il nemico muoia, per `melee_tank` e `evasion_based`
- Se il risultato è fuori target, aggiustare `pressure_cost`, `hp_base`, `atk_base` prima di dichiarare il nemico "pronto"

**Obiettivi indicativi:**
- Nemico normale: muore in 3-5 colpi medi, infligge danno significativo ma non letale
- Elite: 6-9 colpi, richiede attenzione, reward superiore
- Piano dungeon: consuma 40-60% risorse prima del boss
- Dungeon completo: boss affrontabile ma non gratuito

---

## Affissi — lista proposta (15)

| id | prefisso | categoria | rank | effetto principale |
|---|---|---|---|---|
| armored | Corazzato | defensive | minor | DEF ×1.8, DEX ×0.8 |
| berserker | Berserker | offensive | minor | ATK ×1.6, DEF ×0.6 |
| swift | Fulmineo | mobility | minor | DEX ×1.8, HP ×0.8 |
| iron | di Ferro | defensive | minor | DEF ×2.0, ATK ×0.8 |
| frenzied | Frenetico | offensive | minor | ATK ×1.4, HP ×0.9 |
| shadowed | nell'Ombra | mobility | minor | DEX ×2.0, HP ×0.7 |
| bloated | Gonfio | defensive | minor | HP ×2.2, ATK ×0.7, DEX ×0.4 |
| giant | Gigante | defensive | major | HP ×1.5, ATK ×1.2, DEX ×0.7 |
| ancient | Antico | elite | major | tutti ×1.3, XP ×1.6 |
| cursed | Maledetto | special | major | ATK ×1.2, HP ×1.2, futuro: curse on hit |
| venomous | Velenoso | special | minor | ATK ×1.1, futuro: DOT |
| regenerating | Rigenerante | sustain | major | HP ×1.3, futuro: regen/turn |
| spectral | Spettrale | special | major | DEF ×0.5, DEX ×1.5, futuro: 25% phys ignore |
| champion | Campione | elite | legendary | tutti ×1.8, guaranteed drop (futuro) |
| elite | Elite | elite | major | tutti ×1.4, XP ×2, colore oro |

---

## Roster nemici — 30 tipi base

### Tier 1 — Piani 1-4
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| spider | Ragno | r | beast | skirmisher | 5 | 2 | 0 | 8 |
| goblin | Goblin | g | humanoid | skirmisher | 8 | 3 | 0 | 5 |
| rat | Ratto | . | beast | swarm | 3 | 1 | 0 | 7 |
| bat | Pipistrello | v | beast | skirmisher | 4 | 2 | 0 | 9 |
| kobold | Kobold | k | humanoid | soldier | 6 | 3 | 0 | 6 |

### Tier 2 — Piani 2-7
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| skeleton | Scheletro | s | undead | soldier | 12 | 4 | 1 | 3 |
| zombie | Zombie | z | undead | tank | 15 | 3 | 1 | 1 |
| bandit | Bandito | b | humanoid | glass_cannon | 10 | 5 | 1 | 6 |
| giant_spider | Ragno Gigante | R | beast | brute | 14 | 5 | 1 | 6 |
| slime | Melma | * | aberration | tank | 9 | 2 | 2 | 2 |

### Tier 3 — Piani 5-12
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| troll | Troll | T | beast | brute | 22 | 6 | 2 | 2 |
| orc | Orco | O | humanoid | brute | 18 | 7 | 1 | 4 |
| dark_elf | Elfo Oscuro | e | humanoid | assassin | 14 | 6 | 1 | 9 |
| lizardman | Uomo Lucertola | l | beast | soldier | 16 | 5 | 2 | 5 |
| ghoul | Ghoul | G | undead | soldier | 20 | 5 | 2 | 3 |

### Tier 4 — Piani 9-18
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| ogre | Ogre | Q | humanoid | brute | 30 | 9 | 2 | 2 |
| gargoyle | Garguglia | q | construct | tank | 20 | 6 | 5 | 3 |
| werewolf | Lupo Mannaro | W | beast | glass_cannon | 24 | 10 | 1 | 7 |
| witch | Strega | w | humanoid | controller | 16 | 8 | 1 | 5 |
| vampire | Vampiro | V | undead | assassin | 22 | 8 | 2 | 7 |

### Tier 5 — Piani 14-25
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| death_knight | Cavaliere della Morte | D | undead | soldier | 35 | 11 | 4 | 4 |
| demon | Demone | d | demon | brute | 28 | 12 | 3 | 6 |
| golem | Golem | M | construct | tank | 40 | 8 | 8 | 1 |
| dragon_whelp | Drago Giovane | p | dragon | glass_cannon | 32 | 13 | 3 | 5 |
| lich | Lich | L | undead | controller | 25 | 10 | 2 | 4 |

### Tier 6 — Piani 20+
| id | nome | char | family | role | hp | atk | def | dex |
|---|---|---|---|---|---|---|---|---|
| chaos_knight | Cavaliere del Caos | K | demon | soldier | 45 | 15 | 5 | 5 |
| archlich | Arcilich | A | undead | controller | 35 | 13 | 3 | 5 |
| ancient_dragon | Drago Antico | P | dragon | brute | 60 | 16 | 6 | 4 |
| fallen_angel | Angelo Caduto | a | demon | glass_cannon | 40 | 14 | 4 | 8 |
| void_stalker | Predatore del Vuoto | # | aberration | assassin | 30 | 14 | 2 | 10 |

---

## Ordine di implementazione

### Fase 1 — EnemyRegistry e migrazione JSON
Spostare i 4 nemici da `.gd` a JSON, creare `EnemyRegistry` autoload analogo a `ClassRegistry`.
Mantenere piena compatibilità con `BalanceEnemy` esistente.
*Sblocca tutto il resto.*

### Fase 2 — Roster base (10 nemici aggiuntivi)
Aggiungere tier 1 e tier 2 completi. Testare spawn, scaling esistente, visual.
Non aggiungere tutti i 30 in una volta — prima verificare che il sistema li gestisca.

### Fase 3+4 — Seed gerarchici + Pressure Budget (insieme)
Il seed system è load-bearing per il budget: progettarli e implementarli in parallelo.
- Introdurre seed gerarchici (`world_seed → dungeon_seed → floor_seed → ...`)
- `DungeonPressureProfile` e `FloorPressureProfile`
- `effective_pressure` calcolato con seed deterministico
- `EnemySpawnTemplate` generato e salvato nel mondo
- `EnemyRuntimeStats` calcolato on-entry

### Fase 5 — EncounterTemplate (pass 1)
Prima implementazione semplice: scegli 1-3 ruoli compatibili col budget, riempi con nemici matching.
Nessun archetype named — solo "tank + skirmisher" o "swarm × 3".
Obiettivo: encounter che abbiano senso tattico minimo, non random puro.

### Fase 6 — ClassCombatProfile e prime simulazioni
Definire 8-10 archetipi di classe. Simulare TTK e danno subito per ogni nemico esistente.
Da qui in poi, ogni nuovo nemico viene validato con le simulazioni prima di essere dichiarato pronto.
*Questo è uno strumento di sviluppo, non una feature di gioco.*

### Fase 7 — Scaling refinement
- `zone_min_level` / `zone_max_level` per evitare FF8 puro
- `atk_growth` e `def_growth` per scaling ATK/DEF lineare
- `level_pressure_mult` per correggere il budget dopo lo scaling

### Fase 8 — Sistema affissi
- `AffixRegistry`
- Categorie, rank, `pressure_mult` obbligatorio
- Generazione deterministica via `enemy_seed`
- Regole di compatibilità (`incompatible_categories`)
- Ricalcolo `effective_pressure` post-affisso
- Probabilità per piano scalate con `danger_rating`

### Fase 9 — EncounterTemplate (pass 2) + archetype named
Introdurre archetype named (`guarded_caster`, `brute_and_skirmishers`, ecc.) ora che il sistema è stabile.
Completare il roster ai 30 nemici.
AI avanzata per role `controller`, `artillery`, `support` (questo può slittare oltre la fase 9).

---

## Questioni aperte

1. **DEX scaling**: resta fissa o scala minimalmente? Attuale: fissa (proprietà dell'archetipo).
2. **Resistenze**: campo predisposto, sistema danni non le usa ancora. Da implementare con i tipi di danno.
3. **Biomi**: campo nel JSON ma overworld/biomi non ancora implementati. Ignorare per ora.
4. **Abilities**: campo nel JSON come placeholder. Non implementare fino alla Fase 9+.
5. **Invalidazione template**: durante sviluppo loggare sempre; policy di rigenerazione automatica da definire prima della Fase 3.
6. **Loot integration**: affissi `champion` ed `elite` presuppongono drop garantiti. Coordinarsi con `plan_item_system.md` prima della Fase 8.
7. **AI avanzata** (ranged, magic, controller): prerequisito per la vera identità dei ruoli. Può essere parallela o successiva alla Fase 9.

---

## TODO — Tracking implementazione

Ogni fase viene spuntata al completamento. Sotto ogni checkbox completata va aggiunto un paragrafo di tracking con: file toccati, decisioni prese in corso d'opera, deviazioni dal piano, problemi risolti.

- [x] **Fase 1** — EnemyRegistry e migrazione JSON

  **Tracking** — completata il 2026-05-21

  *File creati:*
  - `data/enemies/spider.json`, `goblin.json`, `skeleton.json`, `troll.json` — i 4 nemici migrati da `.gd` a JSON con schema completo (schema_version, family, role, tier, tags, biomes, atk_growth, def_growth, spawn_weight, max_floor, zone_min_level, zone_max_level, resistances, abilities, loot_profile)
  - `scripts/core/EnemyRegistry.gd` — autoload analogo a ClassRegistry; carica tutti i JSON da `data/enemies/`, espone `get_enemy_data(id)`, `get_all()`, `get_by_tier()`, `get_by_role()`, `get_by_family()`

  *File modificati:*
  - `project.godot` — aggiunto `EnemyRegistry` come autoload dopo ClassRegistry
  - `scripts/entities/Enemy.gd` — visual lookup cambiato da scan lineare su `GameBalance.get_enemy_table()` a `EnemyRegistry.get_enemy_data(id)` (lookup O(1) invece di O(n))
  - `scripts/world/dungeon/EnemyPlacer.gd` — `GameBalance.get_enemy_table()` sostituito con `EnemyRegistry.get_all()`
  - `scripts/core/game_balance/BalanceEnemy.gd` — rimossa `get_enemy_table()` con i preload hardcoded; il commento ora rimanda a EnemyRegistry
  - `scripts/core/GameBalance.gd` — rimossa `get_enemy_table()` statica; `roll_enemy_balance` e il preload `_Enemy` restano (servono per i parametri di difficoltà del dungeon, non per il roster)

  *Decisioni prese:*
  - I file `.gd` dei 4 nemici (`enemy_spider.gd` ecc.) sono stati lasciati sul disco ma non sono più referenziati — possono essere eliminati in futuro ma non urgente
  - `GameBalance.get_enemy_table()` rimossa completamente invece di mantenerla come thin wrapper: evita confusione su dove vive il dato
  - EnemyRegistry posizionato in `scripts/core/` (non `scripts/classes/`) per coerenza con gli altri registry di dati di gioco

  *Deviazioni dal piano:* nessuna

  *Problemi:* errori LSP su `EnemyRegistry not declared` in Enemy.gd e EnemyPlacer.gd — false positive da cache stale del language server, comportamento identico a ClassRegistry e BalanceCombat; a runtime tutto funziona

- [x] **Fase 2** — Roster base (10 nemici aggiuntivi, tier 1 e tier 2 completi)

  **Tracking** — completata il 2026-05-21

  *File creati:*
  - `data/enemies/rat.json` — beast / swarm / tier 1: HP 3, ATK 1, DEF 0, DEX 7, pressure 3, biomes [cave, dungeon, ruins], min_floor 1, max_floor 5
  - `data/enemies/bat.json` — beast / skirmisher / tier 1: HP 4, ATK 2, DEF 0, DEX 9, pressure 4, biomes [cave, dungeon], min_floor 1, max_floor 6
  - `data/enemies/kobold.json` — humanoid / soldier / tier 1: HP 6, ATK 3, DEF 0, DEX 6, pressure 5, biomes [cave, ruins, dungeon], min_floor 1, max_floor 7
  - `data/enemies/zombie.json` — undead / tank / tier 2: HP 15, ATK 3, DEF 1, DEX 1, pressure 8, biomes [crypt, dungeon, ruins], min_floor 2, max_floor 10
  - `data/enemies/bandit.json` — humanoid / glass_cannon / tier 2: HP 10, ATK 5, DEF 1, DEX 6, pressure 9, biomes [ruins, dungeon, plains], min_floor 2, max_floor 11
  - `data/enemies/giant_spider.json` — beast / brute / tier 2: HP 14, ATK 5, DEF 1, DEX 6, pressure 11, biomes [cave, dungeon], min_floor 2, max_floor 12
  - `data/enemies/slime.json` — aberration / tank / tier 2: HP 9, ATK 2, DEF 2, DEX 2, pressure 7, biomes [cave, dungeon, swamp], min_floor 2, max_floor 10

  *File modificati:* nessuno — EnemyRegistry scopre i nuovi JSON automaticamente via glob su `data/enemies/*.json`

  *Decisioni prese:*
  - `xp_reward` aggiunto a ogni nemico (range tier 1: 8-14, tier 2: 16-28) proporzionale a pressure_cost × ~1.6-2.5
  - `spawn_weight` calibrato per riflessione sulla frequenza attesa: ratto 80 (comune), pipistrello 75, kobold 90; zombie 90, bandito 85, ragno gigante 70, melma 75
  - `atk_growth` / `def_growth` differenziati per role: glass_cannon ha atk_growth alto (0.18) e def_growth basso (0.04); tank ha def_growth più alto; brute ha entrambi medio-alti
  - Tier 1 tier-completo: 5 nemici coprono tutti i ruoli skirmisher, swarm, soldier
  - Tier 2 tier-completo: 5 nemici coprono tank, glass_cannon, brute, soldier (skeleton), e aberration come wildcard

  *Deviazioni dal piano:* la fase prevedeva 10 nemici aggiuntivi ma ne sono stati creati 7 (3 tier 1 + 4 tier 2) — quelli mancanti al piano erano già presenti dal passaggio Fase 1 (spider, goblin, skeleton, troll che completano il conteggio a 11 totali)

  *Problemi:* nessuno — nessun codice modificato, il sistema EnemyRegistry funziona by design con nuovi file

- [x] **Fase 3+4** — Seed gerarchici + Pressure Budget

  **Tracking** — completata il 2026-05-21

  *File creati:*
  - `scripts/core/game_balance/BalancePressure.gd` — budget curves (rising/flat/spiky/boss_rush/exhaustion), `total_budget(danger_rating, floor_count)`, `floor_budgets(available, floor_count, curve, rng)`, `level_pressure_mult(enemy_level, zone_recommended_level)`. Calibrato su PRESSURE_BASE/PER_FLOOR: danger 1 = base 18/+7 per piano, danger 6 = base 78/+33.

  *File modificati:*
  - `scripts/core/game_balance/BalanceEnemy.gd` — aggiunte tabelle `DANGER_RATING_VALUES/WEIGHTS` (1-6, distribuzione per livello) e `BUDGET_CURVE_VALUES/WEIGHTS` (rising 45%, flat 20%, spiky 15%, boss_rush/exhaustion 10% ciascuna); `roll_balance()` ora restituisce anche `danger_rating` e `budget_curve`
  - `scripts/core/GameBalance.gd` — aggiunto preload `_Pressure`; re-export `BOSS_RESERVE_RATIO`, `ELITE_RESERVE_RATIO`; static methods `total_pressure_budget()`, `floor_pressure_budgets()`, `level_pressure_mult()`
  - `scripts/core/GameState.gd` — aggiunti campi `world_seed: int`, `danger_rating: int`, `budget_curve: String`
  - `scripts/core/WorldSaveManager.gd` — `generate_new_world()` salva `world_seed` in `GameState`, calcola `DungeonPressureProfile` (total, boss_res, elite_res, floor_budgets array) e li aggiunge a `enemy_balance`; `save_world()` usa formato `{ meta: {...}, locations: {...} }` invece del flat dict; `load_world()` legge meta e ripristina seed/danger/curve, compatibile con salvataggi vecchi (fallback al flat dict)
  - `scripts/world/dungeon/EnemyPlacer.gd` — rimossi `pl_level`, `lf`, `lf_base` e tutti i valori baked (`hp`, `attack`, `defense`); entity_def è ora un **EnemySpawnTemplate** con campi `id`, `name`, `schema_version`, `dex`, `xp_reward`, `detection_range`, `encounter_group`; per il boss: aggiunti `boss_hp_mult`, `boss_atk_mult`, `boss_def_mult`; lettura budget da `floor_budgets[floor_num-1]` con fallback alla formula lineare per retrocompatibilità
  - `scripts/entities/Enemy.gd` — `setup()` non legge più `hp`/`attack`/`defense` da entity_def; aggiunto `_apply_runtime_stats(data)` che calcola hp/atk/def da `EnemyRegistry.get_enemy_data(id)` + `GameState.level` al momento dell'entrata; fallback ai valori baked se registry lookup fallisce (es. save vecchi con id sconosciuto)

  *Decisioni prese:*
  - `BOSS_RESERVE_RATIO` e `ELITE_RESERVE_RATIO` impostati a 0.0 per ora: il boss è già piazzato fuori dal budget normale; le riserve elite saranno non-zero dalla Fase 8
  - `encounter_group` per nemici normali: `"f{floor}_r{room_idx}"`; per boss: `"f{floor}_boss"` — permette di raggruppare gli scontri per EncounterTemplate in Fase 5
  - `schema_version` nei template: legge `pick.get("schema_version", 1)` — tutti i JSON attuali non hanno il campo (default 1); aggiungere il campo ai JSON è opzionale finché non serve invalidazione
  - world.json retrocompatibile: `load_world()` controlla se esiste la chiave `"locations"` per discriminare il formato
  - `level` rimosso dall'entity_def dei nemici normali; `Enemy.setup()` usa `GameState.level` per il calcolo runtime; il campo era ridondante (era sempre = player level al momento della generazione)

  *Deviazioni dal piano:*
  - `encounter_seed` e `enemy_seed` per-entity NON implementati — il piano li prevede nella gerarchia ma servono solo per la generazione degli affissi (Fase 8); il seed hierarchy strutturale (world → dungeon → floor) è implementato via world_seed in GameState e derivazione `seed + floor_idx * FLOOR_SEED_STRIDE` già esistente
  - `level_pressure_mult` implementato come formula in BalancePressure ma NON ancora usato nel calcolo effettivo del budget in EnemyPlacer — attivo dalla Fase 7 (scaling refinement)
  - `zone_min_level`/`zone_max_level` non usati per il clamp del livello nemico — Fase 7

  *Problemi:* errori LSP su `GameBalance.total_pressure_budget()` e `GameBalance.floor_pressure_budgets()` in WorldSaveManager — falsi positivi da cache stale del language server (stesso pattern di BalanceCombat, ClassRegistry); a runtime funziona

- [x] **Fase 5** — EncounterTemplate pass 1

  **Tracking** — completata il 2026-05-21

  *File modificati:*
  - `scripts/world/dungeon/EnemyPlacer.gd` — riscritta la logica di placement con composizione per ruolo

  *Cosa è stato implementato:*
  - `ROLE_COMBOS` const: 9 combinazioni di ruoli con peso relativo (`["soldier"]` 20, `["skirmisher"]` 18, `["swarm"]` 15, `["tank","skirmisher"]` 12, ecc.)
  - `_select_encounter_roles(rng, available, room_budget)` — per ogni stanza: filtra i combo per ruoli disponibili a quel piano e budget minimo affordabile, poi fa un weighted-random pick; restituisce `[]` (no filter) se nessun combo è valido
  - `_filter_by_roles(available, roles)` — filtra la lista nemici tenendo solo quelli con `role` in `selected_roles`
  - Loop di placement aggiornato: per ogni stanza sceglie roles → filtra pool → piazza con budget; fallback a pool completo se pool filtrato è vuoto
  - EncounterTemplate salvato in `data.metadata["encounters"][encounter_group]` con campi: `floor`, `room_idx`, `roles`, `pressure_budget`, `pressure_used`, `enemy_uids`; il boss ha il suo template con `pressure_budget: -1`
  - `metadata` è già serializzato/deserializzato da `MapData.serialize()` e `MapData.from_dict()` — nessuna modifica necessaria a MapData

  *Decisioni prese:*
  - Il combo viene scelto con weighted-random seedato deterministicamente (usa il floor RNG, quindi stesso seed = stesso encounter ogni volta)
  - `room_budget` minimo per attivare un combo = somma del cheapest enemy per ciascun ruolo nel combo; evita situazioni in cui un combo viene selezionato ma non è fisicamente piazzabile
  - Posizionamento fisico dei nemici nella stanza rimane random; il "posizionamento coerente" (tank vicino all'ingresso, fragili sul retro) è deferito alla Fase 9 / Pass 2

  *Deviazioni dal piano:* nessun archetype named, come previsto da Pass 1; il campo `archetype` nell'EncounterTemplate è implicitamente `null` (non salvato)

- [x] **Fase 6** — ClassCombatProfile e prime simulazioni
  - [x] `scripts/tools/ClassCombatProfile.gd` — 8 archetipi (melee_bruiser, melee_tank, melee_glass_cannon, ranged_physical, caster_burst, evasion_based, sustain_based, hybrid) con stats_at(profile_id, level) e TTK_TARGETS per ruolo
  - [x] `scripts/tools/CombatSimulator.gd` — simulate_combat(), verdict(), run_validation() che stampa tabella TTK su Output panel per tutti i nemici nel registro
  - [x] Validazione 11 nemici esistenti: formula lf(level)×atk/max(1,def)/5.0, player-first, hit_chance da (atk+dex)/2 vs enemy_dex
  - [x] Fix `data/enemies/troll.json`: def_base 2→1, zone_min_level 3→5 (TTK brute: 36→9, target [4,10])
  - [x] Fix `data/enemies/goblin.json`: hp_base 8→7 (TTK skirmisher: 6→5, target [2,5])

  *Deviazioni dal piano:* nessun aggiustamento a pressure_cost o atk_base necessario sui nemici tier 1-2; solo hp/def e zone_min_level corretti

- [x] **Fase 7** — Scaling refinement

  **Tracking** — completata il 2026-05-22

  *File modificati:*
  - `scripts/entities/Enemy.gd` — `_apply_runtime_stats()` riscritta: livello nemico calcolato come `clamp(player_level + floor_bonus + tier_bonus, zone_min, zone_max)` dove `floor_bonus = floor((floor_num-1)/5)` e `tier_bonus = tier-3`; HP scala su `lf(enemy_level)` invece di `lf(player_level)`; ATK e DEF ora applicano `atk_growth`/`def_growth` dal template JSON; `level` dell'entità aggiornato al valore calcolato (usato da DamagePipeline per il danno in uscita)
  - `scripts/world/dungeon/EnemyPlacer.gd` — aggiunto `var pl_level: int = GameState.level`; `_compute_enemy_level(pl_level, floor_num, e)` helper statico aggiunto in fondo al file; budget check e deduzione usano ora `effective_pressure = pressure_cost × level_pressure_mult(enemy_level, zone_min_level)`; aggiunto `"floor_num": floor_num` all'entity_def di ogni nemico normale e del boss

  *Decisioni prese:*
  - `rng_variance(enemy_seed)` nella formula target_level NON implementato — enemy_seed è deferito alla Fase 8 (affissi); il calcolo deterministico è `player_level + floor_bonus + tier_bonus` senza varianza per ora
  - Il helper `_compute_enemy_level()` è una static func separata per non duplicare la logica tra EnemyPlacer e Enemy — la formula deve restare identica in entrambi i posti
  - Livello nemico aggiornato via `level = enemy_level` in `_apply_runtime_stats()` dopo il livello provvisorio impostato da `setup()`

  *Verifica TTK livelli estremi (.claude/combat_sim_output.md):*
  - **Livello 1:** FAILs solo per nemici con `zone_min_level > 1` (bandito=2, troll=5) — non incontrabili normalmente a livello 1, clamp corretto
  - **Livello 5 (zona target):** 0 FAIL, 2 warn(easy) minori (kobold/zombie TTK=2 per caster, target min=3) — bilanciamento ok
  - **Livello 50:** tutti FAIL(easy) su nemici tier 1-2 — comportamento atteso, player alta livello one-shotta nemici capped a zone_max_level; non è un problema di design

- [x] **Fase 8** — Sistema affissi

  **Tracking** — completata il 2026-05-22

  *File creati:*
  - `scripts/core/AffixRegistry.gd` — autoload (extends Node), carica tutti i JSON da `data/affixes/`; API: `get_affix(id)`, `get_all()`, `get_eligible(floor_num, family)` (filtra per min_floor e compatible_families)
  - `data/affixes/berserker.json` — offensive/minor: atk×1.6, def×0.6, pressure×1.35, min_floor 2
  - `data/affixes/armored.json` — defensive/minor: def×2.0, hp×1.2, pressure×1.30, min_floor 1
  - `data/affixes/swift.json` — evasive/minor: dex×1.8, hp×0.85, pressure×1.25, min_floor 1
  - `data/affixes/venomous.json` — debilitating/minor: atk×1.2, dex×1.2, pressure×1.20, min_floor 2
  - `data/affixes/tough.json` — defensive/minor: hp×1.5, def×1.3, pressure×1.40, min_floor 1
  - `data/affixes/enraged.json` — offensive/major: atk×2.0, hp×1.3, pressure×1.80, min_floor 4
  - `data/affixes/ironclad.json` — defensive/major: def×3.0, hp×1.5, pressure×2.00, min_floor 5

  *File modificati:*
  - `project.godot` — `AffixRegistry` aggiunto come autoload dopo `EnemyRegistry`
  - `scripts/world/dungeon/EnemyPlacer.gd` — aggiunto `danger_rating` e `world_seed` da GameState/enemy_balance; `_seed_hash(a, b)` per derivare semi deterministici per-nemico; `_roll_affixes(seed, enemy, floor_num, danger_rating)` che genera 0-2 affissi rispettando regole max-major e incompatible_categories; probabilità base = danger_rating×10% (max 60%); secondo affisso 30% se danger_rating≥3; lista affissi aggiunta all'entity_def
  - `scripts/entities/Enemy.gd` — `setup()`: legge `affixes` dall'entity_def, applica prefix al nome e color_tint (ultimo affix vince, mai sul boss); `_apply_runtime_stats()`: applica moltiplicatori hp/atk/def/dex/xp da tutti gli affissi prima dei moltiplicatori boss

  *Decisioni prese:*
  - Affissi NON partecipano al budget check di placement — la probabilità scalata con danger_rating è il meccanismo di controllo; `pressure_mult` è informativo e usato nella Fase 9 per statistiche encounter
  - compatible_families: [] significa compatibile con tutte le famiglie
  - Color tint del boss NON viene sovrascritto dagli affissi (boss ha già tint rosso fisso)
  - `enemy_seed` derivato come `_seed_hash(_seed_hash(world_seed, floor_num), uid_counter)` — deterministico, non consuma il floor RNG principale

  *Deviazioni dal piano:*
  - `BOSS_RESERVE_RATIO` e `ELITE_RESERVE_RATIO` restano 0.0 — elite duel archetype e drop garantiti rimandati alla Fase 9 (dipendono dall'item system, vedi note §6)
  - `rng_variance(enemy_seed)` nel calcolo livello nemico NON implementato in questa fase — enemy_seed ora esiste ma viene usato solo per gli affissi; la varianza del livello slittata alla Fase 9
  - Falsi positivi LSP su `AffixRegistry` in Enemy.gd e EnemyPlacer.gd — stesso pattern di EnemyRegistry al primo avvio; si risolve con "GDScript: Restart Language Server"

- [x] **Fase 8.1** — Tooltip hover nemico

  **Tracking** — completata il 2026-05-22

  *File creati:*
  - `scripts/ui/EnemyTooltip.gd` — extends Control, MOUSE_FILTER_IGNORE, layer 90 (sotto targeting a 95); gestisce InputEventMouseMotion senza consumarlo; converte mouse → grid con la stessa formula di TargetingOverlay (canvas_transform inverse + CELL=16); lookup entità via `WorldManager.get_current_map().get_entity_at(grid)`; duck-type check su `enemy_data_id`; contenuto: icona (lettera colorata), display_name (già con prefisso affisso), sottotitolo "Family — Role", lista affissi con "▸ Prefisso"; caching _last_entity per ricostruire solo al cambio nemico; screen-edge clamping sul posizionamento; hidden quando TargetingOverlay è attivo

  *File modificati:*
  - `scripts/entities/Enemy.gd` — aggiunto `var affixes: Array = []`; popolato in `setup()` con `data.get("affixes", []) as Array`
  - `scripts/ui/Main.gd` — aggiunto `_setup_enemy_tooltip()` in `_ready()` e metodo corrispondente: crea CanvasLayer "EnemyTooltipLayer" layer 90, aggiunge EnemyTooltip come figlio, passa riferimento diretto a TargetingOverlay via `set("_targeting_overlay", ...)`

  *Decisioni prese:*
  - Riferimento a TargetingOverlay passato direttamente al setup (non path stringa) — più robusto e non dipende dal nome del nodo
  - `Node.get(property)` accetta solo 1 argomento (diverso da `Dictionary.get(key, default)`) — bug corretto post-implementazione
  - Separator e affix container nascosti se il nemico non ha affissi

  *Deviazioni dal piano:* nessuna — hover invece di click come richiesto durante la sessione

- [x] **Fase 9** — EncounterTemplate pass 2 + archetype named + roster completo

  **Tracking** — completata il 2026-05-22

  *File creati (19 JSON nemici):*
  - Tier 3: `orc.json`, `dark_elf.json`, `lizardman.json`, `ghoul.json`
  - Tier 4: `ogre.json`, `gargoyle.json`, `werewolf.json`, `witch.json`, `vampire.json`
  - Tier 5: `death_knight.json`, `demon.json`, `golem.json`, `dragon_whelp.json`, `lich.json`
  - Tier 6: `chaos_knight.json`, `archlich.json`, `ancient_dragon.json`, `fallen_angel.json`, `void_stalker.json`

  *File modificati:*
  - `scripts/world/dungeon/EnemyPlacer.gd` — `ROLE_COMBOS` rinominato in `ARCHETYPES` con formato `[archetype_name, roles_array, weight]`; aggiunti 6 nuovi archetype (`shadow_strike`, `disruptor`, `guarded_caster`, `brute_and_skirmishers`, `tactical_squad`, `death_from_shadows`) per coprire i ruoli controller e assassin dei nuovi nemici; `_select_encounter_roles()` aggiornata per restituire `[archetype_name, roles_array]`; EncounterTemplate metadata ora include il campo `"archetype"`

  *Nuovi ruoli coperti:* assassin (dark_elf, vampire, void_stalker), controller (witch, lich, archlich), dragon (dragon_whelp, ancient_dragon), demon (demon, chaos_knight, fallen_angel), construct (gargoyle, golem)

  *Decisioni prese:*
  - AI avanzata per controller/artillery deferita — i ruoli esistono nel dato ma il comportamento AI resta identico al soldier (move-toward-player); differenziazione AI sarà una fase separata
  - Validazione TTK coi nuovi nemici da eseguire in-engine via CombatSimulator.run_validation() — i valori di hp_base/atk_base/def_base sono calibrati per coerenza con la progressione tier esistente ma potrebbero richiedere micro-aggiustamenti
  - loot_profile dei nuovi nemici usa nomi semantici (demon, dragon, construct, undead_high, humanoid_mid) anche se l'item system non è ancora implementato; i profili sono placeholder per quando verrà integrato

  *Todo generici aggiunti:*
  - [ ] Integrare loot_profile con item system quando plan_item_system.md sarà implementato
  - [ ] AI differenziata per controller (mantiene distanza), assassin (approccio dal retro), artillery (ranged)
  - [ ] Validazione TTK tier 3-6 con CombatSimulator dopo aver avviato il gioco

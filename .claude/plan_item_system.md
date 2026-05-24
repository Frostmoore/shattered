# Piano: Sistema Oggetti con Affissi (Diablo-style)

**Stato**: Fasi 0–9 complete ✓ — sistema item/loot/UI funzionante e testato. Rimangono solo dipendenze esterne (dungeon generator, key items reali) e opzionali (sotto-filtri consumabili, cap inventario).

> **Catalogo item**: `.claude/items_catalog.md` — lista completa di tutti gli item base per categoria (equipaggiamenti, consumabili, summon). Da consultare durante la Fase 2 per creare i JSON. I Key Item non compaiono nel catalogo: vanno creati a mano uno per uno.

---

## Dipendenze

Il sistema oggetti dipende dal **sistema attributi personaggio** perché:
- `INT` + `WIL` determinano la soglia di auto-identificazione
- `STR`/`DEX`/`INT` determinano i requisiti di equipaggiamento
- I bonus degli affissi si riferiscono agli attributi definitivi

Il sistema dipende anche dal **sistema loot** (da progettare insieme):
- Le leveled drop lists devono conoscere i meta-dati degli item (tier qualità, unicità, slot, affissi possibili)
- I `loot_profile` dei nemici devono mapparsi a file in `data/loot_tables/`

---

## Tier di qualità

| Tier        | Affissi | Colore  | Note                                                             |
|-------------|---------|---------|------------------------------------------------------------------|
| Normale     | 0       | Bianco  | Nessun affisso, stats baked al drop                              |
| Magico      | 1–2     | Blu     | Fino a 1 prefisso + 1 suffisso, rollati all'identificazione      |
| Raro        | 3–4     | Giallo  | Fino a 2 prefissi + 2 suffissi                                   |
| Epico       | 4–5     | Viola   | Fino a 3 prefissi + 2 suffissi                                   |
| Leggendario | 5–6     | Arancio | Fino a 3 prefissi + 3 suffissi (pool esclusivo), scala col pg    |
| Unico       | fissi   | Oro     | Affissi hand-crafted, nome proprio, scala col pg, 1 per dungeon  |

La probabilità di ottenere un tier più alto scala col livello del giocatore (weighted_roll).

---

## Tassonomia tipi di oggetto

### Categorie (`item_category`)

Ogni oggetto appartiene a una delle seguenti categorie di primo livello:

| `item_category` | Descrizione                                          |
|-----------------|------------------------------------------------------|
| `weapon`        | Armi equipaggiabili                                  |
| `armor`         | Armature e protezioni equipaggiabili                 |
| `accessory`     | Accessori equipaggiabili                             |
| `consumable`    | Oggetti usabili che si consumano                     |
| `key_item`      | Oggetti di trama o missione, non droppabili/vendibili|
| `summon`        | Oggetti per evocare pet/compagni (sistema futuro)    |

---

### Armi — `item_type` e slot

| `item_type`       | Slot carattere  | Note                                              |
|-------------------|-----------------|---------------------------------------------------|
| `spada`           | `right_hand`    |                                                   |
| `ascia`           | `right_hand`    |                                                   |
| `mazza`           | `right_hand`    |                                                   |
| `pugnale`         | `right_hand` o `left_hand` | Dual-wield possibile; slot scelto all'equip |
| `bacchetta`       | `right_hand`    | Arma arcana da mano                               |
| `sfera`            | `left_hand`     | Catalizzatore magico off-hand                     |
| `simbolo_sacro`   | `left_hand`     | Catalizzatore divino off-hand                     |
| `totem`           | `left_hand`     | Catalizzatore naturale/sciamanico off-hand        |
| `libro_arcano`    | `left_hand`     | Grimorio off-hand                                 |
| `spadone`         | `both_hands`    | Prende entrambi gli slot mano                     |
| `ascia_bipenne`   | `both_hands`    |                                                   |
| `martello_guerra` | `both_hands`    |                                                   |
| `bastone`         | `both_hands`    | Arma da bastone magica/naturale                   |
| `arco`            | `both_hands`    |                                                   |
| `balestra`        | `both_hands`    |                                                   |
| `lancia`          | `both_hands`    |                                                   |

> **Nota dual-wield**: i `pugnale` con `allowed_slots: ["right_hand", "left_hand"]` possono essere equipaggiati in entrambe le mani. Il check equip verifica solo che `item_type` sia nell'`allowed_item_types` della classe; il giocatore sceglie lo slot.

---

### Armature — `item_type` e slot

| `item_type`        | Slot carattere | Note                                              |
|--------------------|----------------|---------------------------------------------------|
| `armatura_leggera` | `body`         | Cuoio, maglia leggera                             |
| `armatura_media`   | `body`         | Cotta di maglia, lamelle                          |
| `armatura_pesante` | `body`         | Piastre, corazza completa                         |
| `veste`            | `body`         | Abiti arcani, toghe, mantelli                     |
| `elmo`             | `head`         | Copricapi di ogni materiale                       |
| `stivali`          | `feet`         | Calzari e stivali                                 |
| `bracciali`        | `hands`        | Guanti, manopole, bracciali                       |
| `scudo`            | `left_hand`    | Occupa lo slot off-hand                           |

---

### Accessori — `item_type` e slot

| `item_type`  | Slot carattere | Note                                              |
|--------------|----------------|---------------------------------------------------|
| `anello`     | `ring_1` o `ring_2` | Due slot anello distinti sul personaggio    |
| `amuleto`    | `neck`         |                                                   |
| `accessorio` | `trinket`      | Slot generico per oggetti speciali                |

---

### Consumabili — `item_subtype`

I consumabili hanno `item_category: "consumable"` e un campo `item_subtype`:

| `item_subtype` | Esempi                                                    |
|----------------|-----------------------------------------------------------|
| `recupero`     | Pozioni di HP, MP, Stamina                                |
| `cibo`         | Pane, carne essiccata, mela, formaggio — effetti simili al recupero ma con flavor diverso |
| `buff`         | Elisir di forza, pozione di velocità                      |
| `scroll`       | Pergamena di identificazione, teletrasporto, rivelazione  |
| `runa`         | Rune a uso singolo con effetti magici                     |
| `chiave`       | Chiavi per porte e chest bloccate                         |
| `lancio`       | Bombe, fiole acide, granate                               |
| `veleno`       | Veleni da applicare ad arma o da lanciare                 |
| `materiali`    | Pezzi di mostro, ferraglia, rametti, sassetti, rottami — da vendere o usare per crafting futuro |

---

### Slot equipaggiamento sul personaggio (riepilogo)

| Slot ID    | Posizione          | Item types compatibili                                    |
|------------|--------------------|-----------------------------------------------------------|
| `right_hand` | Mano primaria    | spada, ascia, mazza, pugnale, bacchetta                   |
| `left_hand`  | Mano secondaria  | pugnale, sfera, simbolo_sacro, totem, libro_arcano, scudo  |
| `both_hands` | Entrambe le mani | spadone, ascia_bipenne, martello_guerra, bastone, arco, balestra, lancia |
| `body`       | Corpo            | armatura_leggera, armatura_media, armatura_pesante, veste |
| `head`       | Testa            | elmo                                                      |
| `feet`       | Piedi            | stivali                                                   |
| `hands`      | Mani             | bracciali                                                 |
| `ring_1`     | Anello sinistro  | anello                                                    |
| `ring_2`     | Anello destro    | anello                                                    |
| `neck`       | Collo            | amuleto                                                   |
| `trinket`    | Accessorio       | accessorio                                                |

> **Nota `both_hands`**: equipaggiare un'arma a due mani occupa sia `right_hand` che `left_hand`. Il sistema deve liberare lo slot `left_hand` se occupato.

---

## Restrizioni equipaggiamento per classe

Le restrizioni non sono sull'oggetto ma sulla **classe**: ogni classe JSON avrà un campo `allowed_item_types` che elenca esplicitamente i valori `item_type` che quella classe può equipaggiare.

```json
// Esempio — da aggiungere ai file data/classes/*.json
{
  "allowed_item_types": [
    "spada", "ascia", "mazza", "spadone", "ascia_bipenne", "martello_guerra", "lancia",
    "scudo",
    "armatura_leggera", "armatura_media", "armatura_pesante",
    "elmo", "stivali", "bracciali",
    "anello", "amuleto", "accessorio"
  ]
}
```

### Check equip

Al momento dell'equipaggiamento:
```
item.item_type  IN  class.allowed_item_types  →  consentito
```

Eccezioni:
- **Noob** (`special_id: "noob_adaptability"`): il check viene saltato interamente.
- **Unici** con `allowed_classes` esplicito: check aggiuntivo sul nome classe (per armi di trama o lore-locked).

### Generazione orientata alla classe

La specificità di classe è nel **filesystem**, non a runtime: ogni file in `data/loot/{class_id}/` contiene solo oggetti che quella classe può usare. **Nessun drop off-class implicito**: item fuori classe devono essere dichiarati esplicitamente nella loot table — non esiste nessuna logica 70/30 a runtime.

Ogni classe JSON ha un campo `loot_archetype` che raggruppa classi affini:
```json
{ "id": "guerriero", "loot_archetype": "martial", "allowed_item_types": [...] }
```

Il `LootResolver` risolve il path a **3 livelli** di fallback:
```
data/loot/{class_id}/tier{N}/{tipo}.json
  → data/loot/archetypes/{loot_archetype}/tier{N}/{tipo}.json
    → data/loot/default/tier{N}/{tipo}.json
```
Questo permette di scrivere una sola tabella per archetipo (es. `martial` condivisa da Guerriero, Barbaro, Cavaliere) senza duplicare i file per ogni classe.

I vendor possono avere stock fissi indipendenti dalle loot tables.

---

### Lista `allowed_item_types` per classe

> **Universali per tutti**: `elmo`, `stivali`, `bracciali`, `anello`, `amuleto`, `accessorio` — non elencati per brevità.  
> Ogni riga specifica solo: armi ammesse | armatura corpo | scudo (se consentito).  
> `pugnale` in off-hand è implicito per chi ha `pugnale` nella lista (allowed_slots: right+left).

#### Tier 0

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Noob** | *(check saltato — `noob_adaptability`)* | — | — |

#### Tier 1

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Guerriero** | spada, ascia, mazza, spadone, ascia_bipenne, martello_guerra, lancia | leggera, media, pesante | ✓ |
| **Barbaro** | ascia, ascia_bipenne, martello_guerra, spadone, mazza, spada | leggera, media, pesante | — |
| **Ladro** | pugnale | leggera | — |
| **Mago** | bacchetta, sfera, libro_arcano, bastone | veste | — |
| **Druido** | bastone, totem | leggera, veste | — |
| **Monaco** | pugnale, bastone | leggera | — |
| **Negromante** | bacchetta, bastone, libro_arcano, sfera | veste | — |
| **Paladino** | spada, mazza, simbolo_sacro | leggera, media, pesante | ✓ |
| **Ranger** | arco, balestra, pugnale, spada | leggera, media | — |
| **Stregone** | bacchetta, sfera, bastone, libro_arcano | veste | — |
| **Bardo** | spada, pugnale, bacchetta | leggera | — |
| **Alchimista** | pugnale, bacchetta | leggera, veste | — |

#### Tier 2

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Assassino** | pugnale, spada | leggera | — |
| **Biomante** | mazza, simbolo_sacro, bastone | leggera, media, veste | — |
| **Cacciatore di Taglie** | arco, balestra, pugnale, spada | leggera, media | — |
| **Cavaliere** | spada, lancia | media, pesante | ✓ |
| **Gladiatore** | spada, ascia, mazza | media, pesante | ✓ |
| **Inventore** | pugnale, bacchetta | leggera | — |
| **Sacerdote** | mazza, simbolo_sacro, bastone | leggera, media, veste | ✓ |
| **Sciamano** | totem, bastone | leggera, veste | — |
| **Templare** | spada, mazza, simbolo_sacro | media, pesante | ✓ |

#### Tier 3

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Arcanista** | bacchetta, sfera, libro_arcano, bastone | veste | — |
| **Arciere** | arco, balestra, pugnale | leggera, media | — |
| **Berserker** | ascia, ascia_bipenne, martello_guerra, spadone, mazza | leggera, media | — |
| **Cacciatore di Draghi** | spada, lancia, spadone | media, pesante | ✓ |
| **Corsaro** | spada, pugnale | leggera, media | ✓ |
| **Cronomante** | bacchetta, sfera, bastone | veste | — |
| **Custode** | mazza, simbolo_sacro | media, pesante | ✓ |
| **Demonista** | libro_arcano, bacchetta, bastone | veste | — |
| **Esploratore** | arco, pugnale | leggera | — |
| **Evocatore** | bastone, sfera, totem | veste | — |
| **Geomante** | bastone, totem | leggera, veste | — |
| **Illusionista** | bacchetta, sfera | veste | — |
| **Inquisitore** | spada, mazza, simbolo_sacro | leggera, media | — |
| **Mannaro** | ascia, pugnale | leggera | — |
| **Oracolo** | simbolo_sacro, bacchetta | veste | — |
| **Piromante** | bacchetta, sfera, bastone | veste | — |
| **Predatore** | pugnale, arco | leggera | — |
| **Sentinella** | spada, lancia | media, pesante | ✓ |
| **Spellblade** | spada, sfera, libro_arcano | leggera, media | — |
| **Strega** | bacchetta, bastone, sfera | veste | — |
| **Vampiro** | pugnale, spada | leggera | — |
| **Viandante** | pugnale, arco | leggera | — |

#### Tier 4

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Arcicacciatore** | arco, balestra, pugnale | leggera | — |
| **Arcimago** | bacchetta, sfera, libro_arcano, bastone | veste | — |
| **Cacciatore di Anime** | spada, pugnale, bastone | leggera, veste | — |
| **Campione** | spada, simbolo_sacro | media, pesante | ✓ |
| **Colosso** | martello_guerra, ascia_bipenne, spadone | pesante | ✓ |
| **Dio della Guerra** | spada, ascia, spadone, ascia_bipenne, martello_guerra | media, pesante | — |
| **Dominatore** | bacchetta, sfera | veste | — |
| **Lich** | bastone, libro_arcano, sfera | veste | — |
| **Maestro del Tempo** | bacchetta, sfera, bastone | veste | — |
| **Spettro** | pugnale | veste | — |

#### Tier 5

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **L'Eletto** | *(tutti i tipi — prescelta degli dei)* | *(tutti)* | ✓ |
| **Morte Incarnata** | lancia, spadone, ascia_bipenne | veste | — |
| **Paradosso** | *(tutti — effetti caotici)* | *(tutti)* | ✓ |
| **Specchio dell'Abisso** | sfera | veste | — |
| **Il Vuoto** | sfera | veste | — |

#### Tier 6

| Classe | Armi | Armatura corpo | Scudo |
|--------|------|----------------|-------|
| **Divinità** | *(tutti — god mode)* | *(tutti)* | ✓ |

---

## Ciclo di vita di un'istanza item

### Al drop (chest o nemico)
Viene generato solo lo "scheletro" dell'oggetto — gli affissi NON vengono rollati:
```
instance_id  = generate_uid()
base_id      = id del template base
quality      = weighted_roll(player_level)
affix_seed   = rng.randi()   ← seme deterministico, usato all'identificazione
identified   = false
```
Salvato così com'è. Non viene mai rigenerato.

### All'identificazione
Il `affix_seed` viene usato per rollare deterministicamente gli affissi:
```
→ roll affissi eleggibili per item_type, livello, qualità (usando affix_seed)
→ componi nome: NomeBase [Prefisso_display] [Suffisso_display] — tutti dopo il nome (italiano)
→ bake stats: base_stats + somma bonus affissi
→ identified = true
```
> **Nota**: in italiano l'aggettivo va dopo il sostantivo. Tutti gli affissi — sia prefissi che suffissi — vengono appesi dopo il nome base. Es: "Spada Corta Affilata della Velocità", non "Affilata Spada Corta della Velocità".

### Persistenza post-identificazione

**Normali / Magici / Rari / Epici**: le stats sono "baked" e salvate as-is.  
Non vengono mai ricalcolate. Quello che c'è scritto è quello per sempre.

**Leggendari / Unici**: NON si salvano le stats baked.  
Si salva solo `{instance_id, base_id/unique_id, identified}`.  
Le stats vengono ricalcolate da template + `GameState.level` ad ogni caricamento.  
Un Leggendario trovato al livello 5 e riequipaggiato al livello 50 sarà molto più forte.

---

## Struttura file — `data/`

### Item (uno per file, come nemici e classi)
```
data/items/
  weapons/
    primary/        spada_corta.json, ascia.json, mazza.json, pugnale.json, bacchetta.json, …
    secondary/      pugnale_serrato.json, sfera_arcano.json, simbolo_sacro.json, totem.json, …
    twohanded/      spadone.json, ascia_bipenne.json, bastone.json, arco_lungo.json, balestra.json, …
  armor/
    light/          armatura_cuoio.json, giubba_cuoio.json, …
    medium/         cotta_maglia.json, corazza_lamelle.json, …
    heavy/          corazza_ferro.json, piastre_acciaio.json, …
    cloth/          veste_arcana.json, toga_sacerdotale.json, …
    helms/          cappuccio_cuoio.json, elmo_ferro.json, …
    boots/          stivali_cuoio.json, stivali_ferro.json, …
    shields/        scudo_legno.json, scudo_ferro.json, …
    bracers/        bracciali_cuoio.json, guanti_ferro.json, …
  accessories/
    rings/          anello_base.json, …
    amulets/        amuleto_base.json, …
    trinkets/       ciondolo_base.json, …
  consumables/
    recupero/       pozione_piccola.json, pozione_mana.json, benda.json, …
    cibo/           pane.json, carne_essiccata.json, mela.json, formaggio.json, …
    buff/           elisir_forza.json, pozione_velocita.json, …
    scrolls/        pergamena_identificazione.json, pergamena_teletrasporto.json, …
    rune/           runa_fuoco.json, runa_gelo.json, …
    keys/           chiave_comune.json, chiave_maestra.json, …
    throwable/      bomba.json, fiala_acida.json, …
    poison/         veleno_base.json, veleno_paralizzante.json, …
    materiali/      artiglio_goblin.json, pezzo_ferraglia.json, rametto.json, …
  key_items/
    …
  summon/
    …
  uniques/
    spada_dell_alba.json, anello_del_vuoto.json, …
```

### Schema item — equipaggiamento
```json
{
  "id": "spada_corta",
  "name": "Spada Corta",
  "gender": "f",
  "item_category": "weapon",
  "item_type": "spada",
  "slot": "right_hand",
  "tier": 1,
  "min_level": 1,
  "max_level": 10,
  "base_stats": { "attack_bonus": 3 },
  "requirements": { "str": 5 },
  "scalable": false,
  "loot_weight": 20
}
```

Per armi dual-slot (pugnale):
```json
{
  "id": "pugnale",
  "item_type": "pugnale",
  "allowed_slots": ["right_hand", "left_hand"],
  ...
}
```

Per Leggendari/Unici, `"scalable": true` con la formula di scaling nel campo `scale`.

### Schema item — consumabile
```json
{
  "id": "pozione_piccola",
  "name": "Pozione Piccola",
  "gender": "f",
  "item_category": "consumable",
  "item_subtype": "recupero",
  "effect": { "restore_hp": 20 },
  "stackable": true,
  "loot_weight": 40
}
```

### Schema item — key item
```json
{
  "id": "sigillo_del_dungeon",
  "name": "Sigillo del Dungeon",
  "gender": "m",
  "item_category": "key_item",
  "droppable": false,
  "sellable": false,
  "description": "Un antico sigillo che apre la porta del boss."
}
```

### Schema item — summon
```json
{
  "id": "fischietto_corvo",
  "name": "Fischietto del Corvo",
  "gender": "m",
  "item_category": "summon",
  "pet_id": "corvo",
  "stackable": false,
  "loot_weight": 5
}
```

### Schema unico
```json
{
  "id": "spada_dell_alba",
  "name": "Spada dell'Alba",
  "gender": "f",
  "item_category": "weapon",
  "item_type": "spada",
  "slot": "right_hand",
  "scalable": true,
  "scaling_mode": "threshold",
  "scale_levels": [1, 10, 20, 35, 50],
  "scale": { "attack_bonus": "2 + floor(level / 10) * 3" },
  "fixed_affixes": ["affilato", "infuocato"],
  "lore": "Forgiata all'alba dei tempi…",
  "flavor": "Brucia ancora"
}
```

**Modalità di scaling** (`scaling_mode`):

| Valore | Comportamento |
|--------|---------------|
| `full` | Scala linearmente col livello — può diventare best-in-slot permanente |
| `partial` | Scala parzialmente: aggiunge `scale_factor` (0.0–1.0) dei bonus di livello. Es. 0.65 = 65% dello scaling pieno |
| `threshold` | Scala solo ai livelli definiti in `scale_levels` — salti netti, non crescita continua |

`partial` richiede `scale_factor`. `threshold` richiede `scale_levels`. `full` non richiede campi aggiuntivi.

**Regola**: Unici e Leggendari con `scaling_mode: "full"` devono essere rari e giustificati — il rischio è che il giocatore non cambi mai equip. Preferire `threshold` o `partial`.

### Affissi item (uno per file, distinti dagli affissi nemici)
```
data/item_affixes/
  prefixes/
    offensive/    affilato.json, potenziato.json, …
    defensive/    resistente.json, corazzato.json, …
    magical/      arcano.json, mistico.json, …
  suffixes/
    offensive/    della_furia.json, del_predatore.json, …
    defensive/    della_roccia.json, del_baluardo.json, …
    …
```

Schema affisso:
```json
{
  "id": "affilato",
  "type": "prefix",
  "name_m": "Affilato",
  "name_f": "Affilata",
  "affix_category": "offensive",
  "allowed_item_types": ["spada", "ascia", "mazza", "pugnale", "spadone", "ascia_bipenne", "martello_guerra"],
  "min_level": 1,
  "min_quality": "magico",
  "allowed_tiers": ["magico", "raro", "epico"],
  "weight": 20,
  "bonuses": { "attack_bonus": 2 }
}
```

> **Nota**: il campo degli affissi è ora `allowed_item_types` (non `allowed_slots`) per coerenza con il resto del sistema.

### Leveled drop lists

```
data/loot/
  {class_id}/          override specifico per classe (es. guerriero/, mago/) — solo se diverso dall'archetipo
    tier1/ … tier6/
  archetypes/          tabelle condivise tra classi affini
    martial/           → usato da Guerriero, Barbaro, Cavaliere, ecc.
    arcane/            → Mago, Stregone, Arcanista, Negromante, ecc.
    divine/            → Paladino, Sacerdote, Templare, Custode, ecc.
    ranger/            → Ranger, Arciere, Cacciatore di Taglie, ecc.
    rogue/             → Ladro, Assassino, Bardo, Corsaro, ecc.
    …
    tier1/ … tier6/    (dentro ogni archetipo)
  default/             fallback finale se manca sia la classe che l'archetipo
    tier1/ … tier6/
```

Ogni file contiene **solo oggetti utilizzabili dalle classi di quell'archetipo** — la specificità è nel filesystem, non a runtime. **Nessun drop off-class implicito**.

I nomi file in `enemies/` corrispondono 1:1 al campo `loot_profile` nei JSON dei nemici.  
`chest_variant` è una chiave dentro `chest.json` (non una sottocartella).  
Risoluzione path a 3 livelli: `{class_id}/ → archetypes/{loot_archetype}/ → default/`

---

### Sistema importanza chest

Ogni chest ha due proprietà che determinano il loot:

**`chest_tier`** (int 1–6): deriva dal livello del dungeon corrente, determina quale sottocartella `tier{N}/` usare.

**`chest_variant`** (string): determina quale chiave leggere dentro `chest.json`.

| Variante | Peso spawn | Rolls | Quality bias | Note |
|----------|-----------|-------|--------------|------|
| `comune` | 65% | 1–2 | nessuno | Chest standard |
| `ricca` | 20% | 2–3 | nessuno | Più oggetti |
| `abbondante` | 10% | 3–4 | +1 tier | Più oggetti e migliori |
| `boss` | — | 4–6 | +2 tier | Piazzata esplicitamente dal generatore vicino al boss; garantisce almeno 1 item Raro+ |
| `segreto` | — | 3–5 | +2 tier | In stanze segrete; garantisce almeno 1 item Epico+, gold bonus |

`comune`, `ricca`, `abbondante` vengono rollate al momento dello spawn della chest (weighted roll).  
`boss` e `segreto` sono piazzate deterministicamente dal generatore di dungeon — non vengono mai rollate casualmente.

**Quality bias**: quando `quality_bias > 0`, il `weighted_roll(player_level)` per la qualità dell'item viene spostato verso l'alto di N tier. Esempio: con bias +1, un roll che normalmente produce Normale produce Magico.

Il resolver carica `data/loot/{class_id}/tier{chest_tier}/chest.json`, legge la chiave `{chest_variant}` per roll e bias, e usa il `level_bands` condiviso nello stesso file.

---

### Sistema Drop Budget

Le loot tables rollano in modo indipendente per default, il che può produrre dungeon troppo poveri o troppo generosi per pura varianza. Il **Drop Budget** introduce un vincolo a monte: il dungeon ha un budget totale di loot atteso, e il resolver lo consuma invece di rollare nel vuoto.

Il budget **non blocca i drop** — li orienta. Se il budget equip è esaurito, le entry `item_category: weapon/armor` del pool vengono saltate o convertite in consumabili/oro. Questo garantisce distribuzione uniforme senza togliere la sorpresa roll-per-roll.

**Schema `DungeonLootBudget`** (uno per dungeon, calcolato alla generazione):
```json
{
  "dungeon_id": "dungeon_01",
  "expected_gold":         { "min": 120, "max": 200 },
  "expected_consumables":  8,
  "expected_equipment":    2,
  "expected_magic_plus":   1,
  "guaranteed_rewards": [
    { "item_category": "weapon", "min_quality": "raro", "floor": "boss" }
  ],
  "unique_allowed": true,
  "unique_max": 1
}
```

**Schema `FloorLootBudget`** (uno per piano, derivato dal DungeonLootBudget):
```json
{
  "floor_index": 2,
  "budget_share":   0.25,
  "chest_budget":   0.50,
  "enemy_budget":   0.35,
  "ground_budget":  0.15
}
```
`budget_share` è la quota del budget totale del dungeon assegnata a questo piano (es. il piano boss prende quota maggiore). `chest_budget`, `enemy_budget`, `ground_budget` dividono ulteriormente il budget del piano tra le fonti.

Il `LootResolver` riceve il budget corrente come parte del `drop_context` e decrementa i contatori a ogni drop generato.

---

### Struttura loot table — formato dettagliato

Il pool non è piatto: ogni tabella usa **level bands**. Il `LootResolver` seleziona la banda con `level_min ≤ player_level ≤ level_max`. Se nessuna banda fa match si usa l'ultima. Non ci devono essere buchi o sovrapposizioni tra bande.

**Perché level bands invece di filtri `min_level` per entry:**
- Esplicito: si sa esattamente cosa può droppare a ogni livello
- Item comuni a bassi livelli spariscono semplicemente non includendoli nelle bande successive
- I pesi hanno senso localmente — non si deve ribilanciare tutto ogni volta che si aggiunge un item

**Formato entry pool:**

| Campo | Obbligatorio | Descrizione |
|-------|-------------|-------------|
| `item_id` | uno tra questi | ID template specifico da droppare |
| `item_category` | uno tra questi | Categoria generica — il resolver pesca un item dal pool della classe (dal path) |
| `type: "gold"` | uno tra questi | Drop oro; richiede `min`/`max` |
| `nothing: true` | uno tra questi | Nessun drop (entry vuota) |
| `weight` | Sì | Peso relativo nel pool della banda |
| `min_quality` | No | Qualità minima per questa entry (override su quality_bias) |

Quando si usa `item_category`, il resolver pesca dalla `ItemDB` filtrando per `item.min_level ≤ player_level ≤ item.max_level`. **Nessun drop off-class implicito**: il pool è già classe-specifico per via del path. Item fuori classe si dichiarano esplicitamente con `item_id`.

**`rarity_policy`** (opzionale, a livello di intera loot table):
```json
"rarity_policy": {
  "allow_unique": false,
  "allow_legendary": true,
  "max_quality": "epico"
}
```
Usato per limitare la qualità massima ottenibile da una fonte specifica — es. enemy scarsi, ground loot, chest comuni. Se assente, non ci sono limiti salvo il `quality_bias` e il `weighted_roll` standard.

---

### Schema loot table — nemico
`data/loot/guerriero/tier1/enemies/humanoid_low.json`
```json
{
  "rolls": 1,
  "quality_bias": 0,
  "guaranteed": [],
  "level_bands": [
    {
      "level_min": 1,
      "level_max": 10,
      "pool": [
        { "item_id": "spada_corta",              "weight": 25 },
        { "item_id": "coltello_arrugginito",     "weight": 25 },
        { "item_id": "mazza_rozza",              "weight": 20 },
        { "item_id": "pergamena_identificazione","weight":  8 },
        { "item_id": "pozione_piccola",          "weight": 15 },
        { "type": "gold", "min": 1, "max": 6,   "weight": 40 },
        { "nothing": true,                       "weight": 30 }
      ]
    },
    {
      "level_min": 11,
      "level_max": 25,
      "pool": [
        { "item_id": "spada_lunga",              "weight": 20 },
        { "item_id": "ascia_da_guerra",          "weight": 20 },
        { "item_id": "mazza_ferrata",            "weight": 18 },
        { "item_id": "coltello_arrugginito",     "weight":  8 },
        { "item_id": "pergamena_identificazione","weight": 12 },
        { "item_id": "pozione_piccola",          "weight": 15 },
        { "type": "gold", "min": 5, "max": 20,  "weight": 35 },
        { "nothing": true,                       "weight": 20 }
      ]
    },
    {
      "level_min": 26,
      "level_max": 999,
      "pool": [
        { "item_id": "spada_temprata",           "weight": 18 },
        { "item_id": "ascia_pesante",            "weight": 16 },
        { "item_id": "mazza_d_acciaio",          "weight": 16 },
        { "item_id": "pergamena_identificazione","weight": 15 },
        { "item_id": "pozione_media",            "weight": 15 },
        { "type": "gold", "min": 15, "max": 50, "weight": 30 },
        { "nothing": true,                       "weight": 12 }
      ]
    }
  ]
}
```

`spada_corta` e `coltello_arrugginito` compaiono solo nelle prime due bande — a livelli alti spariscono. I pesi sono relativi alla banda: il resolver somma tutti i pesi e fa un weighted pick.

---

### Schema loot table — chest
`data/loot/guerriero/tier2/chest.json`

Tutte e 5 le varianti sono chiavi nello stesso file. Il `level_bands` è condiviso — il resolver legge la variante per roll/bias, poi usa il pool comune.

```json
{
  "comune":    { "rolls_min": 1, "rolls_max": 2, "quality_bias": 0, "guaranteed": [] },
  "ricca":     { "rolls_min": 2, "rolls_max": 3, "quality_bias": 0, "guaranteed": [] },
  "abbondante":{ "rolls_min": 3, "rolls_max": 4, "quality_bias": 1, "guaranteed": [] },
  "boss":      {
    "rolls_min": 4, "rolls_max": 6, "quality_bias": 2,
    "guaranteed": [{ "item_category": ["weapon", "armor"], "min_quality": "raro" }]
  },
  "segreto":   {
    "rolls_min": 3, "rolls_max": 5, "quality_bias": 2,
    "guaranteed": [{ "item_category": "accessory", "min_quality": "epico" }]
  },
  "level_bands": [
    {
      "level_min": 1,
      "level_max": 20,
      "pool": [
        { "item_id": "spada_lunga",              "weight": 20 },
        { "item_id": "cotta_maglia",             "weight": 18 },
        { "item_category": "accessory",          "weight": 12 },
        { "item_id": "pergamena_identificazione","weight": 12 },
        { "item_id": "pozione_piccola",          "weight": 18 },
        { "type": "gold", "min": 15, "max": 50,  "weight": 28 },
        { "nothing": true,                        "weight": 10 }
      ]
    },
    {
      "level_min": 21,
      "level_max": 999,
      "pool": [
        { "item_category": "weapon",             "weight": 22 },
        { "item_category": "armor",              "weight": 22 },
        { "item_category": "accessory",          "weight": 15 },
        { "item_id": "pergamena_identificazione","weight": 10 },
        { "item_id": "pozione_media",            "weight": 14 },
        { "type": "gold", "min": 40, "max": 120, "weight": 22 },
        { "nothing": true,                        "weight":  8 }
      ]
    }
  ]
}
```

La variante `boss` non ha `nothing` nel pool — chi piazza una boss chest si assicura che droppi sempre qualcosa. Il `guaranteed` viene risolto prima dei roll casuali, come roll aggiuntivo non scalato da `rolls_min`/`rolls_max`.

---

### Schema loot table — ground
`data/loot/guerriero/tier1/ground.json`

Oggetti trovabili sul pavimento di qualsiasi area — dungeon, villaggi, edifici, overworld. Non provengono da chest né da nemici. Stessa struttura delle enemy table ma senza `guaranteed`. La frequenza di spawn è calibrata nell'area/generatore, non nel file.

```json
{
  "rolls": 1,
  "quality_bias": 0,
  "level_bands": [
    {
      "level_min": 1,
      "level_max": 999,
      "pool": [
        { "item_id": "pozione_piccola",          "weight": 30 },
        { "item_id": "pergamena_identificazione","weight": 15 },
        { "item_category": "weapon",             "weight": 10 },
        { "type": "gold", "min": 1, "max": 10,  "weight": 25 },
        { "nothing": true,                       "weight": 40 }
      ]
    }
  ]
}
```

---

### Regole di bilanciamento loot

#### Drop da nemici — principio di base

Le loot tables dei nemici devono essere **principalmente vuote**. Non ogni nemico deve droppare qualcosa — trovare un drop deve sembrare significativo.

| Tipo nemico | Può droppare oro? | Può droppare armi/armature? | Può droppare materiali? | Note |
|-------------|-------------------|-----------------------------|-------------------------|------|
| **Umanoidi** (humanoid_*) | ✓ | ✓ | ✓ pezzi di equipaggiamento rotti | Hanno inventario come il giocatore |
| **Bestie** (beast_*) | — | — | ✓ pelle, artigli, ossa, carne | Nessun lupo ha mangiato un anello |
| **Non morti** (undead_*) | — | — | ✓ ossa, bende, polvere | Possibilmente qualche oggetto antico rotto |
| **Costrutti** (construct) | — | — | ✓ ingranaggi, cristalli, metallo | Pezzi meccanici |
| **Draghi** | — | ✓ rarissimo (squame come armatura?) | ✓ squame, denti, sangue | Solo drop di lusso/tematici |
| **Demoni** | — | ✓ rarissimo | ✓ essenza, corno, artiglio | |
| **Aberrazioni** | — | — | ✓ carne mutata, occhi, tentacoli | |

#### Distribuzione peso `nothing`

Come regola generale per enemy tables:
- **Livelli bassi (tier 1–2)**: `nothing` ~50–60% del pool totale
- **Livelli medi (tier 3–4)**: `nothing` ~35–45%
- **Livelli alti (tier 5–6)**: `nothing` ~20–30%

Il peso `nothing` diminuisce col livello ma non sparisce mai del tutto.

#### Chest — sempre qualcosa

Le chest non devono mai essere completamente vuote. Il pool deve garantire almeno:
- Oro (anche poco) come fallback minimo per `comune` e `ricca`
- Almeno un item per `abbondante`, `boss`, `segreto`

Il `nothing` nelle chest è solo un margine tecnico minore (≤ 10%) o assente.

#### Materiali commestibili

Alcuni `materiali` (pezzi di mostro) sono commestibili e devono avere un corrispettivo in `item_subtype: "cibo"` nel catalogo. Esempi: coscia di lupo, fegato di goblin, uova di ragno. Un mostro non droppa l'item cibo direttamente — droppa il `materiale` greggio; la versione cibo si ottiene cucinando (sistema futuro) oppure il materiale è già elencato in `cibo` se può essere mangiato crudo.

---

### drop_context

Il resolver riceve un unico dizionario invece di parametri sciolti:
```gdscript
var ctx = {
  "source_type":   "enemy",          # "enemy" | "chest" | "ground"
  "source_id":     "goblin",         # id specifico del nemico/chest
  "loot_profile":  "humanoid_low",   # profilo loot (per enemy)
  "chest_variant": "comune",         # variante chest (per chest)
  "area_type":     "dungeon",        # "dungeon" | "village" | "building" | "overworld"
  "dungeon_id":    "dungeon_01",
  "floor":         2,
  "player_class":  "guerriero",
  "player_level":  12,
  "world_seed":    "abc123",
  "character_id":  "char_01",
  "floor_budget":  floor_budget_ref  # riferimento al FloorLootBudget corrente
}
LootResolver.resolve(ctx)
```

---

### Algoritmo LootResolver (pseudocodice)

```
function resolve(ctx: Dictionary) -> Array:
  tier   = floor(ctx.floor / 10) + 1  # clamped 1–6
  class  = ctx.player_class
  archetype = ClassDB.get(class).loot_archetype

  # Risoluzione path a 3 livelli
  type = get_type_path(ctx)   # es. "enemies/humanoid_low" | "chest" | "ground"
  path = try_path([
    "data/loot/{class}/tier{tier}/{type}.json",
    "data/loot/archetypes/{archetype}/tier{tier}/{type}.json",
    "data/loot/default/tier{tier}/{type}.json"
  ])
  table = JSON.parse(path)

  # rarity_policy dalla tabella (se presente)
  policy = table.get("rarity_policy", {})

  # Per chest: params dalla variante
  if ctx.source_type == "chest":
    params = table[ctx.chest_variant]
  else:
    params = table

  band = pick_band(table.level_bands, ctx.player_level)   # fallback = ultima banda
  budget = ctx.get("floor_budget")

  drops = []

  # Guaranteed — roll aggiuntivi, non contano nei rolls_min/rolls_max
  for g in params.get("guaranteed", []):
    item = ItemDB.pick_random(g.item_category, ctx.player_level, g.get("min_quality"))
    drops.append(ItemGenerator.drop(item.id, ctx.player_level, rng))
    if budget: budget.consume("equipment")

  # Roll casuali
  roll_count = randi_range(params.get("rolls_min", params.get("rolls", 1)),
                            params.get("rolls_max", params.get("rolls", 1)))
  for i in roll_count:
    entry = weighted_pick(band.pool)
    if   entry.get("nothing"):           continue
    elif entry.get("type") == "gold":
      if budget and budget.gold_exhausted(): continue
      drops.append({ "type": "gold", "amount": randi_range(entry.min, entry.max) })
      if budget: budget.consume("gold", amount)
    elif entry.get("item_id"):
      item = ItemGenerator.drop(entry.item_id, ctx.player_level, rng)
      if policy and not policy_allows(item, policy): continue
      if budget and budget.equipment_exhausted(): continue
      drops.append(item)
      if budget: budget.consume("equipment")
    elif entry.get("item_category"):
      if budget and budget.exhausted_for(entry.item_category): continue
      base = ItemDB.pick_random(entry.item_category, ctx.player_level)
      item = ItemGenerator.drop(base.id, ctx.player_level, rng)
      if policy and not policy_allows(item, policy): continue
      drops.append(item)
      if budget: budget.consume(entry.item_category)

  return drops
```

`policy_allows(item, policy)` verifica `max_quality`, `allow_unique`, `allow_legendary` contro la qualità dell'item generato.

---

## Identificazione e classi

La soglia di auto-identificazione al pickup usa `INT + WIL`:

| Qualità     | INT+WIL minimo |
|-------------|----------------|
| Normale     | 0 (sempre)     |
| Magico      | 10             |
| Raro        | 24             |
| Epico       | 40             |
| Leggendario | 60             |
| Unico       | 70             |

*(Valori da calibrare dopo aver testato la curva attributi — classi "studiose" come Mago, Negromante, Arcanista avranno INT+WIL molto più alti di un Guerriero o Barbaro)*

**Metodi alternativi di identificazione:**
- Pergamena di identificazione: consumabile `effect: { "identify": true }`
- Vendor: identifica in cambio di oro

---

## Fase 0 — Sistema Attributi (COMPLETATA)

- [x] Attributi: STR, DEX, INT, VIT, WIL
- [x] Formule HP/MP/Stamina/ATK/DEF
- [x] Integrazione Player.gd + GameState
- [x] Salvataggio/caricamento
- [x] Level-up automatico
- [x] UI StatusScreen (tasto C)

---

## Fase 1 — Data Layer: Autoload DB ✓

- [x] `ItemDB.gd` (autoload): scansione ricorsiva di `data/items/`, indicizza per `id`, per `item_type`, per `slot`; compatibile con vecchio formato array flat; aggiunto `get_by_type()`, `get_by_slot()`, `pick_random()`
- [x] `ItemAffixDB.gd` (autoload): scansione ricorsiva di `data/item_affixes/`, indicizza per `id`, `allowed_item_types`, categoria; espone `get_eligible(item_type, level, quality)`
- [x] `LootTableDB.gd` (autoload): caricamento lazy on demand con cache; espone `get_enemy()`, `get_chest()`, `get_ground()` con fallback automatico su `archetypes/{archetype}` → `default/`

---

## Fase 2 — Vertical Slice (smoke test del ciclo completo) ✓

**Dataset minimo:**
- 1 classe: Guerriero (con `allowed_item_types` e `loot_archetype: "martial"`)
- 5 item base: `spada_corta`, `armatura_cuoio`, `pozione_piccola`, `anello_base`, `pugnale`
- 4 affissi: 2 prefissi (es. `affilato`, `pesante`) + 2 suffissi (es. `della_guarigione`, `della_velocita`)
- 1 consumabile: `pergamena_identificazione`
- 1 unico: `spada_dell_alba` (con `scaling_mode: "threshold"`)
- `data/loot/archetypes/martial/tier1/enemies/humanoid_low.json`
- `data/loot/archetypes/martial/tier1/chest.json` (tutte e 5 le varianti)
- `data/loot/archetypes/martial/tier1/ground.json`

**Ciclo da testare end-to-end:**
```
nemico muore → drop_context → LootResolver → LootScreen → pickup
  → Inventory → identify → equip → save/load → reload → stats corrette
```

- [x] Aggiungere `allowed_item_types` e `loot_archetype` al JSON Guerriero
- [x] Creare i 5 item JSON + 4 affissi + 1 consumabile + 1 unico
- [x] Creare i 3 file loot in `archetypes/martial/tier1/`
- [x] Implementare `ItemGenerator.drop()` e `ItemGenerator.identify()`
- [x] Implementare `LootResolver.resolve(ctx)` (versione senza budget — budget = null skip)
- [x] Implementare `LootScreen` grezza funzionante (autoload CanvasLayer, grid + tooltip + take-all)
- [x] Collegare `Enemy.die()` → LootResolver → loot su cadavere → LootScreen via interact
- [x] Collegare `Chest.interact()` → LootResolver → LootScreen
- [x] **Da testare in Godot**: save/load con un Leggendario — verificare che stats riscalino al reload ✓
- [x] **Da testare in Godot**: identificazione deterministica — stesso `affix_seed` → stessi affissi ✓

> **Note implementazione**: LootScreen è un autoload CanvasLayer (layer 80). Il loot dei cadaveri viene generato in `Enemy._generate_loot()` e salvato su `BaseMap._corpse_loot[pos]`. Il giocatore interagisce con la tile cadavere (E/spazio) per aprire la schermata. `Inventory.add_item_instance()` gestisce sia stackabili che istanze unique.

---

## Fase 3 — Validatori JSON ✓

Script GDScript da eseguire in editor (tool script, **File > Run Script**) per verificare la coerenza di tutti i dati prima di scriverne centinaia. Tutti in `scripts/tools/validators/`.

- [x] **`validate_items.gd`**:
  - [x] `item_id` unici nel database (scansione ricorsiva `data/items/` + legacy `items.json`)
  - [x] `item_category` in lista valida (weapon/armor/accessory/consumable/key_item/class_license)
  - [x] `item_type` in lista dei 27 tipi validi, coerente con `item_category`
  - [x] Slot presente per tutti gli equipaggiabili (salvo `both_hands`)
  - [x] `scalable: true` → `scale` e `scaling_mode` presenti
  - [x] `quality_override` in lista qualità valide
  - [x] Consumabili hanno `effect`
  - [x] Key items: warn se mancano `droppable: false` / `sellable: false`
  - [x] Legacy items.json: type in [equipment/consumable/class_license], equipment ha slot, consumable ha effect

- [x] **`validate_affixes.gd`**:
  - [x] `id` unici in `data/item_affixes/`
  - [x] `type` è "prefix" o "suffix"
  - [x] `allowed_item_types` presente, non vuoto, tutti valori in lista 27 tipi
  - [x] `allowed_tiers` presente, non vuoto, tutti in [magico/raro/epico/leggendario]
  - [x] `bonuses` presente e non vuoto
  - [x] Warn se `weight` ≤ 0 (affix mai droppato) o `min_level` mancante

- [x] **`validate_loot_tables.gd`**:
  - [x] Level bands senza buchi: `level_min` di banda N = `level_max` di banda N-1 + 1
  - [x] Ultima banda termina a 999
  - [x] Ogni `item_id` nel pool esiste tra gli item conosciuti
  - [x] chest.json ha tutte e 5 le varianti con `rolls_min/max` e `guaranteed` array
  - [x] Warn se `nothing` weight > 10 (solo chest, non enemy/ground)

- [x] **`validate_classes.gd`**:
  - [x] `id` letto da ogni JSON, Noob verificato con early return
  - [x] Noob ha `special_id: "noob_adaptability"`
  - [x] Tutte le classi non-Noob hanno `allowed_item_types` (non vuoto)
  - [x] Tutti i valori in `allowed_item_types` sono in lista 27 tipi
  - [x] `loot_archetype` presente e referenzia cartella esistente in `data/loot/archetypes/`
  - [x] Warn se mancano `tier`, `growth`, `special_id`, `unlock`

---

## Fase 4 — Data Layer Completo

Con il ciclo validato dalla Fase 2 e i validatori della Fase 3, creare tutti i dati.

**Item:**
- [x] Aggiungere `allowed_item_types` e `loot_archetype` ai JSON di tutte le 61 classi (incluse cartelle archetipo arcane/divine/ranger/rogue create)
- [x] Creare tutti gli item JSON per categoria — riferimento: `.claude/items_catalog.md` (682 item: 159 armi, 223 armature, 98 accessori, 195 consumabili, 6 unici + 1 legacy spada_dell_alba)
- [x] Creare set completo di affissi — 48 file: 22 prefissi (offensive/defensive/magical) + 26 suffissi (offensive/defensive/magical)
- [x] Creare tutti i consumabili (195: recupero/cibo/buff/scrolls/rune/chiavi/lancio/veleni/materiali)
- [x] Creare i pezzi di mostro commestibili come item `cibo` (7 item: coscia_lupo, carne_cinghiale, fegato_goblin, bistecca_troll, carne_drago, uova_ragno, carne_ratto)
- [x] Creare unici e leggendari con `scaling_mode` appropriato (6: spada_dell_alba, anello_del_tempo, veste_degli_abissi, ascia_del_mannaro, cuore_della_divinita, codex_del_vuoto)

**Loot Tables:**
- [x] Creare `data/loot/default/` tier 1–6 completi (fallback finale)
- [x] Creare `data/loot/archetypes/{martial|arcane|divine|ranger|rogue}/` tier 1–6 (5 archetipe × 6 tier × 14 file = 420 file)
- [x] Creare override per classi con loot molto specifico (Mannaro, Spettro, Specchio dell'Abisso) ✓
- [x] Verificare con "Tutti" nel pannello Validatori: zero ERR ✓

---

## Fase 5 — ItemGenerator ✓

- [x] `drop(base_id, player_level, rng)` → scheletro istanza (qualità, affix_seed, name_unid)
- [x] `identify(instance, level)` → bake stats + nome con accordo genere (deterministico via affix_seed); leg/uni: solo identified=true
- [x] `resolve_stats(instance, level)` → baked per norm/mag/rar/epi; ricalcolo full/partial/threshold per leg/uni
- [x] `_roll_quality()` con bias, `_eval_scale()` via Expression, `get_quality_color()`

---

## Fase 6 — Refactor Inventory ✓ (parziale)

- [x] `Inventory.gd`: `add_item()`, `remove_item()`, `has_item()`, `add_item_instance()`, `identify_instance()` funzionanti
- [x] `use_item()` aggiornato: gestisce `restore_hp`/`heal`, `restore_mp`, `restore_stamina`, `restore_all`, `identify`
- [x] `Equipment.gd`: `equip()` ora ritorna bool + check `allowed_item_types` via ClassRegistry + gestione `both_hands` (libera left_hand) + blocco left_hand equip se 2H in right_hand
- [x] `equip_instance(instance)` aggiunto per equip diretto da dict
- [x] `SaveManager.gd`: serializzazione as-is funziona (istanze salvate come Dictionary, stackabili come {id,qty})
- [ ] Key Items: array separato `GameState.key_items` — rinviato a quando esistono key items effettivi

---

## Fase 7 — Loot Integration + Budget ✓

- [x] `DungeonLootBudget.gd` — caps equipment/consumable/unique per dungeon; factory `for_tier(tier)`
- [x] `FloorLootBudget.gd` — caps per piano con slot separati per chest/enemy/ground; factory `for_floor(db, idx, tier)`
- [x] `LootResolver.resolve()` — controlla `ctx["budget"]` via `_budget_allows()` + `_consume_budget()` (Variant duck typing)
- [ ] Collegamento a dungeon generator (quando esiste un generatore procedurale)

---

## Fase 8 — UI Inventario e Identificazione ✓ (core)

- [x] Display oro — label `$ N` sempre visibile in cima al zaino, aggiornato in `_refresh()`
- [x] Filtri categoria — 6 pulsanti (Tutti / ⚔ / 🛡 / 💍 / 🧪 / %) inseriti programmaticamente; evidenziati in verde se attivi
- [x] Ordinamento ciclico — pulsante `↕ / ★↓ / A-Z` che cicla: nessuno → qualità desc → nome A-Z
- [x] Schermata identificazione — via pergamena (`effect: {identify}`) già funzionante in `_enter_identify_mode()`
- [x] Colori qualità — già applicati in `_style_bag_btn()` via `ItemGenerator.get_quality_color()`
- [x] Tooltip — `name_unid` per non identificati, stats complete per identificati via `ItemTooltipBuilder`
- [x] Confronto rapido hovering (diff stats vs slot equipaggiato) ✓
- [x] Getta ciarpame (rimuove tutti i materiali con conferma) ✓
- [ ] Sotto-filtri consumabili (recupero / buff / scroll / …) — opzionale

---

## Fase 9 — UI Loot (chest e cadaveri)

Interfaccia a griglia che si apre quando il giocatore interagisce con una **chest** o un **cadavere**.

### Comportamento
- Si apre su interazione con chest o con tile cadavere del nemico
- Mostra tutti gli item droppati come celle in una griglia
- Chiudendo l'interfaccia senza prendere tutto, il loot rimane lì (finché la mappa non si resetta)

### Layout
```
┌─────────────────────────────────┐
│  Chest / Corpo di Goblin        │
├─────┬─────┬─────┬─────┬─────┐  │
│ [S] │ [P] │ [○] │     │     │  │
│     │     │     │     │     │  │
├─────┴─────┴─────┴─────┴─────┤  │
│  [Prendi tutto]   [Chiudi]   │  │
└──────────────────────────────┘
```

- Ogni cella mostra la **lettera-icona** dell'item (placeholder, da sostituire con sprite in futuro)
- Celle vuote se il drop ha meno item della capacità griglia

### Interazioni
- **Click su cella**: sposta l'item nell'inventario del giocatore
- **Hover su cella**: mostra tooltip con nome (colorato per qualità), stats se identificato, "???" se non identificato
- **Prendi tutto**: itera su tutte le celle e aggiunge tutto all'inventario
- **Chiudi** (o tasto Esc): chiude senza prendere

### Implementazione
- [x] LootScreen (CanvasLayer procedurale): griglia celle con icona/qualità, tooltip, take-single, take-all, Esc ✓
- [x] Tooltip: stats se identificato, "???" se no — via `ItemTooltipBuilder` ✓
- [x] `Chest.interact()` → LootResolver → LootScreen ✓
- [x] `Enemy.die()` → drop su tile cadavere → LootScreen via interact ✓
- [x] Loot rimane sul cadavere se si chiude senza prendere tutto ✓
- [ ] Feedback "inventario pieno" (bordo rosso cella) — richiede cap inventario, non ancora definito

---

## Note di design

- `affix_seed` garantisce che lo stesso drop non cambi affissi se l'identificazione viene posticipata o il file ricaricato.
- Leggendari/Unici non salvano stats baked → sul disco pesano pochissimo e scalano automaticamente col pg senza logica di migrazione.
- La pergamena di identificazione è un consumabile `effect: { "identify": true }` — da aggiungere alle loot tables.
- Il vendor potrà identificare in cambio di oro (sistema economico da definire separatamente).
- Gli affissi item (`data/item_affixes/`) sono distinti dagli affissi nemici (`data/affixes/`) — loader separati.
- Il campo `allowed_item_types` sui JSON affisso usa gli stessi valori `item_type` degli item — unica sorgente di verità.
- I `materiali` (pezzi di mostro, ferraglia, ecc.) sono consumabili non usabili direttamente — solo vendibili o usati per crafting futuro. Non hanno `effect`. I pezzi commestibili hanno un corrispettivo in `item_subtype: "cibo"` (vedi regole bilanciamento loot).
- I `key_item` non compaiono nelle loot tables normali; vengono aggiunti all'inventario via script di evento.
- Il sistema `summon` è un placeholder per il futuro sistema pet — la struttura dati è definita ma non implementata.
- `chest_variant` `boss` e `segreto` sono piazzate deterministicamente dal generatore di dungeon — mai rollate. Il generatore deve esporre un metodo per marcare una chest come `boss` o `segreto` al momento della generazione della mappa.
- Il `quality_bias` non cambia il pool di item disponibili, sposta solo il roll della qualità: con bias +2, un roll che produceva Normale → produce Raro, Magico → produce Epico, ecc. Il cap rimane Unico.
- La compatibilità di classe è nel filesystem (`class_id/ → archetypes/{archetype}/ → default/`), non nel codice. Nessun drop off-class implicito.
- `ground.json` vale per qualsiasi area (dungeon, villaggi, edifici, overworld): frequenza e sparsità calibrate nel generatore dell'area, non nel JSON.
- Il campo `id` è rimosso dagli schemi loot table: il path del file è già l'identificatore univoco.
- **Unici — unique_state_key**: la chiave che determina se un unico è già stato trovato è `world_id + character_id + dungeon_id + unique_id`. **Non** solo `world_id + dungeon_id + unique_id`: due personaggi nello stesso mondo devono poter trovare lo stesso unico. La posizione dello spawn del drop si determina con `unique_spawn_seed = hash(world_seed, character_id, dungeon_id, unique_id)` — stesso personaggio trova lo stesso unico nella stessa chest/stanza, personaggio diverso può trovarlo in posizione diversa.
- **Scaling Unici/Leggendari**: preferire `threshold` o `partial` su `full` per evitare che diventino best-in-slot permanenti. Il `scaling_mode` è obbligatorio se `scalable: true`.
- **Drop Budget**: il `DungeonLootBudget` e i `FloorLootBudget` vanno generati all'inizio di ogni dungeon e salvati in `LocationState`. Il resolver li consuma ma non li blocca duramente — sono indicatori, non limiti assoluti.

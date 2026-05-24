# Piano: Sistema Fazioni

**Stato**: In discussione — non iniziare l'implementazione prima di chiudere le domande aperte.

---

## Contesto

Nel gioco esiste già un campo `faction: String` su ogni `Entity` con valori hardcoded
`"player"`, `"enemy"`, `"neutral"`. È la base su cui costruire.

Il sistema fazioni serve come prerequisito al sistema NPC perché:
- Determina come gli NPC reagiscono al player
- Governa se i nemici attaccano o ignorano il player
- Permette agli NPC di avere dialoghi e prezzi diversi in base alla reputazione
- Rende il mondo più coerente (un bandito non dovrebbe essere ostile alle guardie per default)

---

## Approcci comuni (ricerca)

### A — Punteggio numerico per fazione (Fallout, TES)
Ogni fazione ha un `rep: int` (es. -100…+100) con soglie che definiscono stati discreti.
Semplice da leggere/scrivere, supporta variazioni graduali.

### B — Stato discreto diretto (Roguelike classico)
`Hostile | Neutral | Friendly` — nessun numero, si passa da uno stato all'altro con eventi.
Semplicissimo, facile da leggere nel codice. Poco granulare.

### C — Web di relazioni tra fazioni
Ogni fazione ha una reputazione con tutte le altre fazioni, non solo con il player.
Se il player è amico della Fazione A, che è nemica della Fazione B, la Fazione B
abbassa la rep del player automaticamente. Genera dinamiche naturali senza hand-tuning.

**Per Shattered propongo un ibrido A+C**: punteggio numerico con soglie, più una matrice
di relazioni inter-fazione che propaga automaticamente gli effetti.

---

## Schema dati proposto

### Definizione fazione (`data/factions/{id}.json`)
```jsonc
{
  "id": "guardie",
  "name": "Guardie della Città",
  "default_rep": 0,           // reputazione iniziale del player
  "rep_min": -100,
  "rep_max": 100,
  "thresholds": {
    "hostile":  -25,           // rep <= -25 → ostile
    "neutral":   25,           // -25 < rep <= 25 → neutrale
    "friendly":  75            // > 25 → amico, > 75 → alleato
  },
  "relationships": {
    "banditi": -50,            // le guardie sono nemiche dei banditi
    "cittadini": 30,           // alleate dei cittadini
    "player": 0                // posizione iniziale verso il player
  }
}
```

### GameState — reputazioni del player
```gdscript
GameState.faction_rep: Dictionary   # faction_id → int
# es. { "guardie": 10, "banditi": -40, "non_morti": -100 }
```

### FactionRegistry (autoload)
```gdscript
FactionRegistry.get_state(faction_id) -> String   # "hostile"|"neutral"|"friendly"|"allied"
FactionRegistry.get_rep(faction_id) -> int
FactionRegistry.add_rep(faction_id, delta)         # con propagazione sulle fazioni correlate
FactionRegistry.are_enemies(fac_a, fac_b) -> bool
```

---

## Fazioni candidate (proposta da discutere)

| ID | Nome | Esempi di membri |
|----|------|-----------------|
| `cittadini` | Cittadini | Contadini, popolani, NPC generici |
| `guardie` | Guardie | Guardie cittadine, soldati |
| `mercanti` | Gilda dei Mercanti | Mercanti, bottegai |
| `banditi` | Fuorilegge | Banditi, predoni umani |
| `non_morti` | Non Morti | Zombie, scheletri, lich |
| `demoni` | Demoni | Demoni, Chaos Knight |
| `bestie` | Bestie | Pipistrelli, ragni, ratti |
| `draghi` | Draconici | Dragon whelp, Ancient Dragon |
| `neutrale` | Neutrale | Chest, porte, oggetti — nessuna fazione |

Nota: le `family` dei nemici già esistenti (`humanoid`, `undead`, `beast`, `demon`, `dragon`)
si mappano quasi 1:1 sulle fazioni — semplifica l'integrazione.

---

## Propagazione inter-fazione

Quando `add_rep("guardie", +20)`:
1. `guardie.rep += 20`
2. Per ogni fazione F che ha una relazione con `guardie`:
   - se `guardie.relationships[F] < 0` → le fazioni nemiche delle guardie vedono il player negativamente
   - `F.rep += round(delta * relazione_normalizzata * PROPAGATION_FACTOR)`
   - `PROPAGATION_FACTOR` ≈ 0.3–0.5 per non rendere troppo aggressivo l'effetto

Questo crea automaticamente tensioni naturali: aiutare le guardie peggiora la rep con i banditi.

---

## Integrazione con il resto del gioco

### Entity / Enemy
- `faction: String` rimane il campo di appartenenza (già presente)
- Il sistema combattimento usa `FactionRegistry.are_enemies(a, b)` per decidere se attaccare
- Attualmente `"enemy"` è hardcoded — si può mantenere come fallback o sostituire gradualmente

### NPC
- L'NPC legge `FactionRegistry.get_state(npc.faction)` per scegliere il dialogo
- Mercanti modificano i prezzi in base allo stato (hostile → +30%, friendly → -15%)
- NPC ostili non avviano dialogo, entrano in combattimento

### Quest
- Completare una quest può chiamare `FactionRegistry.add_rep(faction_id, reward)`
- Le quest possono avere requisiti di reputazione minima per essere sbloccate

### Loot / prezzi
- Nei negozi: `prezzo * FactionRegistry.get_price_multiplier(faction_id)`

---

## Domande aperte (da chiudere prima di implementare)

1. **Quante fazioni vuoi?** La lista sopra è una proposta — alcune potrebbero essere unite
   (es. `non_morti + demoni` in `malvagi`?) o aggiunte (es. `draghi` → troppo piccola?).

2. **La reputazione persiste tra run?** In permadeath probabilmente no, ma in run normali
   dovrebbe resettarsi per ogni personaggio o per ogni mondo?

3. **Il player può essere membro attivo di una fazione?** (come in TES, dove ci si unisce
   alla gilda dei maghi) — o la reputazione è sempre "esterna"?

4. **I nemici attaccano in base alla fazione o rimane il sistema attuale?** Attualmente
   tutti i nemici con `faction = "enemy"` attaccano sempre. Vogliamo che i banditi
   non attacchino il player se ha alta rep con i `banditi`? O è troppo complesso?

5. **Relazioni tra nemici:** un goblin (bestie?) attacca uno zombie (non_morti)? Questo
   richiederebbe che il sistema combattimento consulti la matrice inter-fazione per tutti,
   non solo per il player.

6. **Crimes system:** azioni illegali (attaccare NPC neutri, rubare) abbassano la rep
   con le guardie? O è troppo per la portata attuale?

---

## Fasi di implementazione (bozza)

- **Fase 1** — Fondamenta: `FactionRegistry` autoload, JSON fazioni, `GameState.faction_rep`,
  `add_rep()` senza propagazione. Sostituire `faction = "enemy"` con id reali sui nemici.
- **Fase 2** — Propagazione: matrice relazioni inter-fazione, `are_enemies()`, propagazione delta.
- **Fase 3** — NPC integration: dialogo condizionale, prezzi dinamici.
- **Fase 4** — Quest integration: rep reward/requirement sulle quest.
- **Fase 5** — Combat integration: nemici che non attaccano se rep alta.

---

## File da creare / modificare

```
data/factions/                  ← nuova cartella, un JSON per fazione
scripts/core/FactionRegistry.gd ← nuovo autoload
scripts/entities/Entity.gd      ← faction rimane String, cambia solo il valore
scripts/entities/Enemy.gd       ← faction = ID reale invece di "enemy"
scripts/core/GameState.gd       ← aggiungere faction_rep: Dictionary
scripts/core/SaveManager.gd     ← persistere faction_rep
```

# Piano: Needs System (Sistema Bisogni)

**Stato**: Bozza revisionata — da implementare dopo Time System ✓. Prerequisito del Travel System.

**Dipendenze**: Time System ✓

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Bisogni implementati | `food`, `water`, `exhaustion`, `temperature` — `sickness` rimosso come campo numerico |
| Semantica | `food`/`water`: 100=pieno, 0=a zero — **risorse positive**. `exhaustion`: 0=riposato, 100=collasso — **pressione negativa**. `temperature`: 0=comodo, <0=freddo, >0=caldo |
| A zero fame/sete | Non causano danno diretto — triggerano le malattie `malnutrizione` / `disidratazione_grave` che poi gestiscono i debuff e il danno |
| Temperatura | Range −100 a +100. 0=comodo. **Equilibrio**: `temperature` si avvicina al `temperature_target` del bioma — non sale/scende indefinitamente. Solo `ipotermia` (≤ −75) e `ipertermia` (≥ +85) come malattie da temperatura. Soglie asimmetriche: il corpo umano tollera meglio il caldo del freddo. Zone intermedie: solo debuff transiensi in `_update_modifiers()` |
| Dungeon | I bisogni calano anche in dungeon (più lentamente) — è il motivo per cui ci si prepara |
| Fatica vs Stamina | Sistemi separati: `stamina` è risorsa da combattimento (secondi), `exhaustion` è accumulo da viaggio (giorni) |
| Malattia | Solo `active_diseases` — no campo `sickness` float. Debuff calcolati direttamente dagli step attivi |
| Recupero | Save point: exhaustion −30. Locanda: exhaustion = 0, temperature = 0. Accampamento: exhaustion −50, temperature = 0 (fuoco implicito). |
| Tick | Segmentato a passi da 60 min max — necessario per calcoli corretti su viaggi lunghi |
| Accumulatori danni | Necessari per danno periodico corretto su qualsiasi durata di tick |
| Notifiche fame | Ancorate all'ora del gioco: mezzogiorno (~12:00) e cena (~19:00) — non a timer puro |
| Notifiche soglie | Solo al cambio di soglia (ok→warning, warning→critical…) — no spam |
| Debuff fame lieve | Fame lieve = solo −5% WIL, non malus fisici. Solo fame estrema (food 1–24) impatta fisicamente |
| Debuff exhaustion | Moderati: una giornata normale deve essere gestibile senza malus significativi |
| Collasso | A exhaustion = 100: fade-out forzato, ~60 min passano, exhaustion −25, HP ridotti |
| Debuff cap | `atk_mult` floor −0.65; `dmg_taken_mult` cap +0.65; `action_cost_mult` cap +2.0 — il personaggio non diventa inutile |
| Item needs | Effetti multi-bisogno via dict `"changes"` — flessibile per oggetti misti |
| Contesto tick | `context: Dictionary` invece di solo `map_type` — pronto per bioma/meteo/attività futuri |
| Sonno e bisogni | Durante il sonno food/water calano quasi nulla; exhaustion diminuisce (via `rest()`) |
| Fast travel | Completamente automatico: consuma prima le provviste del veicolo (carovana/nave), poi quelle del player |
| UI | Solo caratteri ASCII — no emoji. Tasto F per menu rapido cibo/acqua |

---

## Campi GameState

```gdscript
# Bisogni (float per accumulo preciso)
var food:        float = 100.0   # 100 = sazio,    0 = affamato
var water:       float = 100.0   # 100 = idratato, 0 = assetato
var exhaustion:  float = 0.0     # 0 = riposato,   100 = collasso
var temperature: float = 0.0     # 0 = comodo,  <0 = freddo,  >0 = caldo  (range −100…+100)

# Malattie attive (serializzate nel save)
var active_diseases: Array = []
# ciascuna: { "id": "swamp_fever", "stage_index": 0, "elapsed_minutes": 0 }

# Modificatori derivati (NON serializzati — ricalcolati da NeedsManager._update_modifiers())
var needs_modifiers: Dictionary = {}
# es. { "atk_mult": -0.10, "dmg_taken_mult": 0.15, "action_cost_mult": 0.5 }
# I debuff malattia vengono sommati qui insieme a quelli di food/water/exhaustion
```

---

## Rate di consumo

### Base per tipo mappa / attività

Unità per minuto. Calibrati per sentirsi naturali: fame verso pranzo e cena, esaurimento solo dopo 2+ giorni senza sonno.

| Mappa / Attività | food/min | water/min | exhaustion/min | temperatura |
|------------------|----------|-----------|----------------|-------------|
| `overworld` — viaggio | 0.070 | 0.110 | 0.030 | → target bioma (equilibrio)¹ |
| `dungeon` / `ruin` / `encounter` | 0.030 | 0.045 | 0.025 | → 0 (interno) |
| `village` / `city` | 0.008 | 0.012 | 0.010 | → 0 (interno) |
| `building` | 0.004 | 0.006 | 0.005 | → 0 (rapido) |
| `sleep` (qualsiasi mappa) | 0.003 | 0.005 | — (gestito da rest()) | come mappa corrente |

¹ **Modello a equilibrio** (Fase 2 — richiede Overworld System): ogni bioma ha un `temperature_target`; `temperature` si avvicina a quel valore tramite `lerpf()` — non sale/scende indefinitamente. Target indicativi: plain/forest → 0, mountain → −40, tundra → −70, desert → +60, swamp → +30. Vedi sezione "Sistema Temperatura".

**In Fase 1**: `temperature` non cambia automaticamente — il campo esiste e viene serializzato, ma resta a 0. Testabile via debug screen (`set_temperature <n>`).

#### Calibrazione giornata tipo

- Risveglio: food = 100, exhaustion = 0 (dopo riposo completo)
- Viaggio overworld 8h (480 min): −33.6 food, −52.8 water, +14.4 exhaustion
- Viaggio overworld 16h (960 min, giornata intera senza mangiare): −67.2 food, water → 0 dopo ~909 min (clamped), +28.8 exhaustion
  - Exhaustion fine giornata: ~28.8 → appena sotto la soglia warning (30) ✓ "malus moderatissimi"
  - Nota: l'acqua finisce prima del cibo — bere è più urgente che mangiare
- Sonno 8h (480 min): −1.4 food, −2.4 water (quasi nulla ✓), exhaustion gestito da rest()
- Senza mangiare per 1 giorno attivo: food scende da 100 a ~33 → critical a fine sera
- Senza mangiare per 2 giorni attivi: food a 0 → danno letale

### Contesto tick (Fase 2+)

```gdscript
var context := {
    "map_type":    "overworld",
    "activity":    "travel",    # "travel" | "explore" | "combat" | "rest" | "sleep"
    "biome":       "plain",     # Overworld System (futuro)
    "road_type":   "trail",     # Travel System (futuro)
    "encumbrance": 1.0          # Item System attributi (futuro)
}
```

All'inizio si usa solo `map_type` e `activity`; gli altri campi vengono ignorati se assenti.

`activity = "sleep"` usa le rate della riga sleep nella tabella sopra.

### Integrazione con Travel System (futuro)

Il fast travel avviene **solo con carovane, carretti o nave**. Il consumo è completamente automatico:

1. Si usa prima il **scorte del veicolo** (carovana o nave) — il player non deve fare nulla
2. Se le scorte del veicolo si esauriscono, si usano le **provviste del player** in inventario
3. Solo se anche quelle finiscono, i bisogni calano direttamente

Per la nave: i viaggi possono durare settimane — le scorte della nave sono abbondanti by design e il player non deve preoccuparsi normalmente.

```gdscript
# In TravelService.execute_travel(days, context):
var unconsumed_minutes: int = _consume_vehicle_supplies(days, context)
if unconsumed_minutes > 0:
    var player_uncovered: int = _consume_player_supplies(unconsumed_minutes, context)
    if player_uncovered > 0:
        NeedsManager.tick(player_uncovered, context)
```

---

## Soglie e debuff

### food

| Valore | Stato | Effetto |
|--------|-------|---------|
| 50–100 | Ok | Nessun malus |
| 25–49 | Warning | WIL −5% — lieve calo di concentrazione, nessun malus fisico |
| 1–24 | Critical | WIL −10%, ATK −10%, DEF −10% — fame profonda, il corpo comincia a cedere |
| 0 | Depleted | Nessun danno diretto — dopo 120 min a zero triggera la malattia `malnutrizione` |

> **Nota**: una fame lieve non limita fisicamente nel mondo reale. Solo la fame "da stravaganza" (ravaging) ha effetti fisici.
> Il danno vero arriva dalla malattia `malnutrizione` (stage Moderata: 2/30min, Grave: 5/30min).

### water

| Valore | Stato | Effetto |
|--------|-------|---------|
| 50–100 | Ok | Nessun malus |
| 25–49 | Warning | ATK −10%, DEF −10% — la disidratazione impatta subito le prestazioni fisiche |
| 1–24 | Critical | ATK −20%, DMG_TAKEN +15%, action_cost_mult +0.5 |
| 0 | Depleted | Nessun danno diretto — dopo 60 min a zero triggera la malattia `disidratazione_grave` |

### exhaustion

| Valore | Stato | Effetto |
|--------|-------|---------|
| 0–30 | Ok | Nessun malus; regen bonus HP/MP al save point |
| 31–55 | Warning | INT −5%, WIL −5% — stanchezza mentale, fine giornata normale |
| 56–75 | Moderato | INT −10%, WIL −10%, ATK −5%, DEF −5% — secondo giorno senza sonno |
| 76–90 | Critical | ATK −15%, DEF −15%, INT −10%, WIL −10%, niente regen HP/MP |
| 91–99 | Grave | ATK −30%, DMG_TAKEN +20%, action_cost_mult +0.5, danno: −5 HP ogni 30 min |
| 100 | Collasso | Vedi sezione Collasso |

> **Nota**: una giornata normale di viaggio porta exhaustion a ~28–30 → fine giornata safe, o appena in warning.
> Due giorni senza sonno → 57–60 → malus moderati. Tre giorni → ~90 → pericoloso.

### temperature

Le soglie sono **asimmetriche**: il corpo umano tollera meglio il caldo (malattia a +85) che il freddo (malattia a −75). Ogni lato ha 4 zone di debuff graduale.

| Zona freddo | Zona caldo | Nome | Debuff transiente |
|-------------|-----------|------|-------------------|
| −25 a +25 | (uguale) | Comodo | — |
| −26 a −50 | +1 a +28 | Freddo / Caldo | WIL −5%, action_cost_mult +0.1 |
| −51 a −74 | +29 a +56 | Freddissimo / Caldissimo | ATK −10%, DEF −10%, action_cost_mult +0.2 |
| −75 a −99 | +57 a +84 | Congelamento¹ / Surriscaldamento¹ | ATK −20%, DMG_TAKEN +15%, action_cost_mult +0.5 |
| ≤ −75 (malattia) | ≥ +85 (malattia) | **Ipotermia** / **Ipertermia** | debuff grave + `add_disease()` |

¹ *Congelamento* e *Surriscaldamento* sono **nomi di zona**, non malattie. La malattia `congelamento` ha acquisizione diversa (enemy tag / bioma).

Zone freddo di 25 punti ciascuna; zone caldo di ~28 punti (85/3). In `_update_modifiers()`:
```gdscript
var zone: int
if   GameState.temperature < 0.0: zone = min(int(-GameState.temperature / 25.0), 3)
else:                              zone = min(int( GameState.temperature / 28.4), 3)
# zone 0 = nessun debuff; zone 1–2 = debuff graduali; zone 3 = debuff grave + (se malattia) disease
```

I debuff transiensi spariscono appena la temperatura rientra nella zona precedente. Le malattie `ipotermia`/`ipertermia` **non spariscono** quando la temperatura migliora — guariscono solo via cure/riposo.

Trigger malattia gestiti in `_check_disease_triggers()` — **non via JSON acquisition**.

### Debuff malattie

Non ci sono soglie fisse per le malattie: ogni stage di ogni malattia definisce i propri `malus` nel JSON. `_update_modifiers()` somma i malus di tutti gli stage attivi insieme a quelli di food/water/exhaustion. Il danno periodico delle malattie è definito per stage (`damage_per_30min`).

### Cap debuff combinati

```gdscript
needs_modifiers["atk_mult"]               = maxf(combined_atk_mult,          -0.65)  # attacco al minimo 35%
needs_modifiers["dmg_taken_mult"]         = minf(combined_dmg_taken_mult,     0.65)  # max +65% danno subito
needs_modifiers["action_cost_mult"]       = minf(combined_action_cost_mult,   2.0)   # azione max 3× il normale
needs_modifiers["food_drain_mult_sum"]    = minf(combined_food_drain_sum,     2.0)   # max 3× consumo fame
needs_modifiers["exhaustion_gain_mult_sum"] = minf(combined_exh_gain_sum,    1.5)   # max 2.5× accumulo fatica
# food_drain e exhaustion_gain: valori nei JSON sono delta (0.0 = nessun effetto, 0.5 = +50% extra).
# Si sommano tra malattie; applicati in _calculate_rates(): rate *= (1.0 + sum_delta)
# Esempio: ipotermia (exh_gain 0.5) + insonnia_cronica (exh_gain 0.3) → sum=0.8 → rate ×1.8
```

---

## Collasso (exhaustion = 100)

Quando `exhaustion` raggiunge 100 il personaggio crolla involontariamente:

1. **Fade-out** a schermo (come cambio mappa)
2. ~60 minuti passano automaticamente (`TimeManager.advance(60)`)
3. `exhaustion -= 25` — il riposo forzato non è completo
4. HP ridotto del 10% (stress da collasso) — non letale, ma penalizzante
5. **Fade-in** — il player si ritrova nello stesso posto con notifica `"Sei collassato dalla stanchezza"`

Questo non sostituisce il riposo vero (locanda/accampamento). Il collasso è un avvertimento + penalità, non una soluzione.

Il collasso può ripetersi se il player continua senza dormire: dopo il collasso l'exhaustion è 75, che continuerà a salire.

```gdscript
func _check_collapse() -> void:
    if GameState.exhaustion < 100.0:
        return
    GameState.exhaustion = 75.0
    EventBus.player_collapsed.emit()
    # Sequenza in Main.gd:
    #   1. fade-out
    #   2. TimeManager.advance(60, { "activity": "sleep" })
    #      → NeedsManager.tick con activity=sleep → exhaustion rate ≈ 0 (corpo incosciente)
    #   3. fade-in: exhaustion = maxf(0, exhaustion - 25)  → ~50, HP -= 10%
```

---

## Sistema Temperatura — Implementazione

### Come cambia la temperatura

`temperature` non varia a rate fisso — si avvicina a un **target** definito dall'ambiente. In un bioma a +60 (deserto) la temperatura si stabilizza a +60 e non sale oltre, anche dopo settimane.

```gdscript
# In NeedsManager._tick_step():
var target: float = _get_temperature_target(context)
var k:      float = _get_approach_rate(context)
GameState.temperature = lerpf(GameState.temperature, target, k * minutes)
GameState.temperature = clampf(GameState.temperature, -100.0, 100.0)
```

**`_get_temperature_target(context)`** (Fase 2 — dipende da Overworld System):

| Ambiente | target | Zona massima raggiungibile |
|----------|--------|---------------------------|
| `building`, `village`, `city` | 0 | Comodo — nessun effetto |
| `dungeon`, `ruin`, `encounter` (generici) | 0 | Comodo |
| `overworld` bioma `plain` / `forest` | 0 | Comodo |
| `overworld` bioma `mountain` | −40 | Zona −2 (Freddissimo) |
| `overworld` bioma `tundra` | −70 | Zona −3 (Congelamento) — vicino a malattia |
| `overworld` bioma `desert` | +60 | Zona +3 (Surriscaldamento) |
| `overworld` bioma `swamp` | +30 | Zona +2 (Caldissimo) |
| `overworld` bioma `coast` | −10 | Zona −1 (Freddo lieve) |

> I target definitivi sono di competenza di **Overworld System**. I valori sopra sono indicativi per il design.

**`_get_approach_rate(context)`**: velocità di avvicinamento al target. Suggeriti: indoor 0.010, overworld 0.004–0.006. Valore più alto = cambia più rapidamente.

**Modificatori notte** (Fase 2+): la notte abbassa il target di 10–15 punti per biomi temperati/freddi.

**In Fase 1**: `_get_temperature_target()` restituisce sempre 0 — `temperature` non cambia automaticamente.

---

### Recupero attivo temperatura

La temperatura non si recupera da sola all'aperto. Richiede:

| Meccanismo | Effetto |
|-----------|---------|
| Entrare in edificio/dungeon/villaggio | Normalizzazione automatica verso 0 (lenta — 20–30 min via lerpf con target=0) |
| Locanda (`rest("inn")`) | Temperatura → 0 immediato |
| Accampamento (`rest("camp")`) | Temperatura → 0 immediato (fuoco del campo implicito) |
| Item tag `heat_source` (falò portatile) | `consume({"temperature": +20})` — alza la temperatura, non cura l'ipotermia direttamente |
| Item tag `cooling` (acqua fredda, panno bagnato) | `consume({"temperature": -15})` |

**Nota su cura `ipotermia` / `ipertermia`**: gli item `heat_source`/`cooling` spostano la temperatura ma la malattia non sparisce automaticamente quando si esce dalla zona ±4. Il JSON di `ipotermia` deve avere un `cure_trigger` esplicito tipo `{ "type": "item_tag", "item_tag": "heat_source" }` e/o `{ "type": "rest_type", "rest": "inn" }`. Stessa logica per `ipertermia`.

---

### Interazione con altri bisogni

- **Freddo e acqua**: in ambienti freddi il rate `water` diminuisce leggermente (si suda meno). Non implementato ora — Fase 2+ via biome modifier.
- **Caldo e acqua**: `colpo_di_calore` e `ipertermia` già hanno `food_drain_mult` nel loro malus — la sete aumenta indirettamente.
- **Freddo ed exhaustion**: `ipotermia` ha `exhaustion_gain_mult` nel suo malus — non serve un modificatore diretto su `temperature`.
- **Temperatura e combattimento**: nessun effetto diretto di `temperature` sulle stat — tutto passa dalle malattie.

---

### Malattie temperatura — caratteristiche chiave

**`ipotermia`** (temperature ≤ −75 — zona −4):
- Stage: Critico (unico) — danno pesante, azioni rallentate, exhaustion_gain accelerata
- Cura: `heat_source` (falò, magia di fuoco) + riposo; locanda (`rest("inn")`) garantisce guarigione
- Natural recovery: **nessuna** — deve essere trattata

**`ipertermia`** (temperature ≥ +85 — zona +4):
- Stage: Critico (unico) — danno rapido, water drain estremo
- Cura: `cooling` (acqua fredda, panno bagnato) + riposo
- Natural recovery: **nessuna**

La malattia persiste anche dopo che la temperatura è rientrata in zona sicura — rientrare al riparo ferma il peggioramento ma non cura.

I valori precisi di malus e damage_per_30min vengono definiti al momento dell'implementazione (Fase 5).

---

### Localizzazione — Temperatura

Tutte le stringhe visibili al player devono usare `tr("CHIAVE")`. Esempi di chiavi da aggiungere ai file `.po`/`.csv`:

| Chiave | Contenuto |
|--------|-----------|
| `TEMP_ZONE_COLD_1` | "Fa freddo." |
| `TEMP_ZONE_COLD_2` | "Molto freddo." |
| `TEMP_ZONE_COLD_3` | "Freddo pericoloso." |
| `TEMP_ZONE_HOT_1` | "Fa caldo." |
| `TEMP_ZONE_HOT_2` | "Molto caldo." |
| `TEMP_ZONE_HOT_3` | "Caldo pericoloso." |
| `TEMP_DISEASE_IPOTERMIA` | "Hai l'ipotermia." |
| `TEMP_DISEASE_IPERTERMIA` | "Hai l'ipertermia." |
| `TEMP_HUD_LABEL` | "T" (etichetta HUD) |

Le notifiche di cambio zona (emesse da `temperature_zone_changed`) mostrano un messaggio nel log tramite `tr()` — no stringa hardcoded.

### Debug screen — Temperatura

Integrazione nella debug screen esistente (da fare in **Fase 1**, insieme agli altri bisogni):

| Comando | Funzione |
|---------|---------|
| `set_temperature <n>` | Imposta `GameState.temperature` direttamente |
| `simulate_biome <id>` | Setta il `temperature_target` corrente come se si fosse in quel bioma (es. `simulate_biome tundra`) |
| `tick_temperature <min>` | Esegue solo il tick temperatura per N minuti (senza avanzare time/food/water) |

Visualizzazione: mostrare zona corrente (nome + numero), target bioma attivo, debuff transiensi attivi da temperatura.

---

### Questioni aperte — Temperatura

- **Stagioni**: in inverno il bioma `plain` ha una baseline fredda (−0.02/min)? Dipende da TimeManager
- **Pioggia/neve**: meteo come modificatore temperatura? Futuro (Overworld System)
- **Nuoto**: attraversare un fiume in inverno deve raffreddare molto più velocemente?
- **Fuoco in dungeon**: le torce/falò del dungeon hanno effetto sul player?
- **Ice dungeon / volcanic dungeon**: tile speciali con rate temperatura propri?
- **Temperatura e mostri**: alcuni nemici (ice golem, fire elemental) potrebbero modificare la temperatura del player all'attacco?

---

## Integrazione Temperatura ↔ Altri Bisogni

### Decisione: rate diretti o solo via malattia?

`temperature` **non altera i rate di food/water/exhaustion direttamente**. Tutti gli effetti passano dai debuff transiensi (zone ±1–±3 in `_update_modifiers`) e dai malus delle malattie. Questo evita complessità inutile — le zone di debuff già rendono il bioma rilevante prima della malattia.

---

### Temperatura e sonno

Il sonno senza riparo non è possibile. Il camp azzera sempre la temperatura.

| Situazione | Comportamento |
|-----------|--------------|
| Inn (`rest("inn")`) | temperatura → 0 immediato |
| Camp (`rest("camp")`) | temperatura → 0 immediato (il fuoco del campo è implicito) |
| Edificio / dungeon / villaggio | temperature_target = 0; avvicinamento passivo verso 0 |

---

### Decisioni prese

| Domanda | Decisione |
|---------|-----------|
| Rate diretti da temperature su food/water/exhaustion? | **No** — solo via malattia. Temperature non tocca i rate degli altri bisogni. |
| Sonno all'aperto possibile? | **No** — dormire richiede sempre un riparo (edificio o accampamento). Il camp azzera la temperatura. |
| Save point penalizzato da temperatura estrema? | **No** — i save point sono temporanei (debug); nessuna logica speciale. |
| Neve sciolta / bevande fredde? | **No per ora** — troppo rumore per questa fase. |

---

## Notifiche pasto (ancorate all'ora del gioco)

Le notifiche di fame non si basano solo sul valore di `food` ma anche sull'**ora del giorno** — per dare il feeling di "è ora di pranzo" invece di "beep ogni X punti".

### Logica

`NeedsManager` tiene un flag `_last_meal_hint: int = -1` (−1 = nessuno, 0 = colazione, 1 = pranzo, 2 = cena).

Ogni tick, dopo aver aggiornato `food`:

```gdscript
func _check_meal_hints() -> void:
    var hour: int = TimeManager.get_hour()  # 0–23
    if hour >= 12 and hour < 13 and _last_meal_hint != 1:
        if GameState.food < 60.0:
            EventBus.meal_hint.emit("pranzo")
        _last_meal_hint = 1
    elif hour >= 19 and hour < 20 and _last_meal_hint != 2:
        if GameState.food < 60.0:
            EventBus.meal_hint.emit("cena")
        _last_meal_hint = 2
    elif hour >= 6 and hour < 7 and _last_meal_hint != 0:
        _last_meal_hint = 0  # reset giornaliero
```

Il signal `meal_hint(meal: String)` mostra un messaggio testuale discreto nel log (`"E' ora di pranzo."` o `"Dovresti mangiare qualcosa."`). Non è invasivo — un singolo messaggio.

Le notifiche di soglia (`need_warning`, `need_critical`) rimangono per i casi urgenti.

---

## NeedsManager — `scripts/core/NeedsManager.gd`

Nuovo autoload. Registrato dopo `TimeManager`.

```gdscript
extends Node

var _food_zero_acc:         float = 0.0
var _water_zero_acc:        float = 0.0
var _exh_dmg_acc:           float = 0.0
var _disease_dmg_acc:       Dictionary = {}  # disease_id -> accumulated minutes
var _high_exhaustion_count: int   = 0        # volte che exhaustion ha superato 90
var _was_above_90:          bool  = false    # edge detection per insonnia_cronica

var _prev_states: Dictionary = { "food": "ok", "water": "ok", "exhaustion": "ok" }
var _prev_temp_zone: int  = 0       # zona temperatura precedente (0–3); per emettere temperature_zone_changed
var _last_meal_hint: int  = -1

func tick(minutes: int, context: Dictionary = {}) -> void:
    var remaining := float(minutes)
    while remaining > 0.0:
        var step := minf(remaining, 60.0)
        _tick_step(step, context)
        remaining -= step
    _update_modifiers()
    _check_state_transitions()
    _check_meal_hints()
    _check_collapse()
    EventBus.needs_changed.emit()

func _tick_step(minutes: float, context: Dictionary) -> void:
    var rates := _calculate_rates(context)   # restituisce solo food/water/exhaustion
    GameState.food       = maxf(0.0,  GameState.food      - rates.food      * minutes)
    GameState.water      = maxf(0.0,  GameState.water     - rates.water     * minutes)
    GameState.exhaustion = minf(100.0, GameState.exhaustion + rates.exhaustion * minutes)
    # temperatura: modello a equilibrio — si avvicina al target, non varia a rate fisso
    var target: float = _get_temperature_target(context)
    var k:      float = _get_approach_rate(context)
    GameState.temperature = lerpf(GameState.temperature, target, k * minutes)
    GameState.temperature = clampf(GameState.temperature, -100.0, 100.0)
    _tick_diseases(minutes)
    _check_disease_triggers(minutes)

func _calculate_rates(context: Dictionary) -> Dictionary:
    # Restituisce rate per food/water/exhaustion in base a map_type + activity.
    # La temperatura NON ha un rate: usa _get_temperature_target() + lerpf.
    var map_type: String = context.get("map_type", "building")
    var activity: String = context.get("activity", "explore")
    const BASE := {
        "overworld":  { "food": 0.070, "water": 0.110, "exhaustion": 0.030 },
        "dungeon":    { "food": 0.030, "water": 0.045, "exhaustion": 0.025 },
        "ruin":       { "food": 0.030, "water": 0.045, "exhaustion": 0.025 },
        "encounter":  { "food": 0.030, "water": 0.045, "exhaustion": 0.025 },
        "village":    { "food": 0.008, "water": 0.012, "exhaustion": 0.010 },
        "city":       { "food": 0.008, "water": 0.012, "exhaustion": 0.010 },
        "building":   { "food": 0.004, "water": 0.006, "exhaustion": 0.005 },
    }
    const SLEEP := { "food": 0.003, "water": 0.005, "exhaustion": 0.0 }
    var base: Dictionary = SLEEP if activity == "sleep" else BASE.get(map_type, BASE["building"])
    # Applicazione food_drain_mult / exhaustion_gain_mult da needs_modifiers
    var fd: float = GameState.needs_modifiers.get("food_drain_mult_sum", 0.0)
    var eg: float = GameState.needs_modifiers.get("exhaustion_gain_mult_sum", 0.0)
    return {
        "food":      base.food      * (1.0 + fd),
        "water":     base.water,
        "exhaustion": base.exhaustion * (1.0 + eg)
    }

func consume(changes: Dictionary) -> void:
    # { "food": 30, "water": 20, "exhaustion": -10, "temperature": 15 }
    if changes.has("food"):        GameState.food        = clampf(GameState.food        + changes["food"],        0.0, 100.0)
    if changes.has("water"):       GameState.water       = clampf(GameState.water       + changes["water"],       0.0, 100.0)
    if changes.has("exhaustion"):  GameState.exhaustion  = clampf(GameState.exhaustion  + changes["exhaustion"],  0.0, 100.0)
    if changes.has("temperature"): GameState.temperature = clampf(GameState.temperature + changes["temperature"], -100.0, 100.0)
    _update_modifiers()
    _check_state_transitions()
    EventBus.needs_changed.emit()

func rest(rest_type: String) -> void:
    match rest_type:
        "save_point":
            GameState.exhaustion = maxf(0.0, GameState.exhaustion - 30.0)
        "inn":
            GameState.exhaustion  = 0.0
            GameState.temperature = 0.0   # la locanda normalizza anche la temperatura
        "camp":
            GameState.exhaustion  = maxf(0.0, GameState.exhaustion - 50.0)
            GameState.temperature = 0.0   # il camp include sempre il fuoco — temperatura azzera
    _update_modifiers()
    EventBus.needs_changed.emit()

func add_disease(disease_id: String) -> void:
    for d: Variant in GameState.active_diseases:
        if (d as Dictionary).get("id") == disease_id:
            return
    GameState.active_diseases.append({ "id": disease_id, "stage_index": 0, "elapsed_minutes": 0 })
    # DiseaseRegistry è uno stub in Fase 1 (ritorna {}); è completo da Fase 5
    var def: Dictionary = DiseaseRegistry.get_def(disease_id) if DiseaseRegistry else {}
    EventBus.disease_acquired.emit(disease_id, def.get("name", disease_id))
    _update_modifiers()
    EventBus.needs_changed.emit()

func cure_disease(disease_id: String) -> void:
    GameState.active_diseases = GameState.active_diseases.filter(
        func(d: Variant) -> bool: return (d as Dictionary).get("id") != disease_id
    )
    _disease_dmg_acc.erase(disease_id)
    _update_modifiers()
    EventBus.disease_cured.emit(disease_id)
    EventBus.needs_changed.emit()
```

### `_check_disease_triggers(minutes: float)`

Tutti i trigger "diretti" (derivati dai 4 bisogni, gestiti in codice — no JSON acquisition) stanno qui. Le malattie triggerabili da JSON (`enemy_tag`, `item_consume`, ecc.) sono gestite da `_check_acquisition_triggers`.

```gdscript
func _check_disease_triggers(minutes: float) -> void:
    # ── food ──────────────────────────────────────────────────────────────
    # food=0 → malnutrizione dopo 120 min (add_disease è idempotente)
    if GameState.food <= 0.0:
        _food_zero_acc += minutes
        if _food_zero_acc >= 120.0:
            add_disease("malnutrizione")
    else:
        _food_zero_acc = 0.0

    # ── water ─────────────────────────────────────────────────────────────
    # water=0 → disidratazione_grave dopo 60 min
    if GameState.water <= 0.0:
        _water_zero_acc += minutes
        if _water_zero_acc >= 60.0:
            add_disease("disidratazione_grave")
    else:
        _water_zero_acc = 0.0

    # ── exhaustion → insonnia_cronica ──────────────────────────────────────
    # (edge detection: conta ogni nuovo ingresso in exhaustion ≥ 90, non ogni tick)
    # nota: il reset del flag avviene quando exhaustion scende sotto 70 per dare margine
    var over_90: bool = GameState.exhaustion >= 90.0
    if over_90 and not _was_above_90:
        _high_exhaustion_count += 1
        if _high_exhaustion_count >= 3:
            add_disease("insonnia_cronica")
    _was_above_90 = over_90 if GameState.exhaustion >= 70.0 else false

    # ── temperature → ipotermia / ipertermia (zona ±4) ───────────────────────
    # Solo le zone estreme triggerano malattie; zone ±1…±3 producono solo debuff
    # transiensi calcolati in _update_modifiers() — non aggiungono malattie
    if GameState.temperature <= -75.0:
        add_disease("ipotermia")
    if GameState.temperature >= 85.0:
        add_disease("ipertermia")

    # ── danno periodico per ogni malattia attiva al suo stage corrente ─────
    for d: Variant in GameState.active_diseases:
        var entry: Dictionary = d as Dictionary
        var did: String = entry.get("id", "")
        var stage_idx: int = entry.get("stage_index", 0)
        var def: Dictionary = DiseaseRegistry.get(did)
        var stages: Array = def.get("stages", [])
        if stage_idx >= stages.size(): continue
        var dmg: int = (stages[stage_idx] as Dictionary).get("damage_per_30min", 0)
        if dmg <= 0:
            _disease_dmg_acc.erase(did)
            continue
        _disease_dmg_acc[did] = _disease_dmg_acc.get(did, 0.0) + minutes
        while _disease_dmg_acc[did] >= 30.0:
            EventBus.player_took_needs_damage.emit(did, dmg)
            _disease_dmg_acc[did] -= 30.0

    if GameState.exhaustion >= 91.0:
        _exh_dmg_acc += minutes
        while _exh_dmg_acc >= 30.0:
            EventBus.player_took_needs_damage.emit("exhaustion", 5)
            _exh_dmg_acc -= 30.0
    else:
        _exh_dmg_acc = 0.0
```

### `_check_state_transitions()` — anti-spam

```gdscript
func _check_state_transitions() -> void:
    _check_transition("food",       _get_state("food"))
    _check_transition("water",      _get_state("water"))
    _check_transition("exhaustion", _get_state("exhaustion"))
    # temperatura: zona tracciata in _update_modifiers() — emette temperature_zone_changed lì

func _check_transition(need: String, new_state: String) -> void:
    var old: String = _prev_states.get(need, "ok")
    if new_state == old:
        return
    _prev_states[need] = new_state
    match new_state:
        "warning":  EventBus.need_warning.emit(need)
        "critical": EventBus.need_critical.emit(need)
        "depleted": EventBus.need_depleted.emit(need)
```

---

## Integrazione TimeManager

```gdscript
# In TimeManager.advance():
func advance(minutes: int, extra_ctx: Dictionary = {}) -> void:
    ...
    var map: BaseMap = WorldManager.get_current_map()
    var ctx: Dictionary = { "map_type": map.map_type if map else "building" }
    ctx.merge(extra_ctx)   # permette di passare { "activity": "sleep" } dal collasso
    NeedsManager.tick(minutes, ctx)
    EventBus.time_advanced.emit(minutes)
    ...
```

---

## Fatica da combattimento

Legata alle **azioni del player**, non ai colpi ricevuti passivamente:

| Azione | exhaustion gain |
|--------|----------------|
| Attacco leggero | +0.1 |
| Attacco pesante / skill fisica | +0.3–0.5 |
| Schivata | +0.3 |
| Parata | +0.2 |
| Colpo subito pesante (danno > 10% max_hp) | +0.2 |

Hook in `Player._action_done()` o `CombatManager` → `NeedsManager.consume({"exhaustion": +X})`.

---

## HUD

**Il HUD va rifatto contestualmente a questo sistema** — non aggiungere barre all'HUD attuale.

**Design proposto (ASCII puro — no emoji):**
- Indicatori compatti sempre visibili: `[F:85]  [W:62]  [E:12]` — solo fame, sete, exhaustion
- Colore stato: bianco=ok, giallo=warning, rosso=critical, lampeggiante=depleted
- Tasto **F** → apre menu rapido cibo/acqua: lista item consumabili dall'inventario, usa con Enter
- Dettaglio completo (valori precisi, malattie attive) solo nel pannello personaggio
- Alert testuale nel log per notifiche critiche — no popup invasivi

Il refactor HUD è un task separato da fare **in parallelo o prima** dell'implementazione.

---

## Malattie — `active_diseases`

Ogni entry in `active_diseases`: `{ "id": "...", "stage_index": 0, "elapsed_minutes": 0 }`.
`NeedsManager._tick_diseases(minutes)` incrementa `elapsed_minutes`, controlla `advance_triggers` per avanzare lo stage, e calcola debuff e danno dallo stage corrente.

### Schema JSON malattia (`data/diseases/<id>.json`)

```jsonc
{
    "id": "...",
    "name": "Nome Display",
    "description": "Breve descrizione visibile al player",

    // Come si contrae la malattia — condizioni OR: basta che una sia vera
    "acquisition": [
        { "type": "needs_zero",         "need": "food",    "min_minutes": 720 },
        { "type": "enemy_tag",          "tag": "rabid" },
        { "type": "biome",              "biome_id": "swamp", "min_minutes": 240 },
        { "type": "item_consume",       "item_tag": "contaminated" },
        { "type": "item_consume",       "item_id": "fungo_selvatico_non_identificato" },
        { "type": "hp_critical",        "threshold": 0.10, "min_minutes": 5 },
        { "type": "exhaustion_above",   "threshold": 90,   "occurrences": 3 },
        { "type": "continuous_dungeon", "min_days": 7 },
        { "type": "no_item_tag",        "item_tag": "vitamin_source", "min_days": 20 },
        { "type": "game_event",         "event_id": "city_plague_outbreak" }
    ],

    "stages": [
        {
            "label": "Lieve",
            "malus": {
                // ── Combat ────────────────────────────────────────────────────
                "atk_mult":            -0.10,  // delta su ctx.attack_multiplier in DamagePipeline
                                               // final = 1.0 + sum; floor 0.35; hook: player attacca
                "dmg_taken_mult":       0.15,  // delta su ctx.target_multiplier in DamagePipeline
                                               // final = 1.0 + sum; hook: player difende
                "accuracy_penalty":    -0.10,  // delta flat su hit_chance in CombatManager._calc_hit()
                                               // somma diretta; hook: dopo il clamp BASE±stat*K
                // ── Attributi (int/wil → magic hit, MP pool) ─────────────────
                "int_mult":            -0.15,  // delta su effective_attributes["int"]
                                               // final = int * (1.0 + sum); usato in (int+wil)/2 e max_mp
                "wil_mult":            -0.20,  // delta su effective_attributes["wil"]
                                               // final = wil * (1.0 + sum); usato in (int+wil)/2 e max_mp
                // ── Movimento / Tempo ────────────────────────────────────────
                "action_cost_mult":     0.5,   // delta su costo azione in minuti
                                               // final = 1.0 + sum; Player._action_done(): cost *= mult
                // ── Bisogni interni ──────────────────────────────────────────
                "food_drain_mult":      0.5,   // delta rate fame (sommato tra malattie; cap sum 2.0 → max 3× rate)
                "exhaustion_gain_mult": 0.3,   // delta rate exhaustion (sommato tra malattie; cap sum 1.5 → max 2.5× rate)
                // ── Percezione ──────────────────────────────────────────────
                "vision_penalty":      -2      // delta intero su FOV radius
                                               // hook: BaseMap._compute_fov() legge da needs_modifiers
            },
            "damage_per_30min": 0,

            // Condizioni per avanzare allo stage successivo — OR: basta che una sia vera
            "advance_triggers": [
                { "type": "time_elapsed",     "minutes": 1440 },
                { "type": "needs_zero",       "need": "food" },
                { "type": "exhaustion_above", "threshold": 70 },
                { "type": "no_rest",          "min_minutes": 2880 }
            ]
        }
        // ... stage successivi
    ],

    // Come si guarisce — array di trigger OR (basta uno)
    "cure_triggers": [
        { "type": "item_use",    "item_id": "antidoto" },
        { "type": "item_use",    "item_id": "erbe_medicinali" },
        { "type": "item_tag",    "item_tag": "cure_all" },
        { "type": "rest_type",   "rest": "inn" },         // guarigione naturale con riposo
        { "type": "time_elapsed","minutes": 720 },        // guarigione spontanea dopo X min
        { "type": "need_above",  "need": "food", "value": 60 }, // guarisce se mangi
        { "type": "game_event",  "event_id": "miracolo" }
    ],

    // Guarigione naturale per stage: riduce stage_index di 1 ogni N minuti se la condizione è soddisfatta
    // null = non guarisce mai da sola
    "natural_recovery": {
        "condition_type": "need_above",  // stesso tipo dei cure_triggers
        "condition_value": { "need": "food", "value": 60 },
        "minutes_per_stage": 1440
    }
}
```

### 32 malattie

File in `data/diseases/<id>.json`. Le chiavi `malus` omesse equivalgono a 0 / 1.0. Il JSON completo viene generato durante la Fase 5 — qui solo la lista + un esempio di riferimento.

**Lista:**
1. `malnutrizione` — food=0 per 120 min (trigger diretto)
2. `disidratazione_grave` — water=0 per 60 min (trigger diretto)
3. `ipotermia` — temperatura ≤ −75 (zona −4, trigger diretto)
4. `colpo_di_calore` — bioma `desert` / enemy tag `fire_breath` (NON da temperatura)
5. `rabbia` — enemy tag `rabid`; nessuna guarigione naturale
6. `febbre_palude` — bioma `swamp`, min_minutes 240
7. `peste` — enemy tag `plague_carrier` o game_event; 4 stage, letale
8. `colera` — item_consume tag `contaminated_water`
9. `tifo` — map_type `city` prolungato (min_minutes 480) o enemy tag `filthy`¹
10. `influenza` — exhaustion>70 + bioma `mountain` o `tundra`
11. `cancrena` — hp_critical 20% senza riposo per 120+ min; letale se non curata
12. `intossicazione_alimentare` — item_consume tag `spoiled_food`
13. `parassiti_intestinali` — item_consume tag `raw_meat` o `unclean_water`
14. `tetano` — enemy tag `rusty_blade`; accuracy_penalty crescente
15. `veleno_serpente` — enemy tag `venomous_snake`; rapido e letale
16. `veleno_ragno` — enemy tag `venomous_spider`; paralisi + accuracy_penalty
17. `scorbuto` — no `vitamin_source` per 20 giorni
18. `corruzione_umbrale` — enemy tag `corrupting`
19. `febbre_putrefazione` — enemy tag `rotting_undead`
20. `maledizione_mummia` — enemy tag `ancient_undead`; vision_penalty
21. `follia_arcana` — item cursed o game_event `arcane_overload`
22. `febbre_draconica` — enemy tag `dragon_breath`; danno rapido
23. `shock_traumatico` — hp < 10% per 5 min; accuracy_penalty
24. `insonnia_cronica` — exhaustion≥90 per 3 volte distinte (trigger diretto in codice — edge detection `_high_exhaustion_count`; NON gestita da `_check_acquisition_triggers`)
25. `intossicazione_alcol` — 3+ item tag `alcohol`; 1 stage, guarisce in 480 min
26. `febbre_dungeon` — 7 giorni continui in dungeon
27. `cecita_temporanea` — enemy tag `blinding_attack`; vision_penalty −8, accuracy_penalty −0.50
28. `lebbra` — enemy tag `leper`; 4 stage lentissimi (20160/28800 min)
29. `avvelenamento_fungo` — item_consume tag `toxic_mushroom`
30. `maledizione_demoniaca` — enemy tag `demon_curse`; nessuna cura tranne item rituali
31. `congelamento` — enemy tag `frost_bite` o bioma `tundra` prolungato (NON da temperatura diretta)
32. `ipertermia` — temperatura ≥ +85 (zona +4, trigger diretto)

¹ `map_type` è un nuovo tipo di acquisition (`"type": "map_type"`) distinto da `biome`. Serve per malattie legate all'ambiente costruito (città, dungeon), non al bioma overworld.

**Esempio completo** (usato come template per tutti gli altri durante l'implementazione):

```jsonc
// 1 — malnutrizione
{ "id": "malnutrizione", "name": "Malnutrizione",
  "description": "Il corpo ha esaurito le riserve nutritive.",
  "acquisition": [{ "type": "needs_zero", "need": "food", "min_minutes": 120 }],
  "stages": [
    { "label": "Lieve",    "malus": { "wil_mult": -0.10 }, "damage_per_30min": 0,
      "advance_triggers": [{ "type": "needs_zero", "need": "food", "min_minutes": 1440 }] },
    { "label": "Moderata", "malus": { "atk_mult": -0.10, "dmg_taken_mult": 0.10, "wil_mult": -0.15 }, "damage_per_30min": 2,
      "advance_triggers": [{ "type": "needs_zero", "need": "food", "min_minutes": 2880 }] },
    { "label": "Grave",    "malus": { "atk_mult": -0.25, "dmg_taken_mult": 0.20, "wil_mult": -0.25, "action_cost_mult": 0.5 }, "damage_per_30min": 5,
      "advance_triggers": [] }
  ],
  "cure_triggers": [{ "type": "need_above", "need": "food", "value": 50 }],
  "natural_recovery": { "condition_type": "need_above", "condition_value": { "need": "food", "value": 60 }, "minutes_per_stage": 720 } }
// ... (tutti gli altri generati a runtime durante Fase 5)
// FINE ESEMPIO
```

---

## Item — schema effetti

```jsonc
// Oggetto semplice
{ "id": "borraccia_acqua",
  "effect": { "type": "needs", "changes": { "water": 40 } } }

// Oggetto misto
{ "id": "zuppa_calda",
  "effect": { "type": "needs", "changes": { "food": 35, "water": 15, "exhaustion": -5 } } }

// Cura malattia specifica
{ "id": "antidoto",
  "effect": { "type": "disease_cure", "disease_id": "veleno_serpente" } }

// Cura per tag (cura tutte le malattie con questo item_id in cure_triggers)
{ "id": "acqua_santa",
  "effect": { "type": "disease_cure_by_item", "item_id": "acqua_santa" } }

// Item alcolico — usa effect needs + tag "alcohol" nell'item JSON
{ "id": "birra",
  "tags": ["alcohol", "consumable"],
  "effect": { "type": "needs", "changes": { "water": 10, "exhaustion": -3 } } }
// → l'acquisizione di intossicazione_alcol conta i consumi di item con tag "alcohol" (qty ≥ 3)
```

`Inventory.use_item()` legge `effect.type`:
- `"needs"` → `NeedsManager.consume(effect["changes"])`
- `"disease_cure"` → `NeedsManager.cure_disease(effect["disease_id"])` — cura la malattia specifica
- `"disease_cure_by_item"` → `NeedsManager.cure_diseases_matching_item(effect["item_id"])` — cura tutte le malattie che hanno questo item nei `cure_triggers`

---

## Save / Load

```gdscript
# _save_character(): aggiungere
"food":            GameState.food,
"water":           GameState.water,
"exhaustion":      GameState.exhaustion,
"temperature":     GameState.temperature,
"active_diseases": GameState.active_diseases.duplicate(true),

# _apply_save_data(): aggiungere
GameState.food        = float(data.get("food",        100.0))
GameState.water       = float(data.get("water",       100.0))
GameState.exhaustion  = float(data.get("exhaustion",  0.0))
GameState.temperature = float(data.get("temperature", 0.0))
var raw_d: Variant = data.get("active_diseases", [])
if raw_d is Array:
    GameState.active_diseases = (raw_d as Array).duplicate(true)
# Gli accumulatori e _last_meal_hint NON si serializzano — resetrano al load
```

---

## EventBus — nuovi segnali

```gdscript
needs_changed()                                       # HUD update generico
need_warning(need: String)                            # passaggio ok → warning (food/water/exhaustion)
need_critical(need: String)                           # passaggio warning → critical
need_depleted(need: String)                           # food/water = 0, exhaustion = 100
temperature_zone_changed(zone: int, direction: String) # zona cambiata (0–3), "cold"|"hot" — per aggiornare HUD e notifiche
player_took_needs_damage(source: String, amount: int) # intercettato da Player → take_damage(amount)
player_collapsed()                                    # exhaustion = 100 → Main gestisce fade+advance
meal_hint(meal: String)                               # "pranzo" | "cena" — messaggio discreto nel log
disease_acquired(disease_id: String, name: String)    # malattia contratta
disease_progressed(disease_id: String, name: String, stage_label: String)  # stage avanzato
disease_cured(disease_id: String)                     # malattia rimossa
```

---

## Questioni aperte

- **Rate dungeon**: calibrare empiricamente — target ~4–6h dungeon = −15–20 food, non letale in sé
- **Temperatura in dungeon**: i dungeon hanno temperatura interna = 0 (stabile)? O variano per tipo (es. dungeon ghiacciato, vulcanico)?
- **Locanda e pasto**: il prezzo della locanda include cibo/acqua? O sono due voci separate?
- **Display nomi malattie**: solo nel pannello personaggio o anche in HUD?
- **Fatica da combattimento**: i valori +0.1/+0.3/ecc. vanno calibrati dopo i primi test
- **Colazione opzionale**: skip colazione = food ~85 invece di 100 a inizio giornata — gestito dall'item, non dal codice
- **Exhaustion durante sonno**: la sleep recovery è solo via `rest()` o anche via rate negativo nel tick (context sleep)?

---

## Lista task

> **Regole valide per ogni fase:**
> - Aggiungere debug screen integration (comandi/sezione dedicata nella debug screen esistente)
> - **Localizzazione**: tutte le stringhe visibili al player (messaggi log, nomi malattie, notifiche, label HUD) devono usare `tr("CHIAVE")` — nessuna stringa hardcoded diretta nella UI. Le chiavi vanno aggiunte ai file `.po`/`.csv` di localizzazione contestualmente all'implementazione.
> - A fine fase: aggiornare questo piano (segno ✓ sulle voci completate + eventuali commenti)
> - A fine fase: aggiornare `codebase_reference.md` con i nuovi autoload/sistemi/segnali
> - A fine fase: inviare recap con fasi completate (con sottofasi e commenti) e fasi ancora da fare

### FASE 0 — HUD (prerequisito) ✓

*Da fare prima o in parallelo con FASE 1. Senza HUD non si vede nulla durante i test.*

- [x] Refactor HUD completo — `NeedsRTL` + `DiseasesLabel` in HUD.tscn; Panel espanso a 248px
- [x] Indicatori bisogni ASCII compatti (`[F:85]  [W:62]  [E:12]`) con colore stato (bianco/giallo/rosso) — via BBCode in `NeedsRTL`
- [x] Tasto F: menu rapido cibo/acqua — `QuickFoodMenu.gd` (CanvasLayer layer=15); apre solo consumabili
- [x] Alert testuale nel log per notifiche critiche — `Main.gd` connette `need_warning/critical/depleted` → `EventBus.combat_log`
- [x] Aggiornamento su `needs_changed` — HUD.gd connesso al signal
- [x] HUD malattie: nascosto se `active_diseases` vuoto; mostra nome + stage label per ciascuna — `DiseasesLabel` via `DiseaseRegistry.get_def()` (graceful fallback a `id` se registry non ancora caricato)
- [x] **Debug screen**: sezione "Needs System" (aggiornata ogni 0.5s) + NeedsTools con pulsante Toggle HUD Bisogni
- [x] **GameState**: campi `food`, `water`, `exhaustion`, `temperature`, `active_diseases`, `needs_modifiers` aggiunti; reset in `_reset_game_state()`
- [x] **EventBus**: tutti i segnali needs aggiunti (`needs_changed`, `need_warning/critical/depleted`, `player_took_needs_damage`, `player_collapsed`, `meal_hint`, `temperature_zone_changed`, `disease_acquired/progressed/cured`)
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference aggiornato ✓ · recap inviato ✓

### FASE 1 — Core ✓

- [x] `GameState`: `food`, `water`, `exhaustion`, `temperature` (float), `active_diseases` (Array), `needs_modifiers` (Dictionary) — fatto in FASE 0
- [x] `NeedsManager.gd` autoload: `tick()`, `_tick_step()`, `_calculate_rates()`, `_check_disease_triggers()`, `consume()`, `rest()`, `add_disease()`, `cure_disease()`, `cure_all_diseases()`, `rebuild_modifiers()`, `_update_modifiers()`, `_check_state_transitions()`, `_check_meal_hints()`, `_check_collapse()`
- [x] **`DiseaseRegistry.gd` stub** — `get_def(id) -> Dictionary` restituisce `{}`; stub completo in FASE 5
- [x] `project.godot`: `DiseaseRegistry` e `NeedsManager` registrati dopo `TimeManager`
- [x] `TimeManager.advance(minutes, extra_ctx)`: firma aggiornata; chiama `NeedsManager.tick(minutes, ctx)` con merge del context
- [x] `EventBus`: tutti i segnali needs — fatto in FASE 0
- [x] `Player.gd`: `player_took_needs_damage` → `take_damage(amount)` via `_on_needs_damage()`
- [x] `Main.gd`: `player_collapsed` → `ScreenFade.fade()` con `TimeManager.advance(60, {"activity":"sleep"})` + exhaustion −25 + HP −10%
- [x] `SaveManager`: serializza/deserializza `food`, `water`, `exhaustion`, `temperature`, `active_diseases`; `NeedsManager.rebuild_modifiers()` al load
- [x] `Main._reset_game_state()`: inizializza i 5 campi ai default — fatto in FASE 0
- [x] **Debug screen**: `_update_needs()` espanso con zona temperatura, lista malattie con stage/elapsed, tutti i modificatori, accumulatori; `_build_needs_tools()` espanso con SpinBox set per ogni campo, tick N min, simulate biome (OptionButton + target), add_disease / cure_all
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference aggiornato ✓ · recap inviato ✓

### FASE 2 — Effetti su stat e combattimento ✓

- [x] `NeedsManager._update_modifiers()`: già completo in FASE 1; aggiunta chiamata a `GameState.recalculate_derived_stats()` al termine; `tick()` emette `player_stats_changed` dopo `needs_changed`
- [x] `DamagePipeline`: applica `needs_modifiers["atk_mult"]` (player attacca) e `needs_modifiers["dmg_taken_mult"]` (player difende); fatica da colpo pesante: `final_damage * 10 > max_hp` → `NeedsManager.consume({"exhaustion": 0.2})`
- [x] `CombatManager._calc_hit()`: magic hit usa `int_mult`/`wil_mult` su int/wil; `accuracy_penalty` applicato flat dopo il clamp BASE±stat*K
- [x] `GameState.recalculate_derived_stats()`: `max_mp` ora usa `int_mult`/`wil_mult` da `needs_modifiers`; `vision_penalty` applicato in `BaseMap._get_player_fov_radius()` (base + vis_pen, min 1)
- [x] `Player._action_done()`: `action_cost_mult` applicato a qualsiasi costo azione (incluso override overworld); fatica attacco: `_last_action == ATTACK` → `consume({"exhaustion": 0.1})`
- [x] Fatica da combattimento: attacco normale +0.1 (Player._action_done); colpo pesante subito +0.2 (DamagePipeline step 3)
- [x] **Debug screen**: display `needs_modifiers` già completo (FASE 1); aggiunta riga "Simula azione combattimento" con OptionButton (attacco +0.1 / colpo_pesante_subito +0.2) + bottone Simula
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference aggiornato ✓ · recap inviato ✓

### FASE 3 — Item consumabili ✓

- [x] `data/items/consumables/cibo/`: tutti i 32 item aggiornati a schema `"type": "needs"` con `"changes"` (food, water, exhaustion); item ibridi (ambrosia, acqua_fonte_sacra, miele_selvatico, ecc.) mantengono anche legacy keys restore_hp/mp
- [x] `data/items/consumables/recupero/`: `antidoto.json` e `erbe_medicinali.json` creati con `"type": "disease_cure_by_item"`
- [x] `Inventory.use_item()`: dispatch `match effect_type:` per `"needs"`, `"disease_cure"`, `"disease_cure_by_item"`; legacy keys ancora processate per compatibilità ibrida
- [x] `QuickFoodMenu._populate()`: filtro cambiato da `item_category == "consumable"` a `effect.type in ["needs", "disease_cure", "disease_cure_by_item"]`
- [x] Nuovi item: `borraccia_acqua` (water:40), `zuppa_calda` (food:35 water:15 exh:-5), `falo_portatile` (temp:+20, tag heat_source), `panno_bagnato` (temp:-15, tag cooling)
- [x] `birra_guerriero.json`: aggiunto tag `alcohol`; effetto convertito a needs (food:12 water:20 exh:-5)
- [x] `NeedsManager.cure_diseases_matching_item(item_id)` stub aggiunto (implementazione FASE 5)
- [x] **Debug screen**: row "Dai x3 / Usa" con OptionButton per i 12 item needs principali
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference aggiornato ✓ · recap inviato ✓

### FASE 4 — Save point e riposo ✓

- [x] `Player._use_save_point()`: chiama `NeedsManager.rest("save_point")` nella callback del fade (dopo player_stats_changed, prima di FactionEconomy.on_rest)
- [ ] Locanda NPC (quando Vendor System esiste): `NeedsManager.rest("inn")` + `TimeManager.advance(480)`
- [ ] `NeedsManager.rest("camp")` pronto per il Camping System
- [x] **Debug screen**: row "Riposa" con OptionButton (save_point/inn/camp) + pulsante in fondo a NeedsTools
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference aggiornato ✓ · recap inviato ✓

### FASE 5 — Malattie ✓

- [x] `DiseaseRegistry.gd` completo: carica `data/diseases/*.json` via `DirAccess`, espone `get_def(id)` e `get_all_defs()`
- [x] `data/diseases/*.json`: 32 malattie — 5 trigger da codice (malnutrizione, disidratazione_grave, ipotermia, ipertermia, insonnia_cronica), 27 da nemici/biomi; stages con malus, advance_triggers, damage_per_30min; cure_triggers (item_use, item_tag, rest_type, time_elapsed, need_above); natural_recovery opzionale
- [x] `NeedsManager._tick_diseases(minutes)`: già presente da FASE 1; ora lavorativa su dati reali
- [x] `NeedsManager.cure_diseases_matching_item(item_id)`: implementazione completa — controlla item_use e item_tag nei cure_triggers
- [x] `NeedsManager._check_natural_recovery(minutes)`: riduce stage_index quando condizione soddisfatta; usa `_nat_recovery_acc`
- [x] `NeedsManager._check_time_cure_triggers(minutes)`: cura automatica per time_elapsed; usa `_cure_time_acc`
- [x] `NeedsManager._check_need_cure_triggers()`: cura quando bisogno above threshold
- [x] `NeedsManager._check_rest_cures(rest_type)`: cura malattie con rest_type trigger; chiamata da `rest()`
- [x] `_eval_recovery_condition()`: helper per valutare condizione natural_recovery (need_above, exhaustion_below, always)
- [x] `CombatManager._check_disease_on_hit(attacker)`: 30% chance (configurabile) di trasmettere `disease_on_hit` dell'enemy; chiamato dopo ogni colpo su player da nemico
- [x] `antidoto.json`: tag `antidote`; `erbe_medicinali.json`: tag `herbal`, `medicine`
- [x] **Debug screen**: OptionButton malattie aggiornato a 32 id; pulsante "Avanza" per avanzare lo stage manualmente
- [x] **Fine fase**: piano aggiornato ✓ · codebase_reference da aggiornare · recap in corso

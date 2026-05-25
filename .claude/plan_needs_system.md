# Piano: Needs System (Sistema Bisogni)

**Stato**: Bozza — da progettare in dettaglio prima di implementare. Prerequisito del Travel System.

**Dipendenze**: Time System ✗

---

## Bisogni implementati

| Bisogno | Campo GameState | Range | Effetto a zero |
|---------|----------------|-------|----------------|
| Fame (`hunger`) | `hunger: int` | 0–100 | Danno periodico ogni N minuti |
| Sete (`thirst`) | `thirst: int` | 0–100 | Danno periodico ogni N minuti (più veloce della fame) |
| Sonno/fatica (`fatigue`) | `fatigue: int` | 0–100 | Malus stat pesanti; a 100 = esausto |
| Malattia (`illness`) | `illness: int` | 0–100 | Danno periodico + debuff; richiede cure |

Tutti inizializzati a **100** (pieni) per un nuovo personaggio.

---

## Rate di consumo per tipo mappa

Il consumo avviene via `TimeManager.advance()` → `NeedsManager.tick(minutes)`.

| Mappa | Fame/min | Sete/min | Fatica/min |
|-------|----------|----------|------------|
| `overworld` | 0.050 | 0.080 | 0.030 |
| `dungeon` | 0.010 | 0.015 | 0.020 |
| `ruin` | 0.010 | 0.015 | 0.020 |
| `village` | 0.003 | 0.005 | 0.005 |
| `city` | 0.003 | 0.005 | 0.005 |
| `building` | 0.001 | 0.002 | 0.002 |

Con 1 tile overworld = 1440 minuti:
- Plains: -72 fame, -115 sete, -43 fatica per tile (bilanciare dopo test)
- Mountain: -216 fame, -345 sete, -130 fatica (3 giorni)

La fatica si recupera dormendo (save point / locanda) — il riposo la azzera o riduce.

---

## Soglie e debuff

### Fame e Sete

| Valore | Stato | Effetto |
|--------|-------|---------|
| 50–100 | Ben nutrito | Nessun malus |
| 25–49 | Affamato/Assetato | ATK −10%, DEF −10%; notifica |
| 1–24 | Molto affamato/assetato | ATK −25%, DEF −25%, speed −1; notifica urgente |
| 0 | Moribondo | Danno periodico: −3 HP ogni 60 minuti di gioco |

### Fatica

| Valore | Stato | Effetto |
|--------|-------|---------|
| 0–30 | Riposato | Nessun malus; HP/MP regen bonus al save point |
| 31–60 | Stanco | Nessun malus significativo |
| 61–85 | Affaticato | ATK −15%, accuratezza ridotta |
| 86–99 | Esausto | ATK −30%, DEF −20%, no regen HP/MP |
| 100 | Collasso | Stesso di esausto + movimento rallentato (nessuna hold-to-move) |

La fatica si azzera al save point (dormire). In futuro: letto in locanda (NPC vendor).

### Malattia

Si sviluppa quando:
- Fame = 0 per più di 720 minuti (12 ore di gioco)
- Sete = 0 per più di 360 minuti (6 ore)
- Certi nemici infliggono malattia (tag `disease` su attacco)
- Dormire in certi biomi senza riparo (futuro)

Progressione `illness`:
- Sale lentamente se le condizioni sopra persistono (+1 ogni 60 min)
- Scende con cure (`pozione_guarigione`, `antidoto`, NPC Officine)
- A 100: `−5 HP ogni 30 minuti` + ATK −40%

---

## NeedsManager — `scripts/core/NeedsManager.gd`

Nuovo autoload. Da registrare dopo `TimeManager`.

```gdscript
extends Node

# Chiamato da TimeManager.advance() ad ogni avanzamento del tempo
func tick(minutes: int, map_type: String) -> void:
    var rates: Dictionary = _get_rates(map_type)
    GameState.hunger  = maxf(0.0, GameState.hunger  - rates.hunger  * minutes)
    GameState.thirst  = maxf(0.0, GameState.thirst  - rates.thirst  * minutes)
    GameState.fatigue = minf(100.0, GameState.fatigue + rates.fatigue * minutes)
    _check_starvation_damage(minutes)
    _check_illness_progression(minutes)
    _apply_stat_modifiers()
    EventBus.needs_changed.emit()

func consume(need: String, amount: float) -> void:
    # Consuma direttamente un bisogno (es. mangiare cibo → hunger += amount)
    match need:
        "hunger":  GameState.hunger  = minf(100.0, GameState.hunger  + amount)
        "thirst":  GameState.thirst  = minf(100.0, GameState.thirst  + amount)
        "fatigue": GameState.fatigue = maxf(0.0,   GameState.fatigue - amount)
    EventBus.needs_changed.emit()

func rest() -> void:
    # Chiamato dal save point / locanda
    GameState.fatigue = 0.0
    EventBus.needs_changed.emit()

func _get_rates(map_type: String) -> Dictionary:
    # Restituisce {hunger, thirst, fatigue} per tipo mappa
    ...

func _check_starvation_damage(minutes: int) -> void:
    # Se hunger == 0 o thirst == 0: accumula danno proporzionale ai minuti
    ...

func _apply_stat_modifiers() -> void:
    # Scrive GameState.needs_modifiers (Dictionary) letto da GameState.effective_attributes
    # o applica direttamente malus temporanei su player_stats
    ...
```

### Integrazione con TimeManager

In `TimeManager.advance()`:
```gdscript
func advance(minutes: int) -> void:
    ...
    NeedsManager.tick(minutes, _current_map_type())
    EventBus.time_advanced.emit(minutes)
    ...
```

---

## Integrazione GameState

```gdscript
# Nuovi campi (float per precisione)
var hunger:  float = 100.0
var thirst:  float = 100.0
var fatigue: float = 0.0
var illness: float = 0.0

# Modificatori temporanei dai bisogni (letti da CombatManager/DamagePipeline)
var needs_modifiers: Dictionary = {}
# es. { "atk_mult": 0.75, "def_mult": 0.85 }
```

I `needs_modifiers` vengono applicati al calcolo danno in `DamagePipeline` e al calcolo stat nel `HUD`.

---

## HUD

Aggiungere indicatori needs nell'HUD:
- Barre piccole o icone per Fame, Sete, Fatica, Malattia
- Colore: verde (ok), giallo (warning), rosso (critico)
- Si aggiornano su `EventBus.needs_changed`

---

## Item per soddisfare i bisogni

I consumabili esistenti ricevono nuovi campi nei loro JSON:

```jsonc
{
  "id": "pane",
  "effect": { "type": "need", "need": "hunger", "amount": 30 }
}
{
  "id": "borraccia_acqua",
  "effect": { "type": "need", "need": "thirst", "amount": 40 }
}
{
  "id": "antidoto",
  "effect": { "type": "need", "need": "illness", "amount": -30 }
}
```

`Inventory.use_item()` dispatcha al `NeedsManager.consume()` per type `"need"`.

---

## Integrazione Travel System

Quando il Travel System esegue un viaggio astratto di N giorni:
```gdscript
# In TravelService.execute_travel()
NeedsManager.tick(days * 1440, "overworld")
# → consuma automaticamente le risorse proporzionalmente ai giorni
# → se fame/sete a zero durante il viaggio → player arriva debilitato / con danno
```

In futuro: il player può portare provviste per il viaggio (inventario consumato durante `tick`).

---

## EventBus — nuovi segnali

```gdscript
needs_changed()                          # aggiorna HUD
need_critical(need: String)              # notifica quando scende sotto 25
need_depleted(need: String)              # notifica quando raggiunge 0
```

---

## Save/Load

```gdscript
# SaveManager._save_character(): serializza hunger, thirst, fatigue, illness
# SaveManager._load_character(): ripristina
```

---

## Questioni aperte (da decidere al momento dell'implementazione)

- **Come si guadagna fatica in combattimento?** Ogni attacco subito? Solo in certi biomi?
- **Sonno in locanda**: serve un letto NPC vendor per riposare completamente vs save point che resetta solo a metà?
- **Provviste per viaggio**: l'inventario ha slot dedicati (borraccia, zaino viveri) o si usano normali consumabili?
- **Display fatica in HUD**: barra separata o integrata con la stamina esistente?
- **Malattia da nemici**: quali nemici infliggono malattia? Solo non-morti? Solo tier 3+?

---

## Lista task

### FASE 1 — Core (dopo Time System)

- [ ] `GameState`: `hunger`, `thirst`, `fatigue`, `illness` (float, 0–100)
- [ ] `GameState.needs_modifiers: Dictionary`
- [ ] `NeedsManager.gd` autoload: `tick()`, `consume()`, `rest()`
- [ ] `project.godot`: registrare `NeedsManager` dopo `TimeManager`
- [ ] `TimeManager.advance()`: chiama `NeedsManager.tick(minutes, map_type)`
- [ ] `EventBus`: `needs_changed`, `need_critical`, `need_depleted`
- [ ] `SaveManager`: serializza/deserializza i 4 campi needs
- [ ] HUD: indicatori needs (barre o icone)
- [ ] Notifiche: `NOTIF_NEED_HUNGRY`, `NOTIF_NEED_THIRSTY`, `NOTIF_NEED_EXHAUSTED`, `NOTIF_NEED_SICK`

### FASE 2 — Effetti sui combattimento e stat

- [ ] `DamagePipeline`: applica `needs_modifiers.atk_mult` al danno player
- [ ] `GameState.effective_attributes` o `player_stats`: integra malus needs
- [ ] `NeedsManager._apply_stat_modifiers()`: scrive `needs_modifiers`

### FASE 3 — Item consumabili

- [ ] `data/items/consumables/`: aggiungere `need` effect ai JSON cibo/acqua/cure
- [ ] `Inventory.use_item()`: dispatch per type `"need"` → `NeedsManager.consume()`
- [ ] Creare item base: pane, carne secca, borraccia acqua, erbe medicinali

### FASE 4 — Save point e riposo

- [ ] `Player._use_save_point()`: chiama `NeedsManager.rest()` (azzera fatica)
- [ ] Fatica: non si azzera completamente al save point se illness > 50

### FASE 5 — Malattia

- [ ] `NeedsManager._check_illness_progression()`: logica sviluppo malattia da bisogni critici
- [ ] Danno periodico illness a 100
- [ ] Item cura malattia: `antidoto`, `pozione_guarigione_avanzata`

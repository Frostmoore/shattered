# Piano: Camping System

**Stato**: Progettato — da implementare dopo Time System e Needs System.  
**Dipendenze**: Time System (obbligatorio), Needs System (integrazione posticipata).

---

## Obiettivo

Permettere al player di riposare fuori da un save point per recuperare risorse e far avanzare il tempo. Due varianti: **bivacco sul campo** (parziale, rischioso) e **riposo in locanda** (completo, sicuro — già gestito altrove tramite dialogo NPC).

Il Camping System riguarda esclusivamente il bivacco: overworld e dungeon.

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Dove si può campare | Overworld sempre; Dungeon sempre; Village/City/Building mai (usare locanda) |
| Trigger | Tasto dedicato (`C` o voce nel PauseMenu → "Accamparsi") |
| Costo tempo | 480 min (8 ore) — una notte completa |
| Recovery HP | 50% del max_hp mancante (non completa) |
| Recovery MP | 50% del max_mp mancante |
| Recovery stamina | Completa |
| Rischio incontro | Probabilità × map_type × ora del giorno |
| Needs System | Consuma cibo e acqua al camp (hook deferred — vedi sotto) |
| Limite camp | Nessun item richiesto inizialmente; con Needs System servirà un bivacco o legna |

---

## Tipi di riposo — confronto

| | Bivacco (campo) | Locanda | Save Point |
|--|----------------|---------|------------|
| Dove | Overworld, Dungeon | Village/City | Dungeon |
| Tempo avanzato | 480 min | 480 min | 0 min |
| HP recovery | 50% mancante | 100% | 100% |
| MP recovery | 50% mancante | 100% | 100% |
| Rischio incontro | Sì | No | No |
| Salva partita | No | Dipende da NPC | Sì |
| Consuma risorse | Sì (futuro) | Paga oro | No |

---

## Probabilità incontro notturno

La probabilità base di un incontro durante il camp:

| Contesto | Probabilità base |
|----------|-----------------|
| Overworld, di giorno | 10% |
| Overworld, di notte | 25% |
| Dungeon (qualsiasi ora) | 35% |

Modificatori futuri: bioma pericoloso (+10%), Needs System (fame/sete riduce soglia).

Se si verifica un incontro: il player viene svegliato con un messaggio ("Sei stato attaccato nel sonno!") e il combat inizia normalmente. Il tempo avanza comunque di 480 min.

---

## Architettura — CampManager (o in Player.gd)

Data la semplicità, non serve un autoload separato. Il comportamento può stare in `Player.gd` o in un metodo statico chiamato dal menu. Se in futuro cresce (save al camp, fuochi da campo, guard turns), separarlo in `CampManager.gd`.

```gdscript
# In Player.gd (o CampManager.gd):

func try_camp() -> void:
    var map: BaseMap = WorldManager.get_current_map()
    if map == null:
        return
    if map.map_type in ["village", "city", "building"]:
        Notification.warning("Non puoi accamparti qui. Cerca una locanda.")
        return
    if not _can_act:
        return

    _do_camp(map)


func _do_camp(map: BaseMap) -> void:
    # 1. Avanza il tempo
    TimeManager.advance(480)

    # 2. Recovery parziale
    var hp_gain:  int = (GameState.player_stats["max_hp"]  - GameState.player_stats["hp"])  / 2
    var mp_gain:  int = (GameState.player_stats["max_mp"]  - GameState.player_stats["mp"])  / 2
    GameState.player_stats["hp"]      = mini(GameState.player_stats["max_hp"],  GameState.player_stats["hp"]  + maxi(1, hp_gain))
    GameState.player_stats["mp"]      = mini(GameState.player_stats["max_mp"],  GameState.player_stats["mp"]  + maxi(0, mp_gain))
    GameState.player_stats["stamina"] = GameState.player_stats.get("max_stamina", 100)
    EventBus.player_stats_changed.emit()

    # 3. Hook Needs System (deferred — solo se esiste)
    var needs: Node = get_node_or_null("/root/NeedsManager")
    if needs != null:
        needs.call("consume_for_camp")   # consuma cibo/acqua per 8 ore

    # 4. Check incontro casuale
    _roll_camp_encounter(map)

    # 5. Notifica
    Notification.info("Hai riposato. HP e MP parzialmente recuperati.")
```

---

## Probabilità incontro — implementazione

```gdscript
func _roll_camp_encounter(map: BaseMap) -> void:
    var chance: float
    match map.map_type:
        "dungeon": chance = 0.35
        _:         chance = 0.25 if TimeManager.is_night() else 0.10

    if randf() < chance:
        _trigger_camp_encounter(map)


func _trigger_camp_encounter(map: BaseMap) -> void:
    # Sveglia il player con un messaggio
    EventBus.combat_log.emit("Sei stato sorpreso nel sonno!")
    # L'incontro reale dipende dall'Overworld/Dungeon encounter system — per ora solo log
    # TODO: spawn nemico nella tile adiacente e avvia combattimento
```

---

## Integrazione HUD / Input

```gdscript
# In Player._unhandled_input() o Main._unhandled_input():
if Input.is_action_just_pressed("camp"):
    get_node("/root/WorldManager").get_current_map()
    # oppure chiamata diretta al player
    _player.try_camp()
```

Aggiungere `"camp"` all'InputMap in `project.godot` (tasto suggerito: `C`).

---

## Questioni aperte

- **Encounter reale**: per ora il camp encounter è solo un log. Quando esiste il sistema di spawn encounter (Overworld System), va sostituito con uno spawn reale.
- **Legna/bivacco**: con il Needs System, campare senza legna o cibo dovrebbe dare penalità al recovery.
- **Save al camp**: opzione futura — campare potrebbe anche salvare, ma solo su overworld (non in dungeon). Da decidere con Needs + permadeath rules.
- **Guard turns durante il camp**: in futuro gli NPC/nemici overworld si muovono mentre il player dorme (WorldActor ticks). Già gestito dal segnale `world_ticked` che TimeManager.advance(480) emetterà automaticamente (480/30 = 16 tick).

---

## Lista task

- [ ] Aggiungere `"camp"` all'InputMap in `project.godot`
- [ ] Implementare `try_camp()` in `Player.gd` (o `CampManager.gd`)
- [ ] Implementare `_do_camp()` con recovery parziale + TimeManager.advance(480)
- [ ] Implementare `_roll_camp_encounter()` con probabilità per map_type e ora
- [ ] Aggiungere tasto `C` (o voce PauseMenu) al trigger
- [ ] Aggiungere notifica result al player
- [ ] Hook NeedsManager (deferred — post Needs System)
- [ ] Hook encounter reale (deferred — post Overworld System)
- [ ] Voce "Accamparsi" nel PauseMenu con descrizione effetti

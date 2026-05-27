# Piano: Camping System

**Stato**: Design completato — pronto per implementazione.  
**Dipendenze**: Time System ✓, Needs System ✓, ClassRuntime (bonus classe).

---

## Obiettivo

Permettere al player di riposare fuori da un save point per recuperare risorse e far avanzare il tempo. Due varianti: **bivacco sul campo** (completo, con rischio) e **riposo in locanda** (completo, sicuro — già gestito tramite dialogo NPC).

Il Camping System riguarda esclusivamente il bivacco: overworld e dungeon.

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Dove si può campare | Overworld (qualsiasi tile) e Dungeon; mai in Village/City/Building |
| Trigger | Tasto `Z` + pulsante nella ActionBar (sempre visibile, grigio se non usabile) |
| Costo tempo | 480 min (8 ore) |
| Recovery | HP/MP/Stamina al **100%** (salvo classi speciali) |
| Needs consumati | Equivalente a **1 ora** di fabbisogno (metabolismo notturno quasi fermo) |
| Feedback visivo | ScreenFade semplice (come save point), nessun testo a schermo |
| Camp in combat | Impossibile — pulsante disabilitato quando TurnManager.is_active |
| Camp con HP bassi | Sempre permesso, nessuna soglia minima |
| Alleati | Recuperano HP al 100% come il player; partecipano normalmente agli encounter |
| Malattie/status | Il camp non cura nulla — le malattie continuano |
| Camp items | Nessuno — il personaggio è un professionista |

---

## Blocchi al camping

Il camp è bloccato (notifica warning) se:

1. **Mappa non permessa**: map_type in `["village", "city", "building"]`
2. **Nemici in range**: almeno un nemico entro **30 tile** dal player
3. **Limite raggiunto**: contatori esauriti (vedi sotto)
4. **Classe non può**: Mannaro, Lich, Spettro (notifica flavor specifica)

---

## Limiti di utilizzo

| Contesto | Limite base | Reset |
|----------|-------------|-------|
| Overworld | 1 ogni 5 giorni (7200 min) | Cambio mappa |
| Dungeon | 2 al giorno (2880 min) | Cambio dungeon (non cambio floor) |

**Tracking**: salvato nel save file, sopravvive al load.

- **Overworld**: `camp_last_overworld_minutes` in GameState — camp disponibile se `total_minutes - camp_last_overworld_minutes >= 7200`.
- **Dungeon**: `camp_dungeon_id` + `camp_dungeon_count` + `camp_dungeon_day` in GameState — count resettato al cambio dungeon o alla mezzanotte.

**ID dungeon**: estratto da `current_map_id` strippando `_floor_N` (es. `dungeon_01_floor_3` → `dungeon_01`).

---

## Probabilità incontro notturno

| Contesto | Probabilità base |
|----------|-----------------|
| Overworld, di giorno | 10% |
| Overworld, di notte | 25% |
| Dungeon (qualsiasi ora) | 35% |

Se incontro: solo messaggio log (`"Sei stato sorpreso nel sonno!"`). Niente spawn per ora — il nemico già presente sulla mappa si avvicina normalmente nel suo turno successivo.

---

## Bonus e malus per classe

| Classe | Effetto |
|--------|---------|
| Ranger | Probabilità encounter = 0 |
| Ladro | Probabilità encounter −50% |
| Sentinella | Probabilità encounter = 0 |
| Esploratore | Encounter = 0, needs = 0 consumati |
| Druido / Sciamano | Needs consumati dimezzati (0.5 ore invece di 1) |
| Viandante | Overworld: 2/5gg invece di 1/5gg; Dungeon: 3/giorno invece di 2 |
| Predatore | food/water += 3 dopo il camp |
| Arcicacciatore | food += 5 dopo il camp |
| Vampiro | Campa normalmente (tempo avanza, encounter possibile) ma recovery = 0 |
| Mannaro | Non può campare — "Le bestie non dormono" |
| Lich | Non può campare — "I non-morti non hanno bisogno di riposo" |
| Spettro | Non può campare — "Gli spettri non conoscono il sonno" |

**Note classi**:
- I bonus `food/water` di Predatore e Arcicacciatore vengono aggiunti direttamente a `GameState.food` / `GameState.water` per ora. Quando esiste una sezione "risorse inventario" dedicata si migra.
- I bonus classe sono letti da `ClassRuntime` tramite un metodo `get_camp_modifiers()` o da dati statici in `ClassRegistry`.

---

## Struttura dati in GameState

```gdscript
# Da aggiungere a GameState.gd
var camp_last_overworld_minutes: int = -99999  # -99999 = mai campato
var camp_dungeon_id: String = ""               # dungeon_id dell'ultimo camp
var camp_dungeon_count: int = 0                # camp fatti in questo dungeon oggi
var camp_dungeon_last_day: int = -1            # giorno (total_minutes / 1440) dell'ultimo reset
```

---

## Architettura — CampManager.gd (autoload o Node in Main)

Data la presenza di bonus classe, limiti, salvataggio stato — ha senso un `CampManager.gd` separato (non autoload, istanziato da Main o Player).

```gdscript
# Flusso principale
func try_camp() -> void:
    var block_reason: String = _get_block_reason()
    if block_reason != "":
        EventBus.notification_shown.emit(Notification.warning(block_reason))
        return
    _do_camp()

func _get_block_reason() -> String:
    # 1. Mappa
    # 2. Classe (Mannaro/Lich/Spettro)
    # 3. Nemici in range (30 tile)
    # 4. Limite raggiunto
    return ""  # "" = nessun blocco

func _do_camp() -> void:
    # 1. ScreenFade out
    # 2. TimeManager.advance(480)
    # 3. Recovery (salvo Vampiro)
    # 4. Needs consume (1 ora, salvo Esploratore/Druido/Sciamano)
    # 5. Bonus classe (Predatore/Arcicacciatore food/water)
    # 6. Aggiorna contatori + salva
    # 7. Roll encounter
    # 8. ScreenFade in
    # 9. Notifica risultato
```

---

## Integrazione ActionBar

- Aggiungere pulsante "⛺ / Z" nella ActionBar, sempre visibile.
- Disabilitato (grigio) quando `_get_block_reason() != ""`.
- Tooltip dinamico con il motivo del blocco.
- Disabilitato anche quando `TurnManager.is_active`.

---

## Integrazione Input

```gdscript
# In Player._unhandled_input():
if event.is_action_pressed("camp"):
    CampManager.try_camp()
    get_viewport().set_input_as_handled()
```

Aggiungere `"camp"` → `Z` all'InputMap in `project.godot`.

---

## Persistenza (SaveManager)

Aggiungere al save:
```gdscript
"camp_last_overworld_minutes": GameState.camp_last_overworld_minutes,
"camp_dungeon_id":             GameState.camp_dungeon_id,
"camp_dungeon_count":          GameState.camp_dungeon_count,
"camp_dungeon_last_day":       GameState.camp_dungeon_last_day,
```

E al load: ripristino degli stessi campi.

---

## Questioni aperte

- **Encounter reale**: per ora solo log. Quando esiste il sistema spawn encounter (Overworld System), sostituire con spawn nemico sulla tile adiacente.
- **Sezione risorse inventario**: Predatore/Arcicacciatore per ora incrementano `GameState.food/water` direttamente. Migrare quando il sistema risorse è definito.
- **Guard turns durante camp**: `TimeManager.advance(480)` emette 16 world tick (480/30). Se gli NPC overworld reagiscono ai tick, si muovono automaticamente durante il camp.
- **Bonus classe via ClassRuntime**: decidere se i modificatori camp stanno in `class_data.json` (campo `camp_modifiers`) o in `ClassRuntime` con metodi dedicati.

---

## Lista task

- [ ] Aggiungere campi camp a `GameState.gd`
- [ ] Aggiungere `"camp"` → `Z` all'InputMap in `project.godot`
- [ ] Implementare `CampManager.gd` con `try_camp()`, `_get_block_reason()`, `_do_camp()`
- [ ] Check nemici in range (30 tile) — iterare `BaseMap._entities`
- [ ] Recovery HP/MP/Stamina al 100% (con eccezione Vampiro)
- [ ] Needs consume (1 ora) con modificatori classe
- [ ] Bonus loot Predatore (+3 food/water) e Arcicacciatore (+5 food)
- [ ] Contatori overworld e dungeon con logica reset
- [ ] Notifiche flavor per classi non campanti (Mannaro, Lich, Spettro)
- [ ] Modificatori encounter per classe (Ranger, Ladro, Sentinella, Esploratore)
- [ ] Pulsante camp in ActionBar (sempre visibile, disabilitato con tooltip)
- [ ] Hook `Player._unhandled_input` per tasto `Z`
- [ ] Integrazione save/load in `SaveManager.gd`
- [ ] Recupero alleati (AllyManager)
- [ ] Roll encounter con log
- [ ] ScreenFade in/out durante il camp

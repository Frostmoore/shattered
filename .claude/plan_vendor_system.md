# Piano: Vendor System

**Stato**: Bozza — implementato come FASE 4–5 del NPC System, dopo Time System e NPC base.

**Dipendenze**: Time System ✗, NPC System (FASE 1-3) ✗

---

## Nota

Il Vendor System non è un sistema standalone — è la FASE 4 del piano NPC System (`plan_npc_system.md`). Questo file documenta le decisioni di design specifiche del sistema shop per riferimento rapido.

---

## Decisioni di design

| Aspetto | Decisione |
|---------|-----------|
| Inventario | Procedurale, rigenerato ogni N giorni |
| N giorni | Configurabile per NPC (`shop_refresh_days`) |
| UI shop | ShopScreen separato (CanvasLayer layer=85) |
| Prezzi acquisto | `base_price * FactionEconomy.get_price_multiplier(ctx)` |
| Prezzi vendita | 40% del prezzo di acquisto (fisso) |
| Negozi di notte | Chiusi (22:00–6:00); mostra notifica |
| Persistenza | `WorldState.npc_shop_data` serializzato in `world.json` |

---

## Tipi di shop (`shop_type` in NPC params)

| Tipo | Contenuto |
|------|-----------|
| `armeria` | Armi + armature per tier della città |
| `emporio` | Mix: consumabili + accessori + item generici |
| `farmacia` | Consumabili: pozioni, antidoti, bende |
| `alchimista` | Consumabili avanzati, ingredienti, ricette |
| `libri` | Pergamene identificazione, mappe, lore items |
| `mercato_nero` | Rari/epici, item illegali (richiede `tsn_black_market`) |

---

## Struttura dati

### WorldState — aggiunta

```gdscript
var npc_shop_data: Dictionary = {}
# { npc_uid: { "items": Array[Dictionary], "generated_day": int } }

func get_shop(npc_uid: String, refresh_days: int, shop_type: String, city_tier: int) -> Array:
    var entry: Dictionary = npc_shop_data.get(npc_uid, {})
    var generated_day: int = int(entry.get("generated_day", -999))
    if GameState.day_count - generated_day >= refresh_days or entry.is_empty():
        entry = {
            "items": _generate_shop_items(shop_type, city_tier),
            "generated_day": GameState.day_count
        }
        npc_shop_data[npc_uid] = entry
    return entry.get("items", [])

func _generate_shop_items(shop_type: String, tier: int) -> Array:
    # Usa ItemDB.pick_random() o LootResolver per N slot
    # Restituisce Array di item instance (già identificati)
    pass
```

### NPC.gd — nuovi campi

```gdscript
var shop_type:         String = ""
var shop_refresh_days: int    = 3
var shop_uid:          String = ""   # = entity uid dalla LocationState
```

### Item JSON — nuovo campo

```jsonc
{ "base_price": 50 }
```

Se assente: fallback `tier * 10 * quality_multiplier`.

---

## ShopScreen — `scripts/ui/ShopScreen.gd`

CanvasLayer layer=85. Pure-code, stesso pattern di FactionScreen.

### Layout

```
┌─────────────────────────────────────────────────────┐
│  [Nome mercante] — [shop_type]              [Chiudi] │
├─────────────────────────┬───────────────────────────┤
│  MERCE (inventario NPC) │  IL TUO ZAINO             │
│  ┌──────────────────┐   │  ┌──────────────────────┐ │
│  │ item 1  — 50g    │   │  │ item A   [Vendi 20g] │ │
│  │ item 2  — 120g   │   │  │ item B   [Vendi 8g]  │ │
│  │ [Compra]         │   │  │ ...                  │ │
│  └──────────────────┘   │  └──────────────────────┘ │
│  Oro: {player_gold}g    │                            │
└─────────────────────────┴───────────────────────────┘
```

### Apertura

`NPC.interact()`:
```gdscript
if vendor:
    if TimeManager.is_night():
        EventBus.notification_shown.emit(Notification.warning(
            LocaleManager.t_or("NOTIF_SHOP_CLOSED", "Il negozio è chiuso.")))
        return
    var items: Array = WorldState.get_shop(shop_uid, shop_refresh_days, shop_type, _get_city_tier())
    EventBus.shop_opened.emit(shop_uid, items, display_name)
```

### Compra

```gdscript
var price: int = ceili(item.base_price * FactionEconomy.get_price_multiplier(ctx))
if GameState.player_stats.gold >= price:
    GameState.modify_gold(-price)
    Inventory.add_item_instance(item)
    # rimuove item dall'inventario NPC (WorldState.npc_shop_data)
```

### Vendi

```gdscript
var sell_price: int = floori(item.base_price * 0.40)
GameState.modify_gold(sell_price)
Inventory.remove_item_instance(item.instance_id)
# opzionale: aggiunge al negozio (per ora no)
```

---

## EventBus — nuovi segnali

```gdscript
shop_opened(npc_uid: String, items: Array, shop_name: String)
shop_closed()
```

---

## Integrazione FactionEconomy

`FactionEconomy.get_price_multiplier(ctx: Dictionary) -> float`:
- `ctx = { "faction_id": npc.primary_faction_id, "player": true }`
- Già implementato ma non chiamato da nulla — questo è il primo hook reale

---

## Lista task

*(Corrisponde a FASE 4 in plan_npc_system.md)*

- [ ] `WorldState.npc_shop_data` + `get_shop()` + `_generate_shop_items()`
- [ ] `WorldState`: serializza `npc_shop_data` in `world.json`
- [ ] `NPC.gd`: `shop_type`, `shop_refresh_days`, `shop_uid`
- [ ] `NPC.setup()`: legge nuovi campi da params
- [ ] `NPC.interact()`: gate notte + `EventBus.shop_opened`
- [ ] `scripts/ui/ShopScreen.gd` — CanvasLayer layer=85
- [ ] `EventBus`: `shop_opened`, `shop_closed`
- [ ] `Main.gd`: `@onready var shop_screen` + connessione segnali
- [ ] `data/items/`: aggiungere `base_price` ai JSON item rilevanti
- [ ] Fallback price: `tier * 10` se `base_price` assente
- [ ] `FactionEconomy.get_price_multiplier()` collegato allo ShopScreen
- [ ] `NOTIF_SHOP_CLOSED` in `strings_notifications.csv`

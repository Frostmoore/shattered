# Piano: Sistema Oggetti con Affissi (Diablo-style)

**Stato**: In attesa — richiede prima il sistema attributi personaggio (vedi Fase 0)

---

## Dipendenze

Il sistema oggetti dipende dal **sistema attributi personaggio** perché:
- `INT` + `WIL` determinano l'auto-identificazione degli item (KNL rimosso, non è un attributo)
- `STR`/`DEX`/`INT` determinano i requisiti di equipaggiamento
- I bonus degli affissi devono riferirsi agli attributi definitivi

**Non iniziare le fasi 1+ finché il sistema attributi non è completo e salvato.**

---

## Tier di qualità

| Tier        | Affissi | Colore  | Note                                               |
|-------------|---------|---------|--------------------------------------------------- |
| Normale     | 0       | Bianco  | Nessun affisso                                     |
| Magico      | 1–2     | Blu     | Fino a 1 prefisso + 1 suffisso                     |
| Raro        | 3–4     | Giallo  | Fino a 2 prefissi + 2 suffissi                     |
| Epico       | 4–5     | Viola   | Fino a 3 prefissi + 2 suffissi                     |
| Leggendario | 5–6     | Arancio | Fino a 3 prefissi + 3 suffissi                     |
| Unico       | fissi   | Oro     | Affissi hand-crafted, nome proprio, 1 sola istanza per dungeon |

La probabilità di ottenere un tier più alto scala col livello del giocatore (tabella pesata, stesso sistema `weighted_roll` già in uso).

---

## Fase 0 — Sistema Attributi Personaggio (PREREQUISITO)

Prima di tutto il resto.

- [x] Attributi definitivi: `STR`, `DEX`, `INT`, `VIT`, `WIL` (KNL rimosso)
- [x] Formule: HP=VIT×5, MP=(INT+WIL)×2, Stamina=(STR+DEX)×2, ATK=2+STR×0.5, DEF=VIT×0.25
- [x] Integrazione in `Player.gd` e `GameState` con `recalculate_derived_stats()`
- [x] Salvataggio/caricamento in `SaveManager`
- [x] Level-up automatico: tutti gli attributi +1 per livello (curva da definire con le classi)
- [x] UI scheda personaggio: `StatusScreen.tscn` (tasto C), barre HUD aggiornate

---

## Fase 1 — Data Layer

- [ ] Aggiungere campo `gender` ("m"/"f") a ogni item in `items.json`
- [ ] Espandere `items.json` con tutti gli item dei tier 4–15 già presenti in `CHEST_LOOT_TABLE`
- [ ] Creare `data/items/affixes.json` — schema per ogni affisso:
  ```json
  {
    "id": "sharp",
    "type": "prefix",
    "name_m": "Affilato",
    "name_f": "Affilata",
    "allowed_slots": ["right_hand"],
    "min_level": 1,
    "min_quality": "magico",
    "weight": 20,
    "bonuses": { "attack_bonus": 2 }
  }
  ```
- [ ] Creare `data/items/uniques.json` — item unici con affissi fissi e nome proprio
- [ ] Decidere elenco completo degli affissi (da fare insieme, non automatizzare)

---

## Fase 2 — AffixDB + ItemGenerator

- [ ] `scripts/items/AffixDB.gd` (autoload): carica `affixes.json`, indicizza per id e per slot
- [ ] `scripts/items/ItemGenerator.gd`:
  - `generate(base_id, player_level, rng) -> Dictionary` — restituisce un'istanza item completa
  - Tira il tier di qualità (tabella pesata level-based)
  - Tira gli affissi eleggibili per slot e livello
  - Compone il nome: `[prefisso] Nome_base [suffisso]` con accordo di genere
  - Genera `instance_id` univoco
  - Formato istanza:
    ```
    instance_id, base_id, quality, prefix_ids[], suffix_ids[],
    identified (bool), name (se identified), name_unid, stats (se identified)
    ```
- [ ] Logica INT+WIL per auto-identificazione al pickup:
  - `id_score = INT + WIL`: normale=0, magico≥10, raro≥24, epico≥40, leggendario≥60
  - (Valori da calibrare dopo aver testato la curva attributi)

---

## Fase 3 — Refactor Inventory

Modifica più invasiva — aggiornare anche `SaveManager`.

- [ ] Split inventario in due track:
  - **Consumabili / Key**: `{ "id": "small_potion", "qty": 3 }` — invariato
  - **Equipaggiamenti**: ogni pezzo è un'istanza unica, qty sempre 1
- [ ] `Inventory.gd`: aggiornare `add_item()`, `remove_item()`, `has_item()` per gestire entrambi i track
- [ ] `ItemDB.gd`: aggiungere `resolve_instance(instance) -> Dictionary` che fonde base stats + affissi
- [ ] `SaveManager.gd`: aggiornare serializzazione/deserializzazione inventario

---

## Fase 4 — Integrazione Chest

- [ ] `Chest._roll_loot()`: se il base item è `type == "equipment"`, chiamare `ItemGenerator.generate()`
- [ ] `Inventory.add_item()` accetta sia `String` (consumabili) sia `Dictionary` (istanze equipment)
- [ ] Al pickup: check INT+WIL → `identified = true` se sufficiente, altrimenti entra non identificato

---

## Fase 5 — UI

Da fare per ultima, dopo che la logica è stabile.

- [ ] Colore nome item in base al tier qualità
- [ ] Oggetti non identificati: mostrare `name_unid` in grigio/corsivo
- [ ] Tooltip item: mostrare stats se identificato, "???" se no
- [ ] UI identificazione: pergamena o vendor
- [ ] Schermata equipaggiamento: slot con item colorato per qualità

---

## Note di design

- Gli **Unici** sono hand-crafted in `uniques.json`: nome proprio, affissi fissi, non droppano più di una volta per dungeon.
- I **Leggendari** sono generati proceduralmente con pool di affissi esclusivo.
- La **pergamena di identificazione** è un consumabile con `effect: { "identify": true }` — da aggiungere alla loot table.
- Il **vendor** potrà identificare in cambio di oro (sistema economico da definire separatamente).

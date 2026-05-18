---
name: project-next-steps
description: Prossimi step di sviluppo concordati per il gioco Shattered
metadata:
  type: project
---

Prossima sessione da implementare (in ordine):

1. **Sistema inventario visivo** — pannello con slot, oggetti equipaggiabili e consumabili, drag & drop o selezione da lista
2. **Oggetti base**:
   - Armi (spada arrugginita, ascia, ecc.) con bonus attacco che si applica alle stats del player
   - Pozioni (piccola, media) con cure diverse
   - Eventuale armatura con bonus difesa
3. **Sistema di cura** — uso delle pozioni dall'inventario durante il combattimento o fuori, rigenerazione HP

**Why:** concordato con l'utente a fine sessione 2026-05-17.
**How to apply:** iniziare da ItemDB e Inventory.gd già esistenti, estendere con equip slot sul GameState e applicare bonuses alle stats del player.

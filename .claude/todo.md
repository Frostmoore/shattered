# Lista di attività da completare in futuro

---

## Ordine implementazione sistemi

L'ordine rispecchia le dipendenze tecniche. Ogni sistema è implementabile solo se i predecessori sono completi.

### Da implementare

- [x] **Time System** *(completo — plan_time_system.md)*
  `total_minutes`, `TimeManager`, hook in `Player._action_done()`, HUD label, WaitScreen, save/load, continuità temporale multi-personaggio per mondo.

- [x] **Needs System** *(plan_needs_system.md — completo FASI 0–5)*
  Fame, sete, exhaustion, temperatura, malattie (32), item consumabili, save point rest, cure automatiche, disease-on-hit da nemici.

- [ ] **Camping System** *(plan_camping_system.md)*
  Bivacco su overworld/dungeon. Dipende da Time System; hook Needs deferred.

- [ ] **NPC System — Fase 2** *(plan_npc_system.md)*
  Routine NPC, accumulator, schedule venditori (`open_slot`/`close_slot`, `is_open()`). Dipende da Time System.

- [ ] **Vendor System** *(plan_vendor_system.md)*
  Compra/vendi item, prezzi, stock. Dipende da NPC System Fase 2.

- [ ] **Overworld System** *(plan_overworld_system.md — design ancora in corso)*
  Biomi, terrain multiplier, WorldActor/WorldSimulator in WorldManager, carovane. Dipende da Time System.

- [ ] **Local Map System** *(plan_local_map_system.md)*
  Mappe procedurali contestuali: accampamenti bandit, tane creature, rovine carovana visibili sull'overworld; incontri casuali (`clearing`) durante il viaggio. `EncounterGenerator`, prefisso `enc_` in LocationRegistry, persistenza selettiva. Dipende da Overworld System (biomi, chance incontro per tile).

- [ ] **Travel System** *(plan_travel_system.md)*
  Viaggio fast-travel, consumo risorse in viaggio. Dipende da Time System + Needs System + Overworld System.

- [ ] **Quest System — espansioni** *(plan_quest_system.md)*
  Deadline via `total_minutes`, quest con effetti world-persistent, quest a catena. Dipende da Time System + NPC System + Vendor System.

- [ ] **Background Events System** *(plan_background_events_system.md — ancora da progettare)*
  Eventi world che avanzano mentre il player è altrove (WorldActor). Dipende da Overworld System.

- [ ] **Class System — Fasi K–L** *(plan_dev_phases.md)*
  Classi complesse con UI dedicata (K) e Tier 4–6 completi (L). Dipende da Item System attributi.

- [ ] **Item System — attributi personaggio** *(plan_item_system.md)*
  STR/DEX/INT/VIT/WIL che scalano stat. Prerequisito per Licenza di Classe e affissi con requisiti. Dipende da Class System Fasi A–J (già fatto).

---

### Già implementati — da rileggere e verificare alla luce degli altri sistemi

- [x] **Class System — Fasi A–J** *(plan_dev_phases.md)*
  ClassRegistry, ClassRuntime, ClassSpecial, AbilityUseTracker, AllyManager, Respec implementati.
  → **Rivedere**: bilanciamento TTK dopo attributi personaggio (Item System); Licenza di Classe quando esiste; abilità attive/passive delle classi Tier 3+ da testare con il Time System (costo in turni/minuti).

- [x] **Item System base — Fasi 0–9** *(plan_item_system.md)*
  Item, affissi, loot tables, LootScreen, identificazione, budget per floor/dungeon implementati.
  → **Rivedere**: prezzi di vendita/acquisto quando Vendor System esiste; requisiti di attributo sugli item quando attributi personaggio esistono; key items reali quando Quest System espansioni esistono.

- [x] **Enemy System** *(30 nemici, tier 1–6, calibrati)*
  TTK validato, rep_on_kill popolato su tutti i nemici, faction_id assegnati.
  → **Rivedere**: TTK dopo introduzione attributi personaggio (le stat classe cambiano il calcolo); aggiungere nemici overworld/bioma-specifici quando Overworld System esiste; encounter rate per Camping System.

- [x] **Faction System** *(plan_factions_system.md)*
  Rep, membership, passive, effects, economy, screen, relations implementati. 7 fazioni joinabili complete.
  → **Rivedere**: hook NPC shop system (sconti, prezzi fazione) quando Vendor System esiste; trigger rep ambientali (uso magia, contratti, uccisioni speciali) quando sistemi dipendenti esistono; schedule negozi fazione quando NPC System Fase 2 esiste.

- [x] **Quest System base** *(QuestManager, reward, objectives)*
  Start/complete quest, XP/oro/join_faction reward, quest senza objectives implementati.
  → **Rivedere**: aggiungere `deadline` via `total_minutes` quando Time System esiste; quest con effetti world-persistent (village cambia dopo una quest) quando WorldState/Background Events esistono; quest a catena e condizionali quando NPC System Fase 2 esiste.

- [~] **Crime System** *(quasi completo — voci pending in todo.md)*
  CrimeSystem autoload, Guard, arresto, fuga, rep penalty implementati. Mancano alcune UI e debug tools.
  → **Completare** le voci pending prima di considerarlo chiuso, poi **rivedere**: integrazione con Time System (guardie che smontano di notte? crimini prescritti dopo X giorni?); integrazione con NPC System (NPC testimoni con routine proprie); meccaniche furto/minaccia quando NPC interaction è più ricca.

---

## Sistema Fazioni — cose ancora mancanti
*(vedi plan_factions_system.md per dettaglio; tutto il resto è completato)*

- [ ] **NPC shop system** — prerequisito per quasi tutti i benefici economici delle fazioni; sblocca: sconti Officine, prezzi FactionEconomy.get_price_multiplier(), mercato nero TSN, shop Locandieri
- [ ] **Sistema location-events** — "entra in dungeon senza condotta" → penalità rep CamereCondotta; trigger ambientali per-fazione; ricontrollare plan_factions_system dopo implementazione
- [ ] **Trigger rep ambientali** (deferred, dipendono da sistemi specifici):
  - milizia_campane: rep+ per crimini riportati da NPC (dipende da NPC AI)
  - cattedra_canone: uso magia proibita / offerte in chiese (dipende da magic system)
  - corporazione_camere: contratti completati/falliti in tempo (dipende da quest deadline)
  - non_morti/bestie: rep_on_kill negativo per classi speciali (negromante/ranger/druido) (dipende da class system Fase 7+)
- [ ] Crime system — roba deferred:
  - Furto, minaccia, omicidio come meccaniche distinte (dipende da NPC interaction system)
  - Pagare multa esplicitamente / scontare pena in turni (opzionale)
  - milizia_campane rep+ per crimini riportati

---

## Todo generici

- [ ] **Camping system** — il player deve poter accamparsi sull'overworld/dungeon per recuperare risorse e far passare il tempo (dipende da Time System e Needs System)

- [x] ~~Sviluppare un crime system e ricontrollare implementazione plan_factions_system~~ ✅ fatto
- [ ] Implementare schermata di configurazione NPC nel CityBuilder (nome, dialoghi, reputazione, fazioni con ruolo primary/secondary, love interest, dialoghi condizionali per rep/fazione/quest)
- [ ] AI differenziata per controller (mantiene distanza), assassin (approccio dal retro), artillery (ranged)
- [ ] Validazione TTK tier 3-6 con CombatSimulator dopo aver avviato il gioco
- [x] Sistema bisogni: fame, sete, sonno, stanchezza, malattia ✅ completo
- [ ] Sistema di viaggio. Nell'overworld si devono consumare risorse come cibo e acqua
- [ ] Tutte le classi devono avere un'abilità attiva e una passiva
- [ ] Quando si cambia classe, si mantengono tutte le passive delle classi precedenti
- [ ] Quando un pg muore definitivamente, tutte le quest devono avere un effetto tangibile nel mondo di gioco. Qualcosa come "La quest costa di più" o "Nel villaggio muore qualcuno" o "Il dungeon diventa più difficile perchè i nemici si sono organizzati"
- [ ] Ricordare a Claude che ad ogni modifica degli oggetti si deve controllare che i validators siano coerenti
- [ ] Modificare tutte le armature e usare quelle storicamente accurate, oltre a quelle fantasy (dal 1100 circa al 1700 circa)
- [ ] Modificare tutte le armi e usare quelle storicamente accurate, oltre a quelle fantasy (dal 1100 circa al 1700 circa)
- [ ] Creare lore_reference.md
- [ ] Creare sistema location-events e ricontrollare implementazione plan_factions_system
- [ ] Bisogna creare anche un file game_engine_reference in cui ci siano i dettagli di tutti i sistemi e di tutte le meccaniche del gioco, ma non approfondito e "da programmatore" come il codebase_reference
- [ ] Sistemare hud che è na merda così
- [ ] Creare handcrafted_maps_reference.md

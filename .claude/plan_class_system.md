# Piano: Sistema Classi (Jobs)

**Stato**: Da implementare — può iniziare subito
**Dipendenze**: Sistema attributi completato (fatto), sistema oggetti (per Licenza di Classe e Alchimista)
**Documento aggiornato**: 2026-05-19 — 60 classi totali, Tier 1-6

---

## Decisioni di design confermate

### Tasti abilità di classe
**Q = tasto universale "Abilità di Classe"** per tutte le classi attive.
- Classi con abilità singola: Q
- Classi con 2 abilità: Q (prima abilità) + Shift+Q (seconda abilità)
- Abilità che richiedono bersaglio: Q entra in "targeting mode", **solo click col mouse** (tap su smartphone)
- Il tasto Q non fa nulla se la classe è passiva o se l'abilità non è disponibile (con notifica)

### Rispecializzazione (cambio classe)
- Richiede un oggetto consumabile: **"Licenza di Classe"** (item_id: "class_license")
- Ottenibile: drop raro da boss, vendor speciali, eventi unici
- Alla rispecializzazione: si sceglie la nuova classe (tra quelle sbloccate)
- Gli attributi ATTUALI si conservano intatti
- Si applica un **Bonus di Transizione** una tantum definito per ogni classe
- Il bonus è fisso per classe, non dipende dal livello corrente
- NON esiste respec automatico a nessun livello

### Milestone (sblocchi classi)
- **Globali**: una classe sbloccata rimane disponibile per tutte le run future
- Salvate in: `user://saves/global_milestones.json`
- Non legate a nessun personaggio specifico
- Si aggiornano in tempo reale durante il gioco

### Entità alleate — flag permanent
- **permanent: true** = Pet (lupo del Ranger, scheletri del Lichè)
  - Respawna all'inizio del piano successivo se uccisa
  - Salvata nel personaggio (non nel location_state del piano)
- **permanent: false** = Summon (demone, elementale, decoy)
  - Durata limitata a turni o al piano; NON salvata

### Berserker in combattimento
Tentativo di usare oggetti → notifica esplicita: "La frenesia non ti permette di usare oggetti". L'oggetto non si consuma.

### Mannaro — forma lupo
- **Nel dungeon**: sempre in forma lupo, inclusi i save point (falò)
- **Overworld, buildings, villaggi**: sempre in forma umana
- Trasformazione automatica al cambio di contesto

### Classi con sistemi futuri
Ladro (porte chiuse), Esploratore (stanze segrete), Arcanista (tag "magical"):
implementare la meccanica base ora, estendere quando il sistema esiste.

---

## Elenco completo 60 classi

### Schema dati
```json
{
  "id":           "snake_case",
  "name":         "Nome Italiano",
  "description":  "Una riga di flavour text",
  "tier":         1,
  "primary":      ["attr1", "attr2"],
  "growth":       {"str":0,"dex":0,"int":0,"vit":0,"wil":0},
  "respec_bonus": {"str":0,"dex":0,"int":0,"vit":0,"wil":0},
  "special_id":   "mechanic_id",
  "special_type": "passive|active_key|active_target|active_toggle|passive_and_active",
  "special_name": "Nome Abilità",
  "special_desc": "Descrizione breve per UI",
  "unlock": {
    "type": "...",
    "value": ...,
    "trigger_scope": "global|run",
    "reward_scope": "global"
  }
}
```

**Nota growth**: somma 5 per Tier 1 (Noob); 5–6 Tier 1 generiche; 6 Tier 2; 6–7 Tier 3; 7 Tier 4; 8–10 Tier 5.

**Nota unlock**: `trigger_scope` indica dove viene misurata la condizione (global = accumulato tra tutte le run; run = raggiunto in una singola run). `reward_scope` è sempre "global": lo sblocco, una volta ottenuto, vale per sempre.

---

### TIER 1 — Classi Base (12 classi, sempre sbloccabili facilmente)

```
1.  id: noob
    name: Noob
    desc: "Nessuna specializzazione. Sopravvive a tutto, eccelle in niente."
    tier: 1
    primary: []
    growth: {str:1, dex:1, int:1, vit:1, wil:1}
    respec_bonus: {str:3, dex:3, int:3, vit:3, wil:3}
    special_id: noob_adaptability
    special_type: passive
    special_name: "Adattamento"
    special_desc: "Nessun requisito di classe su equipaggiamento. Può usare la Licenza di Classe senza penalità."
    unlock: {type: always, scope: global}

2.  id: guerriero
    name: Guerriero
    desc: "Combattente diretto. Più è in pericolo, più è pericoloso."
    tier: 1
    primary: [str, vit]
    growth: {str:2, dex:1, int:0, vit:2, wil:1}
    respec_bonus: {str:8, dex:3, int:0, vit:8, wil:3}
    special_id: warrior_fury
    special_type: passive
    special_name: "Furia"
    special_desc: "Sotto 30% HP: ATK ×1.5, glyph rosso acceso."
    unlock: {type: level, value: 5, scope: global}

3.  id: mago
    name: Mago
    desc: "Controlla forze arcane. Fragile ma letale a distanza."
    tier: 1
    primary: [int, wil]
    growth: {str:0, dex:1, int:2, vit:0, wil:2}
    respec_bonus: {str:0, dex:3, int:8, vit:0, wil:8}
    special_id: mage_arcane_bolt
    special_type: active_target
    special_name: "Proiettile Arcano"
    special_desc: "Attacca a distanza (range INT/3 tile). Costo: 5 MP. Danno: INT. Richiede line-of-sight."
    unlock: {type: scrolls_collected, value: 3, scope: global}

4.  id: ladro
    name: Ladro
    desc: "Veloce e silenzioso. Il primo colpo è sempre fatale."
    tier: 1
    primary: [dex, int]
    growth: {str:1, dex:2, int:2, vit:0, wil:1}
    respec_bonus: {str:3, dex:8, int:8, vit:0, wil:3}
    special_id: rogue_backstab
    special_type: passive
    special_name: "Pugnalata / Grimaldello"
    special_desc: "Primo attacco fuori-combattimento ×3 danno. Apre porte chiuse a chiave."
    unlock: {type: chests_opened, value: 5, scope: global}

5.  id: ranger
    name: Ranger
    desc: "Esploratore selvaggio. Non combatte mai da solo."
    tier: 1
    primary: [dex, wil]
    growth: {str:1, dex:2, int:0, vit:1, wil:2}
    respec_bonus: {str:3, dex:8, int:0, vit:3, wil:8}
    special_id: ranger_companion
    special_type: passive
    special_name: "Compagno Lupo"
    special_desc: "Un lupo alleato (permanent) combatte insieme a te. Respawna al piano successivo se muore."
    unlock: {type: overworld_tiles, value: 500, scope: global}

6.  id: paladino
    name: Paladino
    desc: "Campione sacro. La fede lo protegge e lo guarisce."
    tier: 1
    primary: [str, wil]
    growth: {str:2, dex:0, int:1, vit:1, wil:2}
    respec_bonus: {str:8, dex:0, int:3, vit:3, wil:8}
    special_id: paladin_lay_on_hands
    special_type: active_key
    special_name: "Imposizione delle Mani"
    special_desc: "Cura VIT×3 HP. Una volta per piano."
    unlock: {type: quests_completed, value: 3, scope: global}

7.  id: negromante
    name: Negromante
    desc: "La morte non è una fine, è una risorsa."
    tier: 1
    primary: [int, wil]
    growth: {str:0, dex:1, int:3, vit:0, wil:2}
    respec_bonus: {str:0, dex:3, int:10, vit:0, wil:7}
    special_id: necro_raise_dead
    special_type: active_key
    special_name: "Risurrezione"
    special_desc: "Rianima l'ultimo nemico ucciso come alleato per INT/2 turni. Costo: 10 MP."
    unlock: {type: kills_total, value: 50, scope: global}

8.  id: monaco
    name: Monaco
    desc: "Corpo come arma, mente come scudo. Niente equipaggiamento necessario."
    tier: 1
    primary: [dex, vit]
    growth: {str:0, dex:2, int:1, vit:2, wil:1}
    respec_bonus: {str:0, dex:8, int:3, vit:8, wil:3}
    special_id: monk_dodge
    special_type: passive
    special_name: "Schivata"
    special_desc: "DEX/100 chance (cap 40%) di evadere ogni attacco in combattimento."
    unlock: {type: dungeon_floor_no_damage, value: 1, scope: run}

9.  id: barbaro
    name: Barbaro
    desc: "Forza bruta e urla. L'intelletto è sopravvalutato."
    tier: 1
    primary: [str, vit]
    growth: {str:3, dex:0, int:0, vit:2, wil:1}
    respec_bonus: {str:12, dex:0, int:0, vit:8, wil:3}
    special_id: barbarian_warcry
    special_type: active_key
    special_name: "Grido di Guerra"
    special_desc: "Tutti i nemici in detection range: ATK -30% per 4 turni. Costo: 10 ST."
    unlock: {type: damage_taken_total, value: 200, scope: run}

10. id: alchimista
    name: Alchimista
    desc: "Trasforma oggetti ordinari in strumenti straordinari."
    tier: 1
    primary: [int, dex]
    growth: {str:0, dex:2, int:2, vit:1, wil:1}
    respec_bonus: {str:0, dex:8, int:8, vit:3, wil:3}
    special_id: alchemist_brew
    special_type: active_key
    special_name: "Mistura"
    special_desc: "Combina 2 consumabili per effetto potenziato. Apre mini-UI."
    unlock: {type: consumables_used, value: 10, scope: global}

11. id: bardo
    name: Bardo
    desc: "Le sue canzoni cambiano il corso delle battaglie."
    tier: 1
    primary: [wil, dex]
    growth: {str:0, dex:2, int:1, vit:1, wil:2}
    respec_bonus: {str:0, dex:8, int:3, vit:3, wil:8}
    special_id: bard_song
    special_type: active_key
    special_name: "Ballata Ispiratrice"
    special_desc: "ATK, DEF, DEX ×1.2 per 5 turni. Una volta per piano. Costo: 15 MP."
    unlock: {type: npcs_spoken, value: 5, scope: global}

12. id: druido
    name: Druido
    desc: "Si fonde con la natura, diventa la natura."
    tier: 1
    primary: [wil, vit]
    growth: {str:0, dex:1, int:1, vit:2, wil:2}
    respec_bonus: {str:0, dex:3, int:3, vit:8, wil:8}
    special_id: druid_shapeshift
    special_type: active_toggle
    special_name: "Forma Animale"
    special_desc: "Q: Forma Orso (HP×1.5, ATK×1.5, DEX/2). Shift+Q: Forma Lupo (DEX×2, schiva+20%). Durata: 5 turni. Costo: 10 MP."
    unlock: {type: overworld_zones_explored, value: "all", scope: global}
```

---

### TIER 2 — Classi Intermedie (10 classi, effort moderato)

```
13. id: cavaliere
    name: Cavaliere
    desc: "Armatura pesante, disciplina totale. La carica è inarrestabile."
    tier: 2
    primary: [str, dex]
    growth: {str:2, dex:2, int:0, vit:1, wil:1}
    respec_bonus: {str:8, dex:8, int:0, vit:3, wil:3}
    special_id: knight_charge
    special_type: passive
    special_name: "Carica"
    special_desc: "Muovendosi in linea retta verso un nemico adiacente: danno ×2 + stordito 1 turno."
    unlock: {type: equip_full_set, value: 1, scope: run}

14. id: assassino
    name: Assassino
    desc: "Colpisce nell'ombra. I boss sono la sua specialità."
    tier: 2
    primary: [dex, str]
    growth: {str:2, dex:3, int:1, vit:0, wil:0}
    respec_bonus: {str:8, dex:12, int:3, vit:0, wil:0}
    special_id: assassin_execute
    special_type: passive
    special_name: "Esecuzione / Ombra"
    special_desc: "Nemici <20% HP: kill istantaneo. Dopo ogni kill: invisibile 1 turno."
    unlock: {type: kills_boss, value: 5, scope: global}

15. id: stregone
    name: Stregone
    desc: "Ha stretto un patto con forze oscure. Il prezzo è il suo stesso corpo."
    tier: 2
    primary: [wil, str]
    growth: {str:2, dex:0, int:1, vit:0, wil:3}
    respec_bonus: {str:8, dex:0, int:3, vit:0, wil:12}
    special_id: warlock_dark_pact
    special_type: active_key
    special_name: "Patto Oscuro"
    special_desc: "Q: consuma HP in MP (1:1), +5% ATK per ogni 10% HP mancante. Costo: 5 HP per attivazione."
    unlock: {type: deaths_total, value: 10, scope: global}

16. id: sacerdote
    name: Sacerdote
    desc: "Guaritore devoto. La sua fede si traduce in recupero continuo."
    tier: 2
    primary: [wil, int]
    growth: {str:0, dex:1, int:2, vit:1, wil:2}
    respec_bonus: {str:0, dex:3, int:8, vit:3, wil:8}
    special_id: priest_blessing
    special_type: passive
    special_name: "Benedizione"
    special_desc: "Rigenera VIT/4 HP ogni 3 turni. Immunità ai debuff di tipo 'maledizione'."
    unlock: {type: save_points_used, value: 10, scope: global}

17. id: biomante
    name: Biomante
    desc: "Ha imparato a rigenerare il proprio corpo nel momento più critico."
    tier: 2
    primary: [int, vit]
    growth: {str:0, dex:1, int:2, vit:3, wil:0}
    respec_bonus: {str:0, dex:3, int:8, vit:12, wil:0}
    special_id: biomancer_regen
    special_type: passive
    special_name: "Rigenerazione"
    special_desc: "Recupera VIT/5 HP ogni turno in cui non si ricevono danni."
    unlock: {type: near_death_survived, value: 3, scope: run}

18. id: gladiatore
    name: Gladiatore
    desc: "Ogni vittoria alimenta la prossima. L'arena è la sua casa."
    tier: 2
    primary: [str, vit]
    growth: {str:2, dex:1, int:0, vit:2, wil:1}
    respec_bonus: {str:8, dex:3, int:0, vit:8, wil:3}
    special_id: gladiator_adrenaline
    special_type: passive
    special_name: "Adrenalina"
    special_desc: "Ogni kill in combattimento: +1 ATK cumulativo (max +10). Dura fino a fine dungeon."
    unlock: {type: combat_wins_no_items, value: 15, scope: run}

19. id: sciamano
    name: Sciamano
    desc: "Invoca spiriti protettori che vigilano sul campo di battaglia."
    tier: 2
    primary: [wil, vit]
    growth: {str:0, dex:1, int:1, vit:2, wil:2}
    respec_bonus: {str:0, dex:3, int:3, vit:8, wil:8}
    special_id: shaman_totem
    special_type: active_target
    special_name: "Totem Curativo"
    special_desc: "Piazza un totem su tile adiacente. Entro 3 tile: +WIL/4 HP ogni 2 turni. Max 1 totem. HP=1."
    unlock: {type: dungeon_floors_total, value: 10, scope: global}

20. id: templare
    name: Templare
    desc: "La sua aura sacra indebolisce i nemici solo stando loro vicino."
    tier: 2
    primary: [str, wil]
    growth: {str:2, dex:0, int:1, vit:1, wil:2}
    respec_bonus: {str:8, dex:0, int:3, vit:3, wil:8}
    special_id: templar_holy_aura
    special_type: passive_and_active
    special_name: "Aura Sacra / Luce Sacra"
    special_desc: "Passiva: nemici entro 2 tile -15% ATK. Q: AoE danno sacro su tutti i nemici in vista (WIL×2, ignora DEF). Costo: 20 MP. Cooldown: 5 turni."
    unlock: {type: dungeon_clear_no_death, value: 1, scope: run}

21. id: inventore
    name: Inventore
    desc: "Trasforma oggetti trovati in trappole micidiali."
    tier: 2
    primary: [int, dex]
    growth: {str:0, dex:2, int:3, vit:0, wil:1}
    respec_bonus: {str:0, dex:8, int:12, vit:0, wil:3}
    special_id: inventor_trap
    special_type: active_target
    special_name: "Trappola"
    special_desc: "Piazza trappola su tile adiacente libera. Esplode al calpestio (INT×2 danno). Max 3 attive."
    unlock: {type: items_collected_unique, value: 20, scope: global}

22. id: cacciatore_di_taglie
    name: Cacciatore di Taglie
    desc: "Studia ogni nemico. Il Marchio garantisce che non sopravviva."
    tier: 2
    primary: [dex, wil]
    growth: {str:1, dex:2, int:1, vit:1, wil:1}
    respec_bonus: {str:3, dex:8, int:3, vit:3, wil:3}
    special_id: bounty_hunter_mark
    special_type: active_target
    special_name: "Marchio"
    special_desc: "Designa un nemico visibile: riceve +50% danno da tutte le fonti. Max 1 bersaglio."
    unlock: {type: kills_enemy_type_all, value: 1, scope: global}
```

---

### TIER 3 — Classi Avanzate (22 classi, impegno significativo)

```
23. id: piromante
    name: Piromante
    desc: "Il fuoco obbedisce ai suoi comandi. E brucia tutto il resto."
    tier: 3
    primary: [int, wil]
    growth: {str:0, dex:0, int:3, vit:0, wil:3}
    respec_bonus: {str:0, dex:0, int:12, vit:0, wil:12}
    special_id: pyromancer_fireball
    special_type: active_target
    special_name: "Pirobola"
    special_desc: "Danno = INT al bersaglio + bruciatura (INT/3 danno/turno per 3 turni). Costo: 8 MP. Range: INT/3 tile."
    unlock: {type: damage_dealt_total, value: 500, scope: global}

24. id: cronomante
    name: Cronomante
    desc: "Il tempo è una risorsa come tutte le altre. E lui sa come spenderlo."
    tier: 3
    primary: [int, dex]
    growth: {str:0, dex:2, int:3, vit:0, wil:1}
    respec_bonus: {str:0, dex:8, int:12, vit:0, wil:3}
    special_id: chrono_slow
    special_type: active_target
    special_name: "Rallentamento"
    special_desc: "Un nemico visibile salta ogni altro turno per INT/2 turni. Costo: 15 MP."
    unlock: {type: dungeon_floors_total, value: 20, scope: global}

25. id: geomante
    name: Geomante
    desc: "La terra è la sua armatura e la sua arma."
    tier: 3
    primary: [vit, wil]
    growth: {str:1, dex:0, int:1, vit:3, wil:2}
    respec_bonus: {str:3, dex:0, int:3, vit:12, wil:8}
    special_id: geo_wall
    special_type: active_target
    special_name: "Muro di Terra"
    special_desc: "Crea parete temporanea su tile adiacente libera. Blocca movimento e visione per VIT/3 turni."
    unlock: {type: tiles_explored_total, value: 1000, scope: global}

26. id: illusionista
    name: Illusionista
    desc: "La realtà è negoziabile. I nemici attaccano ciò che vuole lui."
    tier: 3
    primary: [int, dex]
    growth: {str:0, dex:2, int:2, vit:0, wil:2}
    respec_bonus: {str:0, dex:8, int:8, vit:0, wil:8}
    special_id: illusionist_double
    special_type: active_target
    special_name: "Sosia"
    special_desc: "Crea copia illusoria su tile adiacente. I nemici attaccano il sosia per DEX/4 turni. Costo: 12 MP."
    unlock: {type: attacks_dodged_total, value: 20, scope: global}

27. id: vampiro
    name: Vampiro
    desc: "Ogni ferita inferta lo fa stare meglio. Un predatore perfetto."
    tier: 3
    primary: [str, wil]
    growth: {str:2, dex:1, int:1, vit:0, wil:2}
    respec_bonus: {str:8, dex:3, int:3, vit:0, wil:8}
    special_id: vampire_lifesteal
    special_type: passive
    special_name: "Morso Vitale"
    special_desc: "Ogni attacco fisico inferto cura HP pari al 25% dei danni inflitti."
    unlock: {type: survived_at_1hp, value: 5, scope: global}

28. id: demonista
    name: Demonista
    desc: "Ha imparato a piegare forze che non andrebbero toccate."
    tier: 3
    primary: [wil, int]
    growth: {str:0, dex:0, int:2, vit:0, wil:3}
    respec_bonus: {str:0, dex:0, int:8, vit:0, wil:12}
    special_id: demonist_summon
    special_type: active_key
    special_name: "Servo Demoniaco"
    special_desc: "Evoca un demone (ATK×1.5, HP×0.5) per WIL/2 turni. Costo: 20 MP. Max 1. Non permanente."
    unlock: {type: dungeons_completed, value: 3, scope: global}

29. id: evocatore
    name: Evocatore
    desc: "Chiama spiriti elementali dal piano eterico."
    tier: 3
    primary: [wil, vit]
    growth: {str:0, dex:0, int:2, vit:2, wil:2}
    respec_bonus: {str:0, dex:0, int:8, vit:8, wil:8}
    special_id: summoner_elemental
    special_type: active_key
    special_name: "Spirito Elementale"
    special_desc: "Evoca elementale a scelta (menu). Fuoco: ATK; Acqua: cura periodica; Terra: muro. Durata: 5 turni. Costo: 18 MP. Non permanente."
    unlock: {type: dungeon_floors_total, value: 15, scope: global}

30. id: strega
    name: Strega
    desc: "Le sue maledizioni indeboliscono il corpo e lo spirito."
    tier: 3
    primary: [wil, dex]
    growth: {str:0, dex:2, int:1, vit:1, wil:2}
    respec_bonus: {str:0, dex:8, int:3, vit:3, wil:8}
    special_id: witch_curse
    special_type: active_target
    special_name: "Maledizione"
    special_desc: "Un nemico visibile: tutti i suoi stat -20% per 5 turni. Costo: 10 MP."
    unlock: {type: consumable_types_used, value: 5, scope: global}

31. id: spellblade
    name: Spellblade
    desc: "Fonde magia e acciaio in una singola lama letale."
    tier: 3
    primary: [str, int]
    growth: {str:2, dex:1, int:2, vit:0, wil:1}
    respec_bonus: {str:8, dex:3, int:8, vit:0, wil:3}
    special_id: spellblade_enchant
    special_type: active_key
    special_name: "Lama Incantata"
    special_desc: "I prossimi 3 attacchi fisici aggiungono INT come danno bonus (ignora DEF). Costo: 12 MP."
    unlock: {type: dual_stat_threshold, attr1: "str", attr2: "int", value: 15, scope: run}

32. id: corsaro
    name: Corsaro
    desc: "Combatte sporco. I regolamenti sono per i perdenti."
    tier: 3
    primary: [dex, str]
    growth: {str:2, dex:2, int:1, vit:0, wil:1}
    respec_bonus: {str:8, dex:8, int:3, vit:0, wil:3}
    special_id: corsair_dirty_hit
    special_type: passive
    special_name: "Colpo Sporco"
    special_desc: "Ogni attacco fisico: 35% chance di stordire il nemico (salta 1 turno)."
    unlock: {type: gold_accumulated, value: 200, scope: global}

33. id: sentinella
    name: Sentinella
    desc: "Immobile come una roccia. Altrettanto difficile da abbattere."
    tier: 3
    primary: [vit, str]
    growth: {str:2, dex:0, int:0, vit:3, wil:1}
    respec_bonus: {str:8, dex:0, int:0, vit:12, wil:3}
    special_id: sentinel_guard
    special_type: passive
    special_name: "Posizione di Guardia"
    special_desc: "Ogni turno senza muoversi né attaccare: DEF ×(1+stacks), max ×4. Si azzera al primo movimento."
    unlock: {type: damage_absorbed_total, value: 1000, scope: global}

34. id: predatore
    name: Predatore
    desc: "Ogni stanza è il suo territorio. Ogni nemico è già una preda."
    tier: 3
    primary: [dex, vit]
    growth: {str:1, dex:2, int:1, vit:2, wil:0}
    respec_bonus: {str:3, dex:8, int:3, vit:8, wil:0}
    special_id: predator_instinct
    special_type: passive_and_active
    special_name: "Fiuto / Primo Colpo"
    special_desc: "Q: rivela posizione di tutti i nemici del piano. Passiva: primo attacco su nemico non-allertato ×2 danno."
    unlock: {type: dungeon_rooms_explored, value: 50, scope: global}

35. id: arcanista
    name: Arcanista
    desc: "Studia ogni scuola magica. Il danno magico diventa il suo carburante."
    tier: 3
    primary: [int, wil]
    growth: {str:0, dex:1, int:2, vit:1, wil:2}
    respec_bonus: {str:0, dex:3, int:8, vit:3, wil:8}
    special_id: arcanist_absorb
    special_type: passive
    special_name: "Assorbimento Arcano"
    special_desc: "Ogni danno magico ricevuto converte 25% in MP recuperati."
    unlock: {type: items_identified, value: 10, scope: global}

36. id: inquisitore
    name: Inquisitore
    desc: "Non c'è segreto che non riesca a scoprire. Con o senza consenso."
    tier: 3
    primary: [str, int]
    growth: {str:2, dex:0, int:2, vit:1, wil:1}
    respec_bonus: {str:8, dex:0, int:8, vit:3, wil:3}
    special_id: inquisitor_analyze
    special_type: active_target
    special_name: "Analisi"
    special_desc: "Rivela stats esatti + debolezze di un nemico adiacente, senza attaccarlo. Azione libera."
    unlock: {type: dungeons_completed, value: 5, scope: global}

37. id: viandante
    name: Viandante
    desc: "Ha visto tutto. Sa dove andare. I nemici non lo sentono arrivare."
    tier: 3
    primary: [dex, wil]
    growth: {str:0, dex:2, int:1, vit:1, wil:2}
    respec_bonus: {str:0, dex:8, int:3, vit:3, wil:8}
    special_id: wanderer_stealth
    special_type: passive
    special_name: "Passo Furtivo"
    special_desc: "I nemici non si allertano entro 2 tile. Detection range nemici verso player dimezzato."
    unlock: {type: overworld_zones_visited, value: 3, scope: global}

38. id: berserker
    name: Berserker
    desc: "Entra in frenesia e non si ferma finché c'è ancora qualcosa in piedi."
    tier: 3
    primary: [str, dex]
    growth: {str:3, dex:2, int:0, vit:1, wil:0}
    respec_bonus: {str:12, dex:8, int:0, vit:3, wil:0}
    special_id: berserker_frenzy
    special_type: passive
    special_name: "Frenesia Totale"
    special_desc: "Con nemici in vista: ATK +40%. Non può ritirarsi né usare oggetti in combattimento."
    unlock: {type: boss_killed_no_damage, value: 1, scope: run}

39. id: arciere
    name: Arciere
    desc: "La distanza è un vantaggio. La freccia arriva prima che lui lo sappia."
    tier: 3
    primary: [dex, str]
    growth: {str:1, dex:3, int:0, vit:1, wil:1}
    respec_bonus: {str:3, dex:12, int:0, vit:3, wil:3}
    special_id: archer_arrow
    special_type: active_target
    special_name: "Freccia Precisa"
    special_desc: "Attacco fisico a distanza (range DEX/4 tile). Nessuna risposta nemica. Cooldown: 2 turni."
    unlock: {type: stat_threshold, attr: "dex", value: 20, scope: run}

40. id: oracolo
    name: Oracolo
    desc: "Vede il futuro prossimo. Non abbastanza da evitarlo, ma abbastanza da prepararsi."
    tier: 3
    primary: [wil, int]
    growth: {str:0, dex:1, int:2, vit:1, wil:2}
    respec_bonus: {str:0, dex:3, int:8, vit:3, wil:8}
    special_id: oracle_foresight
    special_type: passive_and_active
    special_name: "Presagio"
    special_desc: "Passiva: vede HP di tutti i nemici in vista. Q: schiva automaticamente il prossimo attacco (1/combattimento)."
    unlock: {type: enemies_seen_die, value: 100, scope: global}

41. id: custode
    name: Custode
    desc: "Protegge ciò che ha di caro. Con la vita se necessario."
    tier: 3
    primary: [vit, wil]
    growth: {str:1, dex:0, int:1, vit:2, wil:2}
    respec_bonus: {str:3, dex:0, int:3, vit:8, wil:8}
    special_id: guardian_shield
    special_type: active_key
    special_name: "Scudo Divino"
    special_desc: "Crea scudo che assorbe VIT×2 danni. Una volta per piano. Costo: 15 MP."
    unlock: {type: quests_completed, value: 10, scope: global}

42. id: mannaro
    name: Mannaro
    desc: "Nel dungeon non è più un uomo. È qualcosa di peggio."
    tier: 3
    primary: [str, vit]
    growth: {str:3, dex:1, int:0, vit:2, wil:0}
    respec_bonus: {str:12, dex:3, int:0, vit:8, wil:0}
    special_id: werewolf_form
    special_type: passive
    special_name: "Licantropia"
    special_desc: "Nel dungeon (anche ai falò): ATK×2, HP×1.5, blocca magia e oggetti scroll. Forma umana solo nell'overworld/buildings/villaggi."
    unlock: {type: kills_boss, value: 10, scope: global}

43. id: cacciatore_di_draghi
    name: Cacciatore di Draghi
    desc: "Specializzato in nemici che nessun altro osa affrontare."
    tier: 3
    primary: [str, wil]
    growth: {str:2, dex:1, int:1, vit:1, wil:1}
    respec_bonus: {str:8, dex:3, int:3, vit:3, wil:3}
    special_id: dragonhunter_slayer
    special_type: passive
    special_name: "Lama Antipavura / Cacciatore"
    special_desc: "+75% danno contro nemici con max_hp > player_max_hp×2. Immune a debuff paura."
    unlock: {type: boss_killed_no_items, value: 3, scope: global}

44. id: esploratore
    name: Esploratore
    desc: "Nessuna mappa gli è sconosciuta. Ogni segreto è suo."
    tier: 3
    primary: [dex, int]
    growth: {str:0, dex:2, int:2, vit:1, wil:1}
    respec_bonus: {str:0, dex:8, int:8, vit:3, wil:3}
    special_id: explorer_sense
    special_type: passive_and_active
    special_name: "Senso del Dungeon"
    special_desc: "Mappa intera del piano rivelata all'ingresso. +25% XP da nemici dungeon."
    unlock: {type: overworld_zones_visited, value: 5, scope: global}
```

---

### TIER 4 — Classi Potenti (10 classi, impegno molto alto)

```
45. id: lich
    name: Lich
    desc: "Ha sfidato la morte e vinto. L'aveva già vista dall'interno."
    tier: 4
    primary: [int, wil]
    growth: {str:0, dex:0, int:3, vit:1, wil:3}
    respec_bonus: {str:0, dex:0, int:15, vit:5, wil:15}
    special_id: liche_army
    special_type: passive
    special_name: "Esercito Non-Morto"
    special_desc: "Ogni kill crea uno scheletro alleato permanente (max INT/4). Gli scheletri vengono distrutti se colpiti (hp=1). Respawnano al piano successivo."
    unlock: {type: kills_total, value: 300, scope: global}

46. id: arcimago
    name: Arcimago
    desc: "Non si specializza. Padroneggia ogni cosa."
    tier: 4
    primary: [int, wil]
    growth: {str:0, dex:1, int:3, vit:0, wil:3}
    respec_bonus: {str:0, dex:5, int:15, vit:0, wil:15}
    special_id: archmage_repertoire
    special_type: active_key
    special_name: "Repertorio Arcano"
    special_desc: "Cicla tra 3 incantesimi appresi (proiettile, bruciatura, rallentamento). Q lancia l'incantesimo attivo. Nuovi incantesimi sbloccati trovando scroll rari."
    unlock: {type: scrolls_collected, value: 30, scope: global}

47. id: cacciatore_anime
    name: Cacciatore di Anime
    desc: "Ogni nemico ucciso lascia qualcosa di sé."
    tier: 4
    primary: [dex, wil]
    growth: {str:1, dex:2, int:1, vit:1, wil:2}
    respec_bonus: {str:5, dex:8, int:5, vit:5, wil:8}
    special_id: soul_harvest
    special_type: passive_and_active
    special_name: "Raccolta Anime / Consumo"
    special_desc: "Passiva: accumula 1 anima per kill (max INT/2). Q: spendi 1 anima per curare WIL HP o +5 ATK per 3 turni."
    unlock: {type: kills_total, value: 500, scope: global}

48. id: colosso
    name: Colosso
    desc: "Non è veloce. Non è furbo. Ma è impossibile fermarlo."
    tier: 4
    primary: [vit, str]
    growth: {str:3, dex:0, int:0, vit:4, wil:0}
    respec_bonus: {str:15, dex:0, int:0, vit:20, wil:0}
    special_id: colossus_resilience
    special_type: passive
    special_name: "Resilienza"
    special_desc: "Immune a stordimento, rallentamento e paura. Rigenera VIT/2 HP ogni turno in combattimento."
    unlock: {type: damage_absorbed_total, value: 5000, scope: global}

49. id: maestro_tempo
    name: Maestro del Tempo
    desc: "Ha imparato che ogni momento si può riavvolgere. Quasi ogni momento."
    tier: 4
    primary: [int, dex]
    growth: {str:0, dex:2, int:3, vit:0, wil:2}
    respec_bonus: {str:0, dex:8, int:15, vit:0, wil:8}
    special_id: time_rewind
    special_type: active_key
    special_name: "Riavvolgimento"
    special_desc: "Annulla le ultime 5 azioni del player (movimento + danni subiti). Una volta per piano. Costo: 25 MP."
    unlock: {type: dungeon_floors_total, value: 50, scope: global}

50. id: spettro
    name: Spettro
    desc: "Non è nel dungeon. È parte di esso."
    tier: 4
    primary: [dex, wil]
    growth: {str:0, dex:3, int:1, vit:0, wil:3}
    respec_bonus: {str:0, dex:15, int:5, vit:0, wil:15}
    special_id: specter_phase
    special_type: passive
    special_name: "Incorporeità"
    special_desc: "Può muoversi attraverso i muri (non porte). I nemici hanno 50% miss rate. Non si allertano oltre 1 tile."
    unlock: {type: deaths_total, value: 30, scope: global}

51. id: campione
    name: Campione
    desc: "Gli dei guardano. E spingono dalla sua parte."
    tier: 4
    primary: [str, wil]
    growth: {str:2, dex:1, int:1, vit:2, wil:1}
    respec_bonus: {str:8, dex:5, int:5, vit:8, wil:5}
    special_id: champion_divine
    special_type: passive_and_active
    special_name: "Grazia Divina / Benedizione Divina"
    special_desc: "Passiva: una volta per run, alla morte viene resuscitato con 50% HP. Q: ATK+DEF ×1.5 per 5 turni. Costo: 20 MP."
    unlock: {type: quests_completed, value: 25, scope: global}

52. id: dio_guerra
    name: Dio della Guerra
    desc: "Due attacchi. Sempre. Non c'è altra regola."
    tier: 4
    primary: [str, dex]
    growth: {str:3, dex:2, int:0, vit:1, wil:1}
    respec_bonus: {str:15, dex:8, int:0, vit:5, wil:5}
    special_id: war_god_double
    special_type: passive
    special_name: "Doppio Colpo"
    special_desc: "Ogni attacco fisico colpisce due volte (secondo colpo: 50% danno). Ogni kill riduce i cooldown di 1 turno."
    unlock: {type: kills_boss, value: 25, scope: global}

53. id: dominatore
    name: Dominatore
    desc: "Non uccide. Persuade. Con la forza mentale."
    tier: 4
    primary: [wil, int]
    growth: {str:0, dex:1, int:2, vit:0, wil:4}
    respec_bonus: {str:0, dex:5, int:8, vit:0, wil:20}
    special_id: dominator_control
    special_type: active_target
    special_name: "Controllo Mentale"
    special_desc: "Controlla un nemico adiacente (WIL/3 turni): attacca i propri alleati. Max 1 controllato. Costo: 30 MP."
    unlock: {type: dungeons_completed, value: 20, scope: global}

54. id: arcicacciatore
    name: Arcicacciatore
    desc: "Ha visto tutto. Sa dove colpire. Il resto è noia."
    tier: 4
    primary: [dex, str]
    growth: {str:2, dex:3, int:0, vit:1, wil:1}
    respec_bonus: {str:8, dex:15, int:0, vit:5, wil:5}
    special_id: archunter_pierce
    special_type: passive
    special_name: "Perforazione / Predatore Nato"
    special_desc: "Gli attacchi fisici ignorano completamente la DEF nemica. DEX aggiunge DEX/4 all'ATK."
    unlock: {type: damage_dealt_total, value: 10000, scope: global}
```

---

### TIER 5 — Classi Rotte (5 classi, sblocchi leggendari)

```
55. id: eletto
    name: L'Eletto
    desc: "Il destino non si sceglie. Ma lui avrebbe rifiutato se avesse potuto."
    tier: 5
    primary: [str, dex, int, vit, wil]
    growth: {str:2, dex:2, int:2, vit:2, wil:2}
    respec_bonus: {str:10, dex:10, int:10, vit:10, wil:10}
    starting_bonus: tutti gli attributi iniziano a 10 invece di 5
    special_id: chosen_one
    special_type: passive
    special_name: "Prescelto"
    special_desc: "Tutti gli attributi iniziano a 10. Crescita +2 per attributo per livello. XP richiesta per ogni livello ×3."
    unlock: {type: dungeons_completed_no_death, value: 10, scope: global}

56. id: specchio_abisso
    name: Specchio dell'Abisso
    desc: "Il suo dolore è il dolore degli altri."
    tier: 5
    primary: [vit, wil]
    growth: {str:0, dex:0, int:0, vit:5, wil:3}
    respec_bonus: {str:0, dex:0, int:0, vit:25, wil:15}
    special_id: abyss_mirror
    special_type: passive
    special_name: "Riflesso dell'Abisso"
    special_desc: "100% dei danni subiti riflessi su tutti i nemici in vista. Non può morire per il riflesso stesso. Immune ai colpi critici."
    unlock: {type: damage_taken_total, value: 10000, scope: global}

57. id: vuoto
    name: Il Vuoto
    desc: "Oltre la morte, oltre il tempo. Non è più niente. Ed è tutto."
    tier: 5
    primary: [wil, int]
    growth: {str:0, dex:0, int:4, vit:0, wil:4}
    respec_bonus: {str:0, dex:0, int:20, vit:0, wil:20}
    special_id: void_form
    special_type: passive_and_active
    special_name: "Forma del Vuoto / Intangibilità"
    special_desc: "Passiva: alla morte, rinasce con 1 HP (1/run). Ogni combattimento vinto: +1 WIL permanente per la run (max +20). Q: intangibile 3 turni (immune a tutto, non può attaccare). Costo: 20 MP."
    unlock: {type: deaths_total, value: 50, scope: global}

58. id: morte_incarnata
    name: Morte Incarnata
    desc: "Non combatte. Falcia."
    tier: 5
    primary: [str, dex]
    growth: {str:4, dex:4, int:0, vit:0, wil:0}
    respec_bonus: {str:20, dex:20, int:0, vit:0, wil:0}
    special_id: death_incarnate
    special_type: passive
    special_name: "Falce della Morte / Aura Mortale"
    special_desc: "Esecuzione istantanea su nemici con HP < 33% del player max_hp. Aura: nemici entro 1 tile perdono 5 HP per turno."
    unlock: {type: kills_total, value: 1000, scope: global}

59. id: paradosso
    name: Paradosso
    desc: "Ogni turno è una sorpresa. Anche per lui."
    tier: 5
    primary: [wil, dex, int]
    growth: {str:2, dex:2, int:2, vit:0, wil:2}
    respec_bonus: {str:8, dex:8, int:8, vit:0, wil:8}
    special_id: paradox_chaos
    special_type: passive
    special_name: "Caos Assoluto"
    special_desc: "Ogni turno ottiene un effetto casuale dal pool (es: ATK×3, HP/2, invisibilità, DEF×0, +50 HP, -30 MP). Gli effetti si accumulano. La casualità è inarrestabile."
    unlock: {type: class_respec_count, value: 10, scope: global}
```

---

### TIER 6 — Divinità (1 classe, sblocco assoluto)

```
60. id: divinita
    name: Divinità
    desc: "Ha completato tutto. Ha visto tutto. Adesso è annoiato."
    tier: 6
    primary: [str, dex, int, vit, wil]
    growth: {str:0, dex:0, int:0, vit:0, wil:0}
    respec_bonus: {str:0, dex:0, int:0, vit:0, wil:0}
    special_id: god_mode
    special_type: passive
    special_name: "God Mode"
    special_desc: "Non può morire. Nessun fog of war (mappa sempre visibile). Fa sempre esattamente 1 danno per attacco, indipendentemente da qualsiasi stat o bonus."
    unlock: {type: all_classes_completed, scope: global}
```

**Nota unlock**: `all_classes_completed` richiede che tutte le altre 59 classi abbiano completato il gioco almeno una volta (segnalato da un segnale `game_completed` con `class_id` al termine dell'ultimo boss). Salvato in `global_milestones.completed_classes: []`.

**Specifica god_mode**:
- `player.invincible = true` → in `Player.take_damage()`: return se flag attivo
- FOV disabilitato: il renderer mostra sempre tutte le tile come visibili (nessuna oscurità)
- In `CombatManager.attack(player, enemy)`: danno finale = 1, ignora qualsiasi moltiplicatore, affix, buff o meccanica speciale
- La Divinità può ancora usare oggetti, camminare, interagire — semplicemente vince in modo umiliante lento

---

## Sistema Rispecializzazione — Licenza di Classe

### Item: class_license
```json
{
  "id": "class_license",
  "name": "Licenza di Classe",
  "type": "consumable",
  "icon": "L",
  "description": "Permette di cambiare classe. Gli attributi vengono conservati e si riceve un bonus di transizione.",
  "effect": { "class_respec": true }
}
```

### Modello attributi (non-cumulativo)

Il `respec_bonus` di una classe NON si somma permanentemente alle stat.
Il bonus è attivo solo mentre quella classe è equipaggiata.

```gdscript
# GameState — tre dizionari separati
var base_attributes := {"str":5,"dex":5,"int":5,"vit":5,"wil":5}  # crescono con i level up
var class_bonus     := {"str":0,"dex":0,"int":0,"vit":0,"wil":0}  # bonus classe corrente
var effective_attributes := {}  # base + class_bonus, usato per calcoli

func recalculate_effective_attributes() -> void:
    for attr in base_attributes:
        effective_attributes[attr] = base_attributes[attr] + class_bonus.get(attr, 0)
```

### Come funziona
1. Il player usa la Licenza dall'inventario
2. Si apre `ClassRespecScreen` (uguale al class picker della creazione personaggio)
3. Il player sceglie tra le classi sbloccate (escludendo la corrente)
4. Vengono applicati:
   - `GameState.current_class = nuova_classe`
   - `GameState.class_bonus = class_data["respec_bonus"]`  (sostituisce, non somma)
   - `GameState.recalculate_effective_attributes()`
   - `GameState.recalculate_derived_stats()`
   - HP, MP, Stamina portati al massimo
   - `GlobalMilestoneTracker.class_respec_count += 1`
5. La Licenza viene rimossa dall'inventario
6. Notifica: "Hai cambiato classe in [Nome Classe]! Bonus attributi applicati."

### Dove si trova la Licenza
- Drop garantito dal boss dell'ultimo piano di ogni dungeon (una volta per dungeon)
- Vendor speciale in città (prezzo elevato, da definire con sistema economico)
- Drop rarissimo (~2%) da qualsiasi boss

---

## MilestoneTracker — Contatori globali vs per-run

### File globale: `user://saves/global_milestones.json`
```json
{
  "kills_total": 0,
  "kills_boss": 0,
  "kills_enemy_type": {},
  "chests_opened": 0,
  "quests_completed": 0,
  "save_points_used": 0,
  "consumables_used": 0,
  "consumable_types_used": [],
  "items_collected_unique": [],
  "damage_dealt_total": 0,
  "damage_taken_total": 0,
  "damage_absorbed_total": 0,
  "deaths_total": 0,
  "overworld_tiles_explored": 0,
  "overworld_zones_visited": [],
  "dungeon_floors_total": 0,
  "dungeons_completed": 0,
  "dungeons_completed_no_death": 0,
  "dungeon_rooms_explored": 0,
  "tiles_explored_total": 0,
  "npcs_spoken": [],
  "scrolls_collected": 0,
  "gold_accumulated": 0,
  "attacks_dodged_total": 0,
  "enemies_seen_die": 0,
  "items_identified": 0,
  "survived_at_1hp": 0,
  "class_respec_count": 0,
  "unlocked_classes": ["noob"]
}
```

### Contatori solo per-run (in GameState.run_milestones, non nel file globale)
```
dungeon_floor_no_damage     — completare un piano senza subire danni
near_death_survived         — 3 turni consecutivi HP<=5
combat_wins_no_items        — N vittorie consecutive senza consumabili
dungeon_clear_no_death      — completare un dungeon senza morire
boss_killed_no_damage       — uccidere un boss senza subire danni
boss_killed_no_items        — uccidere boss senza oggetti
equip_full_set              — avere arma+scudo+armatura equipaggiati contemporaneamente
dual_stat_threshold         — STR≥X e INT≥X nella stessa partita
stat_threshold              — un attributo raggiunge soglia
```

---

## Tasto Q — Schema per tipo di abilità

### Passive (Q non fa nulla)
warrior_fury, rogue_backstab, monk_dodge, ranger_companion, knight_charge,
assassin_execute, priest_blessing, biomancer_regen, gladiator_adrenaline,
berserker_frenzy, vampire_lifesteal, corsair_dirty_hit, sentinel_guard,
werewolf_form, dragonhunter_slayer, colossus_resilience, war_god_double,
specter_phase, archunter_pierce, abyss_mirror, death_incarnate,
chosen_one, paradox_chaos, liche_army

### Active_key (Q → esegui immediatamente)
paladin_lay_on_hands, barbarian_warcry, necro_raise_dead, bard_song,
warlock_dark_pact, guardian_shield, spellblade_enchant, demonist_summon,
summoner_elemental (apre menu scelta), archmage_repertoire, time_rewind

### Active_target (Q → targeting con click mouse)
mage_arcane_bolt, shaman_totem, inventor_trap, bounty_hunter_mark,
witch_curse, chrono_slow, geo_wall, illusionist_double, archer_arrow,
inquisitor_analyze, predator_instinct (attiva), pyromancer_fireball,
dominator_control

### Active_toggle (Q cicla tra stati)
druid_shapeshift (umano → orso → lupo → umano)

### Passive_and_active
templar_holy_aura, predator_instinct, oracle_foresight, explorer_sense,
soul_harvest, champion_divine, void_form

---

## Meccaniche speciali — specifica implementazione

```
noob_adaptability       PASSIVE
  — Ignora ogni requisito "class_requirement" su item data
  — Nessun hook extra; la logica è già in Equipment.can_equip()

warrior_fury            PASSIVE
  — Hook in Player.take_damage() e HUD._refresh()
  — Se hp/max_hp < 0.30: player.attack_multiplier = 1.5, emit glyph_color_override("red")
  — Altrimenti: multiplier = 1.0

mage_arcane_bolt        ACTIVE_TARGET
  — TargetingMode: click su tile visibile entro INT/3 tile
  — Richiede line-of-sight (usa stesso FOV del renderer)
  — Se colpisce: danno = INT, applica a enemy.hp
  — Costo: 5 MP (controllato prima di entrare in targeting mode)

rogue_backstab          PASSIVE
  — Flag "first_attack_bonus" = true, diventa false dopo il primo attacco in combattimento
  — Reset a true quando TurnManager.is_active diventa false (uscita combattimento)
  — In CombatManager.attack(player, enemy): se flag attivo → danno ×3

ranger_companion        PASSIVE (entità permanent)
  — All'entrata in dungeon: spawn LupoAlleato su tile adiacente libera
  — Se ucciso durante il piano: flag "companion_dead = true"
  — All'entrata nel piano successivo: respawn automatico
  — Salvato in GameState.companion_alive (non nel location_state)

paladin_lay_on_hands    ACTIVE_KEY
  — Cura HP = VIT × 3, capped a max_hp
  — Flag: floor_heal_used — reset a false al cambio piano
  — Se flag già usato: notifica "Già usato su questo piano"

necro_raise_dead        ACTIVE_KEY
  — Variabile: last_killed_enemy_data (id, atk, base_hp) salvata in SpecialManager
  — Crea entità RaisedDead con quelle stats, durata INT/2 turni (non permanent)
  — Costo: 10 MP

monk_dodge              PASSIVE
  — In CombatManager.attack(enemy, player): roll float casuale
  — Se roll < DEX/100 (cap 0.40): danno = 0, notifica "Schivato!"

barbarian_warcry        ACTIVE_KEY
  — Applica debuff su tutti i nemici nel detection_range del player
  — Debuff: {"atk_mult": 0.70, "turns": 4}
  — In Enemy.compute_attack(): se debuff attivo → danno × atk_mult
  — Costo: 10 Stamina

alchemist_brew          ACTIVE_KEY (apre UI)
  — Apre mini-pannello con lista consumabili (2 slot drag/select)
  — Ricette definite in data/alchemy_recipes.json
  — Se combinazione valida: rimuove 2 item, aggiunge 1 item risultante
  — Se combinazione non valida: notifica "Incompatibili"

bard_song               ACTIVE_KEY
  — Applica buff al player: atk_mult×1.2, def_mult×1.2, dex_add=DEX×0.2, 5 turni
  — Flag: floor_song_used — reset al cambio piano

druid_shapeshift        ACTIVE_TOGGLE
  — Stato: shape = "human" | "bear" | "wolf"
  — Q cicla: human→bear→wolf→human
  — Bear: max_hp×1.5, attack×1.5, dex/2, blocca magia
  — Wolf: dex×2, dodge+20%, blocca magia
  — I buff sono multiplicativi su base; ricalcolati a ogni cambio forma
  — Costo: 10 MP per trasformazione

knight_charge           PASSIVE
  — In Player.move(): traccia posizione precedente
  — Se movimento in linea retta (stessa riga o colonna) di ≥2 tile verso un nemico
    e il nemico è adiacente dopo il movimento: danno ×2, applica stun 1 turno

assassin_execute        PASSIVE
  — In CombatManager.attack(player, enemy):
    Se enemy.hp / enemy.max_hp < 0.20 → kill istantaneo
  — Dopo ogni kill: player.invisible = true per 1 turno
  — invisible: i nemici non si allertano e non contrattaccano

warlock_dark_pact       ACTIVE_KEY
  — Converti X HP in X MP (1:1), costo base 5 HP per attivazione
  — ATK_bonus = (1.0 - hp/max_hp) / 0.10 * 0.05 (5% per ogni 10% HP mancante)
  — Applicato come multiplier in CombatManager
  — Non può portare HP a 0 per attivazione

priest_blessing         PASSIVE
  — In TurnManager.player_turn_end(): ogni 3 turni (contatore in SpecialManager)
    player.hp += int(VIT / 4), capped a max_hp
  — Immune a debuff con tag "curse"

biomancer_regen         PASSIVE
  — In TurnManager.player_turn_end(): se non si è subito danno nell'ultimo turno
    player.hp += int(VIT / 5), capped a max_hp
  — Flag "took_damage_this_turn" = true in Player.take_damage(), reset a inizio turno player

gladiator_adrenaline    PASSIVE
  — In CombatManager.kill(enemy): adrenaline_stacks = min(stacks+1, 10)
  — Player.attack_bonus = adrenaline_stacks (flat, non percentuale)
  — Reset a 0 all'uscita dal dungeon (non al cambio piano)

sciamano_totem          ACTIVE_TARGET
  — Click su tile adiacente libera → spawn entità Totem (hp=1, faction=player_ally)
  — Ogni 2 turni del Totem: cura WIL/4 HP a tutti entro 3 tile (incluso player)
  — Max 1 totem; se piazzato un secondo, il precedente viene rimosso
  — Non permanent: si perde al cambio piano

templar_holy_aura       PASSIVE + ACTIVE_KEY
  — Passiva: In Enemy.compute_attack(): se manhattan(enemy, player) <= 2 → danno × 0.85
  — Q (cooldown 5 turni): danno WIL×2 su tutti i nemici in vista, ignora DEF
  — Costo: 20 MP

inventor_trap           ACTIVE_TARGET
  — Click su tile adiacente libera → spawn entità Trap (invisibile ai nemici)
  — Quando un nemico calpesta la tile: danno = INT×2, Trap rimossa
  — Max 3 trappole attive contemporaneamente

bounty_hunter_mark      ACTIVE_TARGET
  — Click su nemico visibile → marked_target = enemy_id
  — In CombatManager: danni su marked_target × 1.50 (da qualsiasi fonte)
  — Max 1 bersaglio, rimosso alla morte del nemico

pyromancer_fireball     ACTIVE_TARGET
  — Come mage_arcane_bolt ma: danno = INT + bruciatura
  — Bruciatura: {"burn_damage": INT/3, "burn_turns": 3} su enemy
  — In Enemy.take_turn(): se burn_turns > 0 → enemy.hp -= burn_damage; burn_turns--

chrono_slow             ACTIVE_TARGET
  — Debuff su nemico: {"slowed": true, "slow_turns": INT/2}
  — In Enemy.take_turn(): se slowed e turno pari → skip turno; slow_turns--

geo_wall                ACTIVE_TARGET
  — Crea entità Wall su tile adiacente libera (non calpestabile, opaca, hp=999)
  — Dopo VIT/3 turni: rimossa (contatore in SpecialManager)
  — Max 1 muro alla volta

illusionist_double      ACTIVE_TARGET
  — Crea entità Decoy su tile adiacente (glyph "@", hp=1, faction=player_ally)
  — Logica AI nemica: preferisce Decoy come bersaglio se visibile
  — Dopo DEX/4 turni o se distrutta: rimossa. Non permanent.

vampire_lifesteal       PASSIVE
  — In CombatManager.attack(player, enemy): dopo calcolo danno finale
    player.hp += int(danno_inflitto * 0.25), capped a max_hp

demonist_summon         ACTIVE_KEY
  — Crea entità DemonServant: hp = player.max_hp×0.5, atk = player.attack×1.5
  — Durata: WIL/2 turni (min 3). Non permanent.
  — AI: stesso comportamento del lupo del Ranger

summoner_elemental      ACTIVE_KEY (apre menu scelta)
  — Q apre selezione: Fuoco / Acqua / Terra
  — Fuoco → FireSpirit: atk=INT×1.5, hp=player.max_hp×0.3, attacca a distanza 2 tile
  — Acqua → WaterSpirit: ogni 2 turni cura +WIL/4 HP al player entro 3 tile
  — Terra → EarthSpirit: blocca tile, hp=player.max_hp×2, non attacca
  — Durata: 5 turni. Non permanent.

witch_curse             ACTIVE_TARGET
  — Debuff: {"cursed": true, "stat_mult": 0.80, "curse_turns": 5}
  — In CombatManager: tutti i stat nemico × stat_mult se cursed
  — Decrementato in Enemy.take_turn()

spellblade_enchant      ACTIVE_KEY
  — Stato: enchanted_hits_left = 3
  — In CombatManager.attack(player, enemy): se enchanted_hits_left > 0
    danno_finale += INT (ignora DEF); enchanted_hits_left--

corsair_dirty_hit       PASSIVE
  — In CombatManager.attack(player, enemy): randf() < 0.35 → stun
  — Enemy.stunned = true → skip take_turn(); poi stunned = false

sentinel_guard          PASSIVE
  — In TurnManager.player_turn_end(): se player non si è mosso né attaccato
    guard_stacks = min(guard_stacks+1, 4)
  — altrimenti: guard_stacks = 0
  — Player.defense_effective = base_defense × (1 + guard_stacks)

predator_instinct       PASSIVE + ACTIVE_KEY
  — Passiva: enemy.has_never_acted = true inizialmente; false dopo primo take_turn()
    In CombatManager: se has_never_acted → danno ×2
  — Q: rivela posizioni di tutti i nemici del piano (aggiorna mappa come esplorata)

arcanist_absorb         PASSIVE
  — Trigger quando Player.take_damage() con fonte "magic" o nemico di tipo "mage"
  — MP recuperati = damage_received / 4

inquisitor_analyze      ACTIVE_TARGET (solo adiacenti)
  — Click su nemico adiacente → apre pannello con: nome, hp/max_hp, atk, def, xp_reward
  — Azione libera (non consuma il turno né MP)

wanderer_stealth        PASSIVE
  — In Enemy.take_turn(): effective_detection = detection_range / 2
  — In EnemyPlacer: nemici entro 2 tile dal player spawn non vengono pre-allertati

berserker_frenzy        PASSIVE
  — In CombatManager: se TurnManager.is_active → player.attack × 1.40
  — In Player._unhandled_input: blocca azioni "use_item" e "flee" se in combattimento
    → notifica: "La frenesia non ti permette di usare oggetti"

archer_arrow            ACTIVE_TARGET
  — Come mage_arcane_bolt ma: danno = player.attack (fisico), no MP cost
  — Cooldown: 2 turni (tracked in SpecialManager.arrow_cooldown)
  — Range: DEX/4 tile. Il nemico non contrattacca.

oracle_foresight        PASSIVE + ACTIVE_KEY
  — Passiva: HP nemici in vista mostrati come overlay (via HUD/Renderer)
  — Q: flag "next_dodge = true"; In CombatManager.attack(enemy, player):
    se next_dodge → danno=0, next_dodge=false. Limite: 1/combattimento

guardian_shield         ACTIVE_KEY
  — Crea shield_hp = VIT×2 in SpecialManager
  — In Player.take_damage(): danno va su shield_hp prima che su hp
  — Una volta per piano; reset a cambio piano

werewolf_form           PASSIVE (automatica)
  — All'entrata in dungeon: applica buff: max_hp×1.5, attack×2
    hp scalato proporzionalmente; blocca scroll/wand
  — All'entrata in overworld/building/village: rimuovi buff, ricalcola stats

dragonhunter_slayer     PASSIVE
  — In CombatManager: se enemy.max_hp > player.max_hp×2 → danno ×1.75
  — Immune a debuff con tag "fear"

explorer_sense          PASSIVE
  — All'entrata in nuovo piano: reveal intera mappa (tutte tile "visited")
  — In LevelSystem.add_xp(): se siamo in dungeon → xp × 1.25

liche_army              PASSIVE (entità permanent)
  — In CombatManager.kill(enemy): se skeleton_count < INT/4
    spawn entità Skeleton (hp=1, permanent=true) su tile vicina libera
  — Skeleton: atk basso (INT/3), respawna al piano successivo se ucciso

archmage_repertoire     ACTIVE_KEY
  — Stato: spell_index (0=proiettile, 1=bruciatura, 2=rallentamento)
  — Q lancia spell_index attivo (logica identica alle classi corrispondenti)
  — Shift+Q cicla al prossimo incantesimo
  — Nuovi incantesimi (4+) sbloccati da scroll_rare trovati durante la run

soul_harvest            PASSIVE + ACTIVE_KEY
  — In CombatManager.kill(enemy): souls = min(souls+1, INT/2)
  — Q: se souls > 0 → a scelta (mini-menu): spendi 1 anima per +WIL HP oppure +5 ATK per 3 turni

colossus_resilience     PASSIVE
  — Immune a stun, slow, fear (ignora applicazione debuff)
  — In TurnManager.player_turn_end(): se in combattimento → hp += int(VIT/2)

time_rewind             ACTIVE_KEY
  — Buffer: ultimi 5 stati player (pos, hp, mp, st) in SpecialManager
  — Q: ripristina stato di 5 turni fa
  — Una volta per piano; flag reset a cambio piano

specter_phase           PASSIVE
  — In Player.move(): ignora collisione con tile "wall" (non "door")
  — In CombatManager.attack(enemy, player): randf() < 0.50 → miss
  — In Enemy.take_turn(): detection solo entro 1 tile

champion_divine         PASSIVE + ACTIVE_KEY
  — Passiva: flag "divine_resurrection_used = false"
    In Player.take_damage(): se hp <= 0 e non usato → hp = max_hp/2; flag = true
  — Q: applica buff atk_mult×1.5, def_mult×1.5 per 5 turni. Costo: 20 MP

war_god_double          PASSIVE
  — In CombatManager.attack(player, enemy): calcola danno normale, poi
    applica secondo colpo a 50% danno (bypass DEF)
  — Ogni kill: decrementa tutti i cooldown in SpecialManager di 1

dominator_control       ACTIVE_TARGET
  — Click su nemico adiacente → controlled_enemy = enemy
  — Controlled enemy: faction temporanea "player_ally", attacca i propri alleati
  — Durata: WIL/3 turni; poi torna a faction originale. Non permanent.
  — Costo: 30 MP

archunter_pierce        PASSIVE
  — In CombatManager.attack(player, enemy): ignora enemy.defense completamente
  — player.attack_bonus += int(DEX/4) (flat bonus sempre attivo)

void_form               PASSIVE + ACTIVE_KEY
  — Passiva resurrection: come champion_divine ma con hp=1
  — Passiva wil_growth: In CombatManager.combat_end(victory): wil_run_bonus++
    (max 20 per run); applicato come flat a GameState.attributes["wil"]
  — Q: intangible=true per 3 turni (immune a danno, non può attaccare)

abyss_mirror            PASSIVE
  — In Player.take_damage(amount, source): danno riflesso su tutti i nemici in vista
    usando CombatManager.apply_damage(enemy, amount) per ognuno
  — Il riflesso non può uccidere il player stesso
  — Immune a critical hits

death_incarnate         PASSIVE
  — In CombatManager.attack(player, enemy): se enemy.hp < player.max_hp*0.33 → kill istantaneo
  — Aura: In TurnManager.player_turn_start(): ogni nemico a manhattan<=1 perde 5 HP

paradox_chaos           PASSIVE
  — Pool di 12 effetti (6 positivi, 6 negativi)
  — In TurnManager.player_turn_start(): applica effetto random dal pool
  — Effetti si accumulano (tutti attivi contemporaneamente)
  — Positivi: ATK×2, DEF×2, +30HP, invisibilità 2t, DEX×2, MP+20
  — Negativi: ATK/2, DEF=0, -20HP, stun 1t, DEX/2, MP-15

chosen_one              PASSIVE
  — Override in LevelSystem: xp_required × 3
  — Override in _reset_game_state(): attributi iniziali = 10 invece di 5
  — Growth da ClassDB già a 2 per attributo

liche_army              (vedi sopra)
```

---

## Struttura file — schema completo

### File dati classi (un file per classe, organizzati per tier)
```
data/classes/
    tier1/
        noob.json
        guerriero.json
        mago.json
        ladro.json
        ranger.json
        paladino.json
        negromante.json
        monaco.json
        barbaro.json
        alchimista.json
        bardo.json
        druido.json
    tier2/
        cavaliere.json
        assassino.json
        stregone.json
        sacerdote.json
        biomante.json
        gladiatore.json
        sciamano.json
        templare.json
        inventore.json
        cacciatore_di_taglie.json
    tier3/
        piromante.json
        cronomante.json
        geomante.json
        illusionista.json
        vampiro.json
        demonista.json
        evocatore.json
        strega.json
        lamiere.json
        corsaro.json
        sentinella.json
        predatore.json
        arcanista.json
        inquisitore.json
        viandante.json
        berserker.json
        arciere.json
        oracolo.json
        custode.json
        mannaro.json
        cacciatore_di_draghi.json
        esploratore.json
    tier4/
        liche.json
        arcimago.json
        cacciatore_anime.json
        colosso.json
        maestro_tempo.json
        spettro.json
        campione.json
        dio_guerra.json
        dominatore.json
        arcicacciatore.json
    tier5/
        eletto.json
        specchio_abisso.json
        vuoto.json
        morte_incarnata.json
        paradosso.json
    tier6/
        divinita.json
```

ClassDB scansiona ricorsivamente tutte le sottodirectory in ordine (tier1→tier6).
Per disabilitare una classe senza eliminarla: `"status": "disabled"` nel suo file.

### Schema di ogni file classe
I dati sono gli stessi del piano (id, name, description, tier, primary, growth,
respec_bonus, special_id, special_type, special_name, special_desc, unlock) più:
```json
{
  "implementation": {
    "status": "planned|implemented|disabled|needs_system",
    "complexity": "simple|medium|complex|system",
    "requires": []
  },
  "balance_category": "normal|strong|endgame|legendary_broken|joke|challenge"
}
```

### Nuovi script da creare
```
scripts/classes/ClassDB.gd                   — autoload, carica + valida tutte le classi
scripts/classes/ClassValidator.gd            — validazione schema a startup
scripts/classes/ClassRuntime.gd              — carica ClassSpecial attivo, fa dispatch hook
scripts/classes/ClassUnlockService.gd        — valuta milestone, sblocca classi
scripts/classes/ClassRespecService.gd        — cambia classe, aggiorna class_bonus
scripts/classes/specials/ClassSpecial.gd     — base class con tutti gli hook vuoti
scripts/classes/specials/NoobAdaptability.gd
scripts/classes/specials/WarriorFury.gd
scripts/classes/specials/... (uno script per special_id)

scripts/core/GlobalMilestoneTracker.gd       — autoload, gestisce global_milestones.json
scripts/core/DamagePipeline.gd               — DamageContext + pipeline unica del danno
scripts/core/StatusEffectManager.gd          — buff/debuff centralizzati
scripts/core/AbilityUseTracker.gd            — cooldown e usi per piano/combattimento/run
scripts/core/AllyManager.gd                  — permanent vs temporary entities

scenes/ui/ClassPickerPanel.tscn + .gd        — griglia classi (locked/unlocked)
scenes/ui/ClassRespecScreen.tscn + .gd       — schermata cambio classe
scenes/ui/TargetingOverlay.tscn + .gd        — cursore targeting per active_target
```

### File esistenti da modificare
```
scripts/core/EventBus.gd               — segnali milestone + game_completed
scripts/core/GameState.gd             — base_attributes, class_bonus, effective_attributes,
                                         current_class, run_milestones, companion_alive
scripts/core/LevelSystem.gd           — growth su base_attributes da ClassDB
scripts/core/SaveManager.gd           — salva current_class + run_milestones
scripts/core/CombatManager.gd         — refactor per DamagePipeline
scripts/ui/NewGamePanel.gd/.tscn      — integra ClassPickerPanel
scripts/ui/StatusScreen.gd/.tscn      — mostra classe + abilità speciale
scripts/entities/Player.gd            — hook ClassRuntime + tasto Q + targeting
scripts/entities/Enemy.gd             — debuff support via StatusEffectManager
scripts/entities/Chest.gd             — emette chest_opened per MilestoneTracker
```

### Autoload da aggiungere in Project Settings
```
ClassDB                → scripts/classes/ClassDB.gd
GlobalMilestoneTracker → scripts/core/GlobalMilestoneTracker.gd
```

---

## Fasi di implementazione — ordine per dipendenze

Le fasi rispettano le dipendenze tecniche: ogni fase crea esattamente ciò che serve
alla fase successiva. Non si implementano classi che richiedono sistemi non ancora
esistenti.

---

### Fase A — Data layer + GameState
**Nessuna dipendenza. Base di tutto.**

1. Creare tutti i 60 file JSON in `data/classes/tier{N}/`
   (con `"implementation": {"status": "planned"}` per tutto eccetto le classi MVP)
2. Creare `ClassDB.gd` (scansione ricorsiva tier1→tier6, get_class(), get_all())
3. Creare `ClassValidator.gd` (valida schema a startup, errori leggibili)
4. Aggiornare `GameState`:
   - Sostituire `attributes` con `base_attributes` + `class_bonus` + `effective_attributes`
   - Aggiungere `current_class: String = "noob"` e `run_milestones: Dictionary`
   - Aggiornare `recalculate_derived_stats()` per usare `effective_attributes`
5. Aggiornare `SaveManager` (salva/carica current_class, base_attributes, run_milestones)
6. Aggiornare `LevelSystem._apply_level_up()`: incrementa `base_attributes` con growth da ClassDB

**Output**: il gioco carica i dati classi, GameState ha la struttura corretta, il save include la classe. Nulla è visibile ancora.

---

### Fase B — Class picker + selezione iniziale
**Dipende da: Fase A**

1. Creare `ClassPickerPanel.tscn/.gd`
   - Mostra solo classi con `status = "implemented"` + sbloccate
   - Per ora mostra solo Noob (sempre implementata e sempre sbloccata)
   - Layout: griglia + pannello dettaglio (nome, desc, stats, abilità, unlock)
2. Integrare nel `NewGamePanel` (come step dopo nome personaggio)
3. Aggiornare `StatusScreen` per mostrare nome classe e `special_desc`
4. `_reset_game_state()` in Main.gd: applica `class_bonus` della classe scelta

**Output**: si può iniziare una run scegliendo Noob. Il class picker è pronto per aggiungere classi man mano.

---

### Fase C — DamagePipeline
**Dipende da: Fase A. Obbligatoria prima di qualsiasi classe che modifica il danno.**

1. Creare `DamagePipeline.gd` con `DamageContext` (vedi sezione Architettura tecnica)
2. Refactorare `CombatManager` per usare la pipeline
3. Esporre hook: `before_player_attack`, `after_player_attack`, `before_player_damaged`, `after_player_damaged`, `on_enemy_killed`
4. Creare `ClassRuntime.gd` (carica ClassSpecial, fa dispatch degli hook)
5. Creare `ClassSpecial.gd` (base class con tutti gli hook vuoti)

**Output**: CombatManager usa la pipeline. ClassRuntime può intercettare il combattimento.

---

### Fase D — Prime classi MVP (passive semplici)
**Dipende da: Fase B + Fase C**

Implementare 5 classi che coprono tutti i casi tecnici base:

```
noob_adaptability    — flag passivo, nessun hook combat
warrior_fury         — passive hook su HP ratio → attack_multiplier
monk_dodge           — passive hook before_player_damaged → cancel
ladro_backstab       — passive con stato temporaneo (first_attack flag)
paladino_lay_on_hands — active_key con AbilityUseTracker (una volta per piano)
```

Per Paladino: creare `AbilityUseTracker.gd` prima di procedere.

Impostare `"status": "implemented"` nei file JSON delle 5 classi.
Aggiornare `ClassPickerPanel` per mostrarle se sbloccate.

**Output**: prime 5 classi giocabili, sistema testabile end-to-end.

---

### Fase E — AbilityUseTracker + active_key
**Dipende da: Fase C + Fase D (AbilityUseTracker già creato in D)**

Implementare le restanti classi `active_key` che non richiedono entità né status effect:

```
barbarian_warcry       — AoE debuff ATK (ha bisogno di StatusEffectManager → rimandare)
bard_song              — buff temporaneo al player (semplice, nessun status esterno)
guardian_shield        — shield_hp locale, assorbito in before_player_damaged
spellblade_enchant     — counter locale, hook after_player_attack
warlock_dark_pact      — modifica HP/MP diretta + hook attack_multiplier
```

Nota: `barbarian_warcry` tocca i nemici → va con StatusEffectManager (Fase F).

**Output**: classi active_key funzionanti, AbilityUseTracker stabile.

---

### Fase F — StatusEffectManager + debuff
**Dipende da: Fase C**

1. Creare `StatusEffectManager.gd` (apply, tick, remove, stacking rules)
2. Aggiornare `Enemy.gd` per leggere status effect durante take_turn()
3. Ora è possibile implementare:
   - `barbarian_warcry` (debuff ATK su nemici)
   - `witch_curse`, `chrono_slow` (debuff su nemico target → rinviati a Fase G per targeting)
   - `corsair_dirty_hit` (stun passivo)
   - `berserker_frenzy` (buff passivo + blocco oggetti)
   - `sentinel_guard` (guard_stacks come stato locale)
   - Burn per piromante (rinviato a Fase G)

**Output**: sistema debuff/buff stabile, base per tutte le classi di controllo.

---

### Fase G — TargetingOverlay + active_target
**Dipende da: Fase C + Fase F**

1. Creare `TargetingOverlay.tscn/.gd`
   - Attivato da Q quando la classe ha `special_type = active_target`
   - Click su tile valida → `ClassRuntime.use_targeted(tile)`
   - Highlight tile valide, glyph cursore, ESC per annullare
2. `ClassSpecial.is_valid_target(tile) -> bool` → ogni classe implementa la propria validazione
3. Implementare classi active_target:
   ```
   mage_arcane_bolt, archer_arrow, bounty_hunter_mark, inquisitor_analyze,
   shaman_totem, inventor_trap, pyromancer_fireball, witch_curse, chrono_slow,
   geo_wall, illusionist_double, dominator_control
   ```

**Output**: targeting mode mouse funzionante, tutte le classi a bersaglio implementabili.

---

### Fase H — AllyManager + entità alleate
**Dipende da: Fase C + Fase G**

1. Creare `AllyManager.gd` (spawn, permanent/temporary, floor_changed, respawn)
2. Implementare classi con entità:
   ```
   ranger_companion     — permanent, spawn a inizio dungeon, respawn al piano
   necro_raise_dead     — temporary, turni contati
   demonist_summon      — temporary, turni contati
   shaman_totem         — temporary, entità piazzata su tile
   illusionist_double   — temporary, entità decoy
   summoner_elemental   — temporary, 3 tipi (apre mini-menu → Fase K)
   liche_army           — permanent, spawn da kill
   ```

**Output**: entità alleate funzionanti, distinzione permanent/temporary corretta.

---

### Fase I — MilestoneTracker + sistema sblocco
**Dipende da: Fase A. Può essere fatto in parallelo con Fasi D-H.**

1. Creare `GlobalMilestoneTracker.gd` (load/save global_milestones.json)
2. Aggiungere segnali mancanti a `EventBus` (enemy_killed, chest_opened, damage_dealt, ecc.)
3. `GlobalMilestoneTracker` ascolta i segnali e aggiorna i contatori
4. `ClassUnlockService` controlla le condizioni di sblocco dopo ogni incremento
5. Toast "Classe sbloccata: [Nome]!" quando condizione raggiunta
6. `ClassPickerPanel` aggiorna la lista al cambio di stato

**Output**: le classi si sbloccano giocando, i contatori persistono tra le run.

---

### Fase J — ClassRespecService + Licenza di Classe
**Dipende da: Fase A + Fase B + Fase I**

1. Aggiungere `class_license` a items.json (o file separato)
2. Creare `ClassRespecService.gd`:
   - Legge `GameState.class_bonus` della nuova classe (non somma, sostituisce)
   - `GlobalMilestoneTracker.class_respec_count += 1`
3. Creare `ClassRespecScreen.tscn/.gd` (uguale a ClassPickerPanel ma esclude classe corrente)
4. Connettere uso dell'item all'apertura della schermata

**Output**: il player può cambiare classe senza rompere il bilanciamento.

---

### Fase K — Classi complesse con UI dedicata
**Dipende da: sistema oggetti (Fase K solo dopo plan_item_system.md avanzato)**

```
alchemist_brew      — mini-UI ricette, richiede item system avanzato
summoner_elemental  — mini-menu scelta tipo elementale
druid_shapeshift    — toggle forme, già fattibile dopo Fase C
oracle_foresight    — passiva + active_key, fattibile dopo Fase C
explorer_sense      — rivelazione mappa, fattibile dopo Fase C
```

Nota: druido, oracolo ed esploratore NON richiedono sistema oggetti → possono essere
anticipati a Fase E/F senza aspettare Fase K.

---

### Fase L — Tier 4, 5, 6
**Dipende da: tutte le fasi precedenti stabili**

Implementare solo dopo che i sistemi sono testati e stabili.
Ordine consigliato per complessità crescente:

```
Tier 4 semplici:  colosso, arcicacciatore, dio_guerra, spettro
Tier 4 medi:      cacciatore_anime, campione, maestro_tempo, dominatore
Tier 4 complessi: liche, arcimago
Tier 5:           morte_incarnata, specchio_abisso, vuoto, eletto, paradosso
Tier 6:           divinita (2 flag: invincible + fov_disabled + damage=1)
```

---

### Riepilogo dipendenze

```
A (data) → B (picker) → D (MVP classi)
A        → C (pipeline) → D
C        → E (active_key)
C        → F (status effects)
C + F    → G (targeting)
C + G    → H (allies)
A        → I (milestones) ← può partire subito dopo A
A + B + I → J (respec)
tutto    → K (UI complesse)
tutto    → L (tier 4-6)
```

---

## Questioni aperte (da decidere prima di Fase F+)

1. **Paradosso — pool effetti**: i 12 effetti vanno definiti con valori esatti e
   durata. Proposta: effetti a durata fissa 1 turno salvo indicato diversamente.
2. **Arcimago — scroll rari**: definire quali scroll insegnano incantesimi nuovi
   (da fare quando si implementa il sistema oggetti con affissi).

---

## Architettura tecnica — linee guida implementazione

### SpecialManager: architettura modulare (no switch gigante)
Ogni abilità è uno script separato che estende `ClassSpecial`:

```
res://scripts/classes/
    ClassDB.gd
    ClassRuntime.gd          ← carica ClassSpecial, fa dispatch hook
    ClassUnlockService.gd
    ClassRespecService.gd

res://scripts/classes/specials/
    ClassSpecial.gd           ← base class con hook vuoti
    NoobAdaptability.gd
    WarriorFury.gd
    ...
```

`ClassRuntime` chiama `active_special.on_before_player_attack(ctx)` ecc — non sa
nulla delle logiche interne. Ogni script si registra nel registry di `ClassRuntime`.

### DamagePipeline (obbligatorio prima delle Fasi D+)
Ogni attacco passa per un `DamageContext` con:
- `base_damage`, `flat_bonus`, `attack_multiplier`, `target_multiplier`
- `ignore_defense`, `final_damage`, `damage_type`
- `cancelled`, `instant_kill`, `tags`

Ordine: crea ctx → hook before → calcola → applica → hook after → effetti secondari.
Questo evita che ogni classe modifichi il danno in modo indipendente e incompatibile.

### StatusEffectManager (obbligatorio prima di burn/slow/curse)
Ogni stato ha: `id`, `source`, `duration_turns`, `stacking` (replace/refresh/stack/ignore), `data`.
Gestito centralmente, decrementato a ogni turno.

### AbilityUseTracker (obbligatorio prima di Fase E)
Traccia cooldown e usi per piano/combattimento/run.
Config dentro class data:
```json
"usage": {"limit": 1, "reset": "floor"}
"usage": {"cooldown_turns": 5}
```

### AllyManager (obbligatorio prima di Fase G)
Separazione netta: `permanent_allies` (salvati nel personaggio, respawnano al piano)
vs `temporary_allies` (non salvati, rimossi a cambio piano).

### MVP consigliato per primo test giocabile
Prima di implementare meccaniche complesse, testare con queste 5 classi:
Noob, Guerriero, Mago, Ladro, Paladino — coprono passive, active_key, active_target,
passive con stato, uso per piano, consumo MP.

### Validation all'avvio
`ClassDB` deve validare a startup: id univoco, growth/respec_bonus con tutti e 5 gli
attributi, special_type valido, unlock type valido. Errori leggibili in output.

### Balance categories (da aggiungere a ciascuna classe in futuro)
`"balance_category": "normal|strong|endgame|legendary_broken|joke|challenge"`
Utile per filtrare classi nel class picker e per decidere dove concentrare il testing.

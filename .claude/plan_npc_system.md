# Piano: Sistema NPC

**Stato**: Da progettare — da discutere prima di implementare.

---

## Contesto

Gli NPC esistono già nel gioco (`scripts/entities/NPC.gd`). Il sistema attuale è basilare:
- Char fisso `N`, colore giallo oro
- Dialoghi statici via `DialogueManager`
- Quest linking tramite `linked_quest_id`
- Idle dialogues (array CSV)

Questo piano riguarda l'espansione del sistema NPC in modo che sia più ricco e integrato con il mondo.

---

## Domande aperte (da discutere)

- Tipi di NPC: ci sono categorie diverse (mercante, quest-giver, neutrale, ostile latente, alleato)?
- Gli NPC si muovono? Hanno routine giornaliere (giorno/notte)?
- Gli NPC possono morire permanentemente (permadeath degli NPC)?
- Gli NPC reagiscono alla reputazione del player?
- Ci sono NPC unici (con nome proprio) vs generici (guardia, contadino)?
- I mercanti hanno un sistema di prezzi dinamico o fisso?
- Gli NPC ricordano le azioni del player tra una visita e l'altra?
- I dialoghi sono già implementati o vanno riprogettati?

---

## Da fare (bozza, da raffinare dopo la discussione)

- [ ] Definire tipi NPC e loro comportamenti
- [ ] Sistema routine (se previste)
- [ ] Integrazione con permadeath NPC
- [ ] Sistema reputazione (se previsto)
- [ ] Dialoghi avanzati
- [ ] Mercanti
- [ ] Locandieri
- [ ] Quest NPC avanzati

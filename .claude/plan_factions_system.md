# Piano: Sistema Fazioni

**Stato**: In discussione — architettura definita, mancano ancora alcuni dettagli prima di implementare.

---

## Decisioni prese

### Generali
- La reputazione si resetta con ogni personaggio (non persiste tra run)
- Range reputazione: **-100 … +100**
- Rep default con fazioni nemiche (mostri): **-100**
- Rep default con fazioni neutre (civili): **0**
- La rep delle fazioni nemiche **può cambiare** — le classi come ranger, negromante, druido possono sviluppare relazioni diverse con i vari tipi di mostro

### Soglie comportamentali
| Range | Stato | Comportamento |
|-------|-------|---------------|
| -100 … -75 | **Nemico giurato** | Attacco a vista |
| -74 … -25 | **Ostile** | Dialogo limitato, prezzi maggiorati, rifiuto servizi |
| -24 … +24 | **Neutrale** | Comportamento standard |
| +25 … +49 | **Amico** | Dialogo espanso, missioni disponibili |
| +50 … +74 | **Alleato** | Sconto mercanti, quest esclusive, accesso aree riservate |
| +75 … +100 | **Fidato** | Accesso a fazioni joinabili, informazioni privilegiate |

### Propagazione rep
Due livelli di propagazione, entrambi al **primo livello** (non a cascata):
- **Gerarchica (10%)**: sale/scende lungo l'albero delle dipendenze primarie
- **Laterale (30%)**: si propaga alle fazioni alleate/nemiche nella matrice inter-fazione

### Fazioni joinabili
- `corporazione_camere` è **obbligatoria** all'inizio del gioco
- Lista completa **da fornire**

### Struttura file
- Un JSON per fazione in cartelle separate per tipo:
  `data/factions/tier_s/`, `tier_a/`, `tier_b/`, `tier_c/`, `signorie/`, `nemici/`, `natura/`, `villaggi/`
- Filename = ID fazione (es. `signoria_almerici.json`, non `almerici.json`)
- Un JSON globale `data/factions/relations.json` per la matrice inter-fazione
- Fazioni villaggio pre-definite, modificabili a runtime come esito di quest

### Separazione GameState / WorldState
- **GameState** (per-personaggio, resettato alla morte): `character_faction_rep`, `character_faction_membership`, `character_faction_flags`
- **WorldState** (world-persistent, condiviso tra personaggi): `faction_world_flags`, `registered_dungeon_maps`, `built_post_stations`, `discovered_safe_houses`, `opened_player_services`, `village_faction_changes`
- La reputazione muore col personaggio; le mappe vendute, le stazioni costruite, i negozi aperti restano nel mondo

### Crime system
- Attaccare NPC neutrali è un reato → inseguimento `milizia_campane` → arresto/multa
- Crime system da sviluppare in un piano separato

---

## Albero gerarchico

Il sistema ha **tre alberi indipendenti** più una fazione illegale, con dipendenze trasversali funzionali tra gli alberi. Le Signorie sono entità politiche **parallele**, non subordinate a nessuno dei tre alberi (sebbene abbiano relazioni con tutti).

---

### Albero I — La Cattedra del Canone
*Autorità religiosa, educativa e legale. Autonomia assoluta. Può esautorarsi chiunque nel proprio albero.*

```
Cattedra del Canone
├── Collegio dei Maestri Canonici
│     educazione, certificazione istruttori e percorsi formativi
├── Ordine dei Sigillatori
│     autorità notarile e legale
│     └── Compagnia dei Corrieri di Sigillo
│           trasporto di documenti ufficiali e sigillati
├── Milizia delle Campane
│     ordine pubblico e sicurezza urbana
│     └── Becchini del Canone
│           riti funebri, cripte, gestione non-morti minori
└── Congregazione delle Officine
      guarigione autorizzata e strutture sanitarie licenziate
      └── Sorelle del Sale
            ospedali, ricoveri, assistenza ai feriti sul campo
```

---

### Albero II — La Corporazione delle Camere di Condotta
*Condotte, mostri, dungeon e licenze operative. Autonomia molto alta. Opera indipendentemente ma la sua legittimità pubblica deriva dal riconoscimento della Cattedra.*

```
Corporazione delle Camere di Condotta
├── Collegio dei Cartografi
│     mappatura dungeon e intelligence sui percorsi
├── Fratellanza del Mantello Grigio
│     supporto armato e contratti privati
├── Cacciatori di Rogna
│     controllo mostri minori
└── Confraternita della Buona Strada
      guida ai viaggiatori e sicurezza delle rotte
```

---

### Albero III — La Corporazione delle Spezierie e delle Bilance
*Commercio, credito, merci e logistica. Autonomia alta. Dipende dalla Cattedra per pesi ufficiali, sigilli e dispute giuridiche.*

```
Corporazione delle Spezierie e delle Bilance
├── Banco delle Tre Monete
│     credito, banche, debiti
├── Arte dei Ferri e delle Braci
│     armi, strumenti e beni metallici
├── Compagnia dei Ponti e delle Strade
│     strade, ponti e rotte commerciali
├── Compagnia delle Bestie da Sella
│     cavalcature, animali da soma, trasporti
├── Arte dei Tavolieri
│     locande, taverne, vitto e alloggio
└── Mano dei Campi
      fattorie, rifornimenti alimentari, produzione rurale
```

---

### Albero IV — La Tavola Senza Nome
*Crimine organizzato, contrabbando e condotte illegali. Nessun figlio diretto. Non subordinata a nessuno, ma parassita degli altri tre alberi.*

```
Tavola Senza Nome  (autonomia illegale, nessun figlio diretto)
```

Può **infiltrare**: Corporazione delle Spezierie, Banco delle Tre Monete, Arte dei Tavolieri,
Compagnia dei Corrieri di Sigillo, Fratellanza del Mantello Grigio.

Nemici aperti: Milizia delle Campane, Ordine dei Sigillatori, Cattedra del Canone.

---

### Dipendenze trasversali (funzionali, non gerarchiche)

Queste relazioni non creano propagazione gerarchica ma influenzano la matrice inter-fazione
e danno contesto narrativo e meccanico.

| Da | A | Tipo | Significato in gioco |
|----|---|------|----------------------|
| Corporazione Camere | Cattedra | Riconoscimento legale | Le Camere operano autonomamente ma devono la legittimità alla Cattedra |
| Corporazione Spezierie | Cattedra | Legittimità commerciale | La Cattedra certifica pesi, sigilli e risolve dispute |
| Ordine Sigillatori | Corporazione Camere | Validazione contratti | Le condotte importanti devono essere sigillate |
| Collegio Maestri | Corporazione Camere | Certificazione classi | Il Collegio certifica istruttori, cambi classe e licenze formative dei Condottieri |
| Milizia | Corporazione Camere | Confine giurisdizionale | La Milizia gestisce il crimine urbano, le Camere gestiscono mostri e dungeon |
| Collegio Cartografi | Compagnia Ponti | Scambio dati percorsi | Le mappe dei Cartografi alimentano i rilievi stradali |
| Compagnia Ponti | Corporazione Camere | Infrastruttura | Le Camere dipendono dalle strade per muovere condottieri e rifornimenti |
| Compagnia Bestie | Corporazione Camere | Monture e trasporti | Fornisce cavalcature e animali da soma alle spedizioni |
| Arte Tavolieri | Corporazione Camere | Rete di sosta | Locande e taverne sono punti naturali di sosta, informazione e reclutamento |
| Congregazione Officine | Corporazione Camere | Convenzione medica | Cura i condottieri feriti a tariffe convenzionate; i debiti sanitari sono frequenti |
| Sorelle Sale | Corporazione Camere | Recupero sul campo | Intervengono su feriti, ricoveri poveri e recuperi dopo missioni fallite |
| Arte Ferri | Corporazione Camere | Equipaggiamento | Armi, armature, riparazioni e attrezzi da spedizione |
| Banco Tre Monete | Corporazione Camere | Finanza | Finanzia equipaggiamento, assicurazioni, pegni e debiti dei condottieri |
| Mano dei Campi | Corporazione Camere | Segnalazioni minacce | Spesso i primi a segnalare mostri, razzie e tane in zona rurale |
| Cacciatori Rogna | Mano dei Campi | Disinfestazione rurale | Lavorano principalmente per fattorie e comunità contadine |
| Corrieri Sigillo | Corporazione Camere | Recapito documenti | Trasportano condotte, ordini, notifiche e documenti tra sedi locali |
| Tavola Senza Nome | Corporazione Spezierie | Mercato nero | Ricetta merci rubate, loot non dichiarato, sostanze proibite |
| Tavola Senza Nome | Corporazione Camere | Condotte illegali | Offre incarichi che le Camere non possono accettare ufficialmente |
| Tavola Senza Nome | Milizia Campane | Conflitto | La Milizia è il principale ostacolo urbano alla Tavola |

---

### Le Signorie (entità politiche parallele)

Le 10 Signorie non appartengono ad alcun albero delle Corporazioni. Controllano territori,
hanno guardie proprie e relazioni diplomatiche sia tra loro che con le Corporazioni.
I villaggi appartengono quasi sempre a una Signoria.

Si organizzano in **tre blocchi clientelari** guidati dalle tre Signorie principali,
più una Signoria contesa e indipendente.

---

#### Blocco Canonico-Agrario — *Almerici* (legittimista, ecclesiastico, conservatore)

**Signoria degli Almerici** `signoria_almerici` — Signoria principale. Hanno generato
3 Primi Canonici e trattano la Cattedra come una seconda corte di famiglia. Il loro
potere è antico, devoto e quasi ereditario: per secoli hanno offerto terre, scuole e
difesa militare alla Cattedra in cambio di influenza religiosa crescente. Sono rispettati,
temuti e — in privato — profondamente sospettati di volere la Cattedra come ufficio di
famiglia. Relazione con la Cattedra: fortissima e possessiva.

- **Signoria dei Bellandi** `signoria_bellandi` *(cliente — alimentare/religiosa)*
  Controllano terre fertili, granai e monasteri rurali; sono il braccio agricolo degli
  Almerici e il serbatoio alimentare di molte città canoniche. Devono agli Almerici la
  propria legittimità ecclesiastica. Relazione con la Cattedra: devota per convenienza.

- **Signoria dei Ranucci** `signoria_ranucci` *(cliente — militare/canonica)*
  Piccola signoria militare di servizio: forniscono capitani, guardie e scorte agli
  Almerici e alle sedi locali della Cattedra. Molto fedeli ma troppo piccoli per decidere
  da soli — senza la protezione degli Almerici resterebbero irrilevanti. Relazione con
  la Cattedra: molto pia ma poco influente.

---

#### Blocco dei Banchi e delle Strade — *Valtieri* (mercantile, finanziario, diplomatico)

**Signoria dei Valtieri** `signoria_valtieri` — Signoria principale. Sono saliti grazie
a commercio, credito, porti fluviali e matrimoni ben piazzati, non a devozione. Hanno
generato 1 Papa — per denaro, non per santità. Finanziano monasteri, ponti e cardinali
senza mai farlo gratis. Indispensabili ogni volta che la Cattedra ha bisogno di soldi,
ma troppo furbi per essere davvero amati. Relazione con la Cattedra: pragmatica e
negoziale; rischio che troppi debiti la rendano ricattabile.

- **Signoria dei Doraldi** `signoria_doraldi` *(cliente — diplomatica/informativa)*
  Gestiscono archivi privati, corrieri, matrimoni e diplomazia minore. Sono gli occhi
  eleganti dei Valtieri nelle corti rivali. Donano molto alla Cattedra ma controllano
  informazioni meglio di quanto ammettano. Relazione con la Cattedra: comoda e servile
  in apparenza; sanno troppe cose di troppa gente.

- **Signoria dei Valdameri** `signoria_valdameri` *(cliente — commerciale/logistica)*
  Cresciuti su dazi, traghetti, fiere e mercati di confine. Rispettano il Canone quando
  conviene e lo aggirano quando conviene di più. Legati ai Valtieri da prestiti e rotte,
  ma cambierebbero padrone se il guadagno fosse abbastanza alto. Relazione con la Cattedra:
  opportunista; dove passano merci non dichiarate, spesso passano anche eresie.

---

#### Blocco delle Rocche di Frontiera — *Malcorvi* (militare, autonomista, anti-centralista)

**Signoria dei Malcorvi** `signoria_malcorvi` — Signoria principale. Non hanno mai
generato un Papa e non gliene importa. Sono diventati indispensabili combattendo guerre
di confine, mostri organizzati e incursioni da terre selvagge. Difendono le frontiere
meglio di chiunque ma tollerano male prediche, tasse e ispettori canonici. La Cattedra
li rispetta, li ha bisogno e — in privato — li teme. Relazione con la Cattedra: tesa
e rispettosa solo in pubblico; se si ribellassero, la Cattedra perderebbe gran parte
della sicurezza di frontiera.

- **Signoria dei Montelupi** `signoria_montelupi` *(cliente — montana/mineraria)*
  Presidiano passi montani, miniere e fortezze di quota. Riconoscono i Malcorvi come
  protettori ma mantengono forte orgoglio locale e cultura montana propria. Pagano le
  decime e rispettano i riti, ma proteggono prima le loro montagne. Relazione con la
  Cattedra: fredda ma corretta; la Cattedra li capisce poco e li controlla ancora meno.

- **Signoria dei Castrevani** `signoria_castrevani` *(cliente — militare/archeologica)*
  Controllano castelli, rovine antiche e strade militari dimenticate. Sono clienti dei
  Malcorvi in cambio di protezione contro mostri, banditi e curiosità canoniche — perché
  hanno troppe rovine nei loro territori e troppa poca voglia di farle catalogare.
  Relazione con la Cattedra: diffidente e opaca; le rovine potrebbero contenere qualcosa
  che la Cattedra vorrebbe sigillare.

---

#### Signoria contesa — *Guidalotti*

**Signoria dei Guidalotti** `signoria_guidalotti` — Non appartengono a nessun blocco.
Hanno fondato accademie, biblioteche e scuole d'arme, e hanno generato 1 Papa riformatore.
La loro ossessione per l'educazione autonoma li rende preziosi e pericolosi: la Cattedra
li sospetta di formare classi e idee non allineate al Canone, gli Almerici vorrebbero
riportarli sotto controllo ecclesiastico, i Valtieri li finanziano in silenzio per
guadagnare influenza senza sembrare padroni, i Malcorvi li apprezzano come istruttori
ma non vogliono filosofi nelle fortezze di frontiera. Tutti li vogliono, nessuno li possiede.
Relazione con la Cattedra: ambigua e alta; troppo utili per essere eliminati,
troppo indipendenti per essere fidati.

---

#### Relazioni tra Signorie

| Coppia | Tipo | Stato | Sintesi |
|--------|------|-------|---------|
| Almerici ↔ Valtieri | Rivalità cortese | Fredda | Gli Almerici li vedono come mercanti arricchiti; i Valtieri vedono gli Almerici come nobili che scambiano devozione per diritto naturale al comando |
| Almerici ↔ Malcorvi | Diffidenza strategica | Tesa | Gli Almerici rispettano la forza dei Malcorvi ma temono la loro autonomia militare e la loro scarsa obbedienza alla Cattedra |
| Valtieri ↔ Malcorvi | Accordo di necessità | Pragmatica | I Valtieri finanziano strade verso le frontiere; i Malcorvi garantiscono che non vengano divorate da mostri o briganti |
| Bellandi ↔ Valdameri | Conflitto economico | Ricorrente | I Bellandi producono grano, i Valdameri controllano mercati e dazi — litigano ogni volta che il prezzo del pane sale |
| Ranucci ↔ Montelupi | Rivalità militare | Orgogliosa | I Ranucci si considerano soldati disciplinati; i Montelupi li giudicano soldatini da parata incapaci di sopravvivere in montagna |
| Doraldi ↔ Castrevani | Spionaggio e segreti | Pericolosa | I Doraldi cercano da anni di scoprire cosa i Castrevani custodiscano nelle loro rovine — e i Castrevani lo sanno |
| Guidalotti ↔ Almerici | Pressione ecclesiastica | Sospetta | Gli Almerici vorrebbero riportare le scuole Guidalotti sotto controllo canonico |
| Guidalotti ↔ Valtieri | Corteggiamento finanziario | Aperta | I Valtieri finanziano borse e biblioteche per guadagnare influenza senza sembrare padroni |
| Guidalotti ↔ Malcorvi | Neutralità armata | Prudente | I Malcorvi apprezzano gli istruttori ma non vogliono studenti o filosofi nelle fortezze |

---

### Fazioni nemiche (rep default -100)

| ID | Family corrispondente | Note |
|----|----------------------|------|
| `non_morti` | `undead` | Rep modificabile per classi come negromante |
| `demoni` | `demon` | |
| `bestie` | `beast` | Rep modificabile per classi come ranger, druido |
| `draghi` | `dragon` | |
| `fuorilegge` | `humanoid` (nemico) | Umanoidi ostili — rep più facile da modificare |
| `aberrazioni` | `aberration` | Entità cosmiche e anomalie |
| `costrutti` | `construct` | Costrutti animati (golem, gargoyle) — creati, non nati |

### Assegnazione fazione per nemico

| Nemico | Family | Fazione |
|--------|--------|---------|
| `bat` | beast | `bestie` |
| `rat` | beast | `bestie` |
| `spider` | beast | `bestie` |
| `goblin` | humanoid | `fuorilegge` |
| `kobold` | humanoid | `fuorilegge` |
| `bandit` | humanoid | `fuorilegge` |
| `giant_spider` | beast | `bestie` |
| `skeleton` | undead | `non_morti` |
| `slime` | aberration | `aberrazioni` |
| `zombie` | undead | `non_morti` |
| `dark_elf` | humanoid | `fuorilegge` |
| `ghoul` | undead | `non_morti` |
| `lizardman` | beast | `bestie` |
| `orc` | humanoid | `fuorilegge` |
| `troll` | beast | `bestie` |
| `gargoyle` | construct | `costrutti` |
| `ogre` | humanoid | `fuorilegge` |
| `vampire` | undead | `non_morti` |
| `werewolf` | beast | `bestie` |
| `witch` | humanoid | `fuorilegge` |
| `death_knight` | undead | `non_morti` |
| `demon` | demon | `demoni` |
| `dragon_whelp` | dragon | `draghi` |
| `golem` | construct | `costrutti` |
| `lich` | undead | `non_morti` |
| `ancient_dragon` | dragon | `draghi` |
| `archlich` | undead | `non_morti` |
| `chaos_knight` | demon | `demoni` |
| `fallen_angel` | demon | `demoni` |
| `void_stalker` | aberration | `aberrazioni` |

### Fazione natura (rep default 0)

Fazione distinta da `bestie`. Rappresenta il mondo naturale non ostile: animali comuni,
spiriti della foresta, fauna selvatica neutrale. Classi come ranger e druido interagiscono
con questa fazione più che con le corporazioni civili. La `bestie` copre le creature che
attaccano attivamente; la `natura` copre tutto il selvatico che semplicemente esiste.

| ID | Note |
|----|------|
| `natura` | Animali standard, fauna selvatica, spiriti naturali — rep 0 di default |

---

### Fazioni villaggio (pre-definite, mutabili da quest)

```jsonc
{
  "id": "villaggio_nord",
  "name": "Abitanti del Villaggio del Nord",
  "type": "village",
  "signoria": "almerici",
  "corporazioni_presenti": ["mano_campi", "milizia_campane", "sorelle_sale"],
  "default_rep": 0
}
```

---

## Appartenenza alle fazioni — Joinabili vs. Supporter

### Due livelli di appartenenza

**Supporter** — disponibile per quasi tutte le fazioni (esclusa `tavola_senza_nome`).
Non richiede quest di ingresso: basta raggiungere rep ≥ +50. Dà accesso a servizi
preferenziali ma nessun rango, nessuna passiva esclusiva, nessun avanzamento formale.

**Membro** — disponibile solo per le 7 fazioni joinabili. Richiede una quest di ingresso,
garantisce una passiva permanente e sblocca un sistema di ranghi interno.

---

### Fazioni con sistema di ranghi (joinabili)

Il sistema di ranghi è da definire nel dettaglio (numero di gradi, requisiti di avanzamento,
benefici per grado). Struttura generica proposta: 3–5 ranghi per fazione, avanzamento
tramite quest o soglie di rep. Di seguito: fazione, requisito di ingresso (bozza), e
passiva garantita all'ingresso.

---

**`corporazione_camere`** — *Obbligatoria all'inizio del gioco*
> Quest di ingresso: registrazione del primo contratto (tutorial)
> **Passiva — Patente di Condotta**: sblocca le quest ufficiali (contratti firmati);
> accesso agli archivi della sede locale (mostra il livello raccomandato e i pericoli noti
> di dungeon già registrati dalla Corporazione); bonus XP del 10% su contratti completati
> nei tempi concordati.

---

**`cacciatori_rogna`** — *Tier C, albero Corporazione Camere*
> Quest di ingresso: eliminazione di una prima infestazione verificata con referto scritto
> **Passiva — Bestiari della Rogna**: +15% danno contro mostri di Tier 1–2; al primo
> incontro con un nemico già affrontato in precedenza, mostra automaticamente HP attuali,
> ATK e DEF (come se fosse già identificato).

| Grado | Ruolo |
|-------|-------|
| 1 | Battitore di Rogna |
| 2 | Stanatore |
| 3 | Purgatore di Tane |
| 4 | Bestiario Giurato |
| 5 | Maestro di Disinfestazione |
| 6 | Capocaccia della Rogna |

---

**`collegio_cartografi`** — *Tier B, albero Corporazione Camere*
> Quest di ingresso: consegna di una mappa rilevata personalmente di un dungeon inesplorato
> **Passiva — Senso Cartografico**: raggio FOV aumentato di 1 tile; i dungeon già esplorati
> in run precedenti conservano la mappa (no fog of war sulle sezioni già viste, anche dopo
> la morte se non è permadeath).

| Grado | Ruolo |
|-------|-------|
| 1 | Rilevatore Novizio |
| 2 | Misuratore di Sale |
| 3 | Cartografo di Sottosuolo |
| 4 | Tracciatore di Rovine |
| 5 | Maestro delle Mappe Chiuse |
| 6 | Primo Cartografo di Camera |

---

**`compagnia_ponti`** — *Tier B, albero Corporazione Spezierie*
> Quest di ingresso: scorta a un ingegnere della Compagnia durante un sopralluogo di strada
> **Passiva — Diritto di Strada**: velocità di movimento +1 su strade e sentieri
> nell'overworld; accesso a scorciatoie segnalate solo sui registri della Compagnia;
> pedaggi e traghetti gestiti dalla Compagnia costano il 50% in meno.

| Grado | Ruolo |
|-------|-------|
| 1 | Guardastrada |
| 2 | Misuratore di Passo |
| 3 | Custode di Ponte |
| 4 | Sovrintendente di Tratta |
| 5 | Maestro delle Vie |
| 6 | Capitano delle Strade |

---

**`corrieri_sigillo`** — *Tier C, albero Cattedra del Canone*
> Quest di ingresso: consegna di un dispaccio urgente entro un tempo limite
> **Passiva — Portatore di Sigillo**: le quest di consegna danno +25% ricompensa;
> ogni volta che si entra in una nuova città, c'è una probabilità di ricevere un contratto
> passivo di consegna (missione secondaria automatica); accesso anticipato a voci di
> corridoio su eventi del mondo (news system, da sviluppare).

| Grado | Ruolo |
|-------|-------|
| 1 | Staffetta di Sigillo |
| 2 | Portalettere Giurato |
| 3 | Corriere di Dispaccio |
| 4 | Messo delle Città |
| 5 | Custode dei Plichi Chiusi |
| 6 | Maestro dei Sigilli Vianti |

---

**`congregazione_officine`** — *Tier B, albero Cattedra del Canone*
> Quest di ingresso: assistenza a un'operazione chirurgica sotto supervisione di un Maestro
> **Passiva — Arte della Guarigione**: sconto del 25% su pozioni e cure da NPC delle
> Officine e delle Sorelle del Sale; rigenerazione HP fuori combattimento accelerata
> (+1 HP ogni 2 turni di riposo invece di ogni 3).

| Grado | Ruolo |
|-------|-------|
| 1 | Assistente di Banco |
| 2 | Cerusico Novizio |
| 3 | Curatore di Sala |
| 4 | Maestro di Fasciatura |
| 5 | Chirurgo di Congregazione |
| 6 | Priore delle Officine |

---

**`tavola_senza_nome`** — *Nessun supporter possibile — solo membro o nemico*
> Quest di ingresso: completare un incarico "non ufficiale" senza lasciare tracce
> **Passiva — Rete Oscura**: accesso a venditori del mercato nero (oggetti rari senza
> restrizioni di livello o licenza); pagando una somma, si può ridurre una taglia attiva
> di un valore fisso.
> **Nota join**: nessuna penalità rep automatica al join — la Tavola è segreta.
> La rep con `milizia_campane` e `ordine_sigillatori` cala solo se si viene scoperti
> durante un crimine testimoniato (gestito dal crime system).

| Grado | Ruolo |
|-------|-------|
| 1 | Mano Piccola |
| 2 | Ombra di Banco |
| 3 | Tagliaborse di Tavola |
| 4 | Ricettatore Giurato |
| 5 | Mediatore Senza Nome |
| 6 | Maestro della Tavola |

---

## Appartenenza multi-fazione degli NPC

Ogni NPC appartiene a **una o più fazioni**, con valori di rep verso il player calcolati
separatamente per ciascuna. Il comportamento dell'NPC è determinato dalla **fazione primaria**
(la prima nell'array); le fazioni secondarie influenzano tono del dialogo, prezzi e quest
disponibili, ma non la reazione di base.

Esempio — un fabbro in un villaggio degli Almerici:
```jsonc
{
  "factions": [
    { "id": "arte_ferri",       "role": "primary"   },
    { "id": "signoria_almerici","role": "secondary" },
    { "id": "cittadini_villaggio_nord", "role": "secondary" }
  ]
}
```
- Se il player è ostile con `arte_ferri` → il fabbro rifiuta di parlare
- Se il player è ostile con `signoria_almerici` ma non con `arte_ferri` → il fabbro vende
  ma il tono è freddo e non offre quest della signoria

---

## Implicazioni meccaniche dal contesto narrativo

Il testo narrativo del mondo suggerisce alcune implicazioni di gioco non ancora codificate:

- **La Cattedra come stato amministrativo**: oltre alla religione, controlla nascite, morti,
  licenze, contratti e scuole. In gioco: i cambi di classe richiedono certificazione del
  `collegio_maestri`; certe quest richiedono sigillo dell'`ordine_sigillatori` per essere
  legalmente valide; l'escomunica dalla Cattedra è la penalità di rep più grave possibile
  (reset a -100 con tutte le fazioni del suo albero).

- **Il ruolo dei condottieri**: il player è un condottiero — una professione ufficialmente
  licenziata dalle Camere. Questo giustifica la quest obbligatoria di ingresso alla
  `corporazione_camere` e spiega perché certi dungeon richiedono una "condotta" ufficiale
  per essere esplorati legalmente (con relative quest reward aggiuntive).

- **Le Corporazioni come tessuto del mondo**: ogni corporazione è fisicamente presente
  nei villaggi attraverso i propri NPC (fabbri, locandieri, corrieri, medici). La scelta
  di quali corporazioni ci sono in un villaggio (CityBuilder) determina quali passivi e
  servizi il player può accedere lì, e quali NPC reagiscono alla sua rep.

- **I Guidalotti come chiave dell'avanzamento**: la loro indipendenza dal sistema è
  meccanicamente utile — sono un'opzione sempre disponibile per classi e conoscenze,
  indipendentemente dalla rep con i blocchi principali.

---

## Schema JSON fazione

```jsonc
{
  "id": "milizia_campane",
  "name": "Milizia delle Campane",
  "tier": "B",
  "tree": "cattedra_canone",
  "parent": "cattedra_canone",
  "joinable": false,
  "supporter_eligible": true,
  "default_rep": 0
}
```

```jsonc
{
  "id": "cacciatori_rogna",
  "name": "Cacciatori di Rogna",
  "tier": "C",
  "tree": "corporazione_camere",
  "parent": "corporazione_camere",
  "joinable": true,
  "supporter_eligible": true,
  "default_rep": 0,
  "join_passive": "bestiari_della_rogna",
  "ranks": [],
  "recognition_item_id": null,
  "recognition_slot": null,
  "tax_system": { "status": "planned" },
  "quirk": {
    "id": "minor_infestation_jobs",
    "status": "planned",
    "implementation_phase": "phase_6a"
  }
}
```

## Schema JSON relazioni globali (`data/factions/relations.json`)

```jsonc
{
  "milizia_campane": {
    "tavola_senza_nome": -80,
    "fuorilegge": -100,
    "corporazione_camere": 40
  }
}
```

La matrice non è simmetrica. I valori non specificati valgono 0 (neutre).
Le relazioni ovvie dai cross-dependencies (Tavola vs Milizia, Valtieri vs Almerici, ecc.)
vengono pre-compilate a partire dalla struttura gerarchica; quelle non ovvie vanno definite
manualmente nella matrice.

---

## Decisioni aggiuntive

### Appartenenza e mondo
- Essere membro di una fazione cambia dialoghi, luoghi accessibili, quest disponibili e tasse
- Ogni fazione joinabile ha un **quirk unico** che trasforma il mondo — da definire fazione per fazione
- I quirk vanno implementati come sistemi specifici estendibili, non come semplici flag
- Dettaglio per ogni fazione joinabile:

| Fazione | Quirk (trasformazione del mondo) |
|---------|----------------------------------|
| `corporazione_camere` | Nessuna trasformazione speciale — fornisce quest, info su dungeon e servizi |
| `cacciatori_rogna` | La gente affida piccole missioni di "ripulita" di mostriciattoli; sblocca oggetti specifici nel tempo |
| `collegio_cartografi` | Accesso all'acquisto di mappe; possibilità di scrivere mappe di dungeon visitati e venderle alla `corporazione_camere` |
| `compagnia_ponti` | Si possono costruire stazioni di posta nell'overworld (ogni ~30 tiles tra due destinazioni) per recuperare risorse (cibo, acqua, ecc.) durante il viaggio |
| `corrieri_sigillo` | Ricevi una mount di qualità; puoi viaggiare con le carovane dei corrieri (più sicure, risorse di viaggio molto più economiche) |
| `congregazione_officine` | Possibilità di aprire un banco di cura o ambulatorio convenzionato (non un negozio generico — quello appartiene alle Spezierie/Tavolieri) |
| `tavola_senza_nome` | Accesso a meccaniche di omicidio, furto e minaccia normalmente non disponibili; accesso alle safe house; possibilità di ridurre la propria taglia recuperando rep con le guardie |

### Segni di riconoscimento
- I segni di riconoscimento devono essere **equipaggiati** per essere riconosciuti dagli NPC
- Non equipaggiato = identità di fazione invisibile
- Occupano uno **slot equipment esistente** (non uno slot dedicato) — quale slot, da definire per fazione

### Tasse
- Le tasse sono dovute solo alle fazioni di cui si è membri formali
- La struttura è **diversa per ogni fazione** — va implementata fazione per fazione
- Architetturalmente: campo `tax_system` nel JSON della fazione + hook nel loop di gioco da prevedere
- Escalation comune per mancato pagamento: **prima volta → limitazioni**; **seconda volta → espulsione**

### Ordine pubblico e giurisdizione
- La `milizia_campane` è l'unica forza di ordine pubblico ufficiale
- Le signorie possono avere milizie proprie che funzionano come **gruppi privati di sicurezza**,
  senza autorità giuridica formale sul crimine civile
- Dettagli dell'interazione con il crime system: nel piano crime system

### Visibilità dell'appartenenza
- Gli NPC non sanno a quale fazione appartieni salvo segno di riconoscimento equipaggiato
  o altri motivi espliciti (es. NPC testimone di un evento)
- Crimini testimoniati vs. non testimoniati: nel piano crime system

### Rep da azioni ambientali
- La rep cambia con azioni in gioco (uccidere nemici, usare certi oggetti, entrare in certi luoghi)
- I trigger specifici vanno definiti fazione per fazione in fase di implementazione

### Simulazione politica
- Le dinamiche tra fazioni e signorie (guerre, alleanze, decadenze) sono **narrative**,
  non simulate programmaticamente. Possono essere esito di quest o eventi del mondo.

---

## Decisioni aggiuntive (terza tornata)

### Stazioni di posta (`compagnia_ponti`)
- Permanenti nel mondo (persistono tra sessioni e tra personaggi diversi)
- Utilizzate anche dagli NPC
- Costruibili ogni ~30 tiles tra una destinazione e l'altra

### Carovane (`corrieri_sigillo`)
- Si prenotano in anticipo presso una sede della `confraternita_strada`
- Meccanica di viaggio da definire nel dettaglio

### Meccaniche crimini (`tavola_senza_nome`)
- Omicidio, furto, minaccia sono sistemi separati — non menu di interazione standard
- Architettura da predisporre ora; implementazione con il crime system

### Oggetti speciali (`cacciatori_rogna`)
- Gli oggetti si ottengono come **ricompense** delle missioni di "ripulita"

### Mappe (`collegio_cartografi`)
- Le mappe vendute diventano **permanentemente disponibili** per quel mondo,
  per tutti i personaggi (effetto world-persistent, non per-personaggio)

---

## Domande ancora aperte

### 1. Matrice relazioni — valori numerici
Da definire in fase di implementazione e bilanciamento.

### 2. Ranghi `corporazione_camere`
Nomi e struttura dei gradi per la gilda degli avventurieri (non ancora forniti).

### 3. Segni di riconoscimento — quale slot per ogni fazione
Quale slot equipment esistente serve come segno per ogni fazione joinabile.

Suggerimento provvisorio (da confermare):
| Fazione | Slot suggerito |
|---------|---------------|
| `corporazione_camere` | amuleto / medaglione |
| `cacciatori_rogna` | cintura / trofeo |
| `collegio_cartografi` | mantello / custodia mappe |
| `compagnia_ponti` | mantello / spilla |
| `corrieri_sigillo` | anello / borsa sigillata |
| `congregazione_officine` | fascia / medaglione |
| `tavola_senza_nome` | nessun segno pubblico — solo token nascosto, rilevabile solo da NPC specifici |

### 4. Trigger rep ambientali per fazione
Quali azioni modificano la rep con ogni fazione. Da definire fazione per fazione.

---

## Piano di implementazione

> **Regola trasversale — localizzazione**: ogni stringa visibile all'utente prodotta dal sistema
> fazioni deve passare per `LocaleManager.t(key)` o `t_or(key, fallback)`. Non scrivere mai
> stringhe raw nelle UI, notifiche o dialoghi. Le chiavi fazioni vanno in
> `locales/strings_factions.csv`; UI generiche in `strings_ui.csv`; notifiche in
> `strings_notifications.csv`. Le chiavi segono `PREFIX_ID_UPPER_SUFFIX`.
>
> **Regola trasversale — feature status**: tutte le fazioni vengono registrate nella Fase 1 con
> i campi `quirk.status` e `tax_system.status` impostati a `"planned"`. Il codice non deve mai
> assumere che un quirk o una tax_system siano implementati — verificare sempre lo status.
>
> **Regola trasversale — GameState vs WorldState**: la reputazione e la membership sono
> per-personaggio (GameState). Mappe depositate, stazioni costruite, safe house, negozi aperti
> e cambiamenti ai villaggi sono world-persistent (WorldState). Decidere caso per caso.

---

### FASE 1 — Database completo di tutte le fazioni

**Obiettivo**: registrare TUTTE le fazioni prima di implementare qualsiasi feature. Ogni JSON deve
già avere `quirk.status` e `tax_system.status` impostati a `"planned"` dove non implementato.

#### 1.1 JSON fazioni civili (21 file)
- [x] `data/factions/tier_s/cattedra_canone.json`
- [x] `data/factions/tier_a/corporazione_camere.json`
- [x] `data/factions/tier_a/corporazione_spezierie.json`
- [x] `data/factions/tier_a/collegio_maestri.json`
- [x] `data/factions/tier_a/ordine_sigillatori.json`
- [x] `data/factions/tier_b/milizia_campane.json`
- [x] `data/factions/tier_b/banco_tre_monete.json`
- [x] `data/factions/tier_b/arte_ferri.json`
- [x] `data/factions/tier_b/collegio_cartografi.json`
- [x] `data/factions/tier_b/compagnia_ponti.json`
- [x] `data/factions/tier_b/compagnia_bestie.json`
- [x] `data/factions/tier_b/arte_tavolieri.json`
- [x] `data/factions/tier_b/fratellanza_mantello.json`
- [x] `data/factions/tier_b/congregazione_officine.json`
- [x] `data/factions/tier_b/confraternita_strada.json`
- [x] `data/factions/tier_c/sorelle_sale.json`
- [x] `data/factions/tier_c/becchini_canone.json`
- [x] `data/factions/tier_c/mano_campi.json`
- [x] `data/factions/tier_c/cacciatori_rogna.json`
- [x] `data/factions/tier_c/corrieri_sigillo.json`
- [x] `data/factions/tier_c/tavola_senza_nome.json`

#### 1.2 JSON signorie (filename = ID, 10 file)
- [x] `data/factions/signorie/signoria_almerici.json`
- [x] `data/factions/signorie/signoria_valtieri.json`
- [x] `data/factions/signorie/signoria_malcorvi.json`
- [x] `data/factions/signorie/signoria_bellandi.json`
- [x] `data/factions/signorie/signoria_guidalotti.json`
- [x] `data/factions/signorie/signoria_montelupi.json`
- [x] `data/factions/signorie/signoria_castrevani.json`
- [x] `data/factions/signorie/signoria_doraldi.json`
- [x] `data/factions/signorie/signoria_ranucci.json`
- [x] `data/factions/signorie/signoria_valdameri.json`

#### 1.3 JSON fazioni nemiche e natura (8 file)
- [x] `data/factions/nemici/non_morti.json` (default_rep: -100)
- [x] `data/factions/nemici/demoni.json` (default_rep: -100)
- [x] `data/factions/nemici/bestie.json` (default_rep: -100)
- [x] `data/factions/nemici/draghi.json` (default_rep: -100)
- [x] `data/factions/nemici/fuorilegge.json` (default_rep: -100)
- [x] `data/factions/nemici/aberrazioni.json` (default_rep: -100)
- [x] `data/factions/nemici/costrutti.json` (default_rep: -100)
- [x] `data/factions/natura/natura.json` (default_rep: 0)

#### 1.4 Matrice relazioni globale
- [x] Creare `data/factions/relations.json`
- [x] Popolare le relazioni ovvie da cross-dependencies (Tavola vs Milizia, Almerici vs Valtieri, ecc.)
- [ ] Completare i valori numerici rimanenti durante il bilanciamento (Fase 16)

---

### FASE 2 — Registry, GameState e Save

**Obiettivo**: infrastruttura core divisa in moduli separati — non un unico autoload mostruoso.

#### 2.1 `FactionRegistry` — dati statici (autoload)
- [x] Creare `scripts/core/FactionRegistry.gd`
- [x] Implementare caricamento ricorsivo di tutti i JSON da `data/factions/`
- [x] Implementare `get_faction(id) -> Dictionary`
- [x] Implementare `get_all_factions() -> Array`
- [x] Implementare `get_factions_by_tree(tree_id) -> Array`
- [x] Implementare `get_factions_by_tier(tier) -> Array`
- [x] Implementare `get_relations() -> Dictionary`
- [x] Implementare `are_enemies(fac_a, fac_b) -> bool`
- [x] Implementare `get_children(parent_id)` e `get_siblings(faction_id)` (necessari per propagazione)
- [x] Registrare in `project.godot`

#### 2.2 `FactionReputation` — gestione rep (autoload)
- [x] Creare `scripts/core/FactionReputation.gd`
- [x] Implementare `get_rep(faction_id) -> int` — fallback lazy a `default_rep` JSON se non in GameState
- [x] Implementare `set_rep(faction_id, value)` — clampato ±100, emette `faction_rep_changed`
- [x] Implementare `add_rep(faction_id, delta, reason = "", propagate = true)`
  - Delta diretti applicati sempre
  - Delta propagati calcolati in lista separata, mai in cascata
  - Propagazione gerarchica: parent +10% del delta (se `abs >= 1`)
  - Propagazione laterale: siblings +30% del delta (se `abs >= 1`)
  - Delta propagati non generano altra propagazione
- [x] Implementare `get_state_id(faction_id) -> String`
  (`"enemy_sworn"` ≤-75 | `"hostile"` ≤-30 | `"neutral"` <30 | `"friendly"` <50 | `"allied"` <75 | `"trusted"` ≥75)
- [x] Implementare `initialize_for_new_game()`
- [ ] Propagazione avanzata (inter-signorie, blocchi) → Fase 8
- [x] Registrare in `project.godot`

#### 2.3 `FactionMembership` — membership e ranghi (autoload)
- [x] Creare `scripts/core/FactionMembership.gd`
- [x] Implementare `join_faction(faction_id)` — aggiunge a GameState, emette `faction_joined`
- [x] Implementare `leave_faction(faction_id)` — penalità -20 rep (no propagate), emette `faction_left`
- [x] Implementare `get_rank(faction_id) -> int` — -1 se non membro
- [x] Implementare `advance_rank(faction_id)`
- [x] Implementare `is_member(faction_id) -> bool`
- [x] Implementare `is_supporter(faction_id) -> bool` — derivato (rep ≥ 50 && supporter_eligible && !is_member), non salvato
- [x] Implementare `initialize_for_new_game()`
- [x] Registrare in `project.godot`

#### 2.4 `FactionDisplay` — helper localizzati (autoload)
- [x] Creare `scripts/core/FactionDisplay.gd`
- [x] Implementare `get_display_name` — `t_or("FACTION_{ID}_NAME", raw_json_name)`
- [x] Implementare `get_display_desc` — `t_or("FACTION_{ID}_DESC", "")`
- [x] Implementare `get_display_state` — `t_or("FACTION_STATE_{STATE}", state_id)`
- [x] Implementare `get_display_rank(faction_id, rank_n)`
- [x] Implementare `get_display_passive_name` / `get_display_passive_desc`
- [x] Implementare `get_display_crime(crime_type)`
- [x] Registrare in `project.godot`

#### 2.5 `FactionEffects` — passive e quirk (stub)
- [x] Creare `scripts/core/FactionEffects.gd` — stub completo con tutti i metodi
- [x] Registrare in `project.godot`
- [ ] Implementazione reale per-fazione → Fase 5/6

#### 2.6 `FactionEconomy` — prezzi e tasse (stub)
- [x] Creare `scripts/core/FactionEconomy.gd` — stub con `get_price_multiplier`, `calculate_tax_due`, `process_tax_payment`
- [x] Registrare in `project.godot`
- [ ] Implementazione reale → Fase 12

#### 2.7 `GameState` — aggiornamento per reputazioni
- [x] Aggiungere `character_faction_rep: Dictionary` (faction_id → int)
- [x] Aggiungere `character_faction_membership: Dictionary` (faction_id → {rank, join_date})
- [x] `get_rep()` fa fallback lazy a `default_rep` JSON — nessuna init esplicita richiesta a new game

#### 2.8 `WorldState` — nuovo autoload per dati world-persistent
- [x] Creare `scripts/core/WorldState.gd`
- [x] Aggiungere `faction_world_flags`, `registered_dungeon_maps`, `built_post_stations`,
  `discovered_safe_houses`, `opened_player_services`, `village_faction_changes` (placeholder)
- [x] Implementare `serialize()` / `deserialize()` / `reset()`
- [x] Registrare in `project.godot`

#### 2.9 `SaveManager` / `WorldSaveManager` — serializzazione
- [x] `SaveManager`: serializza/deserializza `faction_rep` e `faction_membership` nel save personaggio
- [x] `WorldSaveManager`: include `WorldState.serialize()` in `world.json`; chiama `WorldState.deserialize()` al load; `WorldState.reset()` se campo assente
- [x] EventBus: aggiunti segnali `faction_rep_changed`, `faction_joined`, `faction_left`
- [ ] Aggiornare `.claude/codebase_reference.md` → da fare a fine fase 3

---

### FASE 3 — Integrazione NPC e nemici

#### 3.1 Nemici — faction ID reali
- [x] Aggiunto campo `"faction_id"` a tutti e 30 i JSON nemici, dopo `"family"`
  - [x] `undead` → `non_morti` (skeleton, zombie, ghoul, vampire, death_knight, lich, archlich)
  - [x] `demon` → `demoni` (demon, chaos_knight, fallen_angel)
  - [x] `beast` → `bestie` (bat, rat, spider, giant_spider, lizardman, troll, werewolf)
  - [x] `dragon` → `draghi` (dragon_whelp, ancient_dragon)
  - [x] `aberration` → `aberrazioni` (slime, void_stalker)
  - [x] `construct` → `costrutti` (gargoyle, golem)
  - [x] `humanoid` (ostile) → `fuorilegge` (goblin, kobold, bandit, dark_elf, orc, ogre, witch)
- [x] Aggiornato `Enemy.gd`: `faction` letta da `EnemyRegistry.get_enemy_data().get("faction_id", "enemy")` — inline, nessuna variabile aggiuntiva
- [ ] Hook di rep su kill nemico → Fase 4 (combat hooks)
- [ ] `FactionRegistry.are_enemies()` usato in combat → Fase 4

#### 3.2 NPC — appartenenza multi-fazione
- [x] Aggiunti campi `primary_faction_id: String` e `secondary_faction_ids: Array[String]` a `NPC.gd`
- [x] `setup()` legge `faction_id` e `secondary_faction_ids` dal data dictionary
- [x] `faction` (Entity) impostata a `primary_faction_id` se presente, altrimenti `"neutral"`
- [ ] Schermata configurazione NPC nel CityBuilder → todo.md (fuori scope Fase 3)
- [ ] Comportamento su fazioni secondarie (prezzi, quest, tono) → Fase 4/5

#### 3.3 Chest e entità neutre
- [x] Verificato: `Chest.gd` e `Door.gd` non impostano `faction`, ereditano `"neutral"` da Entity — nessuna modifica necessaria
- [x] Aggiornato `.claude/codebase_reference.md` — nuovi autoload fazioni, schema `faction_id` nei JSON nemici, campi `character_faction_rep/membership` in GameState, separazione GameState/WorldState

---

### FASE 4 — Reputazione base e supporter

#### 4.1 Hook su kill e quest
- [x] Hook su kill in `Enemy._apply_kill_rep()` — legge `rep_on_kill` (delta diretto sulla fazione del nemico) e `rep_on_kill_targets: [{faction_id, amount}]` (effetti indiretti su altre fazioni) dal JSON nemico; entrambi opzionali, default 0/[]
  - Nota: hook in Enemy.gd (non CombatManager) — il kill è gestito in `die()`, CombatManager non conosce l'esito
- [x] Hook quest in `QuestManager._complete_quest()` — legge `rewards.faction_rep: [{faction_id, amount}]` e chiama `FactionReputation.add_rep()` per ogni entry
- [ ] Hook generico per "entra in location" (es. dungeon senza licenza) → da implementare quando esiste il sistema location-events

#### 4.2 Trigger rep per-fazione
- [ ] `milizia_campane` — crimini testimoniati, aiutare guardie; configurare `rep_on_kill_targets` su nemici `fuorilegge`
- [ ] `cattedra_canone` — uso magia proibita, offerte; dipende da sistema magia
- [ ] `corporazione_camere` — contratti completati/falliti; via `rewards.faction_rep` nelle quest
- [ ] `non_morti` / `bestie` — `rep_on_kill` negativo per classi speciali (negromante, ranger, druido) → da configurare in Fase 5/6 quando le classi vengono implementate
- [ ] Altre fazioni → al momento della loro implementazione

#### 4.3 Segnali e notifiche
- [x] EventBus: aggiunti `faction_state_changed(id, old, new)`, `faction_supporter_gained(id)`, `faction_supporter_lost(id)`
- [x] `FactionReputation.set_rep()`: rileva cambio stato con `_state_rank()` e cambio supporter; emette segnali e mostra `Notification.faction_state()` / `faction_supporter_gained()` / `faction_supporter_lost()`
- [x] `Notification.gd`: aggiunti `faction_state()`, `faction_supporter_gained()`, `faction_supporter_lost()` con fallback raw string via `t_or()`
- [x] Notifiche soppresse durante init/load — `initialize_for_new_game()` e `SaveManager` scrivono direttamente in `GameState.character_faction_rep` bypassando `set_rep()`
- [x] Aggiornare `.claude/codebase_reference.md` — fatto a fine fase

---

### FASE 5 — Membership base e `corporazione_camere`

#### 5.1 Architettura join/rank comune
- [x] Implementare `join_faction()` — aggiunge a `character_faction_membership`, chiama `FactionEffects.apply_join_passive()`
- [x] Implementare `leave_faction()` — chiama `FactionEffects.remove_join_passive()`, poi -20 rep senza propagazione
- [x] Implementare `advance_rank()` — avanza rank, richiama `apply_join_passive()` con nuovo rank
- [x] Implementare `FactionEffects.apply_join_passive()` — dispatch per faction_id + implementazione `patente_di_condotta`; `get_xp_multiplier(context)` esposto per LevelSystem
- [x] `FactionEffects.remove_join_passive()` — rimuove tutti i flag dalla fazione
- [x] `FactionEffects.has_active_passive(id)` — controlla flag `contract_access`
- [x] Implementare architettura segni di riconoscimento:
  - [x] `recognition_item_id` e `recognition_slot` in `corporazione_camere.json` (item: `patente_condotta`, slot: `neck`)
  - [x] Item JSON `data/items/factions/patente_condotta.json` — amuleto neck, no stats, `loot_weight:0`, `faction_sign:true`
  - [x] `FactionMembership.wears_recognition_sign(id)` — controlla `GameState.equipped[slot] == sign_id`; restituisce `true` se nessun segno richiesto
  - Nota: item segno per le fazioni Fase 6/7+ verranno creati quando la fazione viene implementata
- [x] `FactionMembership.reapply_all_passives()` — chiamata da `SaveManager` dopo load per ripristinare `faction_passive_flags`
- [x] `FactionMembership.initialize_for_new_game()` — resetta membership e `faction_passive_flags`; chiamata da `Main._reset_game_state()`
- [x] `FactionReputation.initialize_for_new_game()` — chiamata da `Main._reset_game_state()`
- [x] Implementare architettura tasse (stub):
  - [x] Campo `tax_system` già presente nei JSON joinabili (es. `{"status":"planned"}`)
  - [x] `FactionEconomy.on_rest()` — stub, implementazione reale in Fase 12
- [x] `GameState.faction_passive_flags: Dictionary` — flags derivati dalla membership, ricreati al load; non persiste nel save
- [x] `LevelSystem.add_xp(amount, context)` — accetta context opzionale; multiplier via `FactionEffects.get_xp_multiplier(context)`
- [x] `QuestManager._complete_quest()` — aggiunto reward `join_faction: String` e XP con context `"quest"`
- [x] `QuestManager.start_quest()` — se objectives vuoti, segna la quest ready/complete immediatamente

#### 5.2 `corporazione_camere` — obbligatoria, prima fazione completa
- [x] Quest tutorial `data/quests/quest_corporazione_registrazione.json` — no objectives, turn_in, premia `patente_condotta` + join + 10 rep + 50 xp
- [x] Passiva `patente_di_condotta` al join: flag `contract_access` + `dungeon_archive_access` in `GameState.faction_passive_flags`
- [x] `WorldState.dungeon_archive: Dictionary` — struttura dati per archivio dungeon (UI in Fase 15)
- [x] Bonus XP su contratti: Rank 2 → +10%, Rank 3 → +15%, Rank 4 → +20%, Rank 5 → +25% (via `FactionEffects.get_xp_multiplier("quest")`)
- [x] Rank 5+: flag `elite_contract_access` in `faction_passive_flags`
- [x] 6 ranghi definiti in `corporazione_camere.json`: Iscritto / Patentato / Condottiero / Condottiero Anziano / Referente di Condotta / Gran Condottiero
- [x] Segno di riconoscimento: `patente_condotta` (slot `neck`)
- [ ] UI archivio dungeon — Fase 15
- [ ] Tasse della Corporazione — Fase 12
- [x] Aggiornare `.claude/codebase_reference.md` — documentato

---

### FASE 6 — Fazioni joinabili: Cacciatori di Rogna come modello

**Obiettivo**: implementare una seconda fazione joinabile completa al 100%, che diventi il modello per tutte le successive.

#### 6.1 `cacciatori_rogna` — implementazione completa
- [x] Quest di ingresso `quest_cacciatori_ingresso.json` — kill 5 `bestia`, turn_in, premia `distintivo_cacciatore` + join + 15 rep Cacciatori + 5 rep Corporazione + 100 xp
- [x] Quest "ripulita" modello `quest_cacciatori_ripulita_1.json` — kill 8 `bestia`, turn_in, premia `trofeo_bestia` + 10 rep + 80 xp
- [x] Passiva scalabile `bestiari_della_rogna` in `FactionEffects`:
  - Rank 0-1: `rogna_monster_auto_id: true` (hook visuale futuro per identificazione mostri)
  - Rank 2: `rogna_dmg_bonus_pct: 10`, `rogna_dmg_max_tier: 1` (+10% danno vs tier 1)
  - Rank 3: `rogna_dmg_bonus_pct: 15`, `rogna_dmg_max_tier: 2` (+15% danno vs tier 1-2)
  - Rank 4: `rogna_dmg_bonus_pct: 20`, `rogna_dmg_max_tier: 2`, `rogna_improved_rewards: true`
  - Rank 5: `rogna_dmg_bonus_pct: 25`, `rogna_advanced_id: true`
- [x] `FactionEffects.get_attack_mult(defender)` — moltiplicatore ATK basato su `rogna_dmg_bonus_pct` e `rogna_dmg_max_tier`; legge `enemy_data_id` + `EnemyRegistry.tier`
- [x] Hook in `DamagePipeline` — applica `get_attack_mult()` a `attack_multiplier` quando player attacca
- [x] `rogna_improved_rewards` — hook in `Enemy._generate_loot()`: se flag attivo e `enemy.tier <= 2`, aggiunge `quality_bias_bonus: 1` al ctx
- [x] `LootResolver.resolve()` — legge `quality_bias_bonus` da ctx e lo somma a `quality_bias`
- [x] Item esclusivi: `data/items/factions/distintivo_cacciatore.json` (trinket, `faction_sign:true`) e `data/items/factions/trofeo_bestia.json` (trinket, `attack_bonus:+2`, non droppabile)
- [x] 6 ranghi in `cacciatori_rogna.json`: Apprendista Cacciatore / Cacciatore / Cacciatore Esperto / Cacciatore Veterano / Maestro Cacciatore / Gran Cacciatore
- [x] Segno di riconoscimento: `distintivo_cacciatore` (slot `trinket`)
- [ ] Quirk world-level `infestation_jobs` → Fase 10
- [ ] Tasse → Fase 12
- [x] Aggiornare `.claude/codebase_reference.md` — documentato

---

### FASE 7 — Fazioni joinabili rimanenti (una alla volta)

**Ordine consigliato** (dalla meno dipendente a sistemi esterni alla più dipendente):

#### 7.1 `collegio_cartografi` ✅
- [x] `collegio_cartografi.json` — 6 ranghi: Apprendista Cartografo/Cartografo/Cartografo Esperto/Maestro Cartografo/Primo Cartografo/Gran Cartografo; segno `borsa_mappe` (slot `cloak`)
- [x] `data/items/factions/borsa_mappe.json` — mantello, `faction_sign:true`
- [x] `quest_cartografi_ingresso.json` — kill 1 dungeon_boss + turn_in; premia borsa_mappe + join + rep
- [x] Passiva `senso_cartografico`: Rank 0→`carto_fov_bonus:1`; Rank 2→`carto_map_purchase`; Rank 3→`carto_map_sellable`; Rank 4→`carto_world_persistent`; Rank 5→`carto_advanced_maps`
- [ ] Hook FOV +1 — attende visibilty system (Fase 10)
- [ ] Tipi di mappa (personale/acquistata/registrata) — Fase 10
- [ ] Persistenza mappe depositate world-persistent — Fase 10
- [ ] Tasse → Fase 12

#### 7.2 `compagnia_ponti` ✅
- [x] `compagnia_ponti.json` — 6 ranghi: Associato/Guardiano di Strada/Guardiano Esperto/Ispettore Stradale/Ingegnere dei Ponti/Gran Maestro delle Strade; segno `spilla_strade` (slot `neck`)
- [x] `data/items/factions/spilla_strade.json` — amuleto neck, `faction_sign:true`
- [x] `quest_compagnia_ponti_ingresso.json` — 0 obiettivi, turn_in; premia spilla + join + rep
- [x] Passiva `diritto_di_strada`: Rank 0→`ponti_speed_bonus:1`+`ponti_toll_discount:50`; Rank 3→`ponti_shortcuts`; Rank 5→`ponti_new_roads`
- [ ] Hook overworld speed — attende sistema movimento overworld (Fase 10)
- [ ] Hook pedaggi/traghetti — FactionEconomy Fase 12
- [ ] Sistema stazioni di posta world-persistent — Fase 10
- [ ] Tasse → Fase 12

#### 7.3 `corrieri_sigillo` ✅
- [x] `corrieri_sigillo.json` — 6 ranghi: Staffetta/Corriere/Corriere Esperto/Primo Corriere/Corriere d'Élite/Gran Corriere di Sigillo; segno `anello_corrieri` (slot `ring_1`)
- [x] `data/items/factions/anello_corrieri.json` — anello ring_1, `faction_sign:true`
- [x] `quest_corrieri_ingresso.json` — 0 obiettivi, turn_in; premia anello + join + rep
- [x] Passiva `portatore_di_sigillo`: Rank 0→`corrieri_quest_gold_bonus:25`; Rank 2→`corrieri_passive_contracts`; Rank 4→`corrieri_mount`; Rank 5→`corrieri_world_events`
- [x] `FactionEffects.get_gold_multiplier(context)` — +25% oro su reward quest per membri corrieri
- [x] `QuestManager._complete_quest()` — join_faction eseguito PRIMA dei reward, oro con moltiplicatore via `get_gold_multiplier("quest")`
- [ ] Scoping a sole quest di consegna — attende quest type system
- [ ] Mount speciale — Fase 10
- [ ] Carovane (meccanica con confraternita_strada) — Fase 10
- [ ] Tasse → Fase 12

#### 7.4 `congregazione_officine` ✅
- [x] `congregazione_officine.json` — 6 ranghi: Assistente/Praticante/Officinale/Officinale Esperto/Maestro Officinale/Gran Maestro delle Officine; segno `fascia_officine` (slot `neck`)
- [x] `data/items/factions/fascia_officine.json` — amuleto neck, `faction_sign:true`
- [x] `quest_officine_ingresso.json` — 0 obiettivi, turn_in; premia fascia + join + rep
- [x] Passiva `arte_della_guarigione`: Rank 0→`officine_potion_discount:25`; Rank 2→`officine_hp_regen_bonus:1`; Rank 4→`officine_advanced_care`
- [ ] Hook sconto pozioni NPC — FactionEconomy Fase 12
- [ ] Hook HP regen accelerata — attende sistema regen in-game
- [ ] Quirk ambulatorio convenzionato — Fase 10
- [ ] Tasse → Fase 12

#### 7.5 `tavola_senza_nome` ✅
- [x] `tavola_senza_nome.json` — 6 ranghi: Contatto/Agente/Ombra/Ombra Esperta/Maestro dell'Ombra/Capotavola; segno `token_oscuro` (slot `trinket`, `faction_sign_hidden:true`)
- [x] `data/items/factions/token_oscuro.json` — trinket, `faction_sign:true`, `faction_sign_hidden:true` (rilevabile solo da NPC specifici)
- [x] `quest_tavola_ingresso.json` — kill 3 `fuorilegge`, turn_in; premia token + join + rep
- [x] Passiva `rete_oscura`: Rank 0→`tsn_black_market`; Rank 2→`tsn_bounty_reduction`; Rank 4→`tsn_elite_contracts`
- [x] Nota: `supporter_eligible: false` → nessun supporter; nessuna penalità rep al join (penalità solo al leave -20, già implementata)
- [ ] Safe house, taglie, crimini (crime system) — Fase 11
- [ ] Tasse → Fase 12
- [x] Aggiornare `.claude/codebase_reference.md` — documentato

---

### FASE 8 — CityBuilder minimo e fazioni villaggio ✅

**Priorità**: non serve UI completa subito. Basta il dato nel JSON della mappa.

#### 8.1 Dati mappa ✅
- [x] Aggiungere campo `signoria` (ID signoria, o null) nelle proprietà mappa
- [x] Aggiungere campo `corporazioni_presenti: Array[String]` nelle proprietà mappa
- [x] Salvare in JSON della città
- [x] `CityGenerator._from_json()` legge `signoria` → `MapData.metadata["signoria"]` e `corporazioni_presenti` → `MapData.metadata["corporazioni_presenti"]`

#### 8.2 Fazioni villaggio ✅
- [x] Nota: signorie (`data/factions/signorie/*.json`) esistono già — nessun JSON villaggio separato necessario. Le signorie sono i governing bodies dei villaggi.
- [x] `FactionRegistry` già scansiona ricorsivamente — eventuali future dir `villaggi/` auto-caricabili
- [x] `GameState.current_location_faction_id: String = ""` — signoria della città corrente; set dal WorldManager, cleared su leave
- [x] `WorldManager.change_map()` — legge `data.metadata.get("signoria", "")` e aggiorna `GameState.current_location_faction_id`
- [x] `NPC.setup()` — se `faction_id` vuoto nel data, fallback a `GameState.current_location_faction_id` (gli NPC generici del villaggio appartengono automaticamente alla signoria locale)

#### 8.3 CityBuilder UI ✅
- [x] Var `_csignoria: String` e `_ccorporazioni: Array` aggiunte alla sezione city data
- [x] Riga "Signoria" + "Corporazioni" inserita nel `_build_ui()` tra l'header e il primo HSeparator
- [x] `_save_city()` — include `signoria` e `corporazioni_presenti` se non vuoti
- [x] `_load_file()` — ripristina `_csignoria`, `_ccorporazioni` e sincronizza i campi UI
- [x] `_new_city()` — resetta i nuovi campi
- [x] Signoria: `OptionButton` (`_signoria_opt`) popolato da scan `data/factions/signorie/*.json` via `_load_faction_lists()` (DirAccess diretta, senza autoload — script `@tool`)
- [x] Corporazioni: `Label` (`_corp_summary_lbl`) + `PopupMenu` (`_corp_menu`) multi-select da scan `tier_s/a/b/c/*.json`; `hide_on_checkable_item_selection = false` per mantenere il menu aperto durante selezione multipla
- [x] Aggiornare `.claude/codebase_reference.md` — fatto a fine fase

---

### FASE 9 — Propagazione rep avanzata ✅

#### 9.1 Propagazione gerarchica (10%) ✅
- [x] Propagazione verso il parent diretto — già implementata; confermata
- [x] Propagazione verso i figli diretti — aggiunta via `FactionRegistry.get_faction_children()`
- [x] Solo primo livello — no cascade: i delta propagati usano `set_rep()` direttamente, non `add_rep()`
- [x] Delta = round(delta × 0.10); se |d| < 1 → ignorato

#### 9.2 Propagazione laterale (30% × sign) ✅
- [x] Propagazione verso fazioni nella matrice relazioni con |rel| ≥ 20 (LATERAL_THRESHOLD)
- [x] Sostituita la vecchia logica sibling con lettura da `FactionRegistry.get_relations()`
- [x] Delta = round(delta × 0.30 × sign(rel_value)); se |d| < 1 → ignorato
- [x] `relations.json`: aggiunto `cacciatori_rogna → mano_campi: 30` (cross-dep disinfestazione rurale)

#### 9.3 Logging ✅
- [x] Parametro `reason: String = ""` rinominato (rimosso underscore prefisso — ora usato)
- [x] `DEBUG_PROPAGATION: bool = false` — costante di classe; print attivo solo se true

#### 9.4 Test (verificati manualmente) ✅
- [x] `+10 cacciatori_rogna` → `corporazione_camere` +1 (parent ×10%), `mano_campi` +3 (laterale ×30%)
- [x] `-50 tavola_senza_nome` → `milizia_campane` +15 (rel=-80, sign→inverte), `fuorilegge` -15 (rel=+30)
- [x] No cascata: propagated dict applicato tutto con `set_rep()`, nessun `add_rep()` ricorsivo
- [x] Aggiornare `.claude/codebase_reference.md` — fatto a fine fase

---

### FASE 10 — Accessi condizionali e servizi ✅ (parziale)

#### 10.1 Porte e aree ✅
- [x] Implementare su `Door.gd` il campo `faction_requirement: {faction_id, min_rep, min_rank}`
  - `min_rank = -1` → nessun controllo rango; `min_rank = 0` → qualsiasi membro (rank ≥ 0)
  - `min_rep = 0` → nessun controllo reputazione
- [x] Check in `Door.interact()` via `_check_faction_access()`: apre solo se requisiti soddisfatti; emette `Notification.faction_access_denied()` se bloccata
- [x] Aggiungere supporto nel CityBuilder per assegnare requisiti alle porte
  - Campi `faction_req_fid` (LineEdit), `req_min_rep` (SpinBox 0–100), `req_min_rank` (SpinBox -1 a 5)
  - Helper `_prop_spin_range()` aggiunto per SpinBox con range custom

#### 10.2 Filtro NPC ✅ (parziale)
- [x] Implementare filtro sociale NPC: `enemy_sworn` → accesso negato + `Notification.faction_access_denied()`; stato `hostile` → dialogo consentito (tono futuro)
- [ ] Implementare variazioni tono dialogo in base a fazioni secondarie — stub; dipende da sistema dialogo esteso
- [x] Implementare `FactionEconomy.get_price_multiplier(context)` completo:
  - `context = {base_faction, transaction_type, item_id?, location_id?}`
  - Passive flag discounts (es. `officine_potion_discount` per `congregazione_officine`/`sorelle_sale`)
  - Rep-state: `trusted` ×0.90, `allied` ×0.95, `hostile` ×1.15, `enemy_sworn` ×1.25
  - Recognition sign bonus: membro + segno equipaggiato → ×0.95 su acquisti
- [x] `Notification.faction_access_denied(faction_name)` — aggiunto; colore rosso `Color(0.9, 0.3, 0.25)`

#### 10.3 Servizi supporter/membro (stub)
- [ ] Implementare servizi preferenziali per supporter (prezzo ridotto, dialogo espanso) — dipende da sistema shop NPC
- [ ] Implementare servizi esclusivi per membri (quest riservate, accesso aree) — dipende da sistema shop NPC
- [x] Aggiornare `.claude/codebase_reference.md` — fatto a fine fase

---

### FASE 11 — Quirk world-persistent ✅ (parziale — NPC e profitti stub)

#### 11.1 Mappe depositate (`collegio_cartografi`) ✅
- [x] `WorldState.register_dungeon_map(map_id, floor_n)` — registra mappa, salva in `registered_dungeon_maps`
- [x] `WorldState.has_registered_map(map_id)` / `get_registered_map(map_id)` — lookup world-persistent
- [x] `FactionActionsService.try_deposit_map()` — check `carto_map_sellable`, solo in dungeon, reward oro per piano × `MAP_DEPOSIT_GOLD_PER_FLOOR`
- [x] `BaseMap.populate()` — se mappa registrata in WorldState: `_seen_tiles.fill(1)` (FOV bypass per tutti i personaggi successivi)
- [x] Trigger: F5 in `Main._unhandled_input()` + NPC `faction_action_id = "deposit_map"`
- [ ] Tipi mappa personale/acquistata — solo "registered" implementato; "acquistata" e "personale" deferred a sistema acquisto mappe

#### 11.2 Stazioni di posta (`compagnia_ponti`) ✅ (NPC stub)
- [x] `PostStation.gd` — entity visuale `⚑` giallo, `is_blocking=true`, ripristina HP al max, emette `Notification.faction_action()`
- [x] `WorldState.add_post_station(map_id, pos)` — check distanza minima 30 tiles, salva in `built_post_stations`
- [x] `WorldState.get_post_stations_for_map(map_id)` / `has_post_station_near(map_id, pos, radius)`
- [x] `FactionActionsService.try_build_post_station()` — check `ponti_speed_bonus`, 100g di costo, distanza 30 tiles
- [x] `BaseMap._inject_world_persistent_entities()` — inietta stazioni dal WorldState a ogni caricamento mappa
- [x] `BaseMap._is_uid_spawned(uid)` — evita duplicati
- [x] Trigger: F6 + NPC `faction_action_id = "build_post_station"`
- [ ] Utilizzo da parte degli NPC — STUB; dipende da NPC AI system (Fase futura)

#### 11.3 Ambulatorio convenzionato (`congregazione_officine`) ✅ (NPC/profitti stub)
- [x] `Ambulatorio.gd` — entity visuale `+` rosso, `is_blocking=true`, ripristina HP al max
- [x] `WorldState.open_service(location_id, "ambulatorio", data)` — salva in `opened_player_services`
- [x] `WorldState.has_service(location_id, service_type)` / `get_service(location_id, service_type)`
- [x] `FactionActionsService.try_open_ambulatorio()` — check `officine_advanced_care`, 200g, solo city/village
- [x] `BaseMap._inject_world_persistent_entities()` — inietta ambulatorio se service esiste
- [x] Trigger: F7 + NPC `faction_action_id = "open_ambulatorio"`
- [ ] Visitabile dagli NPC — STUB
- [ ] Rifornimento e gestione profitti — STUB (Fase 12/13)

#### 11.4 Safe house e mercato nero (`tavola_senza_nome`) ✅ (crime system stub)
- [x] `WorldState.register_safe_house(map_id, pos)` — salva in `discovered_safe_houses`, emette `Notification.faction_action()`
- [x] `WorldState.get_safe_houses_for_map(map_id)` / `is_safe_house_location(map_id)`
- [x] `NPC.safe_house: bool` + `NPC.black_market: bool` — letti da params nel CityBuilder
- [x] `NPC.interact()` — `safe_house` registra location al primo incontro; `black_market` richiede `tsn_black_market` flag
- [x] `NPC.faction_action_id = "reduce_bounty"` → stub `FactionActionsService.try_reduce_bounty_tsn()`
- [x] `GameState.active_bounty: int = 0` — placeholder crime system (Fase 12)
- [x] `EventBus.faction_world_action_completed(action, details)` — segnale world action
- [x] `Notification.faction_action(msg)` — notifica ciano per azioni fazione world
- [ ] Meccanica riduzione taglia tramite pagamento/quest — STUB (Fase 12)
- [ ] Venditori mercato nero con comportamento shop — architettura pronta, dipende da NPC shop system
- [x] Aggiornare `.claude/codebase_reference.md` — ✅ fatto

---

### FASE 12 — Crime system completo

*(Dipende da piano separato `plan_crime_system.md` da creare)*

#### 12.1 Crimini e testimoni
- [ ] Definire enum `CrimeType` (assault, murder, theft, trespassing, illegal_magic, ecc.)
- [ ] Definire struttura "witnessed crime" (tipo, chi ha visto, dove, quando)
- [ ] Implementare `CrimeRegistry` (autoload)
- [ ] Implementare `CrimeRegistry.register_crime(type, actor, victim, witnesses, location)`
- [ ] Implementare hook in `CombatManager` per assault testimoniato
- [ ] Implementare furto, minaccia, omicidio, accesso abusivo

#### 12.2 Taglie e risposta Milizia
- [ ] Implementare `bounty` su `GameState` (flag + livello taglia)
- [ ] Implementare risposta `milizia_campane` a crime registrato (avviso → arresto/multa)
- [ ] Implementare possibilità di pagare multa, scontare pena, fuggire

#### 12.3 Collegare `tavola_senza_nome`
- [ ] Collegare funzionalità crime system alle meccaniche Tavola (omicidio, furto, minaccia)
- [ ] Collegare riduzione taglia attraverso Tavola
- [ ] Collegare safe house al crime system

#### 12.4 Hook crimini predisposti (stub già in Fase 2/3, da implementare qui)
- [ ] Sostituire stub `CrimeRegistry` con implementazione reale
- [ ] Collegare `CRIME_*` keys al `FactionDisplay.get_display_crime()`
- [ ] Aggiornare `.claude/codebase_reference.md` — aggiungere `CrimeRegistry` alla tabella autoload; documentare `CrimeType` enum e la struttura "witnessed crime"; documentare `bounty` in `GameState`

---

### FASE 13 — Tasse e obblighi di membership ✅

*(Le tasse non devono essere tutte uguali — struttura per-fazione)*

#### 13.1 Architettura tasse ✅
- [x] `FactionEconomy.on_rest()` — implementazione reale; chiamata da `Player._use_save_point()` prima di `SaveManager.save_game()`
- [x] Trigger: save point (il momento di "riposo" naturale del gioco)
- [x] Stato "in ritardo" (`tax_debt = 1`) → warning + blocco avanzamento rango
- [x] Stato "moroso" (`tax_debt = 2`) → espulsione automatica via `FactionMembership.leave_faction()`
- [x] Notifiche: combined "Tasse di gilda: -Xg" (pagato), per-faction warning (non pagato), per-faction espulsione
- [x] EventBus: `tax_collected(faction_id, amount)`, `tax_warning(faction_id)`, `tax_expelled(faction_id)`
- [x] `tax_debt` salvato in `GameState.character_faction_membership[fid]` → persiste nel save (nessuna modifica a SaveManager necessaria)
- [x] `FactionEconomy.has_tax_restrictions(faction_id)` — usato da `FactionMembership.advance_rank()` per bloccare avanzamento se debitore

#### 13.2 Strutture tasse per-fazione ✅
- [x] `corporazione_camere`: 25g per save point
- [x] `cacciatori_rogna`: 10g per save point (semplificato da "quota ripulite" — dipende da job tracking futuro)
- [x] `collegio_cartografi`: 20% del reward al deposito mappa (`FactionEconomy.collect_deposit_tax()`, hook in `FactionActionsService.try_deposit_map()`)
- [x] `compagnia_ponti`: 15g per save point SOLO se `WorldState.has_any_post_station()` — `WorldState.has_any_post_station()` aggiunto
- [x] `corrieri_sigillo`: 10g per save point (semplificato da "quota carovane" — dipende da caravan system)
- [x] `congregazione_officine`: 10g per save point (contributo periodico semplificato)
- [x] `tavola_senza_nome`: 20g per save point (protezione)
- [x] Aggiornare `.claude/codebase_reference.md` — ✅ fatto

---

### FASE 14 — Localizzazione completa fazioni ✅

> Chiavi reali (da codice): `FACTION_{ID_UPPER}_NAME/DESC` · `FACTION_STATE_{STATE_UPPER}` · `FACTION_{ID_UPPER}_RANK_{n}` (0-indexed) · `PASSIVE_{passive_id_upper}_NAME/DESC` · `CRIME_{type_upper}` · `UI_FACTIONS_*` in `strings_ui.csv` · `NOTIF_FACTION_*` / `NOTIF_TAX_*` in `strings_notifications.csv` · `UI_FACTION_*` (action feedback) in `strings_ui.csv`

#### 14.1 Aggiornare `LocaleManager` ✅
- [x] Aggiunto `"strings_factions"` all'array `CSV_FILES` in `LocaleManager.gd` (dopo `"strings_enemies"`)

#### 14.2 Creare `locales/strings_factions.csv` ✅
- [x] 21 nomi fazioni civili (`FACTION_{ID_UPPER}_NAME`)
- [x] 10 nomi signorie
- [x] 8 nomi fazioni nemiche + natura
- [x] 39 descrizioni brevi (`FACTION_{ID_UPPER}_DESC`) — tutte le fazioni
- [x] 6 stati di reputazione (`FACTION_STATE_ENEMY_SWORN` … `FACTION_STATE_TRUSTED`)
  - `FACTION_STATE_SUPPORTER` / `FACTION_STATE_MEMBER` non aggiunti — non usati da `FactionDisplay.get_display_state()` nella fase corrente
- [x] 42 ranghi joinabili (`FACTION_{ID_UPPER}_RANK_{0…5}`) — indice 0-based conforme a `FactionDisplay.get_display_rank()`
  - Il piano segnava `_RANK_1…_RANK_6` ma il codice usa 0-5 dai JSON
- [x] 14 passivi (`PASSIVE_{passive_id_upper}_NAME/DESC`) — chiave basata su `join_passive` field, non su faction id
  - Il piano segnava `FACTION_{ID}_PASSIVE_NAME` ma `FactionDisplay.get_display_passive_name()` usa `PASSIVE_{join_passive.to_upper()}_NAME`
- [x] 8 tipi crimine (`CRIME_ASSAULT` … `CRIME_BRIBERY`)

#### 14.3 Aggiornare `strings_ui.csv` ✅
- [x] `UI_FACTIONS_TITLE` / `UI_FACTIONS_TAB_CIVIL` / `UI_FACTIONS_TAB_SIGNORIE` / `UI_FACTIONS_TAB_ENEMIES`
- [x] `UI_FACTIONS_REP_LABEL` / `UI_FACTIONS_RANK_LABEL` / `UI_FACTIONS_STATUS_LABEL` / `UI_FACTIONS_PASSIVE_LABEL`
- [x] `UI_FACTIONS_JOIN_BUTTON` / `UI_FACTIONS_LEAVE_BUTTON` / `UI_FACTIONS_SUPPORTER_BADGE` / `UI_FACTIONS_MEMBER_BADGE`
- [x] Feedback azioni fazione: `UI_FACTION_ACTION_NOT_ELIGIBLE` / `UI_FACTION_ACTION_NO_GOLD` / `UI_FACTION_DEPOSIT_NOT_DUNGEON` / `UI_FACTION_MAP_ALREADY_DEPOSITED` / `UI_FACTION_MAP_DEPOSITED` / `UI_FACTION_POST_STATION_TOO_CLOSE` / `UI_FACTION_POST_STATION_BUILT` / `UI_FACTION_AMBUL_ONLY_CITY` / `UI_FACTION_AMBUL_ALREADY_OPEN` / `UI_FACTION_AMBUL_OPENED` / `UI_FACTION_SAFE_HOUSE_FOUND` / `UI_FACTION_NO_BOUNTY`

#### 14.4 Aggiornare `strings_notifications.csv` ✅
- [x] `NOTIF_FACTION_STATE` / `NOTIF_FACTION_SUPPORTER_GAINED` / `NOTIF_FACTION_SUPPORTER_LOST` / `NOTIF_FACTION_ACCESS_DENIED`
- [x] `NOTIF_TAX_PAID_TOTAL` / `NOTIF_TAX_WARNING` / `NOTIF_TAX_EXPELLED` / `NOTIF_TAX_CARTOGRAFI` / `NOTIF_TAX_RANK_BLOCKED`
  - Le chiavi in piano (es. `UI_FACTION_TAX_WARNING`) erano errate — le chiavi reali nel codice sono `NOTIF_TAX_*`
- [ ] `UI_FACTION_CRIME_WITNESSED` — riservato a Fase 12 (crime system, saltata)

#### 14.5 Aggiornare t_or calls con params ✅
- [x] `FactionEconomy.gd` — 4 chiamate t_or aggiornate da `%d`/concatenazione stringa a params `{"amount": ...}` / `{"faction": ...}`
- [x] `FactionActionsService.gd` — 3 chiamate t_or aggiornate (`UI_FACTION_MAP_DEPOSITED`, `UI_FACTION_ACTION_NO_GOLD` ×2) a params `{"gold": ...}` / `{"amount": ...}`

---

### FASE 15 — UI fazioni completa ✅

#### 15.1 Schermata fazioni ✅
- [x] Creare `scripts/ui/FactionScreen.gd` — pure-code CanvasLayer (layer=8), nessuna TSCN (segue pattern ClassPickerPanel/ClassRespecScreen)
- [x] Lista fazioni con barra ProgressBar rep (-100…+100) e stato colorato per tier
- [x] Tab: Civili (`"civil"`) / Signorie (`"signoria"`) / Nemici (`"nemico"` + `"natura"`)
- [x] Pannello dettaglio: rango membro, passiva corrente, debito tasse, nessun dettaglio su relazioni globali (stub futuro)
- [x] Collegato al menu di pausa: bottone "Fazioni [G]" + tasto G in `PauseMenu.gd` e `Main.gd`
- [x] `EventBus.toggle_faction_screen` — apre/chiude via signal dal PauseMenu o da G diretto
- [x] `Main._setup_faction_screen()` — carica e registra FactionScreen, wire signal `pause_menu.faction_screen_requested`
- [x] `Main._go_to_main_menu()` — forza `_faction_screen.visible = false` al ritorno al menu principale

#### 15.2 Notifiche rep in gioco ✅
- [x] `Notification.faction_rep_delta(faction_name, delta)` — notifica verde/rossa `{faction}: {delta} rep`; durata 2s
- [x] `NOTIF_FACTION_REP_DELTA` aggiunta a `locales/strings_notifications.csv`
- [x] `FactionReputation.set_rep()` — emette `faction_rep_delta` solo se stato invariato, supporter invariato e |Δrep| ≥ 5 (evita duplicati con notifiche di stato/supporter)
- [x] Notifiche stato già implementate in Fase 2 (`NOTIF_FACTION_STATE`)

#### 15.3 Dettaglio fazione con barra rep e membri conosciuti ✅
- [x] Pannello dettaglio destra: nome (bold), stato colorato + rep numerica, descrizione, rango e passiva se membro, debito tasse se presente
- [x] `GameState.known_faction_members: Dictionary` — `{faction_id: {npc_id: name}}`
- [x] `GameState.record_known_member(faction_id, npc_id, npc_name)` — aggiunge/aggiorna membro
- [x] `NPC.interact()` — chiama `record_known_member()` prima di ogni altra logica (anche NPC ostili vengono registrati al primo incontro)
- [x] `FactionMembership.initialize_for_new_game()` — resetta `known_faction_members = {}`
- [x] `SaveManager` — salva/ripristina `known_faction_members` nel JSON personaggio
- [x] `UI_FACTIONS_KNOWN_MEMBERS` aggiunta a `locales/strings_ui.csv`
- [x] Aggiornare `.claude/codebase_reference.md` ← da fare

---

### FASE 16 — Bilanciamento finale ✅

#### 16.1 Relazioni laterali — completamento `relations.json` ✅
- [x] `bestie → cacciatori_rogna: -30` / `bestie → compagnia_bestie: 40`
- [x] `non_morti → cattedra_canone: -80` / `non_morti → becchini_canone: 30`
- [x] `demoni → cattedra_canone: -80`
- [x] `cattedra_canone → demoni: -100` / `cattedra_canone → non_morti: -80`
- [x] `corrieri_sigillo → compagnia_ponti: 40` / `compagnia_ponti → corrieri_sigillo: 35`
- [x] `corporazione_camere → milizia_campane: 30` / `corporazione_camere → banco_tre_monete: 25`
- [x] `banco_tre_monete → corporazione_camere: 30`
- [x] `compagnia_bestie → cacciatori_rogna: -25`
- [x] `mano_campi → natura: 30`
- [x] `cacciatori_rogna → compagnia_bestie: -20` *(aggiunto; il `→ mano_campi: 30` era già in Fase 9)*
- [x] Relazioni Signorie (già presenti dalle fasi precedenti) — invariate

#### 16.2 `rep_on_kill` su tutti i nemici ✅
- [x] Campo aggiunto a tutti e 30 i JSON nemici (batch PowerShell su `faction_id`)
  - `fuorilegge` (goblin, kobold, bandit, dark_elf, orc, ogre, witch): `-2`
  - `non_morti` (zombie, skeleton, ghoul, vampire, death_knight, lich): `-2`
  - `bestie` (bat, rat, spider, giant_spider, lizardman, troll, werewolf): `-2`
  - `demoni` (demon, chaos_knight, fallen_angel): `-3`
  - `aberrazioni` (slime, void_stalker): `-1`
  - `costrutti` (gargoyle, golem): `-1`
  - `draghi`: `dragon_whelp: -3`, `ancient_dragon: -5`
  - `archlich` (non_morti, override): `-3`

#### 16.3 Verifica soglie ✅
- [x] **-75 (enemy_sworn) — attacco a vista**: implementato come blocco in `NPC.interact()` + `Notification.faction_access_denied()`. I nemici dungeon non controllano la rep (always-hostile by design — la soglia si applica solo agli NPC civili).
- [x] **+50 (allied) — sconto mercante**: `FactionEconomy.get_price_multiplier()` applica ×0.95 ad `"allied"` e ×0.90 a `"trusted"`. Confermato.
- [x] **+75 (trusted) — accesso joinable**: `join_faction()` non ha un gate rep esplicito. Il gate è la quest di ingresso, la cui NPC è bloccata a `enemy_sworn`. In pratica non si può joinare a rep < −75 perché non si riesce a parlare con l'NPC. Eccezione: `corporazione_camere` si joina via tutorial (rep 0 default).

#### 16.4 Analisi exploit ✅
- [x] **Rep farming da kill** — Intenzionale. Uccidere fuorilegge dà +1 milizia ogni ~2 kill (laterale). Velocità limitata dai rate di spawn; raggiungere +100 richiederebbe ~200 kill, che è ordine di grandezza plausibile per una run.
- [x] **Leave-rejoin per evasione tasse** — Auto-limitante: leave costa -20 rep, la quest di ingresso non è ripetibile (`QuestManager` traccia completate). Nessun percorso di re-join a costo zero.
- [x] **Supporter a +50 senza tasse** — Intenzionale by design: il tier supporter è esplicitamente meno costoso della membership (benefici ridotti, zero tasse).
- [x] **`join_faction()` senza gate rep** — Sicuro: il gate è la quest di ingresso. Unico bypass è il DebugScreen (solo debug build, intenzionale).
- [x] **Propagazione su fazioni già a -100** — Intenzionale e documentato (Fase 9.4): `add_rep()` usa il delta originale per la propagazione anche se `set_rep()` è no-op. Kill su fuorilegge già a -100 producono comunque laterali su milizia e tavola.

#### 16.5 DebugScreen — sezione fazioni ✅
- [x] Sezione `"faction_db"` con contatori totale + breakdown per tipo
- [x] Costanti `STATE_HEX` e `JOINABLE_FACTIONS` a livello di classe in `DebugScreen.gd`
- [x] `_build_faction_tools()` — blocco collassabile (colore viola)
  - [x] Tabella rep live (`_faction_rep_rtl`): tutte le fazioni colorate per stato + badge M[rank]/S
  - [x] Rep editor: `OptionButton` sorted + delta ±10/±25/±50 + `CheckButton` propagazione + "Reset All Rep"
  - [x] Membership: tabella ◆/★/○ per le 7 joinabili + bottoni Join/Leave/+Rank per ognuna
- [x] `_update_faction_rep_table()` / `_update_faction_member_table()` — chiamate da `_refresh()` ogni 0.5s
- [x] `_do_rep_delta()`, `_do_reset_all_rep()`, `_do_faction_join()`, `_do_faction_leave()`, `_do_faction_advance()`

---

## Debug Screen — Sezione Fazioni ✅

Implementata nella Fase 16. Segue il pattern `_add_section` / `_build_*` / `_update_*` già in uso in `DebugScreen.gd`.

### Sezione dati — `faction_db` ✅
- [x] Numero totale di fazioni caricate (`FactionRegistry.get_all_factions().size()`)
- [x] Breakdown per tipo (civile / signoria / nemico / natura / altri)

### Sezione rep — visualizzazione ✅
- [x] Tabella `_faction_rep_rtl` con tutte le fazioni: id · rep numerica · stato colorato (BBCode via `STATE_HEX`)
- [x] Badge M[rank] per membri e S per supporter

### Pannello rep editor ✅
- [x] `_faction_rep_opt` (OptionButton sorted) per selezionare la fazione
- [x] Bottoni delta ±10/±25/±50 (rosso = negativo, verde = positivo)
- [x] `_faction_propagate_cb` (CheckButton "Propagazione") — usa `add_rep()` se checked, `set_rep()` diretto se no
- [x] Bottone "Reset All Rep" → `FactionReputation.initialize_for_new_game()`

### Pannello membership ✅
- [x] `_faction_member_rtl` — lista ◆/★/○ per le 7 joinabili
- [x] Bottoni Join / Leave / +Rank per ogni fazione joinable

### Non implementati (future fasi)
- [ ] Simulatore propagazione dry-run — non urgente, il debug log (`DEBUG_PROPAGATION=true`) copre il caso d'uso
- [ ] WorldState viewer — da aggiungere quando WorldState è più popolato
- [ ] Crime/taglia viewer — Fase 12 (crime system non iniziata)

---

## TODO — Tutto ciò che manca ancora a questo sistema

Elenco esaustivo di tutto ciò che è pianificato, stub, o implicato dal design ma non ancora implementato.
Organizzato per area tematica, con la dipendenza esterna che lo sblocca (dove presente).

---

### 1. Crime system (Fase 12 — intera fase non iniziata)

*Dipende da `plan_crime_system.md` ancora da creare.*

- [ ] Definire enum `CrimeType`: `assault`, `murder`, `theft`, `trespassing`, `illegal_magic`, `bribery`, ecc.
- [ ] Definire struttura "witnessed crime": tipo, attore, vittima, testimoni, luogo, turno
- [ ] Implementare `CrimeRegistry` (autoload): `register_crime()`, query storico crimini attivi
- [ ] Hook in `CombatManager`: attaccare NPC neutrale = `assault` (solo se testimoniato)
- [ ] Implementare furto, minaccia, omicidio come meccaniche distinte (non dialogo standard)
- [ ] Implementare accesso abusivo (`trespassing`) per aree protette senza requisito soddisfatto
- [ ] `GameState.active_bounty: int` → sostituire placeholder con struttura piena (livello taglia, crimini associati)
- [ ] Risposta `milizia_campane` a crime registrato: avviso → inseguimento → arresto/multa → fuga possibile
- [ ] Pagare multa (perde oro), scontare pena (perde turni), fuggire (perde rep)
- [ ] Collegare `tavola_senza_nome` al crime system: omicidio/furto/minaccia sbloccati da `tsn_black_market`
- [ ] `FactionActionsService.try_reduce_bounty_tsn()` — stub → implementazione reale
- [ ] Collegare safe house al crime system: rifugio da inseguimento Milizia
- [ ] `FactionDisplay.get_display_crime()` collegato a chiavi `CRIME_*` reali
- [ ] `UI_FACTION_CRIME_WITNESSED` in `strings_notifications.csv`
- [ ] DebugScreen: sezione crime/taglia (visualizzazione bounty + lista crimini + inject crime + bottoni paga/clear)
- [ ] Aggiornare codebase_reference: `CrimeRegistry`, `CrimeType`, struttura "witnessed crime", `bounty` pieno in GameState

---

### 2. Trigger rep ambientali per-fazione

*Dipende da sistemi specifici indicati per ogni voce.*

- [ ] `milizia_campane` — rep positiva per: aiutare guardie, crimini testimoniati riportati; rep negativa per: crimini testimoniati; dipende da crime system
- [ ] `milizia_campane` — `rep_on_kill_targets` configurato su nemici `fuorilegge` per dare +1 milizia ogni 2 kill (laterale già gestisce questo parzialmente, ma non è verificato end-to-end)
- [ ] `cattedra_canone` — uso magia proibita abbassa rep; offerte in chiese aumentano rep; dipende da magic system
- [ ] `corporazione_camere` — contratti completati nel tempo danno +rep; contratti falliti danno −rep; dipende da quest deadline system
- [ ] Hook generico "entra in location": dungeon senza condotta ufficiale = penalità rep `corporazione_camere`; dipende da location-events system
- [ ] `non_morti` / `bestie` — `rep_on_kill` negativo configurato per classi speciali (negromante, ranger, druido): uccidere non_morti costa −rep non_morti per negromante; dipende da sistema classi Fase 7+
- [ ] Altre fazioni (signorie, corporazioni minori) — trigger rep da azioni nel mondo; da definire fazione per fazione al momento dell'implementazione

---

### 3. NPC commerce / shop system

*Blocca quasi tutti i benefici economici delle fazioni.*

- [ ] NPC shop system: interfaccia acquisto/vendita con NPC merchant; prerequisito per qualsiasi hook di prezzo fazione
- [ ] `FactionEconomy.get_price_multiplier()` è implementato ma non chiamato da nulla (nessun NPC shop esiste); collegarlo al sistema shop quando viene costruito
- [ ] Servizi preferenziali per **supporter** (rep ≥50, non membro): prezzo ridotto (già parzialmente coperto da `get_price_multiplier`), dialogo espanso, accesso a quest secondarie
- [ ] Servizi esclusivi per **membri**: quest riservate, accesso ad aree protette tramite NPC, informazioni esclusive
- [ ] `congregazione_officine` — hook sconto 25% su pozioni/cure da NPC Officine e Sorelle del Sale; dipende da NPC shop
- [ ] `tavola_senza_nome` — venditori mercato nero con comportamento shop distinto: slot `tsn_black_market` in `NPC`, architettura pronta; dipende da NPC shop
- [ ] Segno di riconoscimento — attualmente usato solo per price multiplier (×0.95); estendere a: NPC riconosce il membro, dialogo alternativo, missioni dedicate; dipende da NPC shop + dialogue system

---

### 4. Overworld e movimento

*Dipende da sistema movimento overworld non ancora costruito.*

- [ ] `compagnia_ponti` — velocità overworld +1 su strade e sentieri (`ponti_speed_bonus: 1` in flags, hook non collegato)
- [ ] `compagnia_ponti` — scorciatoie segnalate solo sui registri della Compagnia (accesso a percorsi alternativi)
- [ ] `compagnia_ponti` — pedaggi e traghetti gestiti dalla Compagnia costano il 50% in meno (`ponti_toll_discount: 50` in flags); dipende da NPC/evento pedaggio
- [ ] `corrieri_sigillo` — mount di qualità al Rank 4 (`corrieri_mount` flag, non collegato)
- [ ] `corrieri_sigillo` — viaggio con carovane dei corrieri (più sicuro, risorse più economiche); dipende da sistema carovane + `confraternita_strada`
- [ ] Sistema carovane: prenotazione in anticipo presso `confraternita_strada`, meccanica di viaggio sicuro, interazione con overworld; da progettare separatamente
- [ ] Utilizzo stazioni di posta da parte degli NPC; dipende da NPC AI system

---

### 5. Visibilità / FOV

*Dipende da visibility system avanzato non ancora costruito.*

- [ ] `collegio_cartografi` — raggio FOV +1 (`carto_fov_bonus: 1` in flags, hook non collegato); deve essere applicato in `GameBalance` o `MapRenderer` al cambio di rango
- [ ] Tipi di mappa distinti: mappa **personale** (rilevata dal player), **acquistata** (comprata da NPC cartografo), **registrata** (depositata in WorldState); attualmente solo "registered" implementato
- [ ] Acquisto mappe da NPC (servizio esclusivo `collegio_cartografi`); dipende da NPC shop
- [ ] Persistenza mappa personale cross-run (`carto_world_persistent`, Rank 4): FOV bypass anche in nuove run dello stesso dungeon; infrastruttura `WorldState.register_dungeon_map` pronta, hook al caricamento mappa da verificare

---

### 6. NPC AI

*Dipende da sistema NPC AI non ancora progettato.*

- [ ] NPC che usano stazioni di posta: pathfinding verso `⚑`, HP restore, ripresa percorso
- [ ] NPC che usano ambulatori: NPC feriti si dirigono all'ambulatorio aperto dal player
- [ ] Rifornimento e gestione profitti ambulatorio: NPC pagano, player riceve oro periodicamente (WorldState)
- [ ] NPC che reagiscono alla signoria locale diversamente in base alla propria fazione secondaria
- [ ] Comportamento NPC in base allo stato di inseguimento Milizia (crime system)

---

### 7. Estensioni quest system

*Dipendono da quest type system, deadline system, e news system non ancora costruiti.*

- [ ] `corrieri_sigillo` — bonus +25% oro scoped solo a quest di tipo "consegna" (`corrieri_passive_contracts`); attualmente si applica a tutte le quest; dipende da quest type system
- [ ] `corrieri_sigillo` — ricezione automatica di contratti di consegna passivi all'ingresso in nuova città (`corrieri_passive_contracts` flag); dipende da event trigger città
- [ ] `corrieri_sigillo` — accesso anticipato a voci di corridoio su eventi del mondo (`corrieri_world_events` flag); dipende da news/world-events system
- [ ] Quest con deadline: contratti `corporazione_camere` completati "nel tempo concordato" danno bonus XP/rep; dipende da sistema turni/tempo per deadline
- [ ] `corporazione_camere` — flag `elite_contract_access` (Rank 5+): accesso a quest di tier superiore; nessuna quest elite ancora definita

---

### 8. Passive e quirk deferred per fazione joinabile

- [ ] `cacciatori_rogna` — quirk `infestation_jobs`: la gente del villaggio affida piccole missioni di "ripulita"; sblocca oggetti specifici nel tempo; infrastruttura pronta (NPC `faction_action_id`), manca la generazione procedurale di quest di infestazione
- [ ] `cacciatori_rogna` — `rogna_advanced_id` (Rank 5): identificazione automatica avanzata dei mostri (HP, ATK, DEF visibili); hook visivo in `MapRenderer` o `Enemy` non implementato
- [ ] `cacciatori_rogna` — `rogna_monster_auto_id: true` (Rank 0-1): come sopra ma versione base
- [ ] `collegio_cartografi` — `carto_map_purchase` (Rank 2): acquisto mappe da NPC; dipende da NPC shop
- [ ] `collegio_cartografi` — `carto_advanced_maps` (Rank 5): tipo di mappa avanzato non definito
- [ ] `compagnia_ponti` — `ponti_shortcuts` (Rank 3): scorciatoie visibili solo ai membri
- [ ] `compagnia_ponti` — `ponti_new_roads` (Rank 5): possibilità di far costruire nuove strade (world-persistent); impatto sul mondo non progettato
- [ ] `congregazione_officine` — `officine_hp_regen_bonus: 1` (Rank 2): +1 HP ogni 2 turni di riposo invece di 3; dipende da sistema regen out-of-combat
- [ ] `congregazione_officine` — `officine_advanced_care` (Rank 4): prerequisito per `try_open_ambulatorio()` (già controllato), ma il beneficio aggiuntivo del rango 4 oltre all'ambulatorio non è definito
- [ ] `corrieri_sigillo` — `corrieri_mount` (Rank 4): mount di qualità; dipende da sistema mount/cavalcature
- [ ] `corrieri_sigillo` — `corrieri_world_events` (Rank 5): news system non implementato

---

### 9. Mappa e archivio dungeon

- [ ] UI archivio dungeon (`WorldState.dungeon_archive`): la struttura dati esiste ma non c'è nessuna interfaccia che mostri al player "livello raccomandato e pericoli noti" dei dungeon registrati; pianificata come parte della `corporazione_camere` Fase 5 → Fase 15 → ancora mancante
- [ ] Archivio dungeon popolato: attualmente `WorldState.dungeon_archive` è un `Dictionary` vuoto; nessun sistema scrive in esso (dovrebbe farlo `FactionActionsService.try_deposit_map()` o un hook di esplorazione)

---

### 10. Dialogo e NPC avanzato

*Dipende da dialogue system esteso non ancora costruito.*

- [ ] Variazioni tono dialogo in base a fazioni secondarie: NPC con `secondary_faction_ids` devono parlare diversamente in base alla rep del player con ciascuna fazione secondaria
- [ ] Schermata configurazione NPC nel CityBuilder: attualmente i parametri NPC (fazione primaria, fazioni secondarie, quest, flags safe_house/black_market, faction_action_id) si configurano manualmente nel JSON; un pannello UI nel builder semplificherebbe molto la creazione di NPC
- [ ] `FactionRegistry.are_enemies(a, b)` — collegato al combat system: attualmente non usato; pianificato per permettere a nemici di fazioni nemiche di combattersi tra loro senza il player

---

### 11. Signorie e politica

- [ ] Signorie con milizie private: le signorie possono avere guardie proprie che funzionano come "gruppi privati di sicurezza" senza autorità giuridica formale; nessuna entità `Guardia_Signoria` implementata
- [ ] `village_faction_changes` in WorldState: le modifiche ai villaggi come esito di quest (cambiare la signoria governante, aggiungere/rimuovere corporazioni) sono strutturalmente previste ma nessuna quest le attiva ancora
- [ ] Relazioni diplomatiche tra Signorie come esito di eventi/quest: attualmente statiche in `relations.json`; il piano le prevede come narrative (non simulate programmaticamente) ma il meccanismo di modifica runtime non esiste
- [ ] Escomunica dalla Cattedra: penalità di rep più grave possibile — reset a -100 su tutte le fazioni dell'albero Cattedra; nessun trigger implementato

---

### 12. Meccaniche narrative (implicazioni meccaniche dal contesto)

*Dal documento di design — non ancora convertite in codice.*

- [ ] Cambio classe richiede certificazione `collegio_maestri`: attualmente il respec è libero; la storia prevede che si debba passare per il Collegio per cambiare classe
- [ ] Certe quest richiedono sigillo `ordine_sigillatori` per essere legalmente valide (reward bonus)
- [ ] Dungeon "con condotta": esplorare dungeon con condotta ufficiale della `corporazione_camere` dà reward aggiuntivi rispetto all'esplorazione "illegale"; nessun flag `has_condotta` implementato
- [ ] Segni di riconoscimento e comportamento NPC: equipaggiare o non equipaggiare il segno dovrebbe cambiare come l'NPC si rivolge al player (riconoscimento fazione); attualmente il segno influenza solo il price multiplier (×0.95)
- [ ] Debiti sanitari frequenti con `congregazione_officine`: meccanica narrativa di credito con le Officine per cure ricevute in-world (non implementata, richiede NPC shop + economia più ricca)

---

### 14. Discrepanze JSON ↔ codice

*Campi nei JSON delle fazioni che non rispecchiano lo stato reale dell'implementazione.*

- [ ] **`tax_system.status: "planned"`** nei JSON di tutte e 7 le fazioni joinabili: le tasse sono **già implementate** in `FactionEconomy.PERIODIC_TAX` (Fase 13). Il campo JSON è documentazione-only ma fuorviante — aggiornare a `{ "status": "implemented", "type": "periodic", "amount": N }` (o `"per_action"` per cartografi) in tutti e 7 i file
- [ ] **`quirk.status: "planned"`** in `compagnia_ponti.json` e `congregazione_officine.json`: i loro quirk (`post_stations` e `medical_center`) sono stati **implementati in Fase 11**. Aggiornare a `"status": "implemented"`
- [ ] **`quirk.status: "planned"`** in `cacciatori_rogna.json` (`infestation_jobs`), `collegio_cartografi.json` (`map_system`), `corrieri_sigillo.json` (`caravans`), `tavola_senza_nome.json` (`crime_mechanics`): questi sono genuinamente **non implementati** — status corretto, ma aggiungere note su dipendenza (`"depends_on": "npc_ai_system"` ecc.) per chiarezza

---

### 15. Propagazione avanzata residua

- [ ] Propagazione "blocchi Signorie": azioni che colpiscono una Signoria principale dovrebbero propagarsi ai suoi clienti con peso ridotto (es. danneggiare `signoria_almerici` danneggia lievemente `signoria_bellandi` e `signoria_ranucci`); attualmente la laterale via `relations.json` copre già questo per le coppie esplicite, ma non c'è un meccanismo automatico per l'intero blocco
- [ ] Propagazione intra-albero formalizzata: azioni contro la `cattedra_canone` dovrebbero propagarsi a tutto il suo albero; attualmente la gerarchica (10%) copre solo parent↔figli diretti — gli effetti su tutta la filiera (es. cattedra → ordine_sigillatori → corrieri_sigillo) richiederebbero due livelli di propagazione consecutivi, che non avvengono per il no-cascade rule

# Shattered — Lore Reference

Questo file raccoglie il lore stabilito del gioco. Le sezioni marcate **[DA DEFINIRE]** sono placeholder strutturati: il contenuto narrativo non è ancora stato deciso e non va inventato senza conferma esplicita dell'utente.

---

## Ambientazione generale

**[DA DEFINIRE — panoramica]**
- Genere: fantasy medievale (circa 1100–1700 per riferimento storico)
- Tono: **[DA DEFINIRE]** (dark fantasy? low fantasy? heroic?)
- Nome del mondo / continente: **[DA DEFINIRE]**
- Punto di partenza della campagna: un overworld con almeno un villaggio, un dungeon e una città

---

## Il Canone

Il "Canone" è il sistema di datazione ufficiale del mondo. L'anno corrente della campagna è il **472 C**.

- Cosa segnò l'anno 0 del Canone: **[DA DEFINIRE]** (un evento storico fondante — una guerra, l'ascesa di un dio, la caduta di un impero?)
- Chi mantiene il Canone: **[DA DEFINIRE]** (la Cattedra del Canone — vedi fazioni — è coinvolta?)
- Calendari alternativi: **[DA DEFINIRE]**

---

## Calendario

12 mesi × 30 giorni = 360 giorni/anno. `total_minutes = 0` corrisponde a mezzanotte del 1 Nevargento 472 C.

| N. | Nome | Stagione | Note lore |
|----|------|----------|-----------|
| 1 | **Nevargento** | Inverno | **[DA DEFINIRE]** |
| 2 | **Brumafonda** | Inverno | **[DA DEFINIRE]** |
| 3 | **Fioralba** | Primavera | **[DA DEFINIRE]** |
| 4 | **Verdeluce** | Primavera | **[DA DEFINIRE]** |
| 5 | **Seminoro** | Primavera | **[DA DEFINIRE]** |
| 6 | **Solcaldo** | Estate | **[DA DEFINIRE]** |
| 7 | **Altosole** | Estate | **[DA DEFINIRE]** |
| 8 | **Granarso** | Estate | **[DA DEFINIRE]** |
| 9 | **Rossovento** | Autunno | **[DA DEFINIRE]** |
| 10 | **Vendemmiale** | Autunno | **[DA DEFINIRE]** |
| 11 | **Cineroggia** | Autunno | **[DA DEFINIRE]** |
| 12 | **Notteprima** | Inverno | **[DA DEFINIRE]** |

---

## Struttura del mondo

### Overworld
- Mappa globale a griglia (attualmente generata proceduralmente)
- Tile significativi: villaggio, città, entrata dungeon
- **[DA DEFINIRE]**: biomi, geografia, nomi dei luoghi, relazioni tra insediamenti

### Villaggi e Città
- Generati via CityBuilder, struttura a più piani possibile
- Il villaggio di partenza è `village_01`
- **[DA DEFINIRE]**: nomi ufficiali, storia, population, specializzazioni commerciali

### Il Dungeon
- Generato proceduralmente a ogni nuova partita (seed casuale)
- N piani variabili, boss finale sull'ultimo piano
- Entrata sull'overworld a tile fisso (18, 14)
- **[DA DEFINIRE]**: nome del dungeon, lore dell'origine, perché è lì

---

## Fazioni

### Fazioni civili joinabili (7)

| ID | Nome display | Ruolo nel mondo |
|----|-------------|-----------------|
| `corporazione_camere` | **[DA DEFINIRE]** | Guild di esploratori/contrattisti; gestisce licenze e archivio dungeon |
| `cacciatori_rogna` | **[DA DEFINIRE]** | Cacciatori di mostri; specializzati in bestie e non-morti |
| `collegio_cartografi` | **[DA DEFINIRE]** | Produttori di mappe; vendono e acquistano planimetrie dungeon |
| `compagnia_ponti` | **[DA DEFINIRE]** | Costruttori/gestori di infrastrutture stradali e stazioni di posta |
| `corrieri_sigillo` | **[DA DEFINIRE]** | Rete di messaggeri e trasporti; operano carovane |
| `congregazione_officine` | **[DA DEFINIRE]** | Medici/artigiani; gestiscono servizi di cura convenzionati |
| `tavola_senza_nome` | **[DA DEFINIRE]** | Organizzazione criminale semi-segreta; mercato nero, rifugi |

### Signorie (10 — governano villaggi e città)

**[DA DEFINIRE]** — nomi display, storia, territorio controllato, rapporti tra loro.

ID implementati nel codice: **[verificare `data/factions/` per la lista completa]**

### Fazioni nemiche / non-joinabili

| ID | Tipo | Famiglia nemici associata |
|----|------|--------------------------|
| `fuorilegge` | Criminali | humanoid (bandit, outlaw) |
| `non_morti` | Piaga | undead |
| `bestie` | Fauna pericolosa | beast |
| `demoni` | Entità maligne | demon |
| `natura` | Forze naturali | **[DA DEFINIRE]** |
| `cattedra_canone` | Istituzione religiosa/legale | **[DA DEFINIRE — è davvero nemica?]** |

### Relazioni tra fazioni
- Matrice in `data/factions/relations.json`
- Propagazione: gerarchica (10% parent/figli) + laterale (30% × segno, soglia |rel| ≥ 20)
- **[DA DEFINIRE]**: background narrativo dei conflitti principali

---

## Crimini e Legge

- I crimini sono registrati per città (`criminal_record`)
- La milizia (`milizia_campane`) è la fazione delle guardie cittadine
- Attaccare un NPC richiede l'`amuleto_del_sangue` (slot neck) — simbolo di **[DA DEFINIRE]**
- **[DA DEFINIRE]**: sistema legale narrativo, pene, prescrizione

---

## Magia e Classi

### Sistema di classi
- 22+ classi implementate (tier 1–6 pianificate)
- Ogni personaggio ha una classe corrente; le passive delle classi precedenti si mantengono (futuro)
- **Rispecializzazione**: possibile con `class_license` (oggetto speciale)

### Classi e loro implicazioni narrative

**[DA DEFINIRE per ogni classe]** — background, perché esiste, dove si addestra, organizzazioni associate.

Classi base note: `noob`, `guerriero`, `ladro`, `mago`, `chierico`, `ranger`, `druido`, `negromante`, `eletto`, e altre.

### Magia
**[DA DEFINIRE]**: come funziona la magia nel mondo? È rara? Regolamentata? La `cattedra_canone` la controlla?

---

## Creature e Famiglie

| Famiglia | Esempi nemici | Note lore |
|----------|---------------|-----------|
| `humanoid` | goblin, bandit, outlaw | Razze umanoidi (non necessariamente umane) |
| `beast` | **[DA DEFINIRE]** | Fauna selvatica pericolosa |
| `undead` | **[DA DEFINIRE]** | Morti rianimati; legati a `non_morti` |
| `demon` | **[DA DEFINIRE]** | Origine: **[DA DEFINIRE]** |
| `construct` | **[DA DEFINIRE]** | Creature artificiali |
| `dragon` | dragon_whelp, ancient_dragon | **[DA DEFINIRE]** |
| `aberration` | **[DA DEFINIRE]** | Entità fuori dalla natura ordinaria |

---

## Oggetti notevoli

| ID | Nome | Lore |
|----|------|------|
| `amuleto_del_sangue` | Amuleto del Sangue | Permette di attaccare umanoidi; **[DA DEFINIRE]** origine |
| `class_license` | Licenza di Classe | Permette la rispecializzazione; **[DA DEFINIRE]** chi le emette |
| `pergamena_identificazione` | Pergamena di Identificazione | **[DA DEFINIRE]** |
| Item segni fazione | Patente, Distintivo, ecc. | Oggetti che segnalano appartenenza a una fazione |

---

## Questioni lore aperte (da decidere)

- Nome del mondo e del continente
- Evento fondante del Canone (anno 0)
- Ruolo narrativo della `cattedra_canone` (alleata? nemica? neutrale?)
- Sistema di magia: regolamentazione, origine, scuole
- Background di ogni singola classe
- Storia del dungeon (perché esiste, chi l'ha costruito)
- Nomi ufficiali di villaggi e città
- Rapporti narrativi tra le 10 signorie
- Origine dell'`amuleto_del_sangue`
- Perché il personaggio inizia come `noob` — chi è il PG nel mondo?

@tool
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# TILE CATEGORIES
# ═══════════════════════════════════════════════════════════════════════════════

const CELL       := 16
const FONT_SIZE  := 13
const BASELINE_Y := 12
const THEME_BG   := Color(0.06, 0.05, 0.03)

const CAT_FLOOR     := 0
const CAT_WALL_ST   := 1
const CAT_WALL_WD   := 2
const CAT_FENCE     := 3
const CAT_BARRICADE := 4
const CAT_PATH      := 5
const CAT_SOLCO     := 6
const CAT_BUCA      := 7
const CAT_ENTITY    := 8
const CAT_MARKER    := 9
# decorative (no gameplay blocking by default)
const CAT_DECO_CONT := 10   # Contenitori
const CAT_DECO_MOB  := 11   # Mobili
const CAT_DECO_TOOL := 12   # Artigianato
const CAT_DECO_FOOD := 13   # Cibo / Agricoltura
const CAT_DECO_DECO := 14   # Decorazioni
const CAT_DECO_NAT  := 15   # Natura
const CAT_DECO_ARCH := 16   # Strutture

# Tile encoding: value = category * 16 + variant_index
# CAT_FLOOR var 0 = 0  (old T_FLOOR compatible)
# CAT_WALL_ST var 0 = 16

const BLOCKED_CATS: Array = [CAT_WALL_ST, CAT_WALL_WD, CAT_FENCE, CAT_BARRICADE, CAT_BUCA]

const TILE_CATS: Dictionary = {
	CAT_FLOOR: {
		"label": "Pavimento",
		"vars": [
			{"c": ".",  "col": Color(0.50, 0.42, 0.28)},
			{"c": "·",  "col": Color(0.48, 0.40, 0.26)},
			{"c": ",",  "col": Color(0.42, 0.35, 0.22)},
			{"c": "'",  "col": Color(0.45, 0.38, 0.24)},
			{"c": "`",  "col": Color(0.46, 0.39, 0.25)},
			{"c": "_",  "col": Color(0.54, 0.46, 0.32)},
			{"c": "░",  "col": Color(0.50, 0.42, 0.28)},
			{"c": "▒",  "col": Color(0.44, 0.37, 0.23)},
			{"c": "▓",  "col": Color(0.38, 0.32, 0.20)},
			{"c": "~",  "col": Color(0.40, 0.33, 0.21)},
		],
	},
	CAT_WALL_ST: {
		"label": "Muro Pietra",
		"vars": [
			{"c": "#",  "col": Color(0.75, 0.64, 0.46)},
			{"c": "█",  "col": Color(0.72, 0.62, 0.44)},
			{"c": "▓",  "col": Color(0.68, 0.58, 0.40)},
			{"c": "▒",  "col": Color(0.65, 0.55, 0.37)},
			{"c": "░",  "col": Color(0.78, 0.67, 0.49)},
			{"c": "■",  "col": Color(0.70, 0.60, 0.42)},
			{"c": "▪",  "col": Color(0.73, 0.63, 0.45)},
			{"c": "+",  "col": Color(0.76, 0.65, 0.47)},
			{"c": "=",  "col": Color(0.74, 0.64, 0.46)},
			{"c": "≡",  "col": Color(0.77, 0.66, 0.48)},
		],
	},
	CAT_WALL_WD: {
		"label": "Muro Legno",
		"vars": [
			{"c": "#",  "col": Color(0.58, 0.38, 0.18)},
			{"c": "|",  "col": Color(0.60, 0.40, 0.20)},
			{"c": "=",  "col": Color(0.56, 0.36, 0.16)},
			{"c": "+",  "col": Color(0.62, 0.42, 0.22)},
			{"c": "X",  "col": Color(0.55, 0.35, 0.15)},
			{"c": "╫",  "col": Color(0.59, 0.39, 0.19)},
			{"c": "║",  "col": Color(0.61, 0.41, 0.21)},
			{"c": "╥",  "col": Color(0.57, 0.37, 0.17)},
			{"c": "╨",  "col": Color(0.63, 0.43, 0.23)},
			{"c": "┃",  "col": Color(0.64, 0.44, 0.24)},
		],
	},
	CAT_FENCE: {
		"label": "Staccionata",
		"vars": [
			{"c": "|",  "col": Color(0.52, 0.35, 0.18)},
			{"c": "/",  "col": Color(0.54, 0.37, 0.20)},
			{"c": "\\", "col": Color(0.50, 0.33, 0.16)},
			{"c": "+",  "col": Color(0.56, 0.39, 0.22)},
			{"c": "*",  "col": Color(0.48, 0.31, 0.14)},
			{"c": "†",  "col": Color(0.53, 0.36, 0.19)},
			{"c": "-",  "col": Color(0.55, 0.38, 0.21)},
			{"c": "~",  "col": Color(0.51, 0.34, 0.17)},
			{"c": "≠",  "col": Color(0.57, 0.40, 0.23)},
			{"c": "‡",  "col": Color(0.49, 0.32, 0.15)},
		],
	},
	CAT_BARRICADE: {
		"label": "Barricata",
		"vars": [
			{"c": "%",  "col": Color(0.55, 0.42, 0.28)},
			{"c": "X",  "col": Color(0.57, 0.44, 0.30)},
			{"c": "#",  "col": Color(0.53, 0.40, 0.26)},
			{"c": "@",  "col": Color(0.59, 0.46, 0.32)},
			{"c": "*",  "col": Color(0.51, 0.38, 0.24)},
			{"c": "!",  "col": Color(0.61, 0.48, 0.34)},
			{"c": "†",  "col": Color(0.56, 0.43, 0.29)},
			{"c": "≈",  "col": Color(0.54, 0.41, 0.27)},
			{"c": "§",  "col": Color(0.58, 0.45, 0.31)},
			{"c": "¶",  "col": Color(0.52, 0.39, 0.25)},
		],
	},
	CAT_PATH: {
		"label": "Sentiero",
		"vars": [
			{"c": ",",  "col": Color(0.45, 0.35, 0.22)},
			{"c": ".",  "col": Color(0.47, 0.37, 0.24)},
			{"c": "·",  "col": Color(0.43, 0.33, 0.20)},
			{"c": "-",  "col": Color(0.49, 0.39, 0.26)},
			{"c": "~",  "col": Color(0.41, 0.31, 0.18)},
			{"c": "░",  "col": Color(0.46, 0.36, 0.23)},
			{"c": "_",  "col": Color(0.50, 0.40, 0.27)},
			{"c": "=",  "col": Color(0.44, 0.34, 0.21)},
			{"c": ";",  "col": Color(0.48, 0.38, 0.25)},
			{"c": "'",  "col": Color(0.42, 0.32, 0.19)},
		],
	},
	CAT_SOLCO: {
		"label": "Solchi",
		"vars": [
			{"c": "=",  "col": Color(0.32, 0.20, 0.10)},
			{"c": "-",  "col": Color(0.34, 0.22, 0.12)},
			{"c": "~",  "col": Color(0.30, 0.18, 0.08)},
			{"c": "≈",  "col": Color(0.36, 0.24, 0.14)},
			{"c": "_",  "col": Color(0.28, 0.16, 0.06)},
			{"c": ":",  "col": Color(0.33, 0.21, 0.11)},
			{"c": "·",  "col": Color(0.35, 0.23, 0.13)},
			{"c": ",",  "col": Color(0.31, 0.19, 0.09)},
			{"c": ";",  "col": Color(0.37, 0.25, 0.15)},
			{"c": "'",  "col": Color(0.29, 0.17, 0.07)},
		],
	},
	CAT_BUCA: {
		"label": "Buca",
		"vars": [
			{"c": "O",  "col": Color(0.20, 0.16, 0.12)},
			{"c": "0",  "col": Color(0.22, 0.18, 0.14)},
			{"c": "°",  "col": Color(0.18, 0.14, 0.10)},
			{"c": "o",  "col": Color(0.24, 0.20, 0.16)},
			{"c": "@",  "col": Color(0.16, 0.12, 0.08)},
			{"c": "◎",  "col": Color(0.21, 0.17, 0.13)},
			{"c": "●",  "col": Color(0.19, 0.15, 0.11)},
			{"c": "•",  "col": Color(0.23, 0.19, 0.15)},
			{"c": "○",  "col": Color(0.17, 0.13, 0.09)},
			{"c": "◯",  "col": Color(0.25, 0.21, 0.17)},
		],
	},
	CAT_DECO_CONT: {
		"label": "Contenitori",
		"vars": [
			{"c": "O",  "col": Color(0.55, 0.35, 0.15), "tip": "Barile"},
			{"c": "0",  "col": Color(0.45, 0.28, 0.10), "tip": "Botte"},
			{"c": "o",  "col": Color(0.62, 0.42, 0.20), "tip": "Barile piccolo"},
			{"c": "8",  "col": Color(0.48, 0.30, 0.12), "tip": "Botte grande"},
			{"c": "%",  "col": Color(0.68, 0.57, 0.35), "tip": "Sacco"},
			{"c": "&",  "col": Color(0.60, 0.50, 0.28), "tip": "Sacchetto"},
			{"c": "U",  "col": Color(0.70, 0.46, 0.22), "tip": "Urna"},
			{"c": "u",  "col": Color(0.74, 0.52, 0.26), "tip": "Vaso"},
			{"c": "n",  "col": Color(0.76, 0.54, 0.28), "tip": "Orcio"},
			{"c": "c",  "col": Color(0.62, 0.50, 0.26), "tip": "Cestino"},
			{"c": "C",  "col": Color(0.56, 0.44, 0.22), "tip": "Cesta"},
			{"c": "b",  "col": Color(0.52, 0.38, 0.18), "tip": "Borsa di pelle"},
			{"c": "q",  "col": Color(0.72, 0.50, 0.24), "tip": "Brocca"},
			{"c": "Q",  "col": Color(0.78, 0.56, 0.28), "tip": "Anfora"},
			{"c": "j",  "col": Color(0.30, 0.55, 0.28), "tip": "Bottiglia"},
			{"c": "J",  "col": Color(0.76, 0.60, 0.30), "tip": "Giara"},
		],
	},
	CAT_DECO_MOB: {
		"label": "Mobili",
		"vars": [
			{"c": "T",  "col": Color(0.62, 0.44, 0.20), "tip": "Tavolo"},
			{"c": "t",  "col": Color(0.58, 0.40, 0.17), "tip": "Tavolino"},
			{"c": "H",  "col": Color(0.55, 0.38, 0.16), "tip": "Sedia"},
			{"c": "h",  "col": Color(0.52, 0.35, 0.14), "tip": "Sgabello"},
			{"c": "L",  "col": Color(0.65, 0.46, 0.22), "tip": "Panca"},
			{"c": "l",  "col": Color(0.60, 0.42, 0.18), "tip": "Lettino"},
			{"c": "W",  "col": Color(0.55, 0.36, 0.15), "tip": "Armadio"},
			{"c": "w",  "col": Color(0.52, 0.34, 0.13), "tip": "Credenza"},
			{"c": "D",  "col": Color(0.60, 0.43, 0.19), "tip": "Scrivania"},
			{"c": "d",  "col": Color(0.57, 0.40, 0.16), "tip": "Bancone"},
			{"c": "E",  "col": Color(0.50, 0.33, 0.13), "tip": "Libreria"},
			{"c": "e",  "col": Color(0.53, 0.36, 0.14), "tip": "Scaffale"},
			{"c": "M",  "col": Color(0.56, 0.38, 0.15), "tip": "Manichino"},
			{"c": "m",  "col": Color(0.53, 0.35, 0.13), "tip": "Appendiabiti"},
			{"c": "P",  "col": Color(0.68, 0.50, 0.25), "tip": "Trono"},
			{"c": "p",  "col": Color(0.65, 0.48, 0.22), "tip": "Piedistallo"},
		],
	},
	CAT_DECO_TOOL: {
		"label": "Artigianato",
		"vars": [
			{"c": "A",  "col": Color(0.58, 0.58, 0.62), "tip": "Incudine"},
			{"c": "V",  "col": Color(0.88, 0.48, 0.15), "tip": "Forgia"},
			{"c": "K",  "col": Color(0.60, 0.60, 0.65), "tip": "Mola"},
			{"c": "k",  "col": Color(0.56, 0.56, 0.60), "tip": "Piano da lavoro"},
			{"c": "Y",  "col": Color(0.60, 0.50, 0.36), "tip": "Telaio"},
			{"c": "y",  "col": Color(0.56, 0.46, 0.32), "tip": "Filatoio"},
			{"c": "G",  "col": Color(0.52, 0.52, 0.55), "tip": "Mantice"},
			{"c": "g",  "col": Color(0.42, 0.55, 0.50), "tip": "Calderone"},
			{"c": "R",  "col": Color(0.55, 0.52, 0.50), "tip": "Mortaio"},
			{"c": "r",  "col": Color(0.52, 0.48, 0.45), "tip": "Torchio"},
			{"c": "Z",  "col": Color(0.58, 0.58, 0.62), "tip": "Sega da legno"},
			{"c": "z",  "col": Color(0.55, 0.55, 0.58), "tip": "Morsa"},
			{"c": "F",  "col": Color(0.82, 0.36, 0.15), "tip": "Fornace"},
			{"c": "f",  "col": Color(0.72, 0.32, 0.12), "tip": "Forno da pane"},
			{"c": "I",  "col": Color(0.65, 0.65, 0.70), "tip": "Pressa"},
			{"c": "i",  "col": Color(0.62, 0.62, 0.66), "tip": "Bilancia"},
		],
	},
	CAT_DECO_FOOD: {
		"label": "Cibo / Agric.",
		"vars": [
			{"c": "!",  "col": Color(0.85, 0.76, 0.22), "tip": "Covone di grano"},
			{"c": "|",  "col": Color(0.72, 0.60, 0.18), "tip": "Fascio di canne"},
			{"c": "\"", "col": Color(0.68, 0.56, 0.16), "tip": "Fieno tagliato"},
			{"c": ";",  "col": Color(0.35, 0.62, 0.18), "tip": "Erbe aromatiche"},
			{"c": ":",  "col": Color(0.30, 0.58, 0.15), "tip": "Piantine"},
			{"c": "^",  "col": Color(0.38, 0.66, 0.20), "tip": "Piantina da orto"},
			{"c": ">",  "col": Color(0.62, 0.78, 0.25), "tip": "Mangiatoia"},
			{"c": "<",  "col": Color(0.58, 0.50, 0.18), "tip": "Trogolo"},
			{"c": "*",  "col": Color(0.72, 0.58, 0.16), "tip": "Arnia"},
			{"c": "$",  "col": Color(0.82, 0.72, 0.26), "tip": "Rastrelliera vino"},
			{"c": "@",  "col": Color(0.78, 0.48, 0.22), "tip": "Ceppo da macellaio"},
			{"c": "?",  "col": Color(0.65, 0.72, 0.22), "tip": "Erba medica"},
			{"c": "+",  "col": Color(0.75, 0.66, 0.24), "tip": "Barile salumi"},
			{"c": "=",  "col": Color(0.48, 0.68, 0.18), "tip": "Filare da orto"},
			{"c": "~",  "col": Color(0.40, 0.65, 0.20), "tip": "Pianta selvatica"},
			{"c": "#",  "col": Color(0.62, 0.52, 0.20), "tip": "Rastrelliera fieno"},
		],
	},
	CAT_DECO_DECO: {
		"label": "Decorazioni",
		"vars": [
			{"c": "†",  "col": Color(0.88, 0.78, 0.28), "tip": "Candelabro"},
			{"c": "‡",  "col": Color(0.85, 0.75, 0.25), "tip": "Portatorcia"},
			{"c": "§",  "col": Color(0.70, 0.32, 0.88), "tip": "Stendardo"},
			{"c": "¶",  "col": Color(0.65, 0.28, 0.82), "tip": "Stemma araldico"},
			{"c": "Σ",  "col": Color(0.88, 0.80, 0.30), "tip": "Statua piccola"},
			{"c": "Ψ",  "col": Color(0.82, 0.72, 0.26), "tip": "Statua grande"},
			{"c": "Φ",  "col": Color(0.90, 0.82, 0.32), "tip": "Altare"},
			{"c": "Λ",  "col": Color(0.72, 0.62, 0.22), "tip": "Insegna di palo"},
			{"c": "Π",  "col": Color(0.68, 0.58, 0.20), "tip": "Bacheca"},
			{"c": "Θ",  "col": Color(0.78, 0.68, 0.26), "tip": "Meridiana"},
			{"c": "Γ",  "col": Color(0.65, 0.55, 0.18), "tip": "Insegna appesa"},
			{"c": "Δ",  "col": Color(0.80, 0.70, 0.28), "tip": "Monolite"},
			{"c": "Ξ",  "col": Color(0.68, 0.55, 0.20), "tip": "Dipinto"},
			{"c": "∞",  "col": Color(0.60, 0.88, 0.88), "tip": "Specchio"},
			{"c": "≠",  "col": Color(0.88, 0.60, 0.20), "tip": "Orologio"},
			{"c": "≈",  "col": Color(0.72, 0.42, 0.88), "tip": "Tappeto"},
		],
	},
	CAT_DECO_NAT: {
		"label": "Natura",
		"vars": [
			{"c": "♣",  "col": Color(0.22, 0.58, 0.18), "tip": "Cespuglio"},
			{"c": "♠",  "col": Color(0.18, 0.52, 0.14), "tip": "Cespuglio spinoso"},
			{"c": "*",  "col": Color(0.88, 0.80, 0.22), "tip": "Fiore"},
			{"c": "^",  "col": Color(0.25, 0.55, 0.18), "tip": "Alberello"},
			{"c": "~",  "col": Color(0.28, 0.62, 0.22), "tip": "Erba alta"},
			{"c": "`",  "col": Color(0.22, 0.48, 0.14), "tip": "Muschio"},
			{"c": "Ψ",  "col": Color(0.30, 0.65, 0.25), "tip": "Felce"},
			{"c": "ω",  "col": Color(0.25, 0.52, 0.18), "tip": "Rampicante"},
			{"c": "Ω",  "col": Color(0.20, 0.48, 0.14), "tip": "Rovo"},
			{"c": "∞",  "col": Color(0.35, 0.60, 0.22), "tip": "Vite"},
			{"c": "≈",  "col": Color(0.22, 0.55, 0.18), "tip": "Alghe"},
			{"c": "§",  "col": Color(0.40, 0.30, 0.18), "tip": "Ceppo secco"},
			{"c": "8",  "col": Color(0.28, 0.52, 0.18), "tip": "Fungo grande"},
			{"c": "o",  "col": Color(0.32, 0.55, 0.20), "tip": "Fungo piccolo"},
			{"c": ".",  "col": Color(0.55, 0.45, 0.25), "tip": "Ossario"},
			{"c": "°",  "col": Color(0.78, 0.72, 0.60), "tip": "Teschio"},
		],
	},
	CAT_DECO_ARCH: {
		"label": "Strutture",
		"vars": [
			{"c": "│",  "col": Color(0.62, 0.62, 0.68), "tip": "Pilastro"},
			{"c": "║",  "col": Color(0.58, 0.58, 0.65), "tip": "Colonna"},
			{"c": "─",  "col": Color(0.60, 0.60, 0.66), "tip": "Trave orizzontale"},
			{"c": "═",  "col": Color(0.56, 0.56, 0.62), "tip": "Trave doppia"},
			{"c": "┼",  "col": Color(0.62, 0.62, 0.68), "tip": "Incrocio travi"},
			{"c": "╬",  "col": Color(0.58, 0.58, 0.64), "tip": "Croce strutturale"},
			{"c": "┐",  "col": Color(0.60, 0.60, 0.66), "tip": "Angolo architettonico"},
			{"c": "└",  "col": Color(0.60, 0.60, 0.66), "tip": "Contrafforte"},
			{"c": "╔",  "col": Color(0.56, 0.56, 0.62), "tip": "Arco"},
			{"c": "╗",  "col": Color(0.56, 0.56, 0.62), "tip": "Arco inverso"},
			{"c": "▲",  "col": Color(0.55, 0.55, 0.60), "tip": "Guglia"},
			{"c": "▼",  "col": Color(0.55, 0.55, 0.60), "tip": "Stalattite"},
			{"c": "◄",  "col": Color(0.52, 0.62, 0.72), "tip": "Grata"},
			{"c": "►",  "col": Color(0.52, 0.62, 0.72), "tip": "Feritoia"},
			{"c": "≡",  "col": Color(0.55, 0.55, 0.60), "tip": "Gradino"},
			{"c": "∏",  "col": Color(0.58, 0.58, 0.64), "tip": "Portale"},
		],
	},
}

const ENT_DEFS: Array = [
	{"kind": "npc",        "c": "N", "col": Color(1.00, 0.78, 0.20), "label": "NPC"},
	{"kind": "save_point", "c": "Ω", "col": Color(0.40, 0.88, 0.95), "label": "Save Point"},
	{"kind": "transition", "c": ">", "col": Color(1.00, 0.48, 0.12), "label": "Transizione"},
	{"kind": "port",       "c": "P", "col": Color(0.30, 0.70, 1.00), "label": "Porto"},
	{"kind": "door",       "c": "+", "col": Color(0.65, 0.45, 0.20), "label": "Porta"},
	{"kind": "plant",      "c": "♣", "col": Color(0.25, 0.65, 0.20), "label": "Pianta"},
	{"kind": "well",       "c": "o", "col": Color(0.40, 0.65, 0.85), "label": "Pozzo"},
	{"kind": "item",         "c": "?", "col": Color(0.85, 0.75, 0.30), "label": "Oggetto"},
	{"kind": "light_source", "c": "*", "col": Color(1.00, 0.72, 0.10), "label": "Torcia",        "default_radius": 2},
	{"kind": "light_source", "c": "*", "col": Color(1.00, 0.90, 0.60), "label": "Lanterna",      "default_radius": 3},
	{"kind": "light_source", "c": "*", "col": Color(0.95, 0.85, 0.50), "label": "Candela",       "default_radius": 1},
	{"kind": "light_source", "c": "*", "col": Color(1.00, 0.52, 0.10), "label": "Braciere",      "default_radius": 4},
	{"kind": "light_source", "c": "*", "col": Color(1.00, 0.95, 0.90), "label": "Fiamma Bianca", "default_radius": 3},
	{"kind": "light_source", "c": "*", "col": Color(0.38, 0.68, 1.00), "label": "Luce Magica",   "default_radius": 3},
	{"kind": "light_source", "c": "*", "col": Color(0.28, 1.00, 0.48), "label": "Luce Verde",    "default_radius": 3},
	{"kind": "light_source", "c": "*", "col": Color(0.75, 0.28, 1.00), "label": "Luce Viola",    "default_radius": 3},
]

const MARKER_DEFS: Array = [
	{"kind": "spawn_point",   "c": "S", "col": Color(0.20, 1.00, 0.40), "label": "Spawn"},
	{"kind": "event_trigger", "c": "E", "col": Color(0.75, 0.30, 0.90), "label": "Trigger"},
	{"kind": "exit",          "c": "X", "col": Color(0.20, 0.90, 0.90), "label": "Uscita"},
]

const EDITOR_ONLY_KINDS: Array  = ["spawn_point", "event_trigger", "exit"]
const NIGHT_HIDDEN_KINDS: Array = ["npc", "enemy", "guard"]

const CAT_DEFS: Array = [
	{"id": CAT_FLOOR,     "label": "Pavimento"},
	{"id": CAT_WALL_ST,   "label": "M. Pietra"},
	{"id": CAT_WALL_WD,   "label": "M. Legno"},
	{"id": CAT_FENCE,     "label": "Staccionata"},
	{"id": CAT_BARRICADE, "label": "Barricata"},
	{"id": CAT_PATH,      "label": "Sentiero"},
	{"id": CAT_SOLCO,     "label": "Solchi"},
	{"id": CAT_BUCA,      "label": "Buca"},
	{"id": CAT_ENTITY,    "label": "Entità"},
	{"id": CAT_MARKER,    "label": "Marker"},
	{"id": CAT_DECO_CONT, "label": "Contenitori"},
	{"id": CAT_DECO_MOB,  "label": "Mobili"},
	{"id": CAT_DECO_TOOL, "label": "Artigianato"},
	{"id": CAT_DECO_FOOD, "label": "Cibo/Agric."},
	{"id": CAT_DECO_DECO, "label": "Decorazioni"},
	{"id": CAT_DECO_NAT,  "label": "Natura"},
	{"id": CAT_DECO_ARCH, "label": "Strutture"},
]

# ── city data ──────────────────────────────────────────────────────────────────
var _cid:               String = "nuova_citta"
var _cname:             String = "Nuova Città"
var _ctype:             String = "village"
var _csignoria:         String = ""
var _ccorporazioni:     Array  = []
var _cminimap_enabled:  bool   = false
var _width:         int    = 40
var _height:        int    = 30
var _tiles:         Array  = []   # [y][x] → cat*16 + variant
var _entities:      Array  = []   # [{kind, x, y, uid, params}]
var _lights_preview: bool  = false

# ── ui refs ────────────────────────────────────────────────────────────────────
var _id_edit:       LineEdit
var _name_edit:     LineEdit
var _type_opt:      OptionButton
var _w_spin:        SpinBox
var _h_spin:        SpinBox
var _canvas:        Control
var _props_box:     VBoxContainer
var _status_lbl:    Label
var _cat_btns:      Array[Button] = []
var _var_btns:      Array[Button] = []
var _var_grid:      GridContainer
var _erase_btn:          Button
var _lights_preview_btn: Button
var _load_menu:        PopupMenu
var _signoria_opt:     OptionButton
var _signoria_ids:     Array = []   # parallel to OptionButton items; [0] = ""
var _signoria_names:   Array = []   # parallel to OptionButton items; [0] = "— Nessuna —"
var _corp_summary_lbl:   Label
var _corp_menu:          PopupMenu
var _minimap_check:      CheckBox
var _corp_all:         Array = []   # [{id, name}] corporations available for selection

# ── editor state ───────────────────────────────────────────────────────────────
var _active_cat: int      = CAT_FLOOR
var _active_var: int      = 0
var _is_erasing: bool     = false
var _painting:   bool     = false
var _hover:      Vector2i = Vector2i(-1, -1)
var _sel:        int      = -1
var _ctx_menu:   PopupMenu
var _ctx_cell:   Vector2i = Vector2i(-1, -1)

# ── editor data lists (populated from JSON files) ─────────────────────────────
var _all_factions:  Array = []   # [{id, name}] every faction file recursively
var _all_dialogues: Array = []   # [{id, name}] from data/dialogue/
var _all_quests:    Array = []   # [{id, name}] from data/quests/
var _all_items:     Array = []   # [{id, name}] from data/items/ recursively

# ── shared multiselect popup ───────────────────────────────────────────────────
var _prop_select_popup: PopupMenu
var _prop_select_opts:  Array = []
var _prop_select_cb:    Callable

# ── multi-floor state ──────────────────────────────────────────────────────────
var _floors:           Array    = []   # [{label, width, height, tiles, entities}]
var _current_floor:    int      = 0
var _updating_floor_ui: bool    = false
var _floor_nav_lbl:    Label
var _floor_prev_btn:   Button
var _floor_next_btn:   Button
var _floor_name_edit:  LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_faction_lists()
	_build_ui()
	_new_city()
	get_window().size_changed.connect(_on_window_resized)


func _on_window_resized() -> void:
	size = get_window().size


# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	root.add_child(hdr)

	_lbl(hdr, "ID:")
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size.x = 110
	_id_edit.text_changed.connect(func(t: String) -> void: _cid = t)
	hdr.add_child(_id_edit)

	_lbl(hdr, "Nome:")
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 140
	_name_edit.text_changed.connect(func(t: String) -> void: _cname = t)
	hdr.add_child(_name_edit)

	_lbl(hdr, "Tipo:")
	_type_opt = OptionButton.new()
	for t: String in ["village", "city", "building", "dungeon", "ruin"]:
		_type_opt.add_item(t)
	_type_opt.item_selected.connect(func(i: int) -> void: _ctype = _type_opt.get_item_text(i))
	hdr.add_child(_type_opt)

	_lbl(hdr, "W:")
	_w_spin = _spin(10, 200, _width)
	hdr.add_child(_w_spin)
	_lbl(hdr, "H:")
	_h_spin = _spin(10, 150, _height)
	hdr.add_child(_h_spin)

	var apply_btn := Button.new()
	apply_btn.text = "Applica"
	apply_btn.pressed.connect(_apply_size)
	hdr.add_child(apply_btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)

	for txt: String in ["Nuovo", "Carica…", "Salva"]:
		var b := Button.new()
		b.text = txt
		match txt:
			"Nuovo":   b.pressed.connect(_new_city)
			"Carica…": b.pressed.connect(_open_load_menu)
			"Salva":   b.pressed.connect(_save_city)
		hdr.add_child(b)

	_status_lbl = Label.new()
	_status_lbl.custom_minimum_size.x = 160
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	hdr.add_child(_status_lbl)

	# Faction row (signoria + corporazioni)
	var faction_row := HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 4)
	root.add_child(faction_row)

	_lbl(faction_row, "Signoria:")
	_signoria_opt = OptionButton.new()
	_signoria_opt.add_theme_font_size_override("font_size", 11)
	for i: int in _signoria_ids.size():
		_signoria_opt.add_item(_signoria_names[i])
	_signoria_opt.item_selected.connect(func(idx: int) -> void:
		_csignoria = _signoria_ids[idx] if idx < _signoria_ids.size() else "")
	faction_row.add_child(_signoria_opt)

	_lbl(faction_row, "  Corporazioni:")
	_corp_summary_lbl = Label.new()
	_corp_summary_lbl.custom_minimum_size.x = 90
	_corp_summary_lbl.add_theme_font_size_override("font_size", 11)
	_corp_summary_lbl.text = "0 selezionate"
	faction_row.add_child(_corp_summary_lbl)

	var corp_btn := Button.new()
	corp_btn.text = "Modifica…"
	corp_btn.add_theme_font_size_override("font_size", 11)
	corp_btn.pressed.connect(_open_corp_menu.bind(corp_btn))
	faction_row.add_child(corp_btn)

	_minimap_check = CheckBox.new()
	_minimap_check.text = "Minimap"
	_minimap_check.add_theme_font_size_override("font_size", 11)
	_minimap_check.toggled.connect(func(v: bool) -> void: _cminimap_enabled = v)
	faction_row.add_child(_minimap_check)

	_corp_menu = PopupMenu.new()
	_corp_menu.hide_on_checkable_item_selection = false
	for i: int in _corp_all.size():
		var corp: Dictionary = _corp_all[i]
		_corp_menu.add_check_item(str(corp.get("name", "")), i)
	_corp_menu.id_pressed.connect(_on_corp_menu_pressed)
	add_child(_corp_menu)

	root.add_child(HSeparator.new())

	# Floor navigation row
	var floor_row := HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 4)
	root.add_child(floor_row)

	_floor_prev_btn = Button.new()
	_floor_prev_btn.text = "◀"
	_floor_prev_btn.custom_minimum_size = Vector2(26, 22)
	_floor_prev_btn.add_theme_font_size_override("font_size", 10)
	_floor_prev_btn.tooltip_text = "Piano precedente"
	_floor_prev_btn.pressed.connect(func() -> void: _switch_floor(_current_floor - 1))
	floor_row.add_child(_floor_prev_btn)

	_floor_nav_lbl = Label.new()
	_floor_nav_lbl.custom_minimum_size.x = 180
	_floor_nav_lbl.add_theme_font_size_override("font_size", 10)
	floor_row.add_child(_floor_nav_lbl)

	_floor_next_btn = Button.new()
	_floor_next_btn.text = "▶"
	_floor_next_btn.custom_minimum_size = Vector2(26, 22)
	_floor_next_btn.add_theme_font_size_override("font_size", 10)
	_floor_next_btn.tooltip_text = "Piano successivo"
	_floor_next_btn.pressed.connect(func() -> void: _switch_floor(_current_floor + 1))
	floor_row.add_child(_floor_next_btn)

	_lbl(floor_row, "  Nome:")
	_floor_name_edit = LineEdit.new()
	_floor_name_edit.custom_minimum_size.x = 120
	_floor_name_edit.add_theme_font_size_override("font_size", 10)
	_floor_name_edit.text_changed.connect(func(t: String) -> void:
		if _updating_floor_ui or _current_floor >= _floors.size():
			return
		(_floors[_current_floor] as Dictionary)["label"] = t
		if _floor_nav_lbl:
			_floor_nav_lbl.text = "Piano %d/%d — %s" % [_current_floor + 1, _floors.size(), t])
	floor_row.add_child(_floor_name_edit)

	var add_floor_btn := Button.new()
	add_floor_btn.text = "+ Piano"
	add_floor_btn.add_theme_font_size_override("font_size", 10)
	add_floor_btn.tooltip_text = "Aggiungi nuovo piano"
	add_floor_btn.pressed.connect(_add_floor)
	floor_row.add_child(add_floor_btn)

	var rem_floor_btn := Button.new()
	rem_floor_btn.text = "🗑"
	rem_floor_btn.add_theme_font_size_override("font_size", 10)
	rem_floor_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	rem_floor_btn.tooltip_text = "Rimuovi piano corrente"
	rem_floor_btn.pressed.connect(_remove_floor)
	floor_row.add_child(rem_floor_btn)

	root.add_child(HSeparator.new())

	# Body
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	root.add_child(body)

	# ── Palette ──────────────────────────────────────────────────────────────
	var pal_scroll := ScrollContainer.new()
	pal_scroll.custom_minimum_size.x = 206
	pal_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	pal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(pal_scroll)

	var pal_vbox := VBoxContainer.new()
	pal_vbox.custom_minimum_size.x = 200
	pal_vbox.add_theme_constant_override("separation", 4)
	pal_scroll.add_child(pal_vbox)

	var cat_lbl := Label.new()
	cat_lbl.text = "CATEGORIA"
	cat_lbl.add_theme_font_size_override("font_size", 10)
	cat_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	pal_vbox.add_child(cat_lbl)

	var cat_grid := GridContainer.new()
	cat_grid.columns = 2
	cat_grid.add_theme_constant_override("h_separation", 2)
	cat_grid.add_theme_constant_override("v_separation", 2)
	pal_vbox.add_child(cat_grid)

	for i: int in CAT_DEFS.size():
		var def: Dictionary = CAT_DEFS[i] as Dictionary
		var cat_id: int = int(def["id"])
		var btn := Button.new()
		btn.text = str(def["label"])
		btn.tooltip_text = str(def["label"])
		btn.toggle_mode = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(96, 26)
		btn.pressed.connect(func() -> void: _select_cat(cat_id))
		cat_grid.add_child(btn)
		_cat_btns.append(btn)

	pal_vbox.add_child(HSeparator.new())

	var var_lbl := Label.new()
	var_lbl.text = "VARIANTE"
	var_lbl.add_theme_font_size_override("font_size", 10)
	var_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	pal_vbox.add_child(var_lbl)

	_var_grid = GridContainer.new()
	_var_grid.columns = 5
	_var_grid.add_theme_constant_override("h_separation", 2)
	_var_grid.add_theme_constant_override("v_separation", 2)
	pal_vbox.add_child(_var_grid)

	pal_vbox.add_child(HSeparator.new())

	_erase_btn = Button.new()
	_erase_btn.text = "🗑 Cancella"
	_erase_btn.toggle_mode = true
	_erase_btn.add_theme_font_size_override("font_size", 11)
	_erase_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_erase_btn.pressed.connect(_toggle_erase)
	pal_vbox.add_child(_erase_btn)

	_lights_preview_btn = Button.new()
	_lights_preview_btn.text = "🕯 Luci notte"
	_lights_preview_btn.toggle_mode = true
	_lights_preview_btn.add_theme_font_size_override("font_size", 11)
	_lights_preview_btn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	_lights_preview_btn.pressed.connect(_toggle_lights_preview)
	pal_vbox.add_child(_lights_preview_btn)

	# ── Canvas ───────────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	var CanvasScript: GDScript = load("res://addons/city_builder/CityCanvas.gd")
	_canvas = CanvasScript.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	(_canvas as Object).set("on_draw",  Callable(self, "_draw_canvas"))
	(_canvas as Object).set("on_input", Callable(self, "_on_canvas_input"))
	scroll.add_child(_canvas)

	# ── Properties panel ─────────────────────────────────────────────────────
	var props_outer := PanelContainer.new()
	props_outer.custom_minimum_size.x = 245
	props_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(props_outer)

	var props_vbox := VBoxContainer.new()
	props_vbox.add_theme_constant_override("separation", 3)
	props_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	props_outer.add_child(props_vbox)

	var ptitle := Label.new()
	ptitle.text = "Proprietà"
	ptitle.add_theme_font_size_override("font_size", 11)
	props_vbox.add_child(ptitle)
	props_vbox.add_child(HSeparator.new())

	var props_scroll := ScrollContainer.new()
	props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	props_vbox.add_child(props_scroll)

	_props_box = VBoxContainer.new()
	_props_box.add_theme_constant_override("separation", 2)
	_props_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	props_scroll.add_child(_props_box)

	_load_menu = PopupMenu.new()
	_load_menu.id_pressed.connect(_on_load_item)
	add_child(_load_menu)

	_ctx_menu = PopupMenu.new()
	_ctx_menu.id_pressed.connect(_on_ctx_menu_pressed)
	add_child(_ctx_menu)

	_prop_select_popup = PopupMenu.new()
	_prop_select_popup.hide_on_checkable_item_selection = false
	_prop_select_popup.id_pressed.connect(_on_prop_select_pressed)
	add_child(_prop_select_popup)

	_select_cat(CAT_FLOOR)


# ── palette ────────────────────────────────────────────────────────────────────

func _select_cat(cat_id: int) -> void:
	_active_cat = cat_id
	_active_var = 0
	_is_erasing = false
	_erase_btn.button_pressed = false
	_update_cat_btns()
	_rebuild_var_grid()


func _select_var(var_idx: int) -> void:
	_active_var = var_idx
	_is_erasing = false
	_erase_btn.button_pressed = false
	_update_var_btns()


func _toggle_erase() -> void:
	_is_erasing = _erase_btn.button_pressed
	if _is_erasing:
		for btn: Button in _cat_btns:
			btn.button_pressed = false
		for btn: Button in _var_btns:
			btn.button_pressed = false


func _toggle_lights_preview() -> void:
	_lights_preview = _lights_preview_btn.button_pressed
	_canvas.queue_redraw()


func _update_cat_btns() -> void:
	for i: int in _cat_btns.size():
		var def: Dictionary = CAT_DEFS[i] as Dictionary
		_cat_btns[i].button_pressed = (int(def["id"]) == _active_cat)


func _update_var_btns() -> void:
	for i: int in _var_btns.size():
		_var_btns[i].button_pressed = (i == _active_var)


func _rebuild_var_grid() -> void:
	for child: Node in _var_grid.get_children():
		child.queue_free()
	_var_btns.clear()

	var defs: Array = _get_var_defs()
	for i: int in defs.size():
		var d: Dictionary = defs[i] as Dictionary
		var btn := Button.new()
		btn.text = str(d["c"])
		btn.toggle_mode = true
		btn.button_pressed = (i == _active_var)
		btn.custom_minimum_size = Vector2(36, 36)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", d["col"] as Color)
		if _active_cat == CAT_ENTITY or _active_cat == CAT_MARKER:
			btn.tooltip_text = str(d["label"])
		elif d.has("tip"):
			btn.tooltip_text = str(d["tip"])
		else:
			var cat_label: String = str((TILE_CATS[_active_cat] as Dictionary)["label"])
			btn.tooltip_text = "%s — '%s' (var. %d)" % [cat_label, str(d["c"]), i + 1]
		var idx: int = i
		btn.pressed.connect(func() -> void: _select_var(idx))
		_var_grid.add_child(btn)
		_var_btns.append(btn)


func _get_var_defs() -> Array:
	if _active_cat == CAT_ENTITY:
		return ENT_DEFS
	elif _active_cat == CAT_MARKER:
		return MARKER_DEFS
	elif TILE_CATS.has(_active_cat):
		return (TILE_CATS[_active_cat] as Dictionary)["vars"] as Array
	return []


func _is_tile_mode() -> bool:
	return _active_cat < CAT_ENTITY or _active_cat >= CAT_DECO_CONT


func _current_tile_value() -> int:
	return _active_cat * 16 + _active_var


func _current_entity_kind() -> String:
	if _active_cat == CAT_ENTITY and _active_var < ENT_DEFS.size():
		return str((ENT_DEFS[_active_var] as Dictionary)["kind"])
	elif _active_cat == CAT_MARKER and _active_var < MARKER_DEFS.size():
		return str((MARKER_DEFS[_active_var] as Dictionary)["kind"])
	return "npc"


# ── faction list helpers ───────────────────────────────────────────────────────

func _load_faction_lists() -> void:
	_signoria_ids   = [""]
	_signoria_names = ["— Nessuna —"]
	_corp_all       = []

	var sig_entries: Array = []
	var dir: DirAccess = DirAccess.open("res://data/factions/signorie/")
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var f: FileAccess = FileAccess.open("res://data/factions/signorie/" + fname, FileAccess.READ)
				if f:
					var parsed: Variant = JSON.parse_string(f.get_as_text())
					f.close()
					if parsed is Dictionary:
						var d: Dictionary = parsed as Dictionary
						sig_entries.append({"id": str(d.get("id", "")), "name": str(d.get("name", ""))})
			fname = dir.get_next()
		dir.list_dir_end()
	sig_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))
	for e: Dictionary in sig_entries:
		_signoria_ids.append(str(e.get("id", "")))
		_signoria_names.append(str(e.get("name", "")))

	for tier: String in ["tier_s", "tier_a", "tier_b", "tier_c"]:
		var dir2: DirAccess = DirAccess.open("res://data/factions/" + tier + "/")
		if dir2 == null:
			continue
		dir2.list_dir_begin()
		var fname2: String = dir2.get_next()
		while fname2 != "":
			if fname2.ends_with(".json"):
				var f2: FileAccess = FileAccess.open("res://data/factions/" + tier + "/" + fname2, FileAccess.READ)
				if f2:
					var parsed2: Variant = JSON.parse_string(f2.get_as_text())
					f2.close()
					if parsed2 is Dictionary:
						var d2: Dictionary = parsed2 as Dictionary
						_corp_all.append({"id": str(d2.get("id", "")), "name": str(d2.get("name", ""))})
			fname2 = dir2.get_next()
		dir2.list_dir_end()
	_corp_all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))

	# ── All factions (for entity props dropdowns) ──────────────────────────────
	_all_factions = []
	_scan_json_id_name_recursive("res://data/factions/", _all_factions)
	_all_factions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))

	# ── Dialogues ──────────────────────────────────────────────────────────────
	_all_dialogues = []
	var dial_dir: DirAccess = DirAccess.open("res://data/dialogue/")
	if dial_dir != null:
		dial_dir.list_dir_begin()
		var dfname: String = dial_dir.get_next()
		while dfname != "":
			if dfname.ends_with(".json"):
				var df: FileAccess = FileAccess.open("res://data/dialogue/" + dfname, FileAccess.READ)
				if df:
					var dp: Variant = JSON.parse_string(df.get_as_text())
					df.close()
					if dp is Dictionary:
						var dd: Dictionary = dp as Dictionary
						if dd.has("id"):
							_all_dialogues.append({"id": str(dd["id"]), "name": str(dd.get("title", dd["id"]))})
			dfname = dial_dir.get_next()
		dial_dir.list_dir_end()
	_all_dialogues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))

	# ── Quests ─────────────────────────────────────────────────────────────────
	_all_quests = []
	var quest_dir: DirAccess = DirAccess.open("res://data/quests/")
	if quest_dir != null:
		quest_dir.list_dir_begin()
		var qfname: String = quest_dir.get_next()
		while qfname != "":
			if qfname.ends_with(".json"):
				var qf: FileAccess = FileAccess.open("res://data/quests/" + qfname, FileAccess.READ)
				if qf:
					var qp: Variant = JSON.parse_string(qf.get_as_text())
					qf.close()
					if qp is Dictionary:
						var qd: Dictionary = qp as Dictionary
						if qd.has("id"):
							_all_quests.append({"id": str(qd["id"]), "name": str(qd.get("title", qd["id"]))})
			qfname = quest_dir.get_next()
		quest_dir.list_dir_end()
	_all_quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))

	# ── Items ──────────────────────────────────────────────────────────────────
	_all_items = []
	_scan_json_id_name_recursive("res://data/items/", _all_items)
	_all_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", "")))


func _scan_json_id_name_recursive(dir_path: String, out: Array) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			_scan_json_id_name_recursive(dir_path.path_join(fname), out)
		elif fname.ends_with(".json"):
			var f: FileAccess = FileAccess.open(dir_path.path_join(fname), FileAccess.READ)
			if f:
				var p: Variant = JSON.parse_string(f.get_as_text())
				f.close()
				if p is Dictionary:
					var d: Dictionary = p as Dictionary
					if d.has("id"):
						out.append({"id": str(d["id"]), "name": str(d.get("name", d["id"]))})
		fname = dir.get_next()
	dir.list_dir_end()


func _open_corp_menu(btn: Button) -> void:
	if _corp_menu == null:
		return
	for i: int in _corp_all.size():
		var corp_id: String = str(_corp_all[i].get("id", ""))
		_corp_menu.set_item_checked(_corp_menu.get_item_index(i), _ccorporazioni.has(corp_id))
	var screen_pos: Vector2 = btn.get_screen_position()
	_corp_menu.popup(Rect2i(Vector2i(int(screen_pos.x), int(screen_pos.y) + int(btn.size.y)), Vector2i(220, 0)))


func _on_corp_menu_pressed(id: int) -> void:
	if id < 0 or id >= _corp_all.size():
		return
	var item_idx: int = _corp_menu.get_item_index(id)
	var corp_id: String = str(_corp_all[id].get("id", ""))
	var was_checked: bool = _corp_menu.is_item_checked(item_idx)
	_corp_menu.set_item_checked(item_idx, not was_checked)
	if not was_checked:
		if not _ccorporazioni.has(corp_id):
			_ccorporazioni.append(corp_id)
	else:
		_ccorporazioni.erase(corp_id)
	_update_corp_summary()


func _update_corp_summary() -> void:
	if _corp_summary_lbl == null:
		return
	var n: int = _ccorporazioni.size()
	_corp_summary_lbl.text = "%d selezionate" % n if n != 1 else "1 selezionata"


# ── city operations ────────────────────────────────────────────────────────────

func _new_city() -> void:
	_width             = int(_w_spin.value) if _w_spin else 40
	_height            = int(_h_spin.value) if _h_spin else 30
	_csignoria         = ""
	_ccorporazioni     = []
	_cminimap_enabled  = false
	if _minimap_check: _minimap_check.set_pressed_no_signal(false)
	_entities.clear()
	_sel = -1
	_init_tiles()
	_floors = [_make_floor_dict("Piano Terra", _width, _height, _tiles, [])]
	_current_floor = 0
	_sync_canvas_size()
	_canvas.queue_redraw()
	_rebuild_props()
	_update_floor_ui()
	if _signoria_opt: _signoria_opt.select(0)
	_update_corp_summary()
	_set_status("Nuova città creata.")


func _init_tiles() -> void:
	_tiles.clear()
	var wall_val: int = CAT_WALL_ST * 16 + 0
	var floor_val: int = CAT_FLOOR * 16 + 0
	for y: int in _height:
		var row: Array = []
		for x: int in _width:
			var is_border: bool = (x == 0 or y == 0 or x == _width - 1 or y == _height - 1)
			row.append(wall_val if is_border else floor_val)
		_tiles.append(row)


func _apply_size() -> void:
	var nw: int = int(_w_spin.value)
	var nh: int = int(_h_spin.value)
	if nw == _width and nh == _height:
		return
	var old_tiles: Array = _tiles.duplicate(true)
	var ow: int = _width
	var oh: int = _height
	_width  = nw
	_height = nh
	_init_tiles()
	for y: int in mini(oh, _height):
		for x: int in mini(ow, _width):
			(_tiles[y] as Array)[x] = int(((old_tiles[y] as Array)[x]))
	_entities = _entities.filter(func(e: Dictionary) -> bool:
		return int(e.get("x", 0)) < _width and int(e.get("y", 0)) < _height)
	if _sel >= _entities.size():
		_sel = -1
	_sync_canvas_size()
	_canvas.queue_redraw()
	_set_status("Dimensioni applicate.")


func _sync_canvas_size() -> void:
	if _canvas:
		_canvas.custom_minimum_size = Vector2(_width * CELL, _height * CELL)


# ── save / load ────────────────────────────────────────────────────────────────

func _save_city() -> void:
	_save_current_floor()
	var dir: DirAccess = DirAccess.open("res://data/")
	if dir and not dir.dir_exists("cities"):
		dir.make_dir("cities")
	var path: String = "res://data/cities/%s.json" % _cid
	var data: Dictionary = {
		"id": _cid, "name": _cname, "type": _ctype,
		"floors": _floors.duplicate(true),
	}
	if _csignoria != "":
		data["signoria"] = _csignoria
	if not _ccorporazioni.is_empty():
		data["corporazioni_presenti"] = _ccorporazioni.duplicate()
	if _cminimap_enabled:
		data["minimap_enabled"] = true
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("ERRORE salvataggio.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_write_locale_keys()
	_set_status("Salvato: %s.json (%d piani)" % [_cid, _floors.size()])


func _open_load_menu() -> void:
	_load_menu.clear()
	var dir: DirAccess = DirAccess.open("res://data/cities/")
	if dir == null:
		_set_status("Cartella data/cities/ non trovata.")
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	var idx: int = 0
	while fname != "":
		if fname.ends_with(".json"):
			_load_menu.add_item(fname.trim_suffix(".json"), idx)
			idx += 1
		fname = dir.get_next()
	dir.list_dir_end()
	if idx == 0:
		_set_status("Nessun file in data/cities/")
		return
	var gr: Rect2 = get_global_rect()
	_load_menu.popup(Rect2i(int(gr.position.x), int(gr.position.y + 34), 200, 0))


func _on_load_item(id: int) -> void:
	_load_file("res://data/cities/%s.json" % _load_menu.get_item_text(id))


func _load_file(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_set_status("File non trovato.")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		_set_status("JSON non valido.")
		return
	var d: Dictionary = parsed as Dictionary
	_cid               = str(d.get("id",   "new_city"))
	_cname             = str(d.get("name", "Città"))
	_ctype             = str(d.get("type", "village"))
	_csignoria         = str(d.get("signoria", ""))
	_cminimap_enabled  = bool(d.get("minimap_enabled", false))
	var raw_corp_load: Variant = d.get("corporazioni_presenti", [])
	_ccorporazioni = (raw_corp_load as Array).duplicate() if raw_corp_load is Array else []

	var floors_raw: Variant = d.get("floors", null)
	if floors_raw is Array and (floors_raw as Array).size() > 0:
		_floors = (floors_raw as Array).duplicate(true)
	else:
		# legacy flat format — wrap in a single floor
		var lw: int = int(d.get("width",  40))
		var lh: int = int(d.get("height", 30))
		_floors = [_make_floor_dict("Piano Terra", lw, lh,
				d.get("tiles",    []) as Array,
				d.get("entities", []) as Array)]

	_current_floor = 0
	var fl: Dictionary = _floors[0] as Dictionary
	_width    = int(fl.get("width",  40))
	_height   = int(fl.get("height", 30))
	_tiles    = (fl.get("tiles",    []) as Array).duplicate(true)
	_entities = (fl.get("entities", []) as Array).duplicate(true)
	_sel = -1

	if _id_edit:   _id_edit.text   = _cid
	if _name_edit: _name_edit.text = _cname
	if _type_opt:
		for i: int in _type_opt.item_count:
			if _type_opt.get_item_text(i) == _ctype:
				_type_opt.select(i)
				break
	if _signoria_opt:
		var sig_idx: int = _signoria_ids.find(_csignoria)
		_signoria_opt.select(maxi(0, sig_idx))
	if _minimap_check:
		_minimap_check.set_pressed_no_signal(_cminimap_enabled)
	_update_corp_summary()
	if _w_spin: _w_spin.value = _width
	if _h_spin: _h_spin.value = _height
	_sync_canvas_size()
	_canvas.queue_redraw()
	_rebuild_props()
	_update_floor_ui()
	_set_status("Caricato: %s (%d piani)" % [_cid, _floors.size()])


# ── canvas drawing ─────────────────────────────────────────────────────────────

func _draw_canvas() -> void:
	if _tiles.is_empty():
		return
	var font: Font = ThemeDB.fallback_font

	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(_width * CELL, _height * CELL)), THEME_BG)

	# Pre-compute per-tile night overlay alpha (0.0 = fully lit, 0.85 = fully dark).
	# Tiles within a light's radius get a gradient fading from 0.0 at the source to 0.85 at the edge.
	var tile_overlay: Dictionary = {}   # Vector2i → float
	if _lights_preview:
		for e: Variant in _entities:
			var ed: Dictionary = e as Dictionary
			if str(ed.get("kind", "")) != "light_source":
				continue
			var lx: int = int(ed.get("x", 0))
			var ly: int = int(ed.get("y", 0))
			var params: Dictionary = ed.get("params", {}) as Dictionary
			var rad: int = int(params.get("radius", 3))
			var origin := Vector2i(lx, ly)
			tile_overlay[origin] = 0.0
			for dy: int in range(-rad, rad + 1):
				for dx: int in range(-rad, rad + 1):
					if dx * dx + dy * dy <= rad * rad:
						var tp := Vector2i(lx + dx, ly + dy)
						if _in_bounds(tp) and _preview_has_los(origin, tp):
							var dist: float = Vector2(float(dx), float(dy)).length()
							var alpha: float = 0.85 * (dist / float(rad))
							if not tile_overlay.has(tp) or (tile_overlay[tp] as float) > alpha:
								tile_overlay[tp] = alpha

	# Tiles (always drawn at full color; overlay applied on top)
	for y: int in _height:
		if y >= _tiles.size():
			break
		var row: Array = _tiles[y] as Array
		for x: int in _width:
			if x >= row.size():
				break
			var v: int       = int(row[x])
			var cat: int     = v / 16
			var vi: int      = v % 16
			var cat_data: Dictionary = (TILE_CATS.get(cat, TILE_CATS[CAT_FLOOR])) as Dictionary
			var vars: Array  = cat_data["vars"] as Array
			var td: Dictionary = vars[clampi(vi, 0, vars.size() - 1)] as Dictionary
			_canvas.draw_string(font,
					Vector2(x * CELL, y * CELL + BASELINE_Y),
					str(td["c"]), HORIZONTAL_ALIGNMENT_CENTER, CELL, FONT_SIZE,
					td["col"] as Color)
			if _lights_preview:
				var ov: float = tile_overlay.get(Vector2i(x, y), 0.85) as float
				if ov > 0.0:
					_canvas.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL),
							Color(0.0, 0.0, 0.0, ov))

	# Grid lines
	var gc := Color(0.20, 0.18, 0.15, 0.12)
	for x: int in _width + 1:
		_canvas.draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, _height * CELL), gc)
	for y: int in _height + 1:
		_canvas.draw_line(Vector2(0, y * CELL), Vector2(_width * CELL, y * CELL), gc)

	# Entities
	for i: int in _entities.size():
		var e: Dictionary  = _entities[i] as Dictionary
		var ex: int        = int(e.get("x", 0))
		var ey: int        = int(e.get("y", 0))
		var kind: String   = str(e.get("kind", "npc"))
		var ed: Dictionary = _ent_def_for_kind(kind)
		var ch: String     = str(ed.get("c", "?"))
		var ec: Color      = ed.get("col", Color.WHITE) as Color

		if _lights_preview:
			var ep  := Vector2i(ex, ey)
			var ov: float = tile_overlay.get(ep, 0.85) as float
			if kind == "light_source":
				var params: Dictionary = e.get("params", {}) as Dictionary
				var carr: Array = params.get("color", [1.0, 0.72, 0.10]) as Array
				ec = Color(float(carr[0]), float(carr[1]), float(carr[2]))
			elif NIGHT_HIDDEN_KINDS.has(kind) and ov >= 0.5:
				if i == _sel:
					_canvas.draw_rect(Rect2(ex * CELL, ey * CELL, CELL, CELL),
							Color(1.0, 0.85, 0.1), false, 2)
				continue  # invisible in darkness
			else:
				ec = ec.darkened(ov * 0.8)

		if EDITOR_ONLY_KINDS.has(kind):
			_canvas.draw_rect(Rect2(ex * CELL, ey * CELL, CELL - 1, CELL - 1), ec.darkened(0.65))
		_canvas.draw_string(font,
				Vector2(ex * CELL, ey * CELL + BASELINE_Y),
				ch, HORIZONTAL_ALIGNMENT_CENTER, CELL, FONT_SIZE, ec)
		if i == _sel:
			_canvas.draw_rect(Rect2(ex * CELL, ey * CELL, CELL, CELL),
					Color(1.0, 0.85, 0.1), false, 2)

	# Hover cursor
	if _hover.x >= 0 and _in_bounds(_hover):
		_canvas.draw_rect(Rect2(_hover.x * CELL, _hover.y * CELL, CELL, CELL),
				Color(1, 1, 1, 0.28), false, 1)


func _preview_tile_blocked(pos: Vector2i) -> bool:
	if not _in_bounds(pos):
		return true
	var v: int = int((_tiles[pos.y] as Array)[pos.x])
	return BLOCKED_CATS.has(v / 16)


func _preview_has_los(from: Vector2i, to: Vector2i) -> bool:
	var x0: int = from.x;  var y0: int = from.y
	var x1: int = to.x;    var y1: int = to.y
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	while true:
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
		# Check intermediate tile (not origin, but target is allowed to be a wall)
		if (x0 != to.x or y0 != to.y) and _preview_tile_blocked(Vector2i(x0, y0)):
			return false
	return true


func _ent_def_for_kind(kind: String) -> Dictionary:
	for d: Variant in ENT_DEFS:
		if str((d as Dictionary)["kind"]) == kind:
			return d as Dictionary
	for d: Variant in MARKER_DEFS:
		if str((d as Dictionary)["kind"]) == kind:
			return d as Dictionary
	return {"c": "?", "col": Color.WHITE}


# ── canvas input ───────────────────────────────────────────────────────────────

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var cell := _cell(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_painting = true
				_apply_tool(cell)
			else:
				_painting = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_ctx_menu(cell)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_hover = _cell(mm.position)
		if _painting and _in_bounds(_hover) and (_is_erasing or _is_tile_mode()):
			_apply_tool(_hover)
		_canvas.queue_redraw()


func _apply_tool(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	if _is_erasing:
		(_tiles[cell.y] as Array)[cell.x] = 0   # CAT_FLOOR var 0
		_erase_entity_at(cell)
		_canvas.queue_redraw()
	elif _is_tile_mode():
		(_tiles[cell.y] as Array)[cell.x] = _current_tile_value()
		_canvas.queue_redraw()
	else:
		if not _entity_at(cell):
			_place_entity(_current_entity_kind(), cell)


# ── entity operations ──────────────────────────────────────────────────────────

func _place_entity(kind: String, cell: Vector2i) -> void:
	var uid: String = "%s_%d_%d" % [kind, cell.x, cell.y]
	var params: Dictionary = _default_params(kind, cell)
	if kind == "light_source" and _active_cat == CAT_ENTITY and _active_var < ENT_DEFS.size():
		var def: Dictionary = ENT_DEFS[_active_var] as Dictionary
		var lc: Color = def["col"] as Color
		params["color"] = [lc.r, lc.g, lc.b]
		params["radius"] = int(def.get("default_radius", 3))
	_entities.append({"kind": kind, "x": cell.x, "y": cell.y, "uid": uid, "params": params})
	_sel = _entities.size() - 1
	_canvas.queue_redraw()
	_rebuild_props()


func _default_params(kind: String, cell: Vector2i) -> Dictionary:
	match kind:
		"npc":
			return {
				"id": "npc_%d_%d" % [cell.x, cell.y], "name": "NPC",
				"faction_id": "", "secondary_faction_ids": [],
				"dialogue_id": "", "dialogue_id_quest_active": "", "dialogue_id_quest_done": "",
				"idle_dialogue_ids": [], "linked_quest_id": "",
				"conditional_dialogues": [],
				"vendor": false, "inventory": [], "love_interest": false,
				"is_guard": false, "gender": "", "is_child": false,
			}
		"save_point":
			return {"label": "Fontana"}
		"transition":
			return {"target_map": "overworld", "target_type": "overworld",
					"target_x": 10, "target_y": 10}
		"port":
			return {"id": "port_%d_%d" % [cell.x, cell.y], "name": "Porto", "dialogue_id": ""}
		"door":
			return {"id": "door_%d_%d" % [cell.x, cell.y], "locked": false, "key_id": ""}
		"plant":
			return {"id": "plant_%d_%d" % [cell.x, cell.y],
					"plant_type": "tree", "blocks_movement": true}
		"well":
			return {"id": "well_%d_%d" % [cell.x, cell.y], "label": "Pozzo"}
		"item":
			return {"item_id": "", "qty": 1}
		"light_source":
			return {"radius": 3}
		"spawn_point":
			return {}
		"event_trigger":
			return {"event_id": "", "trigger_type": "once"}
		"exit":
			return {"target_map": "overworld", "target_x": 0, "target_y": 0}
		_:
			return {}


func _erase_entity_at(cell: Vector2i) -> void:
	for i: int in range(_entities.size() - 1, -1, -1):
		var e: Dictionary = _entities[i] as Dictionary
		if int(e.get("x", -1)) == cell.x and int(e.get("y", -1)) == cell.y:
			_entities.remove_at(i)
			if _sel >= _entities.size():
				_sel = _entities.size() - 1
			_rebuild_props()
			return


func _try_select(cell: Vector2i) -> void:
	for i: int in _entities.size():
		var e: Dictionary = _entities[i] as Dictionary
		if int(e.get("x", -1)) == cell.x and int(e.get("y", -1)) == cell.y:
			_sel = i
			_canvas.queue_redraw()
			_rebuild_props()
			return
	_sel = -1
	_canvas.queue_redraw()
	_rebuild_props()


func _entity_at(cell: Vector2i) -> bool:
	for e: Dictionary in _entities:
		if int(e.get("x", -1)) == cell.x and int(e.get("y", -1)) == cell.y:
			return true
	return false


func _show_ctx_menu(cell: Vector2i) -> void:
	if not _entity_at(cell):
		_try_select(cell)
		return
	_ctx_cell = cell
	_ctx_menu.clear()
	_ctx_menu.add_item("Modifica proprietà", 0)
	_ctx_menu.add_separator()
	_ctx_menu.add_item("Elimina entità", 1)
	var mpos := DisplayServer.mouse_get_position()
	_ctx_menu.popup(Rect2i(mpos, Vector2i(0, 0)))


func _on_ctx_menu_pressed(id: int) -> void:
	match id:
		0:
			_try_select(_ctx_cell)
		1:
			_erase_entity_at(_ctx_cell)
			_canvas.queue_redraw()


# ── properties panel ───────────────────────────────────────────────────────────

func _rebuild_props() -> void:
	for child: Node in _props_box.get_children():
		child.queue_free()

	if _sel < 0 or _sel >= _entities.size():
		var hint := Label.new()
		hint.text = "Nessuna selezione\n(click destro su\nun'entità)"
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_props_box.add_child(hint)
		return

	var ent: Dictionary    = _entities[_sel] as Dictionary
	var kind: String       = str(ent.get("kind", ""))
	var params: Dictionary = ent.get("params", {}) as Dictionary

	_prop_lbl("Tipo: " + kind.to_upper())
	_prop_lbl("Pos: %d, %d" % [int(ent.get("x", 0)), int(ent.get("y", 0))])
	_props_box.add_child(HSeparator.new())

	match kind:
		"npc":
			_prop_field("ID",   str(params.get("id",   "")), func(v: String) -> void: params["id"] = v)
			_prop_field("Nome", str(params.get("name", "")), func(v: String) -> void: params["name"] = v)
			_prop_dropdown("Fazione", str(params.get("faction_id", "")), _all_factions,
					func(v: String) -> void: params["faction_id"] = v)
			var sec_ids: Array = []
			var raw_sec: Variant = params.get("secondary_faction_ids", [])
			if raw_sec is Array:
				for s: Variant in (raw_sec as Array): sec_ids.append(str(s))
			_prop_multiselect("Faz. sec.", sec_ids, _all_factions,
					func(v: Array) -> void: params["secondary_faction_ids"] = v)
			_props_box.add_child(HSeparator.new())
			_prop_lbl("— Tipo NPC —")
			_prop_bool("vendor", bool(params.get("vendor", false)), func(v: bool) -> void:
				params["vendor"] = v
				call_deferred("_rebuild_props"))
			if bool(params.get("vendor", false)):
				_prop_lbl("Inventario vendor:")
				_build_vendor_inventory_editor(params)
			_prop_bool("love_interest", bool(params.get("love_interest", false)), func(v: bool) -> void: params["love_interest"] = v)
			_prop_bool("is_guard", bool(params.get("is_guard", false)), func(v: bool) -> void: params["is_guard"] = v)
			_prop_bool("is_child", bool(params.get("is_child", false)), func(v: bool) -> void: params["is_child"] = v)
			_prop_dropdown("gender", str(params.get("gender", "")),
					[{"id": "m", "name": "M"}, {"id": "f", "name": "F"}],
					func(v: String) -> void: params["gender"] = v)
			_props_box.add_child(HSeparator.new())
			_prop_lbl("— Dialogo —")
			_prop_dropdown("dialogue_id",  str(params.get("dialogue_id",  "")), _all_dialogues,
					func(v: String) -> void: params["dialogue_id"] = v)
			_prop_dropdown("quest_active", str(params.get("dialogue_id_quest_active", "")), _all_dialogues,
					func(v: String) -> void: params["dialogue_id_quest_active"] = v)
			_prop_dropdown("quest_done",   str(params.get("dialogue_id_quest_done",   "")), _all_dialogues,
					func(v: String) -> void: params["dialogue_id_quest_done"] = v)
			_prop_dropdown("linked_quest", str(params.get("linked_quest_id", "")), _all_quests,
					func(v: String) -> void: params["linked_quest_id"] = v)
			var idle_ids: Array = []
			var raw_idle: Variant = params.get("idle_dialogue_ids", [])
			if raw_idle is Array:
				for s: Variant in (raw_idle as Array): idle_ids.append(str(s))
			_prop_multiselect("idle dial.", idle_ids, _all_dialogues,
					func(v: Array) -> void: params["idle_dialogue_ids"] = v)
			_prop_lbl("Dial. condizionali:")
			_build_cond_dialogues_editor(params)
		"save_point":
			_prop_field("Label", str(params.get("label", "Fontana")), func(v: String) -> void: params["label"] = v)
		"transition":
			_prop_field("target_map",  str(params.get("target_map",  "")),         func(v: String) -> void: params["target_map"] = v)
			_prop_field("target_type", str(params.get("target_type", "overworld")), func(v: String) -> void: params["target_type"] = v)
			_prop_spin("target_x", int(params.get("target_x", 0)), func(v: float) -> void: params["target_x"] = int(v))
			_prop_spin("target_y", int(params.get("target_y", 0)), func(v: float) -> void: params["target_y"] = int(v))
		"port":
			_prop_field("ID",   str(params.get("id",   "")), func(v: String) -> void: params["id"] = v)
			_prop_field("Nome", str(params.get("name", "")), func(v: String) -> void: params["name"] = v)
			_prop_dropdown("dialogue_id", str(params.get("dialogue_id", "")), _all_dialogues,
					func(v: String) -> void: params["dialogue_id"] = v)
		"door":
			_prop_field("ID",     str(params.get("id",     "")),    func(v: String) -> void: params["id"] = v)
			_prop_bool("Bloccata", bool(params.get("locked", false)), func(v: bool) -> void: params["locked"] = v)
			_prop_field("key_id", str(params.get("key_id", "")),    func(v: String) -> void: params["key_id"] = v)
			_prop_lbl("— Requisito fazione —")
			var req: Dictionary = params.get("faction_requirement", {}) as Dictionary
			_prop_dropdown("req_faction", str(req.get("faction_id", "")), _all_factions,
					func(v: String) -> void:
						if v == "":
							params.erase("faction_requirement")
						else:
							var r: Dictionary = params.get("faction_requirement", {})
							r["faction_id"] = v
							params["faction_requirement"] = r)
			_prop_spin_range("req_min_rep",  int(req.get("min_rep",  0)), 0, 100, func(v: float) -> void:
				var r: Dictionary = params.get("faction_requirement", {})
				r["min_rep"] = int(v)
				params["faction_requirement"] = r)
			_prop_spin_range("req_min_rank", int(req.get("min_rank", -1)), -1, 5, func(v: float) -> void:
				var r: Dictionary = params.get("faction_requirement", {})
				r["min_rank"] = int(v)
				params["faction_requirement"] = r)
		"plant":
			_prop_field("ID",         str(params.get("id",         "")),     func(v: String) -> void: params["id"] = v)
			_prop_field("plant_type", str(params.get("plant_type", "tree")), func(v: String) -> void: params["plant_type"] = v)
			_prop_bool("Blocca mov.", bool(params.get("blocks_movement", true)), func(v: bool) -> void: params["blocks_movement"] = v)
		"well":
			_prop_field("ID",    str(params.get("id",    "")),      func(v: String) -> void: params["id"] = v)
			_prop_field("Label", str(params.get("label", "Pozzo")), func(v: String) -> void: params["label"] = v)
		"item":
			_prop_field("item_id", str(params.get("item_id", "")), func(v: String) -> void: params["item_id"] = v)
			_prop_spin("qty",      int(params.get("qty", 1)),       func(v: float) -> void: params["qty"] = int(v))
		"spawn_point":
			_prop_lbl("Spawn del player all'ingresso.")
		"event_trigger":
			_prop_field("event_id",     str(params.get("event_id",     "")),     func(v: String) -> void: params["event_id"] = v)
			_prop_field("trigger_type", str(params.get("trigger_type", "once")), func(v: String) -> void: params["trigger_type"] = v)
		"exit":
			_prop_field("target_map", str(params.get("target_map", "overworld")), func(v: String) -> void: params["target_map"] = v)
			_prop_spin("target_x",    int(params.get("target_x", 0)), func(v: float) -> void: params["target_x"] = int(v))
			_prop_spin("target_y",    int(params.get("target_y", 0)), func(v: float) -> void: params["target_y"] = int(v))
		"light_source":
			_prop_spin_range("Raggio", int(params.get("radius", 3)), 1, 10,
					func(v: float) -> void: params["radius"] = int(v))

	_props_box.add_child(HSeparator.new())
	var del_btn := Button.new()
	del_btn.text = "🗑 Elimina"
	del_btn.add_theme_font_size_override("font_size", 10)
	del_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	del_btn.pressed.connect(func() -> void:
		_entities.remove_at(_sel)
		_sel = -1
		_canvas.queue_redraw()
		_rebuild_props())
	_props_box.add_child(del_btn)


# ── property widget helpers ────────────────────────────────────────────────────

func _prop_lbl(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_props_box.add_child(lbl)


func _prop_field(label: String, value: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 10)
	l.custom_minimum_size.x = 78
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.add_theme_font_size_override("font_size", 10)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(on_change)
	row.add_child(edit)
	_props_box.add_child(row)


func _prop_spin(label: String, value: int, on_change: Callable) -> void:
	_prop_spin_range(label, value, 0, 9999, on_change)


func _prop_spin_range(label: String, value: int, min_val: int, max_val: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 10)
	l.custom_minimum_size.x = 78
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value     = value
	spin.add_theme_font_size_override("font_size", 10)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_change)
	row.add_child(spin)
	_props_box.add_child(row)


func _prop_bool(label: String, value: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 10)
	l.custom_minimum_size.x = 78
	row.add_child(l)
	var chk := CheckBox.new()
	chk.button_pressed = value
	chk.add_theme_font_size_override("font_size", 10)
	chk.toggled.connect(on_change)
	row.add_child(chk)
	_props_box.add_child(row)


# ── dropdown / multiselect widgets ────────────────────────────────────────────

func _prop_dropdown(label: String, value: String, opts: Array, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 10)
	l.custom_minimum_size.x = 78
	row.add_child(l)
	var opt_btn := OptionButton.new()
	opt_btn.add_theme_font_size_override("font_size", 9)
	opt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_btn.add_item("— Nessuno —", 0)
	var sel: int = 0
	for i: int in opts.size():
		var opt: Dictionary = opts[i] as Dictionary
		opt_btn.add_item(str(opt.get("name", opt.get("id", ""))), i + 1)
		if str(opt.get("id", "")) == value:
			sel = i + 1
	opt_btn.select(sel)
	opt_btn.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			on_change.call("")
		else:
			var ri: int = idx - 1
			on_change.call(str((opts[ri] as Dictionary).get("id", "")) if ri < opts.size() else ""))
	row.add_child(opt_btn)
	_props_box.add_child(row)


func _prop_multiselect(label: String, current: Array, opts: Array, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = label + ":"
	l.add_theme_font_size_override("font_size", 10)
	l.custom_minimum_size.x = 78
	row.add_child(l)
	var sum_lbl := Label.new()
	sum_lbl.add_theme_font_size_override("font_size", 10)
	sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nc: int = current.size()
	sum_lbl.text = "%d sel." % nc if nc != 1 else "1 sel."
	row.add_child(sum_lbl)
	var btn := Button.new()
	btn.text = "…"
	btn.custom_minimum_size = Vector2(26, 20)
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(func() -> void:
		_prop_select_opts = opts
		_prop_select_cb = func(new_arr: Array) -> void:
			on_change.call(new_arr)
			var n: int = new_arr.size()
			sum_lbl.text = "%d sel." % n if n != 1 else "1 sel."
		_prop_select_popup.clear()
		for i: int in opts.size():
			var opt: Dictionary = opts[i] as Dictionary
			var oid: String = str(opt.get("id", ""))
			var oname: String = str(opt.get("name", oid))
			_prop_select_popup.add_check_item(oname, i)
			_prop_select_popup.set_item_checked(i, current.has(oid))
		var mpos := DisplayServer.mouse_get_position()
		_prop_select_popup.popup(Rect2i(mpos, Vector2i(230, 0))))
	row.add_child(btn)
	_props_box.add_child(row)


func _on_prop_select_pressed(item_id: int) -> void:
	if item_id < 0 or item_id >= _prop_select_opts.size():
		return
	var was: bool = _prop_select_popup.is_item_checked(item_id)
	_prop_select_popup.set_item_checked(item_id, not was)
	var new_arr: Array = []
	for i: int in _prop_select_opts.size():
		if _prop_select_popup.is_item_checked(i):
			new_arr.append(str((_prop_select_opts[i] as Dictionary).get("id", "")))
	if _prop_select_cb.is_valid():
		_prop_select_cb.call(new_arr)


# ── array-of-dict editors ─────────────────────────────────────────────────────

func _build_cond_dialogues_editor(params: Dictionary) -> void:
	if not params.has("conditional_dialogues"):
		params["conditional_dialogues"] = []
	var arr: Array = params["conditional_dialogues"] as Array
	for i: int in arr.size():
		var entry: Dictionary = arr[i] as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var idx: int = i
		var cond_e := LineEdit.new()
		cond_e.placeholder_text = "condizione"
		cond_e.text = str(entry.get("condition", ""))
		cond_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cond_e.add_theme_font_size_override("font_size", 9)
		cond_e.text_changed.connect(func(v: String) -> void:
			(params["conditional_dialogues"] as Array)[idx]["condition"] = v)
		row.add_child(cond_e)
		# dialogue_id as compact OptionButton
		var dial_opt := OptionButton.new()
		dial_opt.add_theme_font_size_override("font_size", 9)
		dial_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dial_opt.add_item("—", 0)
		var cur_dial: String = str(entry.get("dialogue_id", ""))
		var dsel: int = 0
		for di: int in _all_dialogues.size():
			var dd: Dictionary = _all_dialogues[di] as Dictionary
			dial_opt.add_item(str(dd.get("id", "")), di + 1)
			if str(dd.get("id", "")) == cur_dial:
				dsel = di + 1
		dial_opt.select(dsel)
		dial_opt.item_selected.connect(func(v: int) -> void:
			var rid: int = v - 1
			var did: String = str((_all_dialogues[rid] as Dictionary).get("id", "")) if rid >= 0 and rid < _all_dialogues.size() else ""
			(params["conditional_dialogues"] as Array)[idx]["dialogue_id"] = did)
		row.add_child(dial_opt)
		var del := Button.new()
		del.text = "✕"
		del.custom_minimum_size = Vector2(20, 20)
		del.add_theme_font_size_override("font_size", 9)
		del.pressed.connect(func() -> void:
			(params["conditional_dialogues"] as Array).remove_at(idx)
			call_deferred("_rebuild_props"))
		row.add_child(del)
		_props_box.add_child(row)
	var add_btn := Button.new()
	add_btn.text = "+ Dialogo condizionale"
	add_btn.add_theme_font_size_override("font_size", 9)
	add_btn.pressed.connect(func() -> void:
		(params["conditional_dialogues"] as Array).append({"condition": "", "dialogue_id": ""})
		call_deferred("_rebuild_props"))
	_props_box.add_child(add_btn)


func _build_vendor_inventory_editor(params: Dictionary) -> void:
	if not params.has("inventory"):
		params["inventory"] = []
	var inv: Array = params["inventory"] as Array
	# Summary + multiselect button
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 2)
	var sum_lbl := Label.new()
	sum_lbl.add_theme_font_size_override("font_size", 10)
	sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_lbl.text = "%d item" % inv.size() if inv.size() != 1 else "1 item"
	hdr.add_child(sum_lbl)
	var sel_btn := Button.new()
	sel_btn.text = "Seleziona…"
	sel_btn.add_theme_font_size_override("font_size", 9)
	sel_btn.pressed.connect(func() -> void:
		var cur_ids: Array = []
		for e: Variant in (params["inventory"] as Array):
			cur_ids.append(str((e as Dictionary).get("item_id", "")))
		_prop_select_opts = _all_items
		_prop_select_cb = func(new_ids: Array) -> void:
			var old_inv: Array = (params["inventory"] as Array).duplicate()
			var new_inv: Array = []
			for nid: Variant in new_ids:
				var kept_qty: int = 1
				for oe: Variant in old_inv:
					if str((oe as Dictionary).get("item_id", "")) == str(nid):
						kept_qty = int((oe as Dictionary).get("qty", 1))
						break
				new_inv.append({"item_id": str(nid), "qty": kept_qty})
			params["inventory"] = new_inv
			call_deferred("_rebuild_props")
		_prop_select_popup.clear()
		for i: int in _all_items.size():
			var item: Dictionary = _all_items[i] as Dictionary
			var iid: String = str(item.get("id", ""))
			_prop_select_popup.add_check_item(str(item.get("name", iid)), i)
			_prop_select_popup.set_item_checked(i, cur_ids.has(iid))
		var mpos := DisplayServer.mouse_get_position()
		_prop_select_popup.popup(Rect2i(mpos, Vector2i(230, 0))))
	hdr.add_child(sel_btn)
	_props_box.add_child(hdr)
	# Per-item qty rows
	for i: int in inv.size():
		var entry: Dictionary = inv[i] as Dictionary
		var iid: String = str(entry.get("item_id", ""))
		var iname: String = iid
		for item: Variant in _all_items:
			if str((item as Dictionary).get("id", "")) == iid:
				iname = str((item as Dictionary).get("name", iid))
				break
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var name_lbl := Label.new()
		name_lbl.text = iname
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row.add_child(name_lbl)
		var qty_s := SpinBox.new()
		qty_s.min_value = 1
		qty_s.max_value = 999
		qty_s.value = int(entry.get("qty", 1))
		qty_s.custom_minimum_size.x = 55
		qty_s.add_theme_font_size_override("font_size", 9)
		var idx: int = i
		qty_s.value_changed.connect(func(v: float) -> void:
			(params["inventory"] as Array)[idx]["qty"] = int(v))
		row.add_child(qty_s)
		_props_box.add_child(row)


# ── misc helpers ───────────────────────────────────────────────────────────────

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / CELL), int(pos.y / CELL))


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _width and cell.y < _height


func _lbl(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	parent.add_child(l)


func _spin(min_v: int, max_v: int, val: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value     = val
	s.custom_minimum_size.x = 55
	return s


func _set_status(text: String) -> void:
	if _status_lbl:
		_status_lbl.text = text


func _array_to_csv(arr: Variant) -> String:
	if not arr is Array:
		return ""
	var parts: Array[String] = []
	for v: Variant in (arr as Array):
		parts.append(str(v))
	return ",".join(parts)


func _csv_to_array(csv: String) -> Array:
	var result: Array = []
	for part: String in csv.split(",", false):
		result.append(part.strip_edges())
	return result


# ── floor management ───────────────────────────────────────────────────────────

func _make_floor_dict(label: String, w: int, h: int, tiles: Array, entities: Array) -> Dictionary:
	return {"label": label, "width": w, "height": h,
			"tiles": tiles.duplicate(true), "entities": entities.duplicate(true)}


func _save_current_floor() -> void:
	if _current_floor >= _floors.size():
		return
	var fl: Dictionary = _floors[_current_floor] as Dictionary
	fl["width"]    = _width
	fl["height"]   = _height
	fl["tiles"]    = _tiles.duplicate(true)
	fl["entities"] = _entities.duplicate(true)


func _load_floor(idx: int) -> void:
	if idx < 0 or idx >= _floors.size():
		return
	var fl: Dictionary = _floors[idx] as Dictionary
	_width    = int(fl.get("width",  40))
	_height   = int(fl.get("height", 30))
	_tiles    = (fl.get("tiles",    []) as Array).duplicate(true)
	_entities = (fl.get("entities", []) as Array).duplicate(true)
	_sel = -1
	if _w_spin: _w_spin.value = _width
	if _h_spin: _h_spin.value = _height
	_sync_canvas_size()
	_canvas.queue_redraw()
	_rebuild_props()
	_update_floor_ui()


func _switch_floor(idx: int) -> void:
	if idx < 0 or idx >= _floors.size():
		return
	_save_current_floor()
	_current_floor = idx
	_load_floor(idx)


func _add_floor() -> void:
	_save_current_floor()
	var new_tiles: Array = []
	var wall_val: int = CAT_WALL_ST * 16
	for y: int in _height:
		var row: Array = []
		for x: int in _width:
			var is_border: bool = (x == 0 or y == 0 or x == _width - 1 or y == _height - 1)
			row.append(wall_val if is_border else 0)
		new_tiles.append(row)
	var new_label: String = "Piano %d" % (_floors.size() + 1)
	_floors.append(_make_floor_dict(new_label, _width, _height, new_tiles, []))
	_current_floor = _floors.size() - 1
	_tiles    = new_tiles
	_entities = []
	_sel      = -1
	_sync_canvas_size()
	_canvas.queue_redraw()
	_rebuild_props()
	_update_floor_ui()
	_set_status("Piano %d aggiunto." % _current_floor)


func _remove_floor() -> void:
	if _floors.size() <= 1:
		_set_status("Deve esserci almeno un piano.")
		return
	_floors.remove_at(_current_floor)
	_current_floor = clampi(_current_floor, 0, _floors.size() - 1)
	_load_floor(_current_floor)
	_set_status("Piano rimosso.")


func _update_floor_ui() -> void:
	if _floor_nav_lbl == null:
		return
	var fl: Dictionary = _floors[_current_floor] as Dictionary
	var lbl: String = str(fl.get("label", "Piano %d" % (_current_floor + 1)))
	_floor_nav_lbl.text = "Piano %d/%d — %s" % [_current_floor + 1, _floors.size(), lbl]
	if _floor_prev_btn:
		_floor_prev_btn.disabled = _current_floor <= 0
	if _floor_next_btn:
		_floor_next_btn.disabled = _current_floor >= _floors.size() - 1
	if _floor_name_edit:
		_updating_floor_ui = true
		_floor_name_edit.text = lbl
		_updating_floor_ui = false


# ── locale key writing ────────────────────────────────────────────────────────

func _write_locale_keys() -> void:
	var path: String = "res://locales/strings_cities.csv"
	# Read existing keys so we don't overwrite manually edited translations.
	var existing: Dictionary = {}
	var f_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f_r != null:
		var header: PackedStringArray = f_r.get_csv_line()
		while not f_r.eof_reached():
			var row: PackedStringArray = f_r.get_csv_line()
			if row.size() > 0 and row[0].strip_edges() != "":
				existing[row[0].strip_edges()] = row
		f_r.close()

	# Collect new keys from all floors.
	var new_keys: Dictionary = {}
	for fl_v: Variant in _floors:
		var fl: Dictionary = fl_v as Dictionary
		var ents: Array = fl.get("entities", []) as Array
		for ent_v: Variant in ents:
			var ent: Dictionary = ent_v as Dictionary
			var p: Dictionary = ent.get("params", {}) as Dictionary
			var kind: String = str(ent.get("kind", ""))
			if kind == "npc":
				var npc_id: String = str(p.get("id", "")).to_upper()
				var npc_name: String = str(p.get("name", "NPC"))
				if npc_id != "":
					new_keys["NPC_" + npc_id + "_NAME"] = npc_name
			elif kind == "port":
				var port_id: String = str(p.get("id", "")).to_upper()
				var port_name: String = str(p.get("name", "Porto"))
				if port_id != "":
					new_keys["PORT_" + port_id + "_NAME"] = port_name

	if new_keys.is_empty():
		return

	var f_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f_w == null:
		push_warning("CityBuilder: cannot write " + path)
		return
	f_w.store_csv_line(PackedStringArray(["key", "it"]))
	# Write existing rows, updating names for keys we re-collected.
	for key: String in existing:
		if new_keys.has(key):
			f_w.store_csv_line(PackedStringArray([key, str(new_keys[key])]))
			new_keys.erase(key)
		else:
			var old_row: PackedStringArray = existing[key] as PackedStringArray
			if old_row.size() >= 2:
				f_w.store_csv_line(PackedStringArray([old_row[0], old_row[1]]))
	# Append any brand-new keys.
	for key: String in new_keys:
		f_w.store_csv_line(PackedStringArray([key, str(new_keys[key])]))
	f_w.close()

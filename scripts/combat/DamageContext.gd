class_name DamageContext
extends RefCounted

# Entità coinvolte
var attacker: Node = null
var defender: Node = null

# Input del calcolo
var base_damage:       int   = 0
var flat_bonus:        int   = 0
var attack_multiplier: float = 1.0
var target_multiplier: float = 1.0
var ignore_defense:    bool  = false
var damage_type:       String = "physical"   # physical | magic | pure
var tags:              Array  = []
var min_damage:        int   = 1

# Stato / output
var cancelled:     bool = false   # hook ha annullato l'attacco (es. schivata)
var instant_kill:  bool = false   # override — porta HP a 0
var final_damage:  int  = 0       # valorizzato da DamagePipeline.execute()
var defense_bonus: int  = 0       # bonus difesa temporaneo (es. Sentinella)

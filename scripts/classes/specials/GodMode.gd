extends ClassSpecial
# passive: immune a tutti i danni.
# Danno=1 per ogni attacco del player già gestito in DamagePipeline (classe "divinita").

func on_before_player_damaged(ctx) -> void:
	ctx.set("cancelled", true)

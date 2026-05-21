extends ClassSpecial
# passive: attributi iniziali a 10 gestiti da Main._reset_game_state().
# XP ×3 via LevelSystem — intercettato su on_enemy_killed riducendo l'XP aggiunto di 2/3
# (il sistema aggiunge normalmente, qui togliamo i 2/3 extra dopo ogni kill).
# Nota: la modifica degli attributi iniziali è in Main._reset_game_state().

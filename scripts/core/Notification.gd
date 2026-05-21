extends RefCounted
class_name Notification

var text:     String
var color:    Color = Color.WHITE
var duration: float = 3.0


static func item(item_name: String, qty: int = 1) -> Notification:
	var n := Notification.new()
	n.text = "Raccolto: %s%s" % [item_name, (" x%d" % qty) if qty > 1 else ""]
	n.color = Color(0.85, 0.85, 0.95)
	return n


static func gold(amount: int) -> Notification:
	var n := Notification.new()
	n.text = "+%d oro" % amount
	n.color = Color(1.0, 0.82, 0.2)
	return n


static func quest_started(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = "Nuova quest: %s" % quest_name
	n.color = Color(0.4, 0.9, 0.45)
	return n


static func quest_ready(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = "Torna a consegnare: %s" % quest_name
	n.color = Color(1.0, 0.6, 0.1)
	n.duration = 4.0
	return n


static func quest_completed(quest_name: String) -> Notification:
	var n := Notification.new()
	n.text = "Quest completata: %s" % quest_name
	n.color = Color(0.95, 0.8, 0.15)
	n.duration = 4.0
	return n


static func level_up(level: int) -> Notification:
	var n := Notification.new()
	n.text = "Livello %d!" % level
	n.color = Color(0.75, 0.4, 1.0)
	n.duration = 4.0
	return n


static func class_unlock(name: String) -> Notification:
	var n := Notification.new()
	n.text  = "Classe sbloccata: %s!" % name
	n.color = Color(0.45, 0.90, 1.0)
	n.duration = 5.0
	return n


static func class_respec(name: String) -> Notification:
	var n := Notification.new()
	n.text  = "Classe cambiata: %s!" % name
	n.color = Color(0.95, 0.55, 0.95)
	n.duration = 4.0
	return n


static func warning(msg: String) -> Notification:
	var n := Notification.new()
	n.text = msg
	n.color = Color(0.95, 0.55, 0.15)
	return n


static func save_point() -> Notification:
	var n := Notification.new()
	n.text = "Partita salvata — HP ripristinati"
	n.color = Color(0.4, 0.88, 0.95)
	n.duration = 3.5
	return n

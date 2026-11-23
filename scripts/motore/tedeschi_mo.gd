extends RefCounted
## Paragrafi d’azione dei tedeschi propri di Move Out! (quelli identici al gioco base usano tedeschi.gd).

var t  # tedeschi.gd

func _init(tedeschi) -> void:
	t = tedeschi

## Esegue il paragrafo n se è di Move Out!; false per lasciarlo al gioco base.
func esegui(n: int) -> bool:
	var g: Dictionary = t._g
	match n:
		466, 469, 471:
			if int(g.get("paracadute", 0)) > 0:
				_togli_paracadute(g)
			else:
				t.esegui({466: 865, 469: 863, 471: 864}[n])
		476:
			if not t._cedi_turno(1):
				esegui(466)
		477:
			g.reazione = "Z"
			t._reazione_cambiata = true
			t.p._log("tedesco", "Reazione speciale Z in vigore per il %s." % t.p.nome(g))
		_:
			return false
	return true

func _togli_paracadute(g: Dictionary) -> void:
	if g.postura == "prone":
		t._accovacciati()
	g.paracadute = int(g.paracadute) - 1
	if int(g.paracadute) > 0:
		t.p._log("tedesco", "Il %s comincia a togliersi il paracadute." % t.p.nome(g))
	else:
		t.p._log("tedesco", "Il %s si è tolto il paracadute." % t.p.nome(g))
	t._fermo = true

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
		967, 969:
			t.p.leggi(str(n), {"g": g.id, "hex": g.hex})
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

## Azioni dei carri di Move Out! (Missione 10). false per lasciarle al gioco base.
func esegui_carro(n: int, g: Dictionary, veic: Dictionary) -> bool:
	var vv = t.p.veicoli
	var c1: bool = int(t.p.s.condizione) == 1
	match n:
		919:
			_log_par(n, g)
			var vicina: bool = t.p.mo.artiglieria_vicina(veic.hex)
			if vicina and not veic.get("chiuso", false):
				vv._apri_chiudi(veic, true)
			elif vicina:
				vv._guida(veic, false, g)
			else:
				vv._guida(veic, not veic.get("chiuso", false), g)
		920:
			_log_par(n, g)
			if not veic.get("chiuso", false):
				vv._apri_chiudi(veic, true)
			else:
				vv._guida(veic, false, g)
		921:
			_log_par(n, g)
			vv._guida(veic, false, g)
			vv._mg(g, veic, "scafo", false, 0)
			vv._cannone_o_carica(g, veic)
		923, 925, 926, 927:
			_log_par(n, g)
			if c1:
				esegui_carro(919, g, veic)
			else:
				var dopo: int = {923: 910, 925: 921, 926: 900, 927: 924}[n]
				if not esegui_carro(dopo, g, veic):
					vv.esegui_carro(dopo, g, veic)
		928, 929, 930, 931:
			_log_par(n, g)
			if c1:
				esegui_carro(920, g, veic)
			else:
				var dopo2: int = {928: 814, 929: 908, 930: 968, 931: 970}[n]
				if not esegui_carro(dopo2, g, veic):
					vv.esegui_carro(dopo2, g, veic)
		968, 970:
			_log_par(n, g)
			vv._cannone_o_carica(g, veic)
			vv._mg(g, veic, "scafo", false, 0)
		972:
			_log_par(n, g)
			vv._mg(g, veic, "scafo", false, 0)
		973:
			_log_par(n, g)
			vv._mg(g, veic, "coax", false, 1)
		_:
			return false
	return true

func _log_par(n: int, g: Dictionary) -> void:
	if t.p.paragrafi.has(str(n)):
		t.p._log("par", t.p.paragrafi[str(n)].it, {"id": str(n), "tedesco": g.id})

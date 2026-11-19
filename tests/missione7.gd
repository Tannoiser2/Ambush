extends SceneTree
## Missione 7: schieramento sul ruscello, mine anticarro, eventi continui, carri, uscita dei tedeschi a ovest.
## Uso: godot --headless --path . --script tests/missione7.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func errori_cronaca(q) -> Array:
	var e: Array = q.s.cronaca.filter(func(c): return str(c.get("t", "")) == "errore")
	for c in e:
		print("        ! " + str(c.x))
	return e

func gioca_round(q, max_passi := 400) -> void:
	var passi := 0
	while q.s.fase == "round" and passi < max_passi:
		passi += 1
		if q.s.pausa != "":
			q.prosegui()
			continue
		var turno: Array = q.americani_di_turno()
		if turno.is_empty():
			q.prosegui()
		else:
			q.passa(turno[0].id)

func _init() -> void:
	for seme in range(1, 9):
		var p = PartitaScript.new(7)
		p.nuova(seme, true)
		if seme == 1:
			ok(p.e_ingresso("T10") and p.e_ingresso("J10") and not p.e_ingresso("A10") and not p.e_ingresso("L7"), "schieramento: riva ovest o entro 3 dal ruscello")
		for id in ["A", "B", "C", "D"]:
			p.schiera([id], "R11")
		for id in ["E", "F", "G", "H"]:
			p.schiera([id], "Q16")
		ok(p.inizia_missione().ok, "partenza (seme %d)" % seme)
		if seme == 1:
			ok(p.s.mine_at.size() == 2, "due mine anticarro in %s" % str(p.s.mine_at))
			ok(not p.veicoli.v("vjeep").is_empty() and p.e_ingresso(p.veicoli.v("vjeep").hex), "la jeep è nell’area di schieramento")
			ok(p.arma_di(p.u("C"), "bazooka").preparata, "bazooka pronti")
			ok(p.fase_round(), "gli eventi portano i tedeschi e iniziano i Round")
		gioca_round(p)
		ok(errori_cronaca(p).is_empty(), "partita %d senza errori (Condizione %d, %s)" % [seme, int(p.s.condizione), p.s.fase])
	# Mina anticarro sotto un’auto e sotto un carro.
	var q = PartitaScript.new(7)
	q.nuova(2)
	q.s.mine_at = ["K11", "K12"]
	var v: Dictionary = q.veicoli.crea("vprova", "kubelwagen", "J11", "de")
	q.veicoli.sposta(v, "K11")
	ok(v.stato != "attivo", "l’auto salta sulla mina")
	q.leggi("715", {"hex": "", "ids": []})
	var jp: Dictionary = q.veicoli.v("v54")
	ok(not jp.is_empty() and jp.modello == "jagdpanther", "Jagdpanther in A6")
	jp.hex = "J12"
	q.veicoli.sposta(jp, "K12")
	ok(jp.get("immobilizzato", false), "il carro sulla mina resta immobilizzato")
	ok(errori_cronaca(q).is_empty(), "mine senza errori")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)

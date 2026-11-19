extends SceneTree
## Regola 6/6: un tedesco attivato a Round in corso dall’azione di un americano non blocca quell’azione.
## Il soldato la porta a termine, poi il tedesco appena attivato usa i suoi turni.
func _init() -> void:
	var errori := 0
	var p := Partita.new()
	p.nuova(5)
	p.muovi(["A"], "E1")
	var attiva := {"stance": "prone", "adv": "de", "two": [], "us_two": false, "aware": false, "reaction": null, "rounds": true}
	var primo := attiva.duplicate()
	primo.g = [[1, "E3"]]
	p._op_attiva(primo, {"hex": "E1", "ids": ["A"]})
	var giri := 0
	while (p.s.pausa != "" or p.americani_di_turno().is_empty()) and giri < 60 and p.s.fase == "round":
		giri += 1
		p.prosegui()
	var a: Dictionary = p.americani_di_turno()[0]
	p.scegli_azione(a.id, "muovi")
	var secondo := attiva.duplicate()
	secondo.g = [[34, "M5"]]
	secondo.two = [34]
	secondo.stance = "crouching"
	p._inizia_registrazione()
	p._op_attiva(secondo, {"hex": a.hex, "ids": [a.id]})
	var esiti := [
		[int(p.u("g34").turni) == 2, "il tedesco 34 entra con 2 turni"],
		[p.puo_agire(a) == "", "il soldato che lo ha attivato può ancora agire (%s)" % p.puo_agire(a)],
		[p.americani_di_turno().map(func(x): return x.id) == [a.id], "ed è lui quello di turno"],
		[not p.destinazioni(a.id).is_empty(), "può continuare il movimento"],
		[p.fine_azione(a.id).ok, "può concludere l’azione"],
		[p.s.pausa == "azioni_tedesche" and int(p.u("g34").turni) < 2, "subito dopo agisce il tedesco appena attivato"],
	]
	for e in esiti:
		print(("ok      " if e[0] else "ERRORE  ") + str(e[1]))
		if not e[0]:
			errori += 1
	print("Errori: ", errori)
	quit(1 if errori > 0 else 0)

extends SceneTree
## Verifica lo schieramento iniziale: disporre i soldati non fa partire nulla; il via legge le carte.
func _init() -> void:
	var errori := 0
	var p := Partita.new()
	p.nuova(7, true)
	var c0: int = p.s.cronaca.size()
	var esiti := [
		[p.s.fase == "schieramento", "la partita comincia in schieramento"],
		[p.schiera(["A", "B", "C"], "E1").ok, "tre soldati in E1"],
		[p.schiera(["D"], "F1").ok and p.schiera(["E", "F", "G", "H"], "C1").ok, "gli altri in F1 e C1"],
		[not p.schiera(["A"], "E2").ok, "E2 non è un esagono d’ingresso"],
		[p.schiera(["D"], "G1").ok and p.u("D").hex == "G1", "un soldato già schierato si può spostare"],
		[p.schiera(["H"], "").ok and p.u("H").stato == "fuori", "un soldato si può rimettere fuori mappa"],
		[p.s.fase == "schieramento" and p.s.cronaca.size() == c0 and p.tedeschi().is_empty(), "finché non si dà il via non succede nulla"],
	]
	var r: Dictionary = p.inizia_missione()
	esiti.append([r.ok and p.s.fase != "schieramento", "il via fa cominciare la missione"])
	esiti.append([p.s.cronaca.size() > c0, "al via si leggono le carte degli esagoni occupati"])
	esiti.append([p.u("H").stato == "fuori" and "A1" in p.destinazioni("H"), "chi è rimasto fuori può entrare dopo"])
	esiti.append([not p.inizia_missione().ok and not p.schiera(["A"], "A1").ok, "dopo il via lo schieramento è chiuso"])
	var q := Partita.new()
	q.nuova(3, true)
	esiti.append([not q.inizia_missione().ok, "senza soldati schierati non si parte"])
	for e in esiti:
		print(("ok      " if e[0] else "ERRORE  ") + str(e[1]))
		if not e[0]:
			errori += 1
	print("Errori: ", errori)
	quit(1 if errori > 0 else 0)

# -*- coding: utf-8 -*-
"""Move Out! – Missione 10 «Assalto per uccidere» (mappa A poi mappa B, Saint-Lô, giugno 1944).

Condizione 1: i tedeschi avanzano sulla mappa A sotto il fuoco dei mortai americani (li comanda il giocatore).
Condizioni 2–4: la squadra entra nella mappa B e difende la città dai tedeschi riattivati.
"""
from paragrafi_m1 import see, if_, S, NOT, sighting, cond

P = {}


def par(pid, it, ops, kind="missione"):
    P[pid] = {"id": pid, "it": it, "ops": ops, "tipo": kind}


def mov(pid, it, ops):
    par(pid, it, ops, "movimento")


def enter(h):
    return {"op": "g_enter", "hex": h}


def num_le(pid, n, a, b):
    mov(pid, f"Se si muove il tedesco {n} o uno con numero più basso entra in {a}; altrimenti entra in {b}.",
        [if_({"g_num_max": n}, [enter(a)], [enter(b)])])


def vede(pid, a, b):
    mov(pid, f"Se non ha bersagli attivi in vista entra in {a}; altrimenti entra in {b}.",
        [if_({"g_vede_almeno": 1}, [enter(b)], [enter(a)])])


def mezzo(pid, v, s_):
    mov(pid, f"Se si muove un mezzo entra in {v}; se si muove un soldato entra in {s_}.",
        [if_({"vehicle_moving": True}, [enter(v)], [enter(s_)])])


def soldato(pid, s_, altro):
    mov(pid, f"Se si muove un soldato entra in {s_}; altrimenti entra in {altro}.",
        [if_({"vehicle_moving": True}, [enter(altro)], [enter(s_)])])


def riattiva(pid, s, coppie, altrimenti, extra=None, testo=""):
    nomi = " e ".join(f"il tedesco {n} in {h}" for n, h in coppie)
    it = (f"[s{s}] Attiva {nomi}, in piedi. Iniziano i Round, vantaggio tedesco, e "
          f"{'ricevono' if len(coppie) > 1 else 'riceve'} 2 turni in questo Round. Chi è stato messo fuori combattimento "
          f"nella Condizione 1 si ignora; se nessuno può entrare, vedi {altrimenti}." + testo)
    ops = sighting(s) + [{"op": "riattiva", "g": [[n, h] for n, h in coppie], "altrimenti": altrimenti}]
    par(pid, it, ops + (extra or []))


# ------------------------------------------------------------------ movimenti (carte Condizione)
num_le("828", 25, "F17", "G18")
num_le("830", 23, "E7", "D7")
num_le("834", 15, "I11", "J10")
num_le("836", 13, "L11", "J11")
num_le("837", 15, "J7", "H7")
num_le("838", 13, "L10", "M12")
num_le("841", 13, "K2", "M2")
num_le("842", 27, "S11", "R10")
num_le("843", 27, "T7", "S7")
num_le("844", 27, "U7", "T6")
num_le("845", 27, "W6", "V5")
num_le("846", 27, "Y5", "X4")
num_le("847", 35, "U14", "V14")
vede("849", "C3", "C2")
vede("850", "M3", "N1")
mov("851", "Se si muove il tedesco 36 o uno con numero più alto entra in U4; altrimenti entra in U3.",
    [if_({"g_num_min": 36}, [enter("U4")], [enter("U3")])])
vede("852", "M9", "M10")
vede("853", "P10", "O9")
vede("854", "H16", "I17")
mov("855", "Se non ha bersagli americani attivi entro sette esagoni entra in M13; altrimenti entra in M14.",
    [if_({"g_vede_entro": 7}, [enter("M14")], [enter("M13")])])
mezzo("621", "S9", "T8")
vede("950", "R14", "R13")
mov("951", "Un soldato senza bersagli in vista entra in T14, con bersagli in vista in S14; un mezzo entra in T15.",
    [if_({"vehicle_moving": True}, [enter("T15")], [if_({"g_vede_almeno": 1}, [enter("S14")], [enter("T14")])])])
mov("952", "Se si muove il tedesco 26 entra in T5; altrimenti entra in R5.",
    [if_({"g_num": 26}, [enter("T5")], [enter("R5")])])
soldato("954", "O8", "O9")
soldato("956", "P9", "P8")
soldato("958", "Q8", "Q9")
soldato("960", "S9", "S10")
soldato("962", "U10", "T8")
soldato("964", "U8", "T6")
mov("966", "Se si muove il tedesco 26 entra in V6; altrimenti entra in V5.",
    [if_({"g_num": 26}, [enter("V6")], [enter("V5")])])
mov("980", "Se è al piano superiore scende al pianterreno. Se è al pianterreno e c’è un americano attivo al piano "
    "superiore, sale e lo carica per ucciderlo. Altrimenti entra in T13.", [{"op": "scala_tedesco", "altrimenti": "T13"}])
mezzo("981", "L4", "L5")
mezzo("982", "O4", "O5")
mezzo("983", "P4", "O5")
mezzo("984", "S5", "S4")
mezzo("985", "I13", "I14")
mezzo("986", "N11", "N10")
mezzo("987", "K12", "J13")
mezzo("988", "R14", "S13")

# ------------------------------------------------------------------ azioni dei carri (scripts/motore/tedeschi_mo.gd)
for n, t in {
    "919": "Se l’artiglieria è caduta nel suo esagono o in uno adiacente chiude i portelli (se già chiuso avanza piano); "
           "se è aperto e non è caduta artiglieria vicino avanza veloce.",
    "920": "Se è aperto chiude i portelli; se è chiuso avanza piano.",
    "921": "Avanza piano. Tiro rapido con la mitragliatrice di scafo al bersaglio più vicino. Spara col cannone a un bersaglio "
           "in un edificio o a un mezzo americano in vista; se non può, carica il cannone.",
    "923": "Nella Condizione 1 vedi 919; nelle Condizioni 2–4 vedi 910.",
    "925": "Nella Condizione 1 vedi 919; nelle Condizioni 2–4 vedi 921.",
    "926": "Nella Condizione 1 vedi 919; nelle Condizioni 2–4 vedi 900.",
    "927": "Nella Condizione 1 vedi 919; nelle Condizioni 2–4 vedi 924.",
    "928": "Nella Condizione 1 vedi 920; nelle Condizioni 2–4 vedi 814.",
    "929": "Nella Condizione 1 vedi 920; nelle Condizioni 2–4 vedi 908.",
    "930": "Nella Condizione 1 vedi 920; nelle Condizioni 2–4 vedi 968.",
    "931": "Nella Condizione 1 vedi 920; nelle Condizioni 2–4 vedi 970.",
    "968": "Spara col cannone a un mezzo nemico in vista o a un bersaglio in un edificio; se non può, carica il cannone. "
           "Spara con la mitragliatrice di scafo al bersaglio più vicino.",
    "970": "Spara col cannone a un bersaglio in un edificio o a un mezzo nemico in vista; se non può, carica il cannone. "
           "Spara con la mitragliatrice di scafo al bersaglio più facile.",
    "972": "Tiro rapido con la mitragliatrice di scafo al bersaglio più vicino.",
    "973": "Tiro rapido con la mitragliatrice coassiale al bersaglio più vicino.",
}.items():
    par(n, t, [], "azione")

# ------------------------------------------------------------------ eventi
par("871", "1. Se l’avvistamento 4 non è avvenuto, vedi 875. 2. Se non è avvenuto l’1, vedi 877. 3. Se non è avvenuto il 5, "
    "vedi 879. 4. Se non è avvenuto lo 0, vedi 881. 5. Se non è avvenuto il 2, vedi 882. 6. Se non è avvenuto il 3, vedi 884. "
    "7. Se non è avvenuto il 6, vedi 886. 8. Se non è avvenuto il 7, vedi 888. 9. Altrimenti vedi 893.",
    [if_(NOT(S(4)), [see("875")], [if_(NOT(S(1)), [see("877")], [if_(NOT(S(5)), [see("879")], [if_(NOT(S(0)), [see("881")],
     [if_(NOT(S(2)), [see("882")], [if_(NOT(S(3)), [see("884")], [if_(NOT(S(6)), [see("886")], [if_(NOT(S(7)), [see("888")],
     [if_(NOT(S(8)), [see("893")], [])])])])])])])])])])
par("873", "Colpo d’artiglieria! Un dado per la colonna (0 P, 1 Q, 2 R, 3 S, 4 T, 5 U, 6 V, 7 W, 8 X, 9 Y), due dadi sommati "
    "per la riga. Nell’esagono colpito si mette un cratere: chiunque vi si trovi (anche tedesco) muore e i mezzi sono fuori uso.",
    [{"op": "colpo_casuale"}])
riattiva("875", 4, [(34, "A1"), (35, "A1")], "877")
riattiva("877", 1, [(14, "A19"), (16, "A18")], "879")
riattiva("879", 5, [(36, "A2"), (37, "A2")], "881")
riattiva("881", 0, [(13, "A17"), (15, "A16")], "882")
riattiva("882", 2, [(22, "A12"), (24, "A13")], "884")
riattiva("884", 3, [(23, "A10"), (25, "A7")], "886", [cond(3)], " Si passa alla Condizione 3.")
riattiva("886", 6, [(26, "A5")], "888")
riattiva("888", 7, [(27, "A17")], "922")
par("893", "[s8] Arriva uno Sherman americano! Entra in Y5 e passa alla Condizione 4. (Nel gioco da tavolo lo muove la sua carta; "
    "qui lo comandi tu, come lo Sherman della Missione 8.)", sighting(8) + [{"op": "sherman_mo", "hex": "Y5"}, cond(4)])
par("922", "Si passa alla Condizione 4.", [cond(4)])
par("461", "Un tedesco incapacitato, scelto a caso, muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "de", "chiave": "mo461"}])
par("485", "Un tedesco ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "de", "chiave": "mo485"}])
par("623", "Un americano ferito, scelto a caso, diventa incapacitato per la perdita di sangue. Una volta sola per missione.",
    [{"op": "dissanguamento", "lato": "us", "chiave": "mo623"}])
par("935", "Un americano incapacitato, scelto a caso, muore per le ferite. Una volta sola per missione.",
    [{"op": "morte_incapacitato", "lato": "us", "chiave": "mo935"}])
par("645", "Un americano in terreno accidentato, scelto a caso, cade: controllo di percezione; se fallisce è colpito come da "
    "un colpo di pistola. Una volta sola per missione.", [{"op": "caduta"}])

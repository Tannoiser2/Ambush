"""Montaggio di modelli che arrivano come kit di stampa (pezzi stesi sul piatto).

Ogni pezzo: (id oggetto nel 3MF, assi, centro, rotazioni extra).
- assi: tre lettere con segno che dicono dove va ogni asse del pezzo (X, Y, Z del file):
  F = avanti, U = su, R = destra; per esempio "R U F" vuol dire X→destra, Y→su, Z→avanti, "-F" ribalta.
- centro: (F, U, R) dove finisce il centro del riquadro del pezzo, nelle unità del file.
- rot: rotazioni extra [(asse F/U/R, gradi)] attorno al centro del pezzo, dopo l'orientamento.
Il risultato è nel sistema di costruisci_mezzi3d: Z in alto, davanti verso +X (destra = −Y).
"""
import os
import sys
import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from leggi_3mf import leggi

_ASSE = {"F": np.array([1.0, 0, 0]), "U": np.array([0, 0, 1.0]), "R": np.array([0, -1.0, 0])}


def _orienta(m, assi):
    """Matrice che porta gli assi del pezzo negli assi F/U/R del mondo."""
    colonne = []
    for a in assi.split():
        s = -1.0 if a.startswith("-") else 1.0
        colonne.append(_ASSE[a[-1]] * s)
    R = np.column_stack(colonne)
    if np.linalg.det(R) < 0:
        # sarebbe uno specchio: si ribalta l'asse che va a destra (i pezzi del kit sono simmetrici o in coppia)
        for k, a in enumerate(assi.split()):
            if a[-1] == "R":
                R[:, k] *= -1
    T = np.eye(4)
    T[:3, :3] = R
    return T


def _metti(m, assi, centro, rot=()):
    m = m.copy()
    m.apply_translation(-m.bounds.mean(axis=0))
    m.apply_transform(_orienta(m, assi))
    for asse, gradi in rot:
        m.apply_transform(trimesh.transformations.rotation_matrix(np.radians(gradi), _ASSE[asse]))
    f, u, r = centro
    m.apply_translation(_ASSE["F"] * f + _ASSE["U"] * u + _ASSE["R"] * r)
    return m


# Sidecar Ural M72 (copia della BMW R71): unità del file, ruota col copertone ≈ 85.
MOTO = [
    ("104", "R U F", (-5, 72, 0), ()),                 # telaio
    ("23", "R F U", (12, 46, 0), ()),                  # motore boxer
    ("49", "R U F", (22, 112, 0), ()),                 # serbatoio
    ("12", "R U F", (-32, 118, 0), ()),                # sella del pilota
    ("29", "R U F", (-78, 108, 0), ()),                # sella del passeggero
    ("127", "R F U", (84, 84, 0), (("R", 22),)),      # forcella
    ("35", "R F U", (66, 150, 0), ()),                 # manubrio
    ("47", "R U F", (93, 62, 0), ()),                  # parafango anteriore
    ("51", "R U F", (-93, 62, 0), ()),                 # parafango posteriore
    ("2", "R U F", (93, 42.5, 0), ()), ("70", "R U F", (93, 42.5, 0), ()),      # ruota anteriore
    ("6", "R U F", (-93, 42.5, 0), ()), ("71", "R U F", (-93, 42.5, 0), ()),    # ruota posteriore
    ("10", "R U F", (-38, 42.5, 140), ()), ("72", "R U F", (-38, 42.5, 140), ()),  # ruota del carrozzino
    ("112", "R U F", (-20, 36, 66), ()),               # telaio del carrozzino
    ("132", "R U -F", (-12, 74, 118), ()),              # carrozzino
    ("116", "R U -F", (-30, 92, 118), ()),              # sedile del carrozzino
    ("122", "R U F", (-38, 60, 140), ()),              # parafango del carrozzino
]


def monta_moto(cartella):
    ogg = leggi(os.path.join(cartella, "M72.3mf"))
    return trimesh.util.concatenate([_metti(ogg[i], a, c, r) for i, a, c, r in MOTO])


# Aliante da modellismo (Aliante.3mf): fusoliera 4 + trave di coda 2, ali in tre pannelli per lato, coda a T.
ALIANTE = [
    ("4", "R F U", (0, 0, 0), ()),                  # fusoliera
    ("22", "R F U", (40, 44, 0), ()),               # tettuccio
    ("2", "R F U", (-310, 8, 0), ()),               # trave di coda
    ("10", "R F U", (-450, 70, 0), ()),             # deriva
    ("6", "R F U", (-470, 124, 60), ()),            # piani di coda
    ("8", "R F U", (-470, 124, -60), ()),
    ("12", "R F U", (10, 42, 190), ()),             # ala: pannello alla radice
    ("14", "R F U", (10, 42, -190), ()),
    ("16", "R F U", (4, 46, 520), ()),              # pannello centrale
    ("18", "R F U", (4, 46, -520), ()),
    ("28", "R F U", (-2, 50, 785), ()),             # estremità
    ("30", "R F U", (-2, 50, -785), ()),
]


def monta_aliante(cartella):
    ogg = leggi(os.path.join(cartella, "Aliante.3mf"))
    return trimesh.util.concatenate([_metti(ogg[i], a, c, r) for i, a, c, r in ALIANTE])


def monta_relitto(cartella):
    """Aliante schiantato: muso a terra, ala destra spezzata con il pannello centrale caduto accanto."""
    ogg = leggi(os.path.join(cartella, "Aliante.3mf"))
    pezzi = [_metti(ogg[i], a, c, r) for i, a, c, r in ALIANTE if i not in ("16", "28")]
    corpo = trimesh.util.concatenate(pezzi)
    corpo.apply_transform(trimesh.transformations.rotation_matrix(np.radians(-7), _ASSE["R"]))   # muso giù
    corpo.apply_transform(trimesh.transformations.rotation_matrix(np.radians(9), _ASSE["F"]))    # sbandato
    ala = _metti(ogg["16"], "R F U", (-90, 18, 430), (("U", 28), ("F", 6)))
    return trimesh.util.concatenate([corpo, ala])


MONTAGGI = {"moto": monta_moto, "aliante": monta_aliante, "aliante_relitto": monta_relitto}


def monta(nome, cartella):
    return MONTAGGI[nome](cartella)

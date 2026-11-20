#!/usr/bin/env python3
"""Prepara i modelli 3D di mezzi e oggetti per la vista 3D (assets/mezzi3d/<nome>.glb).

Ogni modello: ruotato con l'alto su Y e il davanti verso +Z, ridotto di triangoli,
portato alla lunghezza (o altezza) voluta in unità della mappa 3D, con la base a quota 0.
Uso: python3 tools/costruisci_mezzi3d.py <cartella con i file estratti> [nomi,…]
"""
import sys, os, json
import numpy as np, trimesh
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from costruisci_soldati3d import riduci

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USCITA = os.path.join(RADICE, "assets/mezzi3d")

# nome: (file, rotazioni [(asse, gradi)] nel sistema del file con Z in alto, misura, valore, triangoli)
# dopo le rotazioni il modello deve avere Z in alto e il davanti verso +X.
MEZZI = {
    "jagdpanther": ("Jagdpanther/Jagdpanther.stl", [], "lunghezza", 1.55, 9000),
    "sherman": ("WW2+Tabletop+Wargame+-+US+Sherman+Tank/US Sherman stl.stl", [("z", 180)], "lunghezza", 1.45, 9000),
    "kubelwagen": ("Kubel+Wagen/684a7ec615bcb65481aff33f8a18a6f2.stl", [("z", 90)], "lunghezza", 0.95, 5000),
    "jeep": ("miniature+jeep+toy_stls/obj_2_jeep toy 3d model (1).stl_B.stl", [("x", -90), ("z", -90)], "lunghezza", 0.9, 5000),
    "canoa": ("小木船_stls/obj_1_mWkb7ZVmwBezSZP9QBn0y.stl_A.stl", [("z", 90)], "lunghezza", 0.95, 2500),
    "pz4_torretta": ("Pz4_-_G(2)_stls/obj_19_Pz.IV G v20_1.stl", [("z", 90)], "lunghezza", 0.62, 3000),
    "radio": ("Wojskowe+radio+polowe_stls/obj_1_Wojskowe radio polowe.stl_A_A.stl", [], "altezza", 0.22, 2000),
    "tanica": ("Steel+Jerry+Can+1_32.stl", [], "altezza", 0.16, 800),
    "barricata": ("Army+Man+BARRICADE/barracade.3mf", [("z", 90)], "lunghezza", 0.9, 3000),
    "mg_tiratore": ("machine+gun+sld+var+4_stls/obj_1_Assembly_A_A.stl", [], "altezza", 0.7, 4000),
    "mg_treppiede": ("machine+gun+sld+var+4_stls/obj_2_Assembly_A_B.stl", [], "altezza", 0.42, 2500),
    "sacchetti": ("sandbagspart2_3_stls/obj_1_sandbagspart2_3.stl", [], "lunghezza", 1.1, 4000),
}


LIVELLA = {"jeep"}


def costruisci(cartella, nome):
    f, rot, misura, valore, tri = MEZZI[nome]
    m = trimesh.load(os.path.join(cartella, f), force="mesh")
    v, fa = riduci(m.vertices, m.faces, tri)
    m = trimesh.Trimesh(v, fa, process=True)
    if nome in LIVELLA:
        # pezzi stampati inclinati: prima si allineano al loro riquadro orientato
        T, _ = trimesh.bounds.oriented_bounds(m)
        m.apply_transform(T)
    for asse, gradi in rot:
        a = {"x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1]}[asse]
        m.apply_transform(trimesh.transformations.rotation_matrix(np.radians(gradi), a))
    # Z su -> Y su; +X avanti -> +Z avanti
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0]))
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [0, 1, 0]))
    e = m.extents
    s = valore / (e[2] if misura == "lunghezza" else e[1])
    m.apply_scale(s)
    b = m.bounds
    m.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
    m.fix_normals()
    os.makedirs(USCITA, exist_ok=True)
    m.export(os.path.join(USCITA, nome + ".glb"), include_normals=True)
    return len(m.faces), m.extents.round(3).tolist()


if __name__ == "__main__":
    cartella = sys.argv[1]
    solo = sys.argv[2].split(",") if len(sys.argv) > 2 else list(MEZZI)
    for n in solo:
        print(n, costruisci(cartella, n))

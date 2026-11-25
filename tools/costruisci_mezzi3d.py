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
    # dai 3MF (file#oggetto; "#*" = tutti gli oggetti, "#max" = il più grande)
    "opel_blitz": ("vintage+truck+ww2+toy.3mf#*", [("x", 90), ("z", 90)], "lunghezza", 1.5, 7000),
    "pak40": ("Pak 40.3mf#*", [("z", 180)], "lunghezza", 1.25, 7000),
    "sdkfz251": ("SdKfz251_2cm.3mf#*", [("z", -90)], "lunghezza", 1.45, 9000),
    "mortaio": ("81+MM+Mortar+Model+Set.3mf#11", [("z", 180)], "altezza", 0.36, 4000),
    "cane": ("Cane.3mf#*", [("z", 90)], "altezza", 0.24, 4000),
    "faro": ("Faro.3mf#*", [], "altezza", 1.95, 6000),
    "locomotiva": ("ww2+steam+locomotive+bambus.3mf#*", [], "lunghezza", 1.5, 8000),
    "vagone": ("VagoneLetto.3mf#max", [], "lunghezza", 1.42, 6000),
    # kit montati da tools/montaggi3d.py ("@nome")
    "moto": ("@moto", [], "lunghezza", 0.62, 6000),
    "aliante_relitto": ("@aliante_relitto", [], "lunghezza", 1.25, 6000),
}


LIVELLA = {"jeep", "opel_blitz"}


def carica(cartella, f):
    if f.startswith("@"):
        from montaggi3d import monta
        return monta(f[1:], cartella)
    if "#" in f:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from leggi_3mf import leggi
        nome, chi = f.split("#")
        ogg = leggi(os.path.join(cartella, nome))
        if chi == "*":
            return trimesh.util.concatenate(list(ogg.values()))
        if chi == "max":
            return max(ogg.values(), key=lambda m: len(m.faces))
        return ogg[chi]
    if f.endswith("/*"):
        import glob
        parti = [trimesh.load(x, force="mesh") for x in sorted(glob.glob(os.path.join(cartella, f[:-2], "*.stl")))]
        return trimesh.util.concatenate(parti)
    return trimesh.load(os.path.join(cartella, f), force="mesh")


def costruisci(cartella, nome):
    f, rot, misura, valore, tri = MEZZI[nome]
    m = carica(cartella, f)
    v, fa = riduci(m.vertices, m.faces, tri)
    if len(fa) > tri * 1.5:
        # pezzi sottili (cingoli, tralicci): la riduzione prudente si ferma presto; qui si forza
        import pymeshlab
        ms = pymeshlab.MeshSet()
        ms.add_mesh(pymeshlab.Mesh(np.asarray(v, np.float64), np.asarray(fa, np.int32)))
        ms.meshing_merge_close_vertices()
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(tri), preservenormal=True, planarquadric=True)
        mm = ms.current_mesh()
        v, fa = mm.vertex_matrix(), mm.face_matrix()
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

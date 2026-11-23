#!/usr/bin/env python3
"""Mezzi e oggetti dipinti dal modulo Tabletop Simulator di Ambush! per la vista 3D.

Salva assets/mezzi3d/<nome>.glb (con UV) e <nome>.jpg (tessitura); davanti verso +Z,
base a quota 0, lunghezza in unità della mappa 3D (un esagono è largo circa 2,2).
Uso: python3 tools/costruisci_mezzi_tts.py <cartella Mods>
"""
import sys, os
import numpy as np, trimesh
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from costruisci_soldati_tts import modelli, trova

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USCITA = os.path.join(RADICE, "assets/mezzi3d")
# nome: (indice nel modulo, rotazione attorno a Y in gradi per portare il davanti su +Z, misura, valore)
MEZZI = {
    "canoa": (20, 90, "lunghezza", 0.95),
    "jeep": (21, 0, "lunghezza", 1.05),
    "sherman": (22, 0, "lunghezza", 1.45),
    "kubelwagen": (23, 180, "lunghezza", 0.95),
    "panzer4": (24, 0, "lunghezza", 1.45),
    "jagdpanther": (25, 0, "lunghezza", 1.6),
    "bunker": (49, 0, "larghezza", 1.35),
    "cratere": (52, 0, "larghezza", 1.3),
    "crateri": (51, 0, "larghezza", 1.6),
}


def main():
    cartella = sys.argv[1]
    lista = modelli(cartella)
    os.makedirs(USCITA, exist_ok=True)
    for nome, (i, rot, misura, valore) in MEZZI.items():
        m = trimesh.load(trova(cartella, "Models", lista[i][0]), force="mesh", process=False)
        uv = m.visual.uv.copy()
        m.apply_transform(trimesh.transformations.rotation_matrix(np.radians(rot), [0, 1, 0]))
        e = m.extents
        s = valore / (e[2] if misura == "lunghezza" else max(e[0], e[2]))
        m.apply_scale(s)
        b = m.bounds
        m.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
        m.visual = trimesh.visual.TextureVisuals(uv=uv)
        m.export(os.path.join(USCITA, nome + ".glb"), include_normals=True)
        im = Image.open(trova(cartella, "Images", lista[i][1])).convert("RGB")
        im.thumbnail((1024, 1024))
        im.save(os.path.join(USCITA, nome + ".jpg"), quality=88)
        print(nome, len(m.faces), np.round(m.extents, 3).tolist())


if __name__ == "__main__":
    main()

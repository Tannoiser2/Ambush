#!/usr/bin/env python3
"""Miniature dei soldati prese dal modulo Tabletop Simulator di Ambush! (colorate, con tessitura).

Legge il JSON del modulo e le cartelle Models/Images (Mods/ estratto dal .ttsmod), salva per ogni posa
assets/soldati3d/<nome>.glb (con coordinate UV, senza immagine) e le due tessiture condivise
assets/soldati3d/tessitura_us.jpg e tessitura_de.jpg.
Ogni figura: Y in alto, il davanti (la canna dell'arma) verso +Z, piedi a quota 0,
altezza della posa in piedi = 0,5 unità della mappa 3D.
Uso: python3 tools/costruisci_soldati_tts.py <cartella Mods>
"""
import sys, os, re, glob, json
import numpy as np, trimesh
from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USCITA = os.path.join(RADICE, "assets/soldati3d")
ALTEZZA = 0.5

# indice dell'oggetto nel modulo (ordine dei modelli personalizzati nel JSON)
US = {
    "us_garand_piedi": 11, "us_garand_acc": 12, "us_garand_prono": 13,
    "us_carabina_piedi": 8, "us_carabina_acc": 9, "us_carabina_prono": 10,
    "us_mitra_piedi": 14, "us_mitra_acc": 15, "us_mitra_prono": 16,
    "us_bar_piedi": 3, "us_bar_acc": 4, "us_bar_prono": 5,
    "us_bazooka_piedi": 17, "us_bazooka_acc": 18, "us_bazooka_prono": 19,
    "us_morto": 6, "us_ferito": 7,
}
DE = {
    "de_mg_piedi": 26, "de_mg_acc": 27, "de_mg_prono": 28,
    "de_morto": 29, "de_ferito": 30,
    "de_stg_piedi": 31, "de_stg_acc": 32, "de_stg_prono": 33,
    "de_mp_piedi": 34, "de_mp_acc": 35, "de_mp_prono": 36,
    "de_fucile_piedi": 37, "de_fucile_acc": 38, "de_fucile_prono": 39,
    "de_fucile2_piedi": 40, "de_fucile2_acc": 41, "de_fucile2_prono": 42,
    "de_ott_piedi": 43, "de_ott_acc": 44, "de_ott_prono": 45,
    "de_pistola_piedi": 46, "de_pistola_acc": 47, "de_pistola_prono": 48,
}


def pulisci(u):
    return re.sub(r"[^A-Za-z0-9]", "", u or "")


def modelli(cartella):
    d = json.load(open(glob.glob(os.path.join(cartella, "Workshop", "*.json"))[0]))
    lista, visti = [], set()

    def visita(o):
        if isinstance(o, dict):
            if "CustomMesh" in o:
                cm = o["CustomMesh"]
                k = (cm.get("MeshURL"), cm.get("DiffuseURL"))
                if k not in visti:
                    visti.add(k)
                    lista.append(k)
            for v in o.values():
                visita(v)
        elif isinstance(o, list):
            for v in o:
                visita(v)
    visita(d)
    return lista


def trova(cartella, sotto, url):
    coda = pulisci(url)[-20:]
    f = [p for p in glob.glob(os.path.join(cartella, sotto, "*")) if coda in os.path.basename(p)]
    return f[0] if f else None


def avanti(mesh):
    """Direzione orizzontale della canna: il punto più lontano dall'asse del corpo nella metà alta."""
    v = mesh.vertices
    y = v[:, 1]
    alto = v[y > y.min() + (y.max() - y.min()) * 0.5]
    asse = np.median(alto[:, [0, 2]], axis=0)
    d = alto[:, [0, 2]] - asse
    i = np.argmax(np.linalg.norm(d, axis=1))
    return d[i] / np.linalg.norm(d[i])


def main():
    cartella = sys.argv[1]
    lista = modelli(cartella)
    os.makedirs(USCITA, exist_ok=True)
    for lato, tab, rif in (("us", US, "us_garand_piedi"), ("de", DE, "de_fucile_piedi")):
        mesh_rif = trimesh.load(trova(cartella, "Models", lista[tab[rif]][0]), force="mesh", process=False)
        f = avanti(mesh_rif)
        ang = np.arctan2(f[0], f[1])   # da ruotare perché il davanti vada su +Z
        scala = ALTEZZA / mesh_rif.extents[1]
        tex = trova(cartella, "Images", lista[tab[rif]][1])
        im = Image.open(tex).convert("RGB")
        im.thumbnail((2048, 2048))
        im.save(os.path.join(USCITA, "tessitura_%s.jpg" % lato), quality=88)
        for nome, i in tab.items():
            m = trimesh.load(trova(cartella, "Models", lista[i][0]), force="mesh", process=False)
            uv = m.visual.uv.copy()
            a = ang
            if nome.endswith("_prono") or nome.endswith("_morto") or nome.endswith("_ferito"):
                # le pose a terra non sono orientate come quelle in piedi: si allinea il corpo all'asse
                # più lungo e la canna (l'estremo più lontano dal baricentro) va in avanti
                v = m.vertices[:, [0, 2]]
                c = v.mean(0)
                d = v - c
                k = np.argmax(np.linalg.norm(d, axis=1))
                a = np.arctan2(d[k][0], d[k][1])
            m.apply_transform(trimesh.transformations.rotation_matrix(-a, [0, 1, 0]))
            m.apply_scale(scala)
            b = m.bounds
            m.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
            m.visual = trimesh.visual.TextureVisuals(uv=uv)
            m.export(os.path.join(USCITA, nome + ".glb"), include_normals=True)
            print(nome, len(m.faces), np.round(m.extents, 3).tolist())


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Controlla che ogni carattere usato nell’interfaccia esista nei font del gioco.

Cerca i caratteri non ASCII nei sorgenti GDScript e nei dati (paragrafi, missione) e verifica
che siano presenti in ciascun font principale (Oswald, Special Elite, Stardos Stencil).
Un carattere che manca in un font principale ma esiste nel font di riserva (DejaVu) viene
segnalato come avviso; uno che manca ovunque è un errore: comparirebbe come un quadratino.

Uso: python3 tools/controlla_glifi.py
"""
import json, pathlib, sys
from fontTools.ttLib import TTFont

RADICE = pathlib.Path(__file__).resolve().parent.parent
FONT = {
    "Oswald": "assets/fonts/Oswald.ttf",
    "Special Elite": "assets/fonts/SpecialElite-Regular.ttf",
    "Stardos Stencil": "assets/fonts/StardosStencil-Bold.ttf",
}
RISERVA = "assets/fonts/DejaVuSans-Simboli.ttf"


def glifi(percorso):
    f = TTFont(str(RADICE / percorso))
    out = set()
    for t in f["cmap"].tables:
        out |= set(t.cmap.keys())
    return out


def caratteri():
    usati = {}
    for p in list((RADICE / "scripts").rglob("*.gd")):
        for n, riga in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            codice = riga.split("##")[0] if riga.lstrip().startswith("##") else riga
            if riga.lstrip().startswith("#"):
                continue
            # solo il contenuto delle stringhe
            dentro = False
            for ch in codice:
                if ch == '"':
                    dentro = not dentro
                elif dentro and ord(ch) > 126:
                    usati.setdefault(ch, f"{p.relative_to(RADICE)}:{n}")
    for nome in ["paragrafi.json", "missione1.json"]:
        testo = json.dumps(json.loads((RADICE / "data" / nome).read_text(encoding="utf-8")), ensure_ascii=False)
        for ch in testo:
            if ord(ch) > 126:
                usati.setdefault(ch, f"data/{nome}")
    return usati


def main():
    tavole = {n: glifi(p) for n, p in FONT.items()}
    riserva = glifi(RISERVA)
    usati = caratteri()
    errori = 0
    avvisi = 0
    for ch in sorted(usati):
        mancanti = [n for n, g in tavole.items() if ord(ch) not in g]
        if not mancanti:
            continue
        if ord(ch) in riserva:
            avvisi += 1
            print(f"avviso  U+{ord(ch):04X} «{ch}» manca in {', '.join(mancanti)}: usa il font di riserva ({usati[ch]})")
        else:
            errori += 1
            print(f"ERRORE  U+{ord(ch):04X} «{ch}» non esiste in nessun font: comparirebbe un quadratino ({usati[ch]})")
    print(f"Caratteri non ASCII usati: {len(usati)} · avvisi: {avvisi} · errori: {errori}")
    return 1 if errori else 0


if __name__ == "__main__":
    sys.exit(main())

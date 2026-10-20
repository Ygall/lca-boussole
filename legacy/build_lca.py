#!/usr/bin/env python3
"""
Boussole LCA - génération des livrables à partir des référentiels.

Usage : python build_lca.py [--sortie dist]

Entrées (dossier du script) :
  data/config.yml       métadonnées (titre, auteur, version, avertissement)
  data/notions.yml      libellés des notions, indexés par identifiant stable
  data/categories.yml   catégories A-D et domaines rattachés
  data/domaines.yml     domaines, notions de base et avancées (ordre de la carte mentale)
  data/parcours.yml     phases ordonnées, notions et prérequis directs
  fiches/<id>.md        fiches récap (corps uniquement ; en-tête généré)
  vendor/               d3 et markmap-view, intégrés tels quels dans le HTML

Sorties (dossier --sortie) :
  lca_notions_parcours.html   page unique à quatre onglets, utilisable hors ligne
  carte_mentale_lca.md/.mm    carte des notions (Markmap / Freeplane)
  parcours_lca.md/.mm         parcours ordonné avec prérequis (Markmap / Freeplane)
  reseau_lca.dot/.svg/.pdf    réseau de dépendances (Graphviz)

Dépendances : Python >= 3.9, PyYAML, Markdown, Graphviz (exécutable `dot`).

Dans les fiches, [[id]] est remplacé par le numéro de la notion (ex. 071) et
[[id:libelle]] par le numéro suivi du libellé (ex. 071. Rapport de cotes, ...).
"""
import argparse
import html as H
import json
import re
import shutil
import subprocess
import sys
import textwrap
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

import markdown
import yaml

RACINE = Path(__file__).resolve().parent.parent  # script déplacé dans legacy/
COUL = {"A": "#534AB7", "B": "#0F6E56", "C": "#993C1D", "D": "#185FA5"}
FOND = {"A": "#EEEDFE", "B": "#E1F5EE", "C": "#FAECE7", "D": "#E6F1FB"}
TEXTE = {"A": "#26215C", "B": "#04342C", "C": "#4A1B0C", "D": "#042C53"}


def lire(nom):
    return yaml.safe_load((RACINE / "data" / nom).read_text(encoding="utf-8"))


# Lecture et validation des référentiels ----------------------------------------------------------

def charger():
    cfg, lib, cats, doms, parc = (lire(f) for f in
                                   ["config.yml", "notions.yml", "categories.yml", "domaines.yml", "parcours.yml"])
    err = []
    dom_num = {d["numero"]: d for d in doms}
    cat_of_dom = {}
    for c in cats:
        for d in c["domaines"]:
            if d in cat_of_dom:
                err.append(f"domaine {d} rattaché à deux catégories")
            cat_of_dom[d] = c["code"]
    if set(cat_of_dom) != set(dom_num):
        err.append(f"domaines sans catégorie ou inconnus : {set(cat_of_dom) ^ set(dom_num)}")
    # notion -> domaine, niveau
    info = {}
    for d in doms:
        for niv in ("base", "avance"):
            for i in d.get(niv) or []:
                if i in info:
                    err.append(f"notion {i} présente dans plusieurs domaines")
                if i not in lib:
                    err.append(f"notion {i} (domaine {d['numero']}) absente de notions.yml")
                info[i] = {"domaine": d["numero"], "niveau": niv}
    # parcours : numérotation, prérequis antérieurs, cohérence année/niveau
    num, ordre = {}, []
    for ph in parc:
        for n in ph["notions"]:
            i = n["id"]
            if i in num:
                err.append(f"notion {i} présente deux fois dans le parcours")
                continue
            if i not in info:
                err.append(f"notion {i} du parcours absente de domaines.yml")
                continue
            for p in n.get("prerequis") or []:
                if p not in num:
                    err.append(f"{i} : prérequis {p} inconnu ou placé après la notion")
            if (ph["annee"] == 1) != (info[i]["niveau"] == "base"):
                err.append(f"{i} : niveau {info[i]['niveau']} incohérent avec l'année {ph['annee']}")
            num[i] = len(num) + 1
            info[i].update(phase=ph["numero"], annee=ph["annee"], prerequis=n.get("prerequis") or [])
            ordre.append(i)
    manquants = set(info) - set(num)
    if manquants:
        err.append(f"notions absentes du parcours : {sorted(manquants)}")
    if set(lib) - set(info):
        err.append(f"notions orphelines dans notions.yml : {sorted(set(lib) - set(info))}")
    if err:
        sys.exit("Référentiels invalides :\n- " + "\n- ".join(err))
    for i in ordre:
        d = info[i]["domaine"]
        info[i].update(num=num[i], libelle=lib[i], cat=cat_of_dom[d], code=f"{cat_of_dom[d]}{d}",
                       dependants=[])
    for i in ordre:
        for p in info[i]["prerequis"]:
            info[p]["dependants"].append(i)
    return cfg, cats, doms, parc, info, ordre


def n3(info, i):
    return f"{info[i]['num']:03d}"


def ligne_parcours(info, i):
    pre = ", ".join(n3(info, p) for p in info[i]["prerequis"])
    return f"{n3(info, i)}. {info[i]['libelle']} [{info[i]['code']}]" + (f" ← {pre}" if pre else "")


# Exports Markdown et Freeplane ---------------------------------------------------------------------

def exporter_cartes(sortie, cats, doms, parc, info):
    e = lambda s: escape(s, {'"': "&quot;"})
    dom_num = {d["numero"]: d for d in doms}
    # carte des notions
    md = ["# Carte mentale des notions de lecture critique d'article (EDN)", ""]
    mm = ['<map version="freeplane 1.9.13">',
          '<node TEXT="Lecture critique d\'article - EDN" FOLDED="false" BACKGROUND_COLOR="#F1EFE8"><font SIZE="18" BOLD="true"/>',
          '<node TEXT="Légende : fond bleu = base (année 1), italique gris = avancé (année 2)" POSITION="left" COLOR="#5F5E5A"><font SIZE="10"/></node>']
    for k, c in enumerate(cats):
        col = COUL[c["code"]]
        md += [f"## {c['code']}. {c['libelle']}", ""]
        mm.append(f'<node TEXT="{e(c["code"] + ". " + c["libelle"])}" POSITION="{"right" if k % 2 == 0 else "left"}" FOLDED="false" COLOR="{col}"><edge COLOR="{col}" WIDTH="3"/><font SIZE="15" BOLD="true"/>')
        for d in c["domaines"]:
            dd = dom_num[d]
            md += [f"### Domaine {d}. {dd['libelle']}", "", "- Base (année 1)"]
            md += [f"  - {info[i]['libelle']}" for i in dd.get("base") or []]
            md += ["- Avancé (année 2)"] + [f"  - {info[i]['libelle']}" for i in dd.get("avance") or []] + [""]
            mm.append(f'<node TEXT="{e(f"Domaine {d}. {dd["libelle"]}")}" FOLDED="false" COLOR="{col}"><edge COLOR="{col}" WIDTH="2"/><font SIZE="13" BOLD="true"/>')
            for i in dd.get("base") or []:
                mm.append(f'<node TEXT="{e(info[i]["libelle"])}" COLOR="#0C447C" BACKGROUND_COLOR="#E6F1FB"><edge COLOR="{col}" WIDTH="1"/><font SIZE="11"/></node>')
            for i in dd.get("avance") or []:
                mm.append(f'<node TEXT="{e(info[i]["libelle"])}" COLOR="#5F5E5A"><edge COLOR="{col}" WIDTH="1"/><font SIZE="11" ITALIC="true"/></node>')
            mm.append("</node>")
        mm.append("</node>")
    mm += ["</node>", "</map>"]
    (sortie / "carte_mentale_lca.md").write_text("\n".join(md), encoding="utf-8")
    ET.fromstring("\n".join(mm))
    (sortie / "carte_mentale_lca.mm").write_text("\n".join(mm), encoding="utf-8")
    # parcours (phases chaînées en escalier)
    md = [f"# Parcours d'apprentissage LCA ({len(info)} notions)", "",
          "Le code entre crochets indique catégorie et domaine ; les numéros après la flèche sont les prérequis directs.", ""]
    mm = ['<map version="freeplane 1.9.13">',
          f'<node TEXT="Parcours LCA - {len(info)} notions" FOLDED="false" BACKGROUND_COLOR="#F1EFE8" STYLE="bubble"><font SIZE="18" BOLD="true"/>',
          '<node TEXT="Légende : [A1] = catégorie A, domaine 1 ; ← = notions prérequises ; couleur = catégorie" POSITION="left" COLOR="#5F5E5A"><font SIZE="10"/></node>']
    annee = None
    for k, ph in enumerate(parc):
        if ph["annee"] != annee:
            annee = ph["annee"]
            md += [f"## Année {annee} ({'notions de base' if annee == 1 else 'notions avancées'})", ""]
        md += [f"### Phase {ph['numero']}. {ph['titre']}", ""] + [f"- {ligne_parcours(info, n['id'])}" for n in ph["notions"]] + [""]
        mm.append(f'<node TEXT="{e(f"Année {annee} - Phase {ph["numero"]}. {ph["titre"]}")}"{" POSITION=\"right\"" if k == 0 else ""} FOLDED="false" BACKGROUND_COLOR="#F1EFE8" STYLE="bubble"><font SIZE="13" BOLD="true"/><edge STYLE="horizontal" COLOR="#888780" WIDTH="3"/>')
        for n in ph["notions"]:
            col = COUL[info[n["id"]]["cat"]]
            mm.append(f'<node TEXT="{e(ligne_parcours(info, n["id"]))}" COLOR="{col}" STYLE="fork"><font SIZE="11"/><edge STYLE="bezier" COLOR="{col}" WIDTH="1"/></node>')
    mm += ["</node>"] * len(parc) + ["</node>", "</map>"]
    (sortie / "parcours_lca.md").write_text("\n".join(md), encoding="utf-8")
    ET.fromstring("\n".join(mm))
    (sortie / "parcours_lca.mm").write_text("\n".join(mm), encoding="utf-8")


# Réseau de dépendances (Graphviz) -----------------------------------------------------------------

def exporter_reseau(sortie, info, ordre):
    if shutil.which("dot") is None:
        sys.exit("Graphviz introuvable : installer l'exécutable `dot` (https://graphviz.org).")
    g = ["digraph G {", 'rankdir=LR; splines=true; nodesep=0.12; ranksep=0.9; bgcolor="transparent";',
         'node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=10 margin="0.08,0.04" width=2.1];',
         "edge [arrowsize=0.5 penwidth=0.8];"]
    for i in ordre:
        x, c = info[i], info[i]["cat"]
        lab = "\\n".join(textwrap.wrap(f"{n3(info, i)}. {x['libelle']}", 30)) + f"\\nPhase {x['phase']} - [{x['code']}]"
        sty = '"rounded,filled,dashed"' if x["annee"] == 2 else '"rounded,filled"'
        g.append(f'n{n3(info, i)} [label="{lab}" fillcolor="{FOND[c]}" color="{COUL[c]}" fontcolor="{TEXTE[c]}" '
                 f'style={sty} penwidth={1.6 if x["annee"] == 2 else 0.8} tooltip="{x["libelle"]}"];')
    for i in ordre:
        for p in info[i]["prerequis"]:
            g.append(f'n{n3(info, p)} -> n{n3(info, i)} [tailport=e headport=w color="{COUL[info[p]["cat"]]}70"];')
    # notion isolée (ni prérequis ni dépendant) : alignée sur la notion précédente du parcours
    for k, i in enumerate(ordre):
        if k and not info[i]["prerequis"] and not info[i]["dependants"]:
            g.append(f"{{rank=same; n{n3(info, i)}; n{n3(info, ordre[k - 1])};}}")
    g.append("}")
    dot = sortie / "reseau_lca.dot"
    dot.write_text("\n".join(g), encoding="utf-8")
    for fmt in ("svg", "pdf"):
        subprocess.run(["dot", f"-T{fmt}", str(dot), "-o", str(sortie / f"reseau_lca.{fmt}")], check=True)
    svg = (sortie / "reseau_lca.svg").read_text(encoding="utf-8")
    svg = svg[svg.index("<svg"):]
    svg = re.sub(r'<svg width="[^"]*" height="[^"]*"', '<svg id="net"', svg, count=1)
    return re.sub(r'<polygon fill="white" stroke="transparent"[^>]*/>', "", svg, count=1)


# Fiches récap ----------------------------------------------------------------------------------------

def construire_fiches(info):
    fiches, err = [], []
    for fp in sorted((RACINE / "fiches").glob("*.md")):
        i = fp.stem
        if i not in info:
            err.append(f"fiche {fp.name} : identifiant inconnu")
            continue
        corps = fp.read_text(encoding="utf-8")

        def lien(m):
            ref, lib = m.group(1), m.group(2)
            if ref not in info:
                err.append(f"fiche {fp.name} : renvoi [[{ref}]] inconnu")
                return m.group(0)
            return f"{n3(info, ref)}. {info[ref]['libelle']}" if lib else n3(info, ref)

        corps = re.sub(r"\[\[([a-z0-9-]+)(:libelle)?\]\]", lien, corps)
        x = info[i]
        liste = lambda ids: " ; ".join(f"{n3(info, j)}. {info[j]['libelle']}" for j in ids) or "aucun"
        tete = (f"# {n3(info, i)}. {x['libelle']}\n\n"
                f"Phase {x['phase']} - [{x['code']}] - {'Base' if x['annee'] == 1 else 'Avancé'}\n\n"
                f"**Prérequis :** {liste(x['prerequis'])}\n\n**Ouvre vers :** {liste(x['dependants'])}\n\n")
        rendu = markdown.markdown(tete + corps, extensions=["tables"]).replace("<a href=", '<a target="_blank" rel="noopener" href=')
        fiches.append({"num": x["num"], "titre": f"{n3(info, i)}. {x['libelle']}", "html": rendu})
    if err:
        sys.exit("Fiches invalides :\n- " + "\n- ".join(err))
    return sorted(fiches, key=lambda f: f["num"])


# Page HTML ---------------------------------------------------------------------------------------------

def noeud(txt, cat, enfants=None, fold=0, cls=""):
    st = {"cat": "font-weight:700;font-size:16px", "dom": "font-weight:600", "lv": "font-style:italic;color:var(--muted)",
          "b": "padding:1px 6px;border-radius:4px;background:rgba(55,138,221,.16)",
          "a": "padding:1px 6px;border-radius:4px;border:1px dashed var(--muted)"}
    n = {"content": f'<span style="{st[cls]}">{H.escape(txt)}</span>' if cls else H.escape(txt),
         "payload": {"cat": cat, "fold": fold}}
    if enfants:
        n["children"] = enfants
    return n


def construire_html(sortie, cfg, cats, doms, parc, info, ordre, svg, fiches):
    dom_num = {d["numero"]: d for d in doms}
    N = len(info)
    root = noeud("Lecture critique d'article - EDN", "R", [
        noeud(f"{c['code']}. {c['libelle']}", c["code"], [
            noeud(f"Domaine {d}. {dom_num[d]['libelle']}", c["code"], [
                noeud("Base (année 1)", c["code"], [noeud(info[i]["libelle"], c["code"], cls="b") for i in dom_num[d].get("base") or []], cls="lv"),
                noeud("Avancé (année 2)", c["code"], [noeud(info[i]["libelle"], c["code"], cls="a") for i in dom_num[d].get("avance") or []], cls="lv")],
                fold=1, cls="dom") for d in c["domaines"]], cls="cat") for c in cats])
    proot = noeud(f"Parcours LCA - {N} notions", "R", [
        noeud(f"Année {a} - {'notions de base' if a == 1 else 'notions avancées'}", "R", [
            noeud(f"Phase {ph['numero']}. {ph['titre']}", "R",
                  [noeud(ligne_parcours(info, n["id"]), info[n["id"]]["cat"], cls="b" if a == 1 else "a") for n in ph["notions"]], cls="dom")
            for ph in parc if ph["annee"] == a], cls="cat") for a in (1, 2)])
    phases = [{"k": ph["numero"], "l": f"Phase {ph['numero']}. {ph['titre']}", "an": f"Année {ph['annee']}",
               "ids": [f"n{n3(info, n['id'])}" for n in ph["notions"]]} for ph in parc]
    pdata = {f"n{n3(info, i)}": {"num": n3(info, i), "t": info[i]["libelle"], "c": info[i]["code"], "p": info[i]["phase"],
                                 "lvl": "base" if info[i]["annee"] == 1 else "avancé"} for i in ordre}
    d3js = (RACINE / "vendor" / "d3-7.9.0.min.js").read_text(encoding="utf-8")
    mmjs = (RACINE / "vendor" / "markmap-view-0.17.2.js").read_text(encoding="utf-8")
    nb_dom = len(doms)
    page = f'''<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Notions de LCA : carte mentale et parcours</title>
<style>
:root{{--bg:#F7F6F2;--fg:#2C2C2A;--muted:#5F5E5A;--panel:#FFFFFF;--line:#D3D1C7;--fig:#FBFAF6;--acc:#185FA5;
box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}}
@media (prefers-color-scheme: dark){{:root:not([data-theme="light"]){{--bg:#1E1E1C;--fg:#ECEAE3;--muted:#B4B2A9;--panel:#2C2C2A;--line:#444441;--acc:#85B7EB;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#1E1E1C;--fg:#ECEAE3;--muted:#B4B2A9;--panel:#2C2C2A;--line:#444441;--acc:#85B7EB;color-scheme:dark}}
html{{scroll-padding-top:env(safe-area-inset-top,0px)}}
body{{margin:0;background:var(--bg);color:var(--fg);font-family:system-ui,-apple-system,"Segoe UI",sans-serif;font-size:15px;line-height:1.5}}
main{{padding:16px}}
h1{{font-size:20px;font-weight:600;margin:0 0 10px}}
p.sub{{margin:0 0 12px;color:var(--muted);font-size:14px}}
.tabs{{display:flex;gap:4px;border-bottom:1px solid var(--line);margin-bottom:14px}}
.tab{{font:inherit;background:none;border:none;border-bottom:2px solid transparent;color:var(--muted);padding:8px 14px;cursor:pointer}}
.tab[aria-selected="true"]{{color:var(--fg);border-bottom-color:var(--acc);font-weight:600}}
.bar{{display:flex;flex-wrap:wrap;gap:12px;align-items:center;background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-bottom:12px;font-size:14px}}
.bar label{{display:flex;align-items:center;gap:6px}}
select,input[type=number],button.btn{{font:inherit;color:var(--fg);background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:4px 8px}}
button.btn{{cursor:pointer}}
.leg{{display:flex;flex-wrap:wrap;gap:12px;font-size:13px;color:var(--muted)}}
.sw{{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-2px;margin-right:4px;border:1px solid}}
.wrap{{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:12px}}
@media (max-width:900px){{.wrap{{grid-template-columns:minmax(0,1fr)}}}}
.fig{{background:var(--fig);border:1px solid var(--line);border-radius:10px;overflow:auto;max-height:78vh}}
#info{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px;font-size:14px;align-self:start}}
#info h2{{font-size:15px;margin:0 0 6px}}
#info ul{{margin:4px 0 10px;padding-left:18px}}
#info li{{cursor:pointer}}
.dim{{opacity:.08;transition:opacity .15s}}
g.node{{cursor:pointer}}
.hl-a path,.hl-a polygon{{stroke:#BA7517!important;stroke-width:2.2px}}
.hl-a polygon{{fill:#BA7517!important}}
.hl-d path,.hl-d polygon{{stroke:#185FA5!important;stroke-width:2.2px}}
.hl-d polygon{{fill:#185FA5!important}}
.sel path,.sel polygon{{stroke-width:3px!important;stroke:#2C2C2A!important}}
.hl-p path{{stroke:#2C2C2A!important;stroke-width:2px}}
.hl-p polygon{{stroke:#2C2C2A!important;fill:#2C2C2A!important}}
.mmbox{{background:var(--panel);border:1px solid var(--line);border-radius:10px;height:78vh}}
.mmsvg{{width:100%;height:100%;display:block}}
#mm.markmap,#pm.markmap{{--markmap-text-color:var(--fg);--markmap-circle-open-bg:var(--panel)}}
.markmap.markmap{{--markmap-font:400 14px/18px system-ui,-apple-system,"Segoe UI",sans-serif}}
#mm .cat,#pm .cat{{font-weight:700;font-size:16px}}
#mm .dom,#pm .dom{{font-weight:600}}
#mm .lv,#pm .lv{{font-style:italic;color:var(--muted)}}
#mm .b,#pm .b{{padding:1px 6px;border-radius:4px;background:rgba(55,138,221,.16)}}
#mm .a,#pm .a{{padding:1px 6px;border-radius:4px;border:1px dashed var(--muted)}}
[hidden]{{display:none!important}}
#fiche{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:16px 22px;max-width:900px}}
#fiche h1{{font-size:20px;margin:0 0 6px}}
#fiche h2{{font-size:16px;margin:18px 0 6px;color:var(--acc)}}
#fiche p,#fiche li{{margin:4px 0}}
#fiche ul{{padding-left:20px}}
#fiche table{{border-collapse:collapse;margin:8px 0}}
#fiche th,#fiche td{{border:1px solid var(--line);padding:4px 12px;text-align:left}}
#fiche a{{color:var(--acc)}}
</style></head><body><main>
<h1>{H.escape(cfg['titre'])}</h1>
<div class="tabs" role="tablist">
<button class="tab" role="tab" id="t1" aria-selected="true" aria-controls="p1">Carte mentale des notions</button>
<button class="tab" role="tab" id="t2" aria-selected="false" aria-controls="p2">Carte mentale du parcours</button>
<button class="tab" role="tab" id="t3" aria-selected="false" aria-controls="p3">Réseau des dépendances</button>
<button class="tab" role="tab" id="t4" aria-selected="false" aria-controls="p4">Fiches récap</button>
</div>

<section id="p1" role="tabpanel" aria-labelledby="t1">
<p class="sub">{N} notions réparties en {len(cats)} catégories et {nb_dom} domaines. Cliquer sur un cercle pour déplier ou replier une branche ; molette pour zoomer, glisser pour déplacer.</p>
<div class="bar">
<button class="btn" id="mmAll">Tout déplier</button>
<button class="btn" id="mmDom">Replier aux domaines</button>
<button class="btn" id="mmFit">Recentrer</button>
<div class="leg"><span><span class="sw" style="background:#534AB7;border-color:#534AB7"></span>A Conception</span><span><span class="sw" style="background:#0F6E56;border-color:#0F6E56"></span>B Analyse</span><span><span class="sw" style="background:#993C1D;border-color:#993C1D"></span>C Validité</span><span><span class="sw" style="background:#185FA5;border-color:#185FA5"></span>D Schémas</span><span><span class="sw" style="background:rgba(55,138,221,.16);border-color:transparent"></span>base</span><span><span class="sw" style="background:transparent;border-color:var(--muted);border-style:dashed"></span>avancé</span></div>
</div>
<div class="mmbox" id="mmbox"><svg id="mm" class="mmsvg"></svg></div>
</section>

<section id="p2" role="tabpanel" aria-labelledby="t2" hidden>
<p class="sub">Les {N} notions dans l’ordre d’apprentissage, regroupées en {len(parc)} phases. Chaque notion indique son code catégorie-domaine et, après la flèche, les numéros de ses notions prérequises.</p>
<div class="bar">
<button class="btn" id="pmAll">Tout déplier</button>
<button class="btn" id="pmPh">Replier aux phases</button>
<button class="btn" id="pmFit">Recentrer</button>
<div class="leg"><span><span class="sw" style="background:#534AB7;border-color:#534AB7"></span>A Conception</span><span><span class="sw" style="background:#0F6E56;border-color:#0F6E56"></span>B Analyse</span><span><span class="sw" style="background:#993C1D;border-color:#993C1D"></span>C Validité</span><span><span class="sw" style="background:#185FA5;border-color:#185FA5"></span>D Schémas</span><span>← = prérequis</span></div>
</div>
<div class="mmbox"><svg id="pm" class="mmsvg"></svg></div>
</section>

<section id="p3" role="tabpanel" aria-labelledby="t3" hidden>
<p class="sub">Cliquer sur une notion pour afficher ses prérequis et dépendances.</p>
<div class="bar">
<label>Notion n° <input id="num" type="number" min="1" max="{N}" style="width:70px"></label>
<label>Portée <select id="scope"><option value="all">chaîne complète</option><option value="direct">liens directs</option></select></label>
<label>Afficher <select id="dir"><option value="both">prérequis et dépendances</option><option value="anc">prérequis</option><option value="desc">dépendances</option></select></label>
<label>Zoom <input id="zoom" type="range" min="25" max="150" step="5" value="60"></label>
<label>Phase <select id="phase"><option value="">aucune</option></select></label>
<button class="btn" id="reset">Tout afficher</button>
<div class="leg"><span><span class="sw" style="background:#EEEDFE;border-color:#534AB7"></span>A Conception</span><span><span class="sw" style="background:#E1F5EE;border-color:#0F6E56"></span>B Analyse</span><span><span class="sw" style="background:#FAECE7;border-color:#993C1D"></span>C Validité</span><span><span class="sw" style="background:#E6F1FB;border-color:#185FA5"></span>D Schémas</span><span>trait plein = base, pointillé = avancé</span><span><span class="sw" style="background:#BA7517;border-color:#BA7517"></span>prérequis</span><span><span class="sw" style="background:#185FA5;border-color:#185FA5"></span>dépendances</span></div>
</div>
<div class="wrap"><div class="fig" id="fig">{svg}</div>
<aside id="info"><h2>Aucune notion sélectionnée</h2><p style="color:var(--muted);margin:0">Sélectionner une notion dans la figure ou saisir son numéro.</p></aside></div>
</section>

<section id="p4" role="tabpanel" aria-labelledby="t4" hidden>
<div class="bar"><label>Fiche <select id="fsel"></select></label><span style="color:var(--muted);font-size:13px" id="fcount"></span></div>
<article id="fiche"></article>
</section>
<footer style="margin-top:20px;padding-top:12px;border-top:1px solid var(--line);font-size:13px;color:var(--muted)">
<p style="margin:0 0 4px">{H.escape(cfg['projet'])} - {H.escape(cfg['auteur'])}, {H.escape(cfg['affiliation'])}. Version {H.escape(str(cfg['version']))} du {H.escape(str(cfg['date']))}.</p>
<p style="margin:0">{H.escape(cfg['avertissement'])}</p>
</footer>
</main>
<script>{d3js}</script>
<script>{mmjs}</script>
<script>
// Onglets
const tabs=[['t1','p1'],['t2','p2'],['t3','p3'],['t4','p4']];
function show(k){{tabs.forEach(([t,p])=>{{const on=t===k;document.getElementById(t).setAttribute('aria-selected',on);document.getElementById(p).hidden=!on;}});if(k==='t1'&&mm)mm.fit();if(k==='t2'){{if(!pm)initPm();else pm.fit();}}}}
tabs.forEach(([t])=>document.getElementById(t).onclick=()=>show(t));

// Carte mentale (markmap)
const COL={{R:'#5F5E5A',A:'#534AB7',B:'#0F6E56',C:'#993C1D',D:'#185FA5'}};
const MM={json.dumps(root,ensure_ascii=False)};
function setFold(n,depth,mode){{if(n.children){{n.payload.fold=(mode==='dom'&&depth===2)?1:0;n.children.forEach(c=>setFold(c,depth+1,mode));}}}}
let mm=null;
try{{mm=markmap.Markmap.create('#mm',{{color:n=>COL[(n.payload||{{}}).cat]||'#5F5E5A',duration:300,maxWidth:0,spacingVertical:6,paddingX:10}},MM);}}catch(e){{document.getElementById('mmbox').textContent='La carte mentale n’a pas pu être affichée.';}}
document.getElementById('mmAll').onclick=()=>{{setFold(MM,0,'all');mm.setData(MM);mm.fit();}};
document.getElementById('mmDom').onclick=()=>{{setFold(MM,0,'dom');mm.setData(MM);mm.fit();}};
document.getElementById('mmFit').onclick=()=>mm.fit();
const PM={json.dumps(proot,ensure_ascii=False)};
let pm=null;
function phFold(n,depth,mode){{if(n.children){{n.payload.fold=(mode==='ph'&&depth===2)?1:0;n.children.forEach(c=>phFold(c,depth+1,mode));}}}}
function initPm(){{phFold(PM,0,'ph');try{{pm=markmap.Markmap.create('#pm',{{color:n=>COL[(n.payload||{{}}).cat]||'#5F5E5A',duration:300,maxWidth:0,spacingVertical:6,paddingX:10}},PM);}}catch(e){{document.getElementById('pm').parentNode.textContent='La carte du parcours n’a pas pu être affichée.';}}}}
document.getElementById('pmAll').onclick=()=>{{phFold(PM,0,'all');pm.setData(PM);pm.fit();}};
document.getElementById('pmPh').onclick=()=>{{phFold(PM,0,'ph');pm.setData(PM);pm.fit();}};
document.getElementById('pmFit').onclick=()=>pm.fit();

// Parcours (réseau)
const PD={json.dumps(pdata,ensure_ascii=False)};
const svg=document.getElementById('net');const vb=svg.viewBox.baseVal;
const nodes={{}},pred={{}},succ={{}},edges=[];
svg.querySelectorAll('g.node').forEach(g=>{{const id=g.querySelector('title').textContent.trim();nodes[id]=g;pred[id]=[];succ[id]=[];}});
svg.querySelectorAll('g.edge').forEach(g=>{{const [a,b]=g.querySelector('title').textContent.trim().split('->').map(x=>x.split(':')[0]);edges.push({{a,b,g}});succ[a].push(b);pred[b].push(a);}});
svg.querySelectorAll('a').forEach(a=>a.removeAttribute('xlink:title'));
function zoom(){{const z=document.getElementById('zoom').value/100;svg.setAttribute('width',vb.width*z);svg.setAttribute('height',vb.height*z);}}
document.getElementById('zoom').oninput=zoom;zoom();
function closure(id,m,full){{const s=new Set();const st=[...m[id]];while(st.length){{const x=st.pop();if(s.has(x))continue;s.add(x);if(full)st.push(...m[x]);}}return s;}}
let cur=null;
function clear(){{Object.values(nodes).forEach(g=>g.classList.remove('dim','sel'));edges.forEach(e=>e.g.classList.remove('dim','hl-a','hl-d'));}}
function li(ids){{return [...ids].sort().map(i=>`<li data-id="${{i}}">${{PD[i].num}}. ${{PD[i].t}} <span style="color:var(--muted)">[${{PD[i].c}}]</span></li>`).join('')||'<li style="list-style:none;margin-left:-18px;color:var(--muted)">aucune</li>';}}
function select(id){{if(!nodes[id])return;cur=id;clear();
const full=document.getElementById('scope').value==='all',dir=document.getElementById('dir').value;
const A=dir!=='desc'?closure(id,pred,full):new Set(),De=dir!=='anc'?closure(id,succ,full):new Set();
Object.entries(nodes).forEach(([k,g])=>{{if(k!==id&&!A.has(k)&&!De.has(k))g.classList.add('dim');}});
nodes[id].classList.add('sel');
edges.forEach(e=>{{const inA=A.has(e.a)&&(A.has(e.b)||e.b===id),inD=(e.a===id||De.has(e.a))&&De.has(e.b);
if(inA)e.g.classList.add('hl-a');else if(inD)e.g.classList.add('hl-d');else e.g.classList.add('dim');}});
const d=PD[id];document.getElementById('info').innerHTML=`<h2>${{d.num}}. ${{d.t}}</h2><p style="margin:0 0 8px;color:var(--muted)">[${{d.c}}], phase ${{d.p}}, ${{d.lvl}}</p><strong>Prérequis directs</strong><ul>${{li(pred[id])}}</ul><strong>Dépendances directes</strong><ul>${{li(succ[id])}}</ul>`+(full?`<p style="color:var(--muted);margin:0">Chaîne complète : ${{A.size}} prérequis, ${{De.size}} dépendances.</p>`:'');
document.querySelectorAll('#info li[data-id]').forEach(l=>l.onclick=()=>{{select(l.dataset.id);center(l.dataset.id);}});
document.getElementById('num').value=parseInt(d.num,10);}}
function center(id){{const f=document.getElementById('fig'),r=nodes[id].getBoundingClientRect(),fr=f.getBoundingClientRect();f.scrollBy({{left:r.left-fr.left-fr.width/2+r.width/2,top:r.top-fr.top-fr.height/2+r.height/2,behavior:'smooth'}});}}
Object.entries(nodes).forEach(([k,g])=>g.addEventListener('click',ev=>{{ev.stopPropagation();phSel.value='';select(k);}}));
document.getElementById('num').onchange=e=>{{phSel.value='';const id='n'+String(e.target.value).padStart(3,'0');select(id);center(id);}};
['scope','dir'].forEach(i=>document.getElementById(i).onchange=()=>cur&&select(cur));
const PH={json.dumps(phases,ensure_ascii=False)};
const phSel=document.getElementById('phase');
PH.forEach(p=>{{const o=document.createElement('option');o.value=p.k;o.textContent=p.l;phSel.appendChild(o);}});
function selectPhase(k){{const p=PH.find(x=>String(x.k)===String(k));if(!p)return;cur=null;clear();document.getElementById('num').value='';
const S=new Set(p.ids),Ext=new Set();p.ids.forEach(i=>pred[i].forEach(a=>{{if(!S.has(a))Ext.add(a);}}));
Object.entries(nodes).forEach(([k2,g])=>{{if(S.has(k2))g.classList.add('sel');else if(!Ext.has(k2))g.classList.add('dim');}});
edges.forEach(e=>{{if(S.has(e.a)&&S.has(e.b))e.g.classList.add('hl-p');else if(Ext.has(e.a)&&S.has(e.b))e.g.classList.add('hl-a');else e.g.classList.add('dim');}});
document.getElementById('info').innerHTML=`<h2>${{p.l}}</h2><p style="margin:0 0 8px;color:var(--muted)">${{p.an}}, ${{p.ids.length}} notions</p><strong>Notions de la phase</strong><ul>${{li(p.ids)}}</ul><strong>Prérequis issus d’autres phases</strong><ul>${{li(Ext)}}</ul>`;
document.querySelectorAll('#info li[data-id]').forEach(l=>l.onclick=()=>{{phSel.value='';select(l.dataset.id);center(l.dataset.id);}});
center(p.ids[0]);}}
phSel.onchange=e=>{{if(e.target.value)selectPhase(e.target.value);else document.getElementById('reset').click();}};
document.getElementById('reset').onclick=()=>{{cur=null;clear();phSel.value='';document.getElementById('info').innerHTML='<h2>Aucune notion sélectionnée</h2>';}};

// Fiches récap
const FI={json.dumps(fiches,ensure_ascii=False)};
const fsel=document.getElementById('fsel');
FI.forEach((f,i)=>{{const o=document.createElement('option');o.value=i;o.textContent=f.titre;fsel.appendChild(o);}});
document.getElementById('fcount').textContent=FI.length+' fiche'+(FI.length>1?'s':'')+' disponible'+(FI.length>1?'s':'');
function showFiche(i){{document.getElementById('fiche').innerHTML=FI[i]?FI[i].html:'<p>Aucune fiche disponible.</p>';}}
fsel.onchange=e=>showFiche(e.target.value);showFiche(0);
</script></body></html>'''
    (sortie / "lca_notions_parcours.html").write_text(page, encoding="utf-8")


# Programme principal -------------------------------------------------------------------------------

def main():
    arg = argparse.ArgumentParser(description="Génère les livrables Boussole LCA.")
    arg.add_argument("--sortie", default="dist", help="dossier de sortie (défaut : dist)")
    sortie = (RACINE / arg.parse_args().sortie).resolve()
    sortie.mkdir(parents=True, exist_ok=True)
    cfg, cats, doms, parc, info, ordre = charger()
    fiches = construire_fiches(info)
    exporter_cartes(sortie, cats, doms, parc, info)
    svg = exporter_reseau(sortie, info, ordre)
    construire_html(sortie, cfg, cats, doms, parc, info, ordre, svg, fiches)
    nb = sum(1 for i in ordre if info[i]["annee"] == 1)
    print(f"{len(info)} notions ({nb} base, {len(info) - nb} avancées), {len(parc)} phases, "
          f"{sum(len(info[i]['prerequis']) for i in ordre)} dépendances, {len(fiches)} fiches -> {sortie}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Générateur déterministe des données sources du projet médaillon (v1.2).

Produit :
  sql/01_source_erp_lot1.sql        base opérationnelle simulée (ERP), lot 1
  sql/07_source_erp_lot2.sql        modifications ERP du lot 2
  donnees/lot1/magasins/*.csv       exports caisses magasins (format français)
  donnees/lot1/web/*.json           commandes e-commerce (JSON lines)
  donnees/lot2/magasins/*.csv
  donnees/lot2/web/*.json
  generateur/resultats_attendus.json  volumes attendus après lot 1 et après lot 2

Usage : python3 generateur/generer_donnees.py   (depuis la racine du projet)
"""
import csv
import datetime as dt
import json
import random
from collections import Counter, defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
rng = random.Random(20260901)

DEBUT_LOT1 = dt.date(2026, 9, 1)
FIN_LOT1 = dt.date(2026, 9, 28)
JOURS_LOT2 = [dt.date(2026, 9, 29), dt.date(2026, 9, 30)]

VILLES = [
    ("Lille", "59000", "Hauts-de-France"),
    ("Paris", "75011", "Île-de-France"),
    ("Lyon", "69003", "Auvergne-Rhône-Alpes"),
    ("Marseille", "13001", "Provence-Alpes-Côte d'Azur"),
    ("Bordeaux", "33000", "Nouvelle-Aquitaine"),
    ("Nantes", "44000", "Pays de la Loire"),
    ("Toulouse", "31000", "Occitanie"),
    ("Strasbourg", "67000", "Grand Est"),
]

CATALOGUE = {
    "Running": ["Chaussures trail", "Chaussures route", "Veste coupe-vent", "Collant", "Montre GPS"],
    "Vélo": ["Casque route", "Gants vélo", "Compteur", "Chambre à air", "Maillot cycliste"],
    "Randonnée": ["Sac à dos 30 L", "Bâtons", "Gourde 1 L", "Polaire", "Chaussures tige haute"],
    "Fitness": ["Tapis de sol", "Haltères 5 kg", "Élastique", "Corde à sauter", "Kettlebell 12 kg"],
    "Natation": ["Lunettes", "Bonnet", "Maillot", "Palmes", "Planche"],
    "Sports collectifs": ["Ballon football", "Ballon basket", "Protège-tibias", "Chasubles", "Pompe"],
}
MARQUES = ["Altura", "Velocis", "Trekka", "Hydra", "Pulso", "Strada"]
PRIX = [Decimal(p) for p in ["7.90", "9.99", "12.90", "14.99", "19.90", "24.99", "29.90", "34.99",
                              "39.90", "49.90", "59.99", "69.90", "79.99", "89.90", "119.00", "149.90"]]
PRENOMS = ["Camille", "Lucas", "Léa", "Hugo", "Chloé", "Nathan", "Manon", "Louis", "Inès", "Jules",
           "Sarah", "Adam", "Emma", "Yanis", "Jade", "Malik", "Lina", "Tom", "Zoé", "Karim"]
NOMS = ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy",
        "Moreau", "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "Benali", "Roux", "Fournier"]


def q2(x: Decimal) -> Decimal:
    return x.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def montant_net(qte: int, prix: Decimal, remise: Decimal) -> Decimal:
    return q2(Decimal(qte) * prix * (Decimal(1) - remise / Decimal(100)))


def jours(d1, d2):
    d = d1
    while d <= d2:
        yield d
        d += dt.timedelta(days=1)


def sql_str(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, Decimal)):
        return str(v)
    if isinstance(v, dt.datetime):
        return f"TIMESTAMP'{v:%Y-%m-%d %H:%M:%S}'"
    if isinstance(v, dt.date):
        return f"DATE'{v:%Y-%m-%d}'"
    return "'" + str(v).replace("'", "''") + "'"


def inserts(table, colonnes, lignes, taille=400):
    out = []
    for i in range(0, len(lignes), taille):
        bloc = lignes[i:i + taille]
        valeurs = ",\n".join("  (" + ", ".join(sql_str(v) for v in l) + ")" for l in bloc)
        out.append(f"INSERT INTO {table} ({', '.join(colonnes)}) VALUES\n{valeurs};\n")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Référentiels ERP
# ---------------------------------------------------------------------------
magasins = []
for i, (ville, cp, region) in enumerate(VILLES, start=1):
    magasins.append(dict(code_magasin=f"MAG{i:02d}", nom=f"Sport Hub {ville}", ville=ville, region=region,
                         surface_m2=rng.choice([450, 600, 800, 1200, 1500]),
                         date_ouverture=dt.date(rng.randint(2015, 2023), rng.randint(1, 12), 1),
                         date_maj=dt.datetime(2026, 1, 2, 8, 0, 0)))
CODES_MAGASINS = {m["code_magasin"] for m in magasins}

produits = []
n = 0
for categorie, articles in CATALOGUE.items():
    for article in articles:
        for variante in ("Essentiel", "Performance"):
            n += 1
            prix = rng.choice(PRIX)
            if variante == "Performance":
                prix = max(prix, rng.choice(PRIX[6:]))
            produits.append(dict(sku=f"SKU-{n:04d}", libelle=f"{article} {variante}", categorie=categorie,
                                 marque=rng.choice(MARQUES), prix_catalogue=prix,
                                 cout_achat=q2(prix * Decimal(str(round(rng.uniform(0.45, 0.62), 2)))),
                                 actif=True, date_maj=dt.datetime(2026, 1, 2, 8, 0, 0)))
PRODUITS = {p["sku"]: p for p in produits}
SKUS = list(PRODUITS)

clients = []
for cid in range(1, 301):
    prenom, nom = rng.choice(PRENOMS), rng.choice(NOMS)
    ville, cp, _ = rng.choice(VILLES)
    creation = dt.date(2022, 1, 1) + dt.timedelta(days=rng.randint(0, 1700))
    clients.append(dict(client_id=cid, prenom=prenom, nom=nom,
                        email=f"{prenom.lower()}.{nom.lower()}{cid}@example.com".replace("é", "e").replace("è", "e").replace("ï", "i").replace("ë", "e"),
                        telephone=f"06{rng.randint(10000000, 99999999)}", ville=ville, code_postal=cp,
                        segment=rng.choices(["Particulier", "Premium", "Professionnel"], [70, 15, 15])[0],
                        date_creation=creation,
                        date_maj=dt.datetime.combine(creation, dt.time(9, 0))))
# Anomalies de saisie ERP (nettoyées en silver)
clients[6]["email"] = "  Camille.MARTIN7@Example.COM  "
clients[6]["prenom"], clients[6]["nom"] = "camille", "martin"
clients[22]["email"] = "pas-un-email"
# Client 12 et 45 : modifiés au lot 2 (SCD2)
clients[11]["ville"], clients[11]["code_postal"], clients[11]["segment"] = "Lille", "59000", "Particulier"
clients[44]["segment"] = "Particulier"
CLIENT_IDS = [c["client_id"] for c in clients]

# ---------------------------------------------------------------------------
# Commandes ERP (vente directe)
# ---------------------------------------------------------------------------
commandes, lignes_cmd = [], []
cmd_id = 100000


def nouvelle_commande_erp(jour, client_id=None, statut=None):
    global cmd_id
    cmd_id += 1
    ts = dt.datetime.combine(jour, dt.time(rng.randint(8, 18), rng.randint(0, 59), rng.randint(0, 59)))
    cmd = dict(commande_id=cmd_id, client_id=client_id or rng.choice(CLIENT_IDS), date_commande=ts,
               statut=statut or rng.choices(["LIVREE", "VALIDEE", "ANNULEE"], [70, 25, 5])[0],
               canal_commercial=rng.choice(["Téléphone", "Commercial terrain", "Salon pro"]), date_maj=ts)
    lignes = []
    for num, sku in enumerate(rng.sample(SKUS, rng.randint(1, 4)), start=1):
        lignes.append(dict(commande_id=cmd_id, ligne_num=num, sku=sku, quantite=rng.randint(1, 20),
                           prix_unitaire=PRODUITS[sku]["prix_catalogue"],
                           remise_pct=rng.choice([Decimal(0), Decimal(5), Decimal(10), Decimal(15)]), date_maj=ts))
    return cmd, lignes


for jour in jours(DEBUT_LOT1, FIN_LOT1):
    for _ in range(rng.randint(6, 10)):
        c, l = nouvelle_commande_erp(jour)
        commandes.append(c); lignes_cmd.extend(l)
for jour, cid in [(dt.date(2026, 9, 9), 12), (dt.date(2026, 9, 21), 12), (dt.date(2026, 9, 17), 45)]:
    c, l = nouvelle_commande_erp(jour, cid, "LIVREE")
    commandes.append(c); lignes_cmd.extend(l)
commande_a_annuler = next(c for c in commandes if c["statut"] == "LIVREE" and c["date_commande"].date() == dt.date(2026, 9, 18))

# ---------------------------------------------------------------------------
# Script SQL source ERP lot 1
# ---------------------------------------------------------------------------
entete = """-- =====================================================================
-- 01_source_erp_lot1.sql — Base opérationnelle simulée (ERP), état au 28/09/2026
-- Rôle : représente la base SQL de production (clients, produits, magasins, commandes).
-- Dans un vrai projet, ces tables seraient lues via Lakehouse Federation (voir guide, annexe A).
-- Ré-exécutable : oui (réinitialise la source)
-- Généré par generateur/generer_donnees.py — ne pas modifier à la main
-- =====================================================================

USE CATALOG projet_medaillon;

CREATE OR REPLACE TABLE source_erp.clients (
  client_id      INT,
  prenom         STRING,
  nom            STRING,
  email          STRING,
  telephone      STRING,
  ville          STRING,
  code_postal    STRING,
  segment        STRING,
  date_creation  DATE,
  date_maj       TIMESTAMP
) COMMENT 'ERP : clients';

CREATE OR REPLACE TABLE source_erp.produits (
  sku             STRING,
  libelle         STRING,
  categorie       STRING,
  marque          STRING,
  prix_catalogue  DECIMAL(10,2),
  cout_achat      DECIMAL(10,2),
  actif           BOOLEAN,
  date_maj        TIMESTAMP
) COMMENT 'ERP : catalogue produits';

CREATE OR REPLACE TABLE source_erp.magasins (
  code_magasin    STRING,
  nom             STRING,
  ville           STRING,
  region          STRING,
  surface_m2      INT,
  date_ouverture  DATE,
  date_maj        TIMESTAMP
) COMMENT 'ERP : magasins physiques';

CREATE OR REPLACE TABLE source_erp.commandes (
  commande_id       INT,
  client_id         INT,
  date_commande     TIMESTAMP,
  statut            STRING,
  canal_commercial  STRING,
  date_maj          TIMESTAMP
) COMMENT 'ERP : commandes de vente directe';

CREATE OR REPLACE TABLE source_erp.lignes_commande (
  commande_id    INT,
  ligne_num      INT,
  sku            STRING,
  quantite       INT,
  prix_unitaire  DECIMAL(10,2),
  remise_pct     DECIMAL(5,2),
  date_maj       TIMESTAMP
) COMMENT 'ERP : lignes de commandes';

"""
cols_cli = ["client_id", "prenom", "nom", "email", "telephone", "ville", "code_postal", "segment", "date_creation", "date_maj"]
cols_pro = ["sku", "libelle", "categorie", "marque", "prix_catalogue", "cout_achat", "actif", "date_maj"]
cols_mag = ["code_magasin", "nom", "ville", "region", "surface_m2", "date_ouverture", "date_maj"]
cols_cmd = ["commande_id", "client_id", "date_commande", "statut", "canal_commercial", "date_maj"]
cols_lig = ["commande_id", "ligne_num", "sku", "quantite", "prix_unitaire", "remise_pct", "date_maj"]

sql1 = entete
sql1 += inserts("source_erp.clients", cols_cli, [[c[k] for k in cols_cli] for c in clients]) + "\n"
sql1 += inserts("source_erp.produits", cols_pro, [[p[k] for k in cols_pro] for p in produits]) + "\n"
sql1 += inserts("source_erp.magasins", cols_mag, [[m[k] for k in cols_mag] for m in magasins]) + "\n"
sql1 += inserts("source_erp.commandes", cols_cmd, [[c[k] for k in cols_cmd] for c in commandes]) + "\n"
sql1 += inserts("source_erp.lignes_commande", cols_lig, [[l[k] for k in cols_lig] for l in lignes_cmd]) + "\n"
sql1 += """-- Contrôle
SELECT 'clients' AS table_source, count(*) AS lignes FROM source_erp.clients
UNION ALL SELECT 'produits', count(*) FROM source_erp.produits
UNION ALL SELECT 'magasins', count(*) FROM source_erp.magasins
UNION ALL SELECT 'commandes', count(*) FROM source_erp.commandes
UNION ALL SELECT 'lignes_commande', count(*) FROM source_erp.lignes_commande;
"""

# ---------------------------------------------------------------------------
# Lot 2 ERP
# ---------------------------------------------------------------------------
commandes_l2, lignes_l2 = [], []
for jour in JOURS_LOT2:
    for _ in range(rng.randint(6, 10)):
        c, l = nouvelle_commande_erp(jour)
        commandes_l2.append(c); lignes_l2.extend(l)
c, l = nouvelle_commande_erp(dt.date(2026, 9, 30), 12, "VALIDEE")
commandes_l2.append(c); lignes_l2.extend(l)
c, l = nouvelle_commande_erp(dt.date(2026, 9, 30), 301, "VALIDEE")
commandes_l2.append(c); lignes_l2.extend(l)

nouveau_client = dict(client_id=301, prenom="Inès", nom="Garcia", email="ines.garcia301@example.com",
                      telephone="0611223344", ville="Nantes", code_postal="44000", segment="Particulier",
                      date_creation=dt.date(2026, 9, 16), date_maj=dt.datetime(2026, 9, 29, 10, 0, 0))

sql2 = f"""-- =====================================================================
-- 07_source_erp_lot2.sql — Évolutions de la base ERP au 30/09/2026
--   * client 12 : déménage à Bordeaux et passe Premium      (→ SCD2)
--   * client 45 : passe Professionnel                       (→ SCD2)
--   * client 301 : créé dans l'ERP (déjà vu sur le web)     (→ client tardif)
--   * commande {commande_a_annuler['commande_id']} : annulée                     (→ suppression du fait)
--   * nouvelles commandes des 29 et 30/09
-- Ré-exécutable : non (rejouer 01 puis 07 pour repartir de zéro)
-- Généré par generateur/generer_donnees.py — ne pas modifier à la main
-- =====================================================================

USE CATALOG projet_medaillon;

UPDATE source_erp.clients
SET ville = 'Bordeaux', code_postal = '33000', segment = 'Premium', date_maj = TIMESTAMP'2026-09-29 09:00:00'
WHERE client_id = 12;

UPDATE source_erp.clients
SET segment = 'Professionnel', date_maj = TIMESTAMP'2026-09-29 09:30:00'
WHERE client_id = 45;

UPDATE source_erp.commandes
SET statut = 'ANNULEE', date_maj = TIMESTAMP'2026-09-29 11:00:00'
WHERE commande_id = {commande_a_annuler['commande_id']};

"""
sql2 += inserts("source_erp.clients", cols_cli, [[nouveau_client[k] for k in cols_cli]]) + "\n"
sql2 += inserts("source_erp.commandes", cols_cmd, [[c[k] for k in cols_cmd] for c in commandes_l2]) + "\n"
sql2 += inserts("source_erp.lignes_commande", cols_lig, [[l[k] for k in cols_lig] for l in lignes_l2]) + "\n"
sql2 += """-- Contrôle
SELECT client_id, ville, segment, date_maj FROM source_erp.clients WHERE client_id IN (12, 45, 301) ORDER BY client_id;
SELECT count(*) AS commandes_depuis_le_29 FROM source_erp.commandes WHERE date_maj >= TIMESTAMP'2026-09-29 00:00:00';
"""

# ---------------------------------------------------------------------------
# Fichiers CSV magasins
# ---------------------------------------------------------------------------
ENTETE_CSV = ["ticket_id", "ligne", "date_heure", "code_magasin", "sku", "quantite", "prix_unitaire", "remise_pct", "carte_fidelite"]


def fr(dec: Decimal) -> str:
    return f"{dec:.2f}".replace(".", ",")


def lignes_magasins(jour):
    rows = []
    for m in magasins:
        for t in range(1, rng.randint(18, 30) + 1):
            ts = dt.datetime.combine(jour, dt.time(rng.randint(9, 19), rng.randint(0, 59)))
            carte = str(rng.choice(CLIENT_IDS)) if rng.random() < 0.4 else ""
            ticket = f"T{jour:%Y%m%d}-{m['code_magasin']}-{t:04d}"
            for num in range(1, rng.randint(1, 4) + 1):
                sku = rng.choice(SKUS)
                rows.append([ticket, str(num), f"{ts:%d/%m/%Y %H:%M}", m["code_magasin"], sku,
                             str(rng.randint(1, 3)), fr(PRODUITS[sku]["prix_catalogue"]),
                             rng.choice(["0", "0", "0", "10", "20"]), carte])
    return rows


def ecrire_csv(chemin: Path, rows):
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with chemin.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";", lineterminator="\n")
        w.writerow(ENTETE_CSV)
        w.writerows(rows)


fichiers_csv = {}  # nom -> (lot, rows)
for jour in jours(DEBUT_LOT1, FIN_LOT1):
    rows = lignes_magasins(jour)
    if jour.day == 3:
        rows[5][5] = "0"
    if jour.day == 7:
        rows[8][4] = "SKU-9999"
    if jour.day == 10:
        rows[12][2] = "31/09/2026 10:15"
    if jour.day == 12:
        rows[20][3] = "MAG99"
    if jour.day == 20:
        rows[30][8] = "9998"
    fichiers_csv[f"ventes_magasins_{jour:%Y-%m-%d}.csv"] = (1, rows)
    if jour.day == 15:
        correctif = []
        for idx in (2, 40, 77):
            r = list(rows[idx])
            r[5] = str(int(r[5]) + 1)
            correctif.append(r)
        fichiers_csv[f"ventes_magasins_{jour:%Y-%m-%d}_correctif.csv"] = (1, correctif)
for jour in JOURS_LOT2:
    fichiers_csv[f"ventes_magasins_{jour:%Y-%m-%d}.csv"] = (2, lignes_magasins(jour))

# ---------------------------------------------------------------------------
# Fichiers JSON web
# ---------------------------------------------------------------------------
def commande_web(jour, n, client_id="aleatoire", statut=None):
    ts = dt.datetime.combine(jour, dt.time(rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59)))
    if client_id == "aleatoire":
        r = rng.random()
        client_id = None if r < 0.10 else rng.choice(CLIENT_IDS)
    client = None
    if client_id is not None:
        email = next((c["email"] for c in clients if c["client_id"] == client_id), f"client{client_id}@example.com")
        client = {"id": client_id, "email": email.strip().lower()}
    items = []
    for sku in rng.sample(SKUS, rng.randint(1, 3)):
        items.append({"sku": sku, "qty": rng.randint(1, 2), "unit_price": float(PRODUITS[sku]["prix_catalogue"]),
                      "discount_pct": rng.choice([0, 0, 5, 10])})
    statut = statut or rng.choices(["paid", "shipped", "cancelled"], [60, 35, 5])[0]
    maj = ts + dt.timedelta(minutes=rng.randint(1, 240)) if statut != "paid" else ts
    return {"order_id": f"WEB-{jour:%Y%m%d}-{n:04d}", "created_at": f"{ts:%Y-%m-%dT%H:%M:%S}Z",
            "updated_at": f"{maj:%Y-%m-%dT%H:%M:%S}Z", "status": statut, "customer": client, "items": items,
            "shipping": {"method": rng.choice(["colissimo", "relais", "express"]),
                         "cost": rng.choice([0, 3.9, 4.9, 9.9]), "city": rng.choice(VILLES)[0]}}


fichiers_json = {}  # nom -> (lot, [lignes texte])
commandes_web_lot1 = {}
for jour in jours(DEBUT_LOT1, FIN_LOT1):
    cmds = [commande_web(jour, i) for i in range(1, rng.randint(25, 45) + 1)]
    if jour.day in (16, 22):
        cmds.append(commande_web(jour, 900, client_id=301, statut="paid"))
    if jour.day == 8:
        cmds[3]["items"].append({"sku": SKUS[3], "qty": -1, "unit_price": float(PRODUITS[SKUS[3]]["prix_catalogue"]), "discount_pct": 0})
    if jour.day == 14:
        cmds[6]["items"] = []
    for c in cmds:
        commandes_web_lot1[c["order_id"]] = c
    lignes = [json.dumps(c, ensure_ascii=False) for c in cmds]
    if jour.day == 11:
        lignes.append(lignes[4])
    if jour.day == 5:
        lignes.append('{"order_id": "WEB-20260905-9999", "created_at": "2026-09-05T23:59:00Z", "items": [{"sku": "SKU-0001"')
    fichiers_json[f"commandes_web_{jour:%Y-%m-%d}.json"] = (1, lignes)

commande_web_a_annuler = next(c for c in commandes_web_lot1.values()
                              if c["status"] == "paid" and c["order_id"].startswith("WEB-20260910") and c["customer"] and len(c["items"]) >= 2)
for jour in JOURS_LOT2:
    cmds = [commande_web(jour, i) for i in range(1, rng.randint(25, 45) + 1)]
    if jour.day == 30:
        cmds.append(commande_web(jour, 900, client_id=12, statut="paid"))
    lignes = [json.dumps(c, ensure_ascii=False) for c in cmds]
    if jour.day == 29:
        annul = json.loads(json.dumps(commande_web_a_annuler))
        annul["status"] = "cancelled"
        annul["updated_at"] = "2026-09-29T08:00:00Z"
        lignes.append(json.dumps(annul, ensure_ascii=False))
    fichiers_json[f"commandes_web_{jour:%Y-%m-%d}.json"] = (2, lignes)

# ---------------------------------------------------------------------------
# Écriture des fichiers
# ---------------------------------------------------------------------------
(RACINE / "sql").mkdir(exist_ok=True)
(RACINE / "sql" / "01_source_erp_lot1.sql").write_text(sql1, encoding="utf-8")
(RACINE / "sql" / "07_source_erp_lot2.sql").write_text(sql2, encoding="utf-8")
for nom, (lot, rows) in fichiers_csv.items():
    ecrire_csv(RACINE / "donnees" / f"lot{lot}" / "magasins" / nom, rows)
for nom, (lot, lignes) in fichiers_json.items():
    p = RACINE / "donnees" / f"lot{lot}" / "web" / nom
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(lignes) + "\n", encoding="utf-8")

# ---------------------------------------------------------------------------
# Simulation du pipeline → résultats attendus
# ---------------------------------------------------------------------------
def simuler(lot_max):
    rejets = Counter()
    silver = {}  # (canal, vente_id, ligne) -> dict

    # Référentiel clients ERP
    cli = {c["client_id"]: dict(c) for c in clients}
    if lot_max >= 2:
        cli[12].update(ville="Bordeaux", code_postal="33000", segment="Premium")
        cli[45].update(segment="Professionnel")
        cli[301] = dict(nouveau_client)

    # ERP
    cmds = {c["commande_id"]: dict(c) for c in commandes}
    lgs = list(lignes_cmd)
    if lot_max >= 2:
        cmds[commande_a_annuler["commande_id"]]["statut"] = "ANNULEE"
        for c in commandes_l2:
            cmds[c["commande_id"]] = dict(c)
        lgs += lignes_l2
    for l in lgs:
        c = cmds[l["commande_id"]]
        silver[("ERP", str(l["commande_id"]), l["ligne_num"])] = dict(
            date=c["date_commande"].date(), client_id=c["client_id"],
            statut="ANNULEE" if c["statut"] == "ANNULEE" else "VALIDEE",
            net=montant_net(l["quantite"], l["prix_unitaire"], l["remise_pct"]))

    # Magasins : dédoublonnage (fichier le plus récent / nom le plus grand)
    retenues = {}
    for nom in sorted(fichiers_csv):
        lot, rows = fichiers_csv[nom]
        if lot > lot_max:
            continue
        for r in rows:
            cle = (r[0], int(r[1]))
            prec = retenues.get(cle)
            if prec is None or (lot, nom) > (prec[0], prec[1]):
                retenues[cle] = (lot, nom, r)
    for (ticket, ligne), (_, _, r) in retenues.items():
        try:
            d = dt.datetime.strptime(r[2], "%d/%m/%Y %H:%M")
        except ValueError:
            d = None
        qte, prix = int(r[5]), Decimal(r[6].replace(",", "."))
        if d is None:
            rejets[("MAGASIN", "date invalide")] += 1; continue
        if r[3] not in CODES_MAGASINS:
            rejets[("MAGASIN", "magasin inconnu")] += 1; continue
        if r[4] not in PRODUITS:
            rejets[("MAGASIN", "produit inconnu")] += 1; continue
        if qte <= 0:
            rejets[("MAGASIN", "quantité invalide")] += 1; continue
        silver[("MAGASIN", ticket, ligne)] = dict(date=d.date(), client_id=int(r[8]) if r[8] else None,
                                                  statut="VALIDEE", net=montant_net(qte, prix, Decimal(r[7])))

    # Web
    retenues = {}
    for nom in sorted(fichiers_json):
        lot, lignes = fichiers_json[nom]
        if lot > lot_max:
            continue
        for txt in lignes:
            try:
                o = json.loads(txt)
            except json.JSONDecodeError:
                o = None
            cle = o["order_id"] if o else txt
            maj = o["updated_at"] if o else ""
            prec = retenues.get(cle)
            if prec is None or (maj, lot) >= (prec[0], prec[1]):
                retenues[cle] = (maj, lot, o)
    for cle, (_, _, o) in retenues.items():
        if o is None:
            rejets[("WEB", "JSON invalide")] += 1; continue
        if not o["items"]:
            rejets[("WEB", "commande sans article")] += 1; continue
        for pos, it in enumerate(o["items"], start=1):
            if it["sku"] not in PRODUITS:
                rejets[("WEB", "produit inconnu")] += 1; continue
            if it["qty"] <= 0:
                rejets[("WEB", "quantité invalide")] += 1; continue
            silver[("WEB", o["order_id"], pos)] = dict(
                date=dt.date.fromisoformat(o["created_at"][:10]),
                client_id=o["customer"]["id"] if o["customer"] else None,
                statut="ANNULEE" if o["status"] == "cancelled" else "VALIDEE",
                net=montant_net(it["qty"], Decimal(str(it["unit_price"])), Decimal(it["discount_pct"])))

    silver_canal = Counter(k[0] for k in silver)
    fait = {k: v for k, v in silver.items() if v["statut"] == "VALIDEE"}
    fait_canal = Counter(k[0] for k in fait)
    ca_canal = defaultdict(Decimal)
    for k, v in fait.items():
        ca_canal[k[0]] += v["net"]
    inconnus = Counter(k[0] for k, v in fait.items() if v["client_id"] is None or v["client_id"] not in cli)
    versions = len(cli) + (2 if lot_max >= 2 else 0) + 1  # + membre inconnu
    bronze = {
        "erp_clients": len(clients) + (3 if lot_max >= 2 else 0),
        "erp_produits": len(produits),
        "erp_magasins": len(magasins),
        "erp_commandes": len(commandes) + (len(commandes_l2) + 1 if lot_max >= 2 else 0),
        "erp_lignes_commande": len(lignes_cmd) + (len(lignes_l2) if lot_max >= 2 else 0),
        "magasins_ventes_brut": sum(len(r) for l, r in fichiers_csv.values() if l <= lot_max),
        "magasins_fichiers": sum(1 for l, _ in fichiers_csv.values() if l <= lot_max),
        "web_commandes_brut": sum(len(r) for l, r in fichiers_json.values() if l <= lot_max),
        "web_fichiers": sum(1 for l, _ in fichiers_json.values() if l <= lot_max),
    }
    return {
        "bronze_lignes": bronze,
        "silver_vente_ligne_par_canal": dict(sorted(silver_canal.items())),
        "rejets_par_source_motif": {f"{s} | {m}": n for (s, m), n in sorted(rejets.items())},
        "fact_ventes_lignes_par_canal": dict(sorted(fait_canal.items())),
        "fact_ventes_ca_net_par_canal": {k: str(v) for k, v in sorted(ca_canal.items())},
        "fact_ventes_ca_net_total": str(sum(ca_canal.values())),
        "fact_ventes_client_inconnu_par_canal": dict(sorted(inconnus.items())),
        "dim_client_lignes_total": versions,
        "dim_client_versions_courantes_hors_inconnu": len(cli),
        "client_360_lignes": len(cli),
    }


attendus = {"apres_lot1": simuler(1), "apres_lot2": simuler(2),
            "reperes": {"commande_erp_annulee_lot2": commande_a_annuler["commande_id"],
                        "commande_web_annulee_lot2": commande_web_a_annuler["order_id"]}}
(RACINE / "generateur" / "resultats_attendus.json").write_text(json.dumps(attendus, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(attendus, ensure_ascii=False, indent=2))

# ---------------------------------------------------------------------------
# Script de contrôle 06 avec valeurs attendues
# ---------------------------------------------------------------------------
nb_lignes_erp_annulee = sum(1 for l in lignes_cmd if l["commande_id"] == commande_a_annuler["commande_id"])
nb_lignes_web_annulee = len(commande_web_a_annuler["items"])
a1, a2 = attendus["apres_lot1"], attendus["apres_lot2"]

controles = []  # (code, requete_scalaire, attendu_lot1, attendu_lot2)
for t in ["erp_clients", "erp_produits", "erp_magasins", "erp_commandes", "erp_lignes_commande",
          "magasins_ventes_brut", "web_commandes_brut"]:
    controles.append((f"bronze.{t} : lignes", f"SELECT count(*) FROM bronze.{t}",
                      a1["bronze_lignes"][t], a2["bronze_lignes"][t]))
controles.append(("bronze : fichiers CSV ingérés", "SELECT count(DISTINCT _fichier) FROM bronze.magasins_ventes_brut",
                  a1["bronze_lignes"]["magasins_fichiers"], a2["bronze_lignes"]["magasins_fichiers"]))
controles.append(("bronze : fichiers JSON ingérés", "SELECT count(DISTINCT _fichier) FROM bronze.web_commandes_brut",
                  a1["bronze_lignes"]["web_fichiers"], a2["bronze_lignes"]["web_fichiers"]))
for canal in ["ERP", "MAGASIN", "WEB"]:
    controles.append((f"silver.vente_ligne {canal} : lignes",
                      f"SELECT count(*) FROM silver.vente_ligne WHERE canal = '{canal}'",
                      a1["silver_vente_ligne_par_canal"][canal], a2["silver_vente_ligne_par_canal"][canal]))
for cle in a2["rejets_par_source_motif"]:
    src, motif = [x.strip() for x in cle.split("|")]
    controles.append((f"silver.rejets {src} / {motif}",
                      f"SELECT count(*) FROM silver.rejets WHERE source = '{src}' AND motif = '{motif}'",
                      a1["rejets_par_source_motif"].get(cle, 0), a2["rejets_par_source_motif"][cle]))
controles.append(("silver.rejets : total", "SELECT count(*) FROM silver.rejets",
                  sum(a1["rejets_par_source_motif"].values()), sum(a2["rejets_par_source_motif"].values())))
for canal in ["ERP", "MAGASIN", "WEB"]:
    controles.append((f"gold.fact_ventes {canal} : lignes",
                      f"SELECT count(*) FROM gold.fact_ventes WHERE canal_code = '{canal}'",
                      a1["fact_ventes_lignes_par_canal"][canal], a2["fact_ventes_lignes_par_canal"][canal]))
for canal in ["ERP", "MAGASIN", "WEB"]:
    controles.append((f"gold.fact_ventes {canal} : CA net",
                      f"SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = '{canal}'",
                      a1["fact_ventes_ca_net_par_canal"][canal], a2["fact_ventes_ca_net_par_canal"][canal]))
controles.append(("gold.fact_ventes : CA net total", "SELECT sum(montant_net) FROM gold.fact_ventes",
                  a1["fact_ventes_ca_net_total"], a2["fact_ventes_ca_net_total"]))
for canal in ["ERP", "MAGASIN", "WEB"]:
    controles.append((f"gold.fact_ventes {canal} : lignes client inconnu (-1)",
                      f"SELECT count(*) FROM gold.fact_ventes WHERE canal_code = '{canal}' AND client_sk = -1",
                      a1["fact_ventes_client_inconnu_par_canal"].get(canal, 0),
                      a2["fact_ventes_client_inconnu_par_canal"].get(canal, 0)))
controles.append(("gold.dim_client : lignes (versions + membre inconnu)", "SELECT count(*) FROM gold.dim_client",
                  a1["dim_client_lignes_total"], a2["dim_client_lignes_total"]))
controles.append(("gold.dim_client : versions courantes hors inconnu",
                  "SELECT count(*) FROM gold.dim_client WHERE est_courant AND client_sk <> -1",
                  a1["dim_client_versions_courantes_hors_inconnu"], a2["dim_client_versions_courantes_hors_inconnu"]))
controles.append(("gold.dim_client : versions du client 12", "SELECT count(*) FROM gold.dim_client WHERE client_id = 12", 1, 2))
controles.append((f"gold.fact_ventes : lignes de la commande ERP {commande_a_annuler['commande_id']} (annulée au lot 2)",
                  f"SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP' AND vente_id = '{commande_a_annuler['commande_id']}'",
                  nb_lignes_erp_annulee, 0))
controles.append((f"gold.fact_ventes : lignes de la commande {commande_web_a_annuler['order_id']} (annulée au lot 2)",
                  f"SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB' AND vente_id = '{commande_web_a_annuler['order_id']}'",
                  nb_lignes_web_annulee, 0))
controles.append(("gold.agg_ca_journalier : CA net total", "SELECT sum(ca_net) FROM gold.agg_ca_journalier",
                  a1["fact_ventes_ca_net_total"], a2["fact_ventes_ca_net_total"]))
controles.append(("gold.agg_produit_mensuel : CA net total", "SELECT sum(ca_net) FROM gold.agg_produit_mensuel",
                  a1["fact_ventes_ca_net_total"], a2["fact_ventes_ca_net_total"]))
controles.append(("gold.agg_magasin_mensuel : CA net total", "SELECT sum(ca_net) FROM gold.agg_magasin_mensuel",
                  a1["fact_ventes_ca_net_par_canal"]["MAGASIN"], a2["fact_ventes_ca_net_par_canal"]["MAGASIN"]))
controles.append(("gold.client_360 : lignes", "SELECT count(*) FROM gold.client_360",
                  a1["client_360_lignes"], a2["client_360_lignes"]))

blocs = []
for i, (code, req, v1, v2) in enumerate(controles, start=1):
    blocs.append(f"  SELECT {i:2d} AS num, '{code.replace(chr(39), chr(39) * 2)}' AS controle,\n"
                 f"         CAST(({req}) AS DECIMAL(18,2)) AS obtenu,\n"
                 f"         CAST({v1} AS DECIMAL(18,2)) AS attendu_lot1,\n"
                 f"         CAST({v2} AS DECIMAL(18,2)) AS attendu_lot2")
sql6 = """-- =====================================================================
-- 06_controles.sql — Contrôle de bout en bout avec valeurs attendues
-- À exécuter après 05 (lot 1), puis à nouveau après le lot 2 (07 + fichiers + 02 → 05).
-- Colonne "resultat" : OK (lot 1), OK (lot 2) ou ÉCART.
-- Généré par generateur/generer_donnees.py — ne pas modifier à la main
-- =====================================================================

USE CATALOG projet_medaillon;

WITH controles AS (
""" + "\n  UNION ALL\n".join(blocs) + """
)
SELECT
  num,
  controle,
  obtenu,
  attendu_lot1,
  attendu_lot2,
  CASE
    WHEN obtenu <=> attendu_lot1 AND obtenu <=> attendu_lot2 THEN 'OK'
    WHEN obtenu <=> attendu_lot1 THEN 'OK (lot 1)'
    WHEN obtenu <=> attendu_lot2 THEN 'OK (lot 2)'
    ELSE 'ÉCART'
  END AS resultat
FROM controles
ORDER BY num;

-- Synthèse : une seule ligne
WITH r AS (
""" + "\n  UNION ALL\n".join(
    f"  SELECT CAST(({req}) AS DECIMAL(18,2)) AS obtenu, CAST({v1} AS DECIMAL(18,2)) AS a1, CAST({v2} AS DECIMAL(18,2)) AS a2"
    for _, req, v1, v2 in controles) + """
)
SELECT
  count(*)                                                AS nb_controles,
  count_if(obtenu <=> a1)                                 AS conformes_lot1,
  count_if(obtenu <=> a2)                                 AS conformes_lot2,
  CASE WHEN count_if(obtenu <=> a1) = count(*) THEN 'LOT 1 CONFORME'
       WHEN count_if(obtenu <=> a2) = count(*) THEN 'LOT 2 CONFORME'
       ELSE 'ÉCARTS À ANALYSER (voir requête précédente)' END AS bilan
FROM r;

-- Historique SCD2 du client 12 (1 version après le lot 1, 2 après le lot 2)
SELECT client_sk, client_id, nom_complet, ville, segment, date_debut, date_fin, est_courant
FROM gold.dim_client
WHERE client_id = 12
ORDER BY date_debut;

-- Ventes du client 12 rattachées à chaque version
SELECT dc.client_sk, dc.ville, dc.segment, f.canal_code, count(*) AS lignes, min(f.horodatage_vente) AS premiere, max(f.horodatage_vente) AS derniere
FROM gold.fact_ventes f
JOIN gold.dim_client dc ON dc.client_sk = f.client_sk
WHERE dc.client_id = 12
GROUP BY ALL
ORDER BY premiere;
"""
(RACINE / "sql" / "06_controles.sql").write_text(sql6, encoding="utf-8")
print(f"06_controles.sql : {len(controles)} contrôles")

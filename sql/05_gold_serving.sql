-- =====================================================================
-- 05_gold_serving.sql — Tables de service consommées par l'API
--   agg_ca_journalier     CA par jour et par canal
--   agg_produit_mensuel   performance produit par mois (+ rang dans la catégorie)
--   agg_magasin_mensuel   performance magasin par mois
--   client_360            fiche client consolidée tous canaux
-- Rechargement complet (INSERT OVERWRITE) : la table, ses droits et son historique sont conservés.
-- Ré-exécutable : oui
-- =====================================================================

USE CATALOG projet_medaillon;

-- =====================================================================
-- 1. STRUCTURES
-- =====================================================================
CREATE TABLE IF NOT EXISTS gold.agg_ca_journalier (
  date_vente     DATE   NOT NULL,
  canal_code     STRING NOT NULL,
  canal_libelle  STRING,
  nb_ventes      BIGINT,
  nb_lignes      BIGINT,
  quantite       BIGINT,
  ca_net         DECIMAL(18,2),
  marge          DECIMAL(18,2),
  _maj_ts        TIMESTAMP,
  CONSTRAINT pk_agg_ca_journalier PRIMARY KEY (date_vente, canal_code)
) COMMENT 'Service API : chiffre d''affaires par jour et par canal';

CREATE TABLE IF NOT EXISTS gold.agg_produit_mensuel (
  mois                 DATE   NOT NULL COMMENT 'Premier jour du mois',
  sku                  STRING NOT NULL,
  libelle              STRING,
  categorie            STRING,
  marque               STRING,
  quantite             BIGINT,
  ca_net               DECIMAL(18,2),
  marge                DECIMAL(18,2),
  taux_marge_pct       DECIMAL(6,2),
  rang_dans_categorie  INT,
  _maj_ts              TIMESTAMP,
  CONSTRAINT pk_agg_produit_mensuel PRIMARY KEY (mois, sku)
) COMMENT 'Service API : performance produit mensuelle, tous canaux';

CREATE TABLE IF NOT EXISTS gold.agg_magasin_mensuel (
  mois          DATE   NOT NULL COMMENT 'Premier jour du mois',
  code_magasin  STRING NOT NULL,
  nom           STRING,
  ville         STRING,
  region        STRING,
  nb_tickets    BIGINT,
  nb_articles   BIGINT,
  ca_net        DECIMAL(18,2),
  marge         DECIMAL(18,2),
  panier_moyen  DECIMAL(12,2),
  rang_ca       INT,
  _maj_ts       TIMESTAMP,
  CONSTRAINT pk_agg_magasin_mensuel PRIMARY KEY (mois, code_magasin)
) COMMENT 'Service API : performance mensuelle des magasins physiques';

CREATE TABLE IF NOT EXISTS gold.client_360 (
  client_id           INT    NOT NULL,
  nom_complet         STRING,
  email               STRING,
  ville               STRING,
  segment             STRING,
  nb_ventes           BIGINT,
  ca_total            DECIMAL(18,2),
  panier_moyen        DECIMAL(12,2),
  premiere_vente      DATE,
  derniere_vente      DATE,
  recence_jours       INT,
  canal_prefere       STRING,
  categorie_preferee  STRING,
  _maj_ts             TIMESTAMP,
  CONSTRAINT pk_client_360 PRIMARY KEY (client_id)
) COMMENT 'Service API : vue client consolidée (attributs courants, ventes tous canaux et toutes versions)';

-- =====================================================================
-- 2. CHARGEMENT
-- =====================================================================
INSERT OVERWRITE gold.agg_ca_journalier
SELECT
  d.date_jour,
  f.canal_code,
  c.libelle,
  count(DISTINCT f.vente_id),
  count(*),
  sum(f.quantite),
  sum(f.montant_net),
  sum(f.marge),
  current_timestamp()
FROM gold.fact_ventes f
JOIN gold.dim_date d  ON d.date_key   = f.date_key
JOIN gold.dim_canal c ON c.canal_code = f.canal_code
GROUP BY d.date_jour, f.canal_code, c.libelle;

INSERT OVERWRITE gold.agg_produit_mensuel
SELECT
  d.mois_debut,
  p.sku,
  p.libelle,
  p.categorie,
  p.marque,
  sum(f.quantite),
  sum(f.montant_net),
  sum(f.marge),
  CAST(round(100 * sum(f.marge) / nullif(sum(f.montant_net), 0), 2) AS DECIMAL(6,2)),
  CAST(rank() OVER (PARTITION BY d.mois_debut, p.categorie ORDER BY sum(f.montant_net) DESC) AS INT),
  current_timestamp()
FROM gold.fact_ventes f
JOIN gold.dim_date d    ON d.date_key = f.date_key
JOIN gold.dim_produit p ON p.sku      = f.sku
GROUP BY d.mois_debut, p.sku, p.libelle, p.categorie, p.marque;

INSERT OVERWRITE gold.agg_magasin_mensuel
SELECT
  d.mois_debut,
  m.code_magasin,
  m.nom,
  m.ville,
  m.region,
  count(DISTINCT f.vente_id),
  sum(f.quantite),
  sum(f.montant_net),
  sum(f.marge),
  CAST(sum(f.montant_net) / count(DISTINCT f.vente_id) AS DECIMAL(12,2)),
  CAST(rank() OVER (PARTITION BY d.mois_debut ORDER BY sum(f.montant_net) DESC) AS INT),
  current_timestamp()
FROM gold.fact_ventes f
JOIN gold.dim_date d    ON d.date_key     = f.date_key
JOIN gold.dim_magasin m ON m.code_magasin = f.code_magasin
WHERE f.canal_code = 'MAGASIN'
GROUP BY d.mois_debut, m.code_magasin, m.nom, m.ville, m.region;

INSERT OVERWRITE gold.client_360
WITH base AS (
  SELECT
    cur.client_id,
    f.canal_code,
    f.vente_id,
    f.montant_net,
    p.categorie,
    d.date_jour
  FROM gold.fact_ventes f
  JOIN gold.dim_client v   ON v.client_sk   = f.client_sk
  JOIN gold.dim_client cur ON cur.client_id = v.client_id AND cur.est_courant
  JOIN gold.dim_date d     ON d.date_key    = f.date_key
  JOIN gold.dim_produit p  ON p.sku         = f.sku
  WHERE f.client_sk <> -1
),
agg AS (
  SELECT
    client_id,
    count(DISTINCT canal_code, vente_id) AS nb_ventes,
    sum(montant_net)                     AS ca_total,
    min(date_jour)                       AS premiere_vente,
    max(date_jour)                       AS derniere_vente
  FROM base
  GROUP BY client_id
),
canal AS (
  SELECT client_id, canal_code
  FROM (SELECT client_id, canal_code, sum(montant_net) AS ca FROM base GROUP BY client_id, canal_code)
  QUALIFY row_number() OVER (PARTITION BY client_id ORDER BY ca DESC, canal_code) = 1
),
categorie AS (
  SELECT client_id, categorie
  FROM (SELECT client_id, categorie, sum(montant_net) AS ca FROM base GROUP BY client_id, categorie)
  QUALIFY row_number() OVER (PARTITION BY client_id ORDER BY ca DESC, categorie) = 1
)
SELECT
  c.client_id,
  c.nom_complet,
  c.email,
  c.ville,
  c.segment,
  coalesce(a.nb_ventes, 0),
  coalesce(a.ca_total, 0),
  CAST(a.ca_total / nullif(a.nb_ventes, 0) AS DECIMAL(12,2)),
  a.premiere_vente,
  a.derniere_vente,
  datediff(current_date(), a.derniere_vente),
  cn.canal_code,
  ct.categorie,
  current_timestamp()
FROM gold.dim_client c
LEFT JOIN agg a        ON a.client_id  = c.client_id
LEFT JOIN canal cn     ON cn.client_id = c.client_id
LEFT JOIN categorie ct ON ct.client_id = c.client_id
WHERE c.est_courant AND c.client_sk <> -1;

-- =====================================================================
-- 3. DROITS POUR L'API
--    Avec un token personnel : rien à faire (vous êtes propriétaire).
--    Avec un service principal : droits attribués dans l'interface (guide, étape 10.3 :
--    Catalog → Permissions → Grant). Équivalent SQL, en remplaçant par l'Application ID :
-- GRANT USE CATALOG ON CATALOG projet_medaillon TO `00000000-0000-0000-0000-000000000000`;
-- GRANT USE SCHEMA, SELECT ON SCHEMA projet_medaillon.gold TO `00000000-0000-0000-0000-000000000000`;

-- =====================================================================
-- 4. CONTRÔLE
-- =====================================================================
SELECT 'agg_ca_journalier' AS table_service, count(*) AS lignes, sum(ca_net) AS ca_net FROM gold.agg_ca_journalier
UNION ALL SELECT 'agg_produit_mensuel', count(*), sum(ca_net) FROM gold.agg_produit_mensuel
UNION ALL SELECT 'agg_magasin_mensuel', count(*), sum(ca_net) FROM gold.agg_magasin_mensuel
UNION ALL SELECT 'client_360',          count(*), sum(ca_total) FROM gold.client_360;

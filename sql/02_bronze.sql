-- =====================================================================
-- 02_bronze.sql — Ingestion des 3 sources en bronze (données brutes)
--   A. SQL  : source_erp.*      → bronze.erp_*                 (extraction incrémentale par date_maj)
--   B. CSV  : landing/magasins/ → bronze.magasins_ventes_brut  (COPY INTO, tout en texte)
--   C. JSON : landing/web/      → bronze.web_commandes_brut    (COPY INTO, une ligne JSON brute par enregistrement)
-- Ré-exécutable : oui (incrémental : seules les nouveautés sont ajoutées)
-- =====================================================================

USE CATALOG projet_medaillon;

-- =====================================================================
-- A. SOURCE SQL (ERP) — high watermark sur date_maj
--    La table bronze garde l'historique de toutes les versions extraites.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.erp_clients
COMMENT 'Bronze : extraction incrémentale de source_erp.clients'
AS SELECT *, current_timestamp() AS _ingest_ts FROM source_erp.clients WHERE 1 = 0;

INSERT INTO bronze.erp_clients
SELECT *, current_timestamp() FROM source_erp.clients
WHERE date_maj > (SELECT coalesce(max(date_maj), TIMESTAMP'1900-01-01 00:00:00') FROM bronze.erp_clients);

CREATE TABLE IF NOT EXISTS bronze.erp_produits
COMMENT 'Bronze : extraction incrémentale de source_erp.produits'
AS SELECT *, current_timestamp() AS _ingest_ts FROM source_erp.produits WHERE 1 = 0;

INSERT INTO bronze.erp_produits
SELECT *, current_timestamp() FROM source_erp.produits
WHERE date_maj > (SELECT coalesce(max(date_maj), TIMESTAMP'1900-01-01 00:00:00') FROM bronze.erp_produits);

CREATE TABLE IF NOT EXISTS bronze.erp_magasins
COMMENT 'Bronze : extraction incrémentale de source_erp.magasins'
AS SELECT *, current_timestamp() AS _ingest_ts FROM source_erp.magasins WHERE 1 = 0;

INSERT INTO bronze.erp_magasins
SELECT *, current_timestamp() FROM source_erp.magasins
WHERE date_maj > (SELECT coalesce(max(date_maj), TIMESTAMP'1900-01-01 00:00:00') FROM bronze.erp_magasins);

CREATE TABLE IF NOT EXISTS bronze.erp_commandes
COMMENT 'Bronze : extraction incrémentale de source_erp.commandes'
AS SELECT *, current_timestamp() AS _ingest_ts FROM source_erp.commandes WHERE 1 = 0;

INSERT INTO bronze.erp_commandes
SELECT *, current_timestamp() FROM source_erp.commandes
WHERE date_maj > (SELECT coalesce(max(date_maj), TIMESTAMP'1900-01-01 00:00:00') FROM bronze.erp_commandes);

CREATE TABLE IF NOT EXISTS bronze.erp_lignes_commande
COMMENT 'Bronze : extraction incrémentale de source_erp.lignes_commande'
AS SELECT *, current_timestamp() AS _ingest_ts FROM source_erp.lignes_commande WHERE 1 = 0;

INSERT INTO bronze.erp_lignes_commande
SELECT *, current_timestamp() FROM source_erp.lignes_commande
WHERE date_maj > (SELECT coalesce(max(date_maj), TIMESTAMP'1900-01-01 00:00:00') FROM bronze.erp_lignes_commande);

-- =====================================================================
-- B. SOURCE CSV (caisses magasins) — COPY INTO idempotent
--    Tout est stocké en STRING : le typage se fait en silver.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.magasins_ventes_brut (
  ticket_id       STRING,
  ligne           STRING,
  date_heure      STRING,
  code_magasin    STRING,
  sku             STRING,
  quantite        STRING,
  prix_unitaire   STRING,
  remise_pct      STRING,
  carte_fidelite  STRING,
  _fichier        STRING,
  _ingest_ts      TIMESTAMP
) COMMENT 'Bronze : lignes de tickets de caisse, telles que reçues (CSV ; virgule décimale)';

COPY INTO bronze.magasins_ventes_brut
FROM (
  SELECT ticket_id, ligne, date_heure, code_magasin, sku, quantite, prix_unitaire, remise_pct, carte_fidelite,
         _metadata.file_name AS _fichier,
         current_timestamp() AS _ingest_ts
  FROM '/Volumes/projet_medaillon/bronze/landing/magasins/'
)
FILEFORMAT = CSV
PATTERN = '*.csv'
FORMAT_OPTIONS ('header' = 'true', 'delimiter' = ';', 'inferSchema' = 'false', 'encoding' = 'UTF-8');

-- =====================================================================
-- C. SOURCE JSON (site e-commerce) — COPY INTO en texte brut
--    Chaque ligne JSON est conservée intacte : un JSON mal formé ne bloque pas l'ingestion.
-- =====================================================================
CREATE TABLE IF NOT EXISTS bronze.web_commandes_brut (
  payload     STRING,
  _fichier    STRING,
  _ingest_ts  TIMESTAMP
) COMMENT 'Bronze : commandes web, une ligne JSON brute par commande';

COPY INTO bronze.web_commandes_brut
FROM (
  SELECT value AS payload,
         _metadata.file_name AS _fichier,
         current_timestamp() AS _ingest_ts
  FROM '/Volumes/projet_medaillon/bronze/landing/web/'
)
FILEFORMAT = TEXT
PATTERN = '*.json';

-- =====================================================================
-- Contrôle (valeurs attendues : voir 06_controles.sql)
-- =====================================================================
SELECT 'erp_clients' AS table_bronze, count(*) AS lignes FROM bronze.erp_clients
UNION ALL SELECT 'erp_produits',         count(*) FROM bronze.erp_produits
UNION ALL SELECT 'erp_magasins',         count(*) FROM bronze.erp_magasins
UNION ALL SELECT 'erp_commandes',        count(*) FROM bronze.erp_commandes
UNION ALL SELECT 'erp_lignes_commande',  count(*) FROM bronze.erp_lignes_commande
UNION ALL SELECT 'magasins_ventes_brut', count(*) FROM bronze.magasins_ventes_brut
UNION ALL SELECT 'web_commandes_brut',   count(*) FROM bronze.web_commandes_brut;

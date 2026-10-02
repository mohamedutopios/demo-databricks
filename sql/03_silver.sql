-- =====================================================================
-- 03_silver.sql — Bronze → Silver : nettoyage, typage, dédoublonnage, conformation
--   1. Tables silver (référentiels + table unifiée des ventes + quarantaine)
--   2. Vues de préparation : une par source, mêmes colonnes en sortie
--   3. Chargement (MERGE) des référentiels puis des ventes
--   4. Quarantaine et rapport qualité
-- Ré-exécutable : oui (idempotent)
-- =====================================================================

USE CATALOG projet_medaillon;

-- =====================================================================
-- 1. TABLES
-- =====================================================================
CREATE TABLE IF NOT EXISTS silver.client (
  client_id      INT       NOT NULL,
  nom_complet    STRING    NOT NULL,
  email          STRING,
  telephone      STRING,
  ville          STRING,
  code_postal    STRING,
  segment        STRING,
  date_creation  DATE,
  date_maj       TIMESTAMP NOT NULL,
  _charge_ts     TIMESTAMP,
  CONSTRAINT pk_silver_client PRIMARY KEY (client_id)
) COMMENT 'Silver : clients nettoyés (dernière version connue)';

CREATE TABLE IF NOT EXISTS silver.produit (
  sku             STRING    NOT NULL,
  libelle         STRING,
  categorie       STRING,
  marque          STRING,
  prix_catalogue  DECIMAL(10,2),
  cout_achat      DECIMAL(10,2),
  actif           BOOLEAN,
  date_maj        TIMESTAMP,
  _charge_ts      TIMESTAMP,
  CONSTRAINT pk_silver_produit PRIMARY KEY (sku)
) COMMENT 'Silver : catalogue produits';

CREATE TABLE IF NOT EXISTS silver.magasin (
  code_magasin    STRING    NOT NULL,
  nom             STRING,
  ville           STRING,
  region          STRING,
  surface_m2      INT,
  date_ouverture  DATE,
  date_maj        TIMESTAMP,
  _charge_ts      TIMESTAMP,
  CONSTRAINT pk_silver_magasin PRIMARY KEY (code_magasin)
) COMMENT 'Silver : magasins physiques';

CREATE TABLE IF NOT EXISTS silver.vente_ligne (
  canal             STRING        NOT NULL COMMENT 'ERP, MAGASIN ou WEB',
  vente_id          STRING        NOT NULL COMMENT 'N° de commande ERP, de ticket ou de commande web',
  ligne_num         INT           NOT NULL,
  horodatage_vente  TIMESTAMP     NOT NULL,
  date_vente        DATE          NOT NULL,
  client_id         INT                    COMMENT 'NULL si client anonyme',
  sku               STRING        NOT NULL,
  code_magasin      STRING                 COMMENT 'Renseigné pour le canal MAGASIN uniquement',
  quantite          INT           NOT NULL,
  prix_unitaire     DECIMAL(10,2) NOT NULL,
  remise_pct        DECIMAL(5,2)  NOT NULL,
  montant_brut      DECIMAL(12,2),
  montant_net       DECIMAL(12,2),
  statut            STRING        NOT NULL COMMENT 'VALIDEE ou ANNULEE',
  source_fichier    STRING,
  _charge_ts        TIMESTAMP,
  CONSTRAINT pk_silver_vente_ligne PRIMARY KEY (canal, vente_id, ligne_num)
) COMMENT 'Silver : lignes de vente des 3 canaux, au format commun'
CLUSTER BY (date_vente);

CREATE TABLE IF NOT EXISTS silver.rejets (
  source       STRING,
  cle          STRING,
  motif        STRING,
  fichier      STRING,
  _detecte_ts  TIMESTAMP
) COMMENT 'Silver : quarantaine des enregistrements refusés par les règles qualité';

-- Contraintes CHECK : appliquées à chaque écriture (contrairement aux PK/FK, informatives)
ALTER TABLE silver.vente_ligne DROP CONSTRAINT IF EXISTS chk_vl_quantite;
ALTER TABLE silver.vente_ligne ADD CONSTRAINT chk_vl_quantite CHECK (quantite > 0);
ALTER TABLE silver.vente_ligne DROP CONSTRAINT IF EXISTS chk_vl_prix;
ALTER TABLE silver.vente_ligne ADD CONSTRAINT chk_vl_prix CHECK (prix_unitaire >= 0);
ALTER TABLE silver.vente_ligne DROP CONSTRAINT IF EXISTS chk_vl_remise;
ALTER TABLE silver.vente_ligne ADD CONSTRAINT chk_vl_remise CHECK (remise_pct BETWEEN 0 AND 100);
ALTER TABLE silver.vente_ligne DROP CONSTRAINT IF EXISTS chk_vl_canal;
ALTER TABLE silver.vente_ligne ADD CONSTRAINT chk_vl_canal CHECK (canal IN ('ERP', 'MAGASIN', 'WEB'));
ALTER TABLE silver.vente_ligne DROP CONSTRAINT IF EXISTS chk_vl_statut;
ALTER TABLE silver.vente_ligne ADD CONSTRAINT chk_vl_statut CHECK (statut IN ('VALIDEE', 'ANNULEE'));

-- =====================================================================
-- 2. VUES DE PRÉPARATION
-- =====================================================================

-- 2.1 Référentiels ERP : dernière version par clé, nettoyage
CREATE OR REPLACE VIEW silver.v_client_prepare AS
SELECT
  client_id,
  nullif(concat_ws(' ', initcap(trim(prenom)), upper(trim(nom))), '') AS nom_complet,
  CASE WHEN lower(trim(email)) RLIKE '^[^@ ]+@[^@ ]+[.][a-z]{2,}$' THEN lower(trim(email)) END AS email,
  regexp_replace(telephone, '[^0-9]', '')                             AS telephone,
  initcap(trim(ville))                                                AS ville,
  trim(code_postal)                                                   AS code_postal,
  segment,
  date_creation,
  date_maj,
  CASE
    WHEN client_id IS NULL                 THEN 'identifiant absent'
    WHEN prenom IS NULL AND nom IS NULL    THEN 'nom absent'
    WHEN date_maj IS NULL                  THEN 'date de mise à jour absente'
  END AS motif_rejet
FROM bronze.erp_clients
QUALIFY row_number() OVER (PARTITION BY client_id ORDER BY date_maj DESC, _ingest_ts DESC) = 1;

CREATE OR REPLACE VIEW silver.v_produit_prepare AS
SELECT upper(trim(sku)) AS sku, trim(libelle) AS libelle, categorie, marque,
       prix_catalogue, cout_achat, actif, date_maj
FROM bronze.erp_produits
QUALIFY row_number() OVER (PARTITION BY upper(trim(sku)) ORDER BY date_maj DESC, _ingest_ts DESC) = 1;

CREATE OR REPLACE VIEW silver.v_magasin_prepare AS
SELECT upper(trim(code_magasin)) AS code_magasin, nom, ville, region, surface_m2, date_ouverture, date_maj
FROM bronze.erp_magasins
QUALIFY row_number() OVER (PARTITION BY upper(trim(code_magasin)) ORDER BY date_maj DESC, _ingest_ts DESC) = 1;

-- 2.2 Ventes ERP : commandes + lignes (dernière version de chacune)
CREATE OR REPLACE VIEW silver.v_vente_erp AS
WITH cmd AS (
  SELECT * FROM bronze.erp_commandes
  QUALIFY row_number() OVER (PARTITION BY commande_id ORDER BY date_maj DESC, _ingest_ts DESC) = 1
),
lig AS (
  SELECT * FROM bronze.erp_lignes_commande
  QUALIFY row_number() OVER (PARTITION BY commande_id, ligne_num ORDER BY date_maj DESC, _ingest_ts DESC) = 1
)
SELECT
  'ERP'                                                     AS canal,
  CAST(l.commande_id AS STRING)                             AS vente_id,
  CAST(l.ligne_num AS INT)                                  AS ligne_num,
  c.date_commande                                           AS horodatage_vente,
  CAST(c.client_id AS INT)                                  AS client_id,
  upper(trim(l.sku))                                        AS sku,
  CAST(NULL AS STRING)                                      AS code_magasin,
  CAST(l.quantite AS INT)                                   AS quantite,
  CAST(l.prix_unitaire AS DECIMAL(10,2))                    AS prix_unitaire,
  CAST(coalesce(l.remise_pct, 0) AS DECIMAL(5,2))           AS remise_pct,
  CASE WHEN c.statut = 'ANNULEE' THEN 'ANNULEE' ELSE 'VALIDEE' END AS statut,
  'source_erp.lignes_commande'                              AS source_fichier,
  concat(l.commande_id, '/', l.ligne_num)                   AS cle_rejet,
  CASE
    WHEN c.commande_id IS NULL                              THEN 'commande inconnue'
    WHEN c.date_commande IS NULL                            THEN 'date invalide'
    WHEN p.sku IS NULL                                      THEN 'produit inconnu'
    WHEN l.quantite IS NULL OR l.quantite <= 0              THEN 'quantité invalide'
    WHEN l.prix_unitaire IS NULL OR l.prix_unitaire < 0     THEN 'prix invalide'
    WHEN coalesce(l.remise_pct, 0) NOT BETWEEN 0 AND 100    THEN 'remise invalide'
  END                                                       AS motif_rejet
FROM lig l
LEFT JOIN cmd c            ON c.commande_id = l.commande_id
LEFT JOIN silver.produit p ON p.sku = upper(trim(l.sku));

-- 2.3 Ventes magasins (CSV) : typage du texte, format français, dédoublonnage
--     En cas de doublon (fichier correctif), la ligne du fichier le plus récent l'emporte.
CREATE OR REPLACE VIEW silver.v_vente_magasin AS
WITH typee AS (
  SELECT
    nullif(trim(ticket_id), '')                                                      AS vente_id,
    try_cast(trim(ligne) AS INT)                                                     AS ligne_num,
    try_to_timestamp(trim(date_heure), 'dd/MM/yyyy HH:mm')                           AS horodatage_vente,
    try_cast(nullif(trim(carte_fidelite), '') AS INT)                                AS client_id,
    upper(trim(sku))                                                                 AS sku,
    upper(trim(code_magasin))                                                        AS code_magasin,
    try_cast(trim(quantite) AS INT)                                                  AS quantite,
    try_cast(replace(trim(prix_unitaire), ',', '.') AS DECIMAL(10,2))                AS prix_unitaire,
    try_cast(replace(coalesce(nullif(trim(remise_pct), ''), '0'), ',', '.') AS DECIMAL(5,2)) AS remise_pct,
    _fichier,
    _ingest_ts
  FROM bronze.magasins_ventes_brut
),
dedup AS (
  SELECT * FROM typee
  QUALIFY row_number() OVER (PARTITION BY vente_id, ligne_num ORDER BY _ingest_ts DESC, _fichier DESC) = 1
)
SELECT
  'MAGASIN'                                                 AS canal,
  d.vente_id,
  d.ligne_num,
  d.horodatage_vente,
  d.client_id,
  d.sku,
  d.code_magasin,
  d.quantite,
  d.prix_unitaire,
  d.remise_pct,
  'VALIDEE'                                                 AS statut,
  d._fichier                                                AS source_fichier,
  concat_ws('/', d.vente_id, CAST(d.ligne_num AS STRING))   AS cle_rejet,
  CASE
    WHEN d.vente_id IS NULL OR d.ligne_num IS NULL          THEN 'identifiant invalide'
    WHEN d.horodatage_vente IS NULL                         THEN 'date invalide'
    WHEN m.code_magasin IS NULL                             THEN 'magasin inconnu'
    WHEN p.sku IS NULL                                      THEN 'produit inconnu'
    WHEN d.quantite IS NULL OR d.quantite <= 0              THEN 'quantité invalide'
    WHEN d.prix_unitaire IS NULL OR d.prix_unitaire < 0     THEN 'prix invalide'
    WHEN d.remise_pct IS NULL OR d.remise_pct NOT BETWEEN 0 AND 100 THEN 'remise invalide'
  END                                                       AS motif_rejet
FROM dedup d
LEFT JOIN silver.magasin m ON m.code_magasin = d.code_magasin
LEFT JOIN silver.produit p ON p.sku = d.sku;

-- 2.4 Ventes web (JSON) : validation, parsing, dédoublonnage, une ligne par article
--     Dernière version d'une commande = updated_at le plus récent (renvois de l'API).
CREATE OR REPLACE VIEW silver.v_vente_web AS
WITH parse AS (
  SELECT
    payload,
    try_parse_json(payload) IS NOT NULL AS json_valide,
    from_json(
      payload,
      'order_id STRING, created_at STRING, updated_at STRING, status STRING,
       customer STRUCT<id: INT, email: STRING>,
       items ARRAY<STRUCT<sku: STRING, qty: INT, unit_price: DECIMAL(10,2), discount_pct: DECIMAL(5,2)>>'
    ) AS o,
    _fichier,
    _ingest_ts
  FROM bronze.web_commandes_brut
),
dedup AS (
  SELECT * FROM parse
  QUALIFY row_number() OVER (
    PARTITION BY CASE WHEN json_valide THEN o.order_id ELSE payload END
    ORDER BY try_cast(o.updated_at AS TIMESTAMP) DESC, _ingest_ts DESC
  ) = 1
),
lignes AS (
  SELECT d.payload, d.json_valide, d.o, d._fichier, e.pos, e.item
  FROM dedup d
  LATERAL VIEW OUTER posexplode(d.o.items) e AS pos, item
)
SELECT
  'WEB'                                                     AS canal,
  l.o.order_id                                              AS vente_id,
  CAST(l.pos + 1 AS INT)                                    AS ligne_num,
  try_cast(l.o.created_at AS TIMESTAMP)                     AS horodatage_vente,
  CAST(l.o.customer.id AS INT)                              AS client_id,
  upper(trim(l.item.sku))                                   AS sku,
  CAST(NULL AS STRING)                                      AS code_magasin,
  CAST(l.item.qty AS INT)                                   AS quantite,
  CAST(l.item.unit_price AS DECIMAL(10,2))                  AS prix_unitaire,
  CAST(coalesce(l.item.discount_pct, 0) AS DECIMAL(5,2))    AS remise_pct,
  CASE WHEN lower(l.o.status) = 'cancelled' THEN 'ANNULEE' ELSE 'VALIDEE' END AS statut,
  l._fichier                                                AS source_fichier,
  CASE WHEN l.json_valide AND l.o.order_id IS NOT NULL
       THEN concat(l.o.order_id, '/', CAST(l.pos + 1 AS STRING))
       ELSE left(l.payload, 80) END                         AS cle_rejet,
  CASE
    WHEN NOT l.json_valide OR l.o.order_id IS NULL          THEN 'JSON invalide'
    WHEN l.item IS NULL                                     THEN 'commande sans article'
    WHEN try_cast(l.o.created_at AS TIMESTAMP) IS NULL      THEN 'date invalide'
    WHEN p.sku IS NULL                                      THEN 'produit inconnu'
    WHEN l.item.qty IS NULL OR l.item.qty <= 0              THEN 'quantité invalide'
    WHEN l.item.unit_price IS NULL OR l.item.unit_price < 0 THEN 'prix invalide'
    WHEN coalesce(l.item.discount_pct, 0) NOT BETWEEN 0 AND 100 THEN 'remise invalide'
  END                                                       AS motif_rejet
FROM lignes l
LEFT JOIN silver.produit p ON p.sku = upper(trim(l.item.sku));

-- =====================================================================
-- 3. CHARGEMENT
-- =====================================================================

-- 3.1 Référentiels (avant les ventes, qui les utilisent pour la validation)
MERGE INTO silver.client AS t
USING (
  SELECT client_id, nom_complet, email, telephone, ville, code_postal, segment, date_creation, date_maj,
         current_timestamp() AS _charge_ts
  FROM silver.v_client_prepare
  WHERE motif_rejet IS NULL
) AS s
ON t.client_id = s.client_id
WHEN MATCHED AND t.date_maj < s.date_maj THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

MERGE INTO silver.produit AS t
USING (
  SELECT sku, libelle, categorie, marque, prix_catalogue, cout_achat, actif, date_maj,
         current_timestamp() AS _charge_ts
  FROM silver.v_produit_prepare
) AS s
ON t.sku = s.sku
WHEN MATCHED AND t.date_maj < s.date_maj THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

MERGE INTO silver.magasin AS t
USING (
  SELECT code_magasin, nom, ville, region, surface_m2, date_ouverture, date_maj,
         current_timestamp() AS _charge_ts
  FROM silver.v_magasin_prepare
) AS s
ON t.code_magasin = s.code_magasin
WHEN MATCHED AND t.date_maj < s.date_maj THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- 3.2 Ventes des 3 canaux → table unifiée
MERGE INTO silver.vente_ligne AS t
USING (
  SELECT
    canal, vente_id, ligne_num, horodatage_vente,
    CAST(horodatage_vente AS DATE)                                                AS date_vente,
    client_id, sku, code_magasin, quantite, prix_unitaire, remise_pct,
    CAST(quantite * prix_unitaire AS DECIMAL(12,2))                               AS montant_brut,
    CAST(quantite * prix_unitaire * (1 - remise_pct / 100) AS DECIMAL(12,2))      AS montant_net,
    statut, source_fichier,
    current_timestamp()                                                           AS _charge_ts
  FROM (
    SELECT * FROM silver.v_vente_erp
    UNION ALL
    SELECT * FROM silver.v_vente_magasin
    UNION ALL
    SELECT * FROM silver.v_vente_web
  )
  WHERE motif_rejet IS NULL
) AS s
ON t.canal = s.canal AND t.vente_id = s.vente_id AND t.ligne_num = s.ligne_num
WHEN MATCHED AND NOT (    t.statut        <=> s.statut
                      AND t.client_id     <=> s.client_id
                      AND t.quantite      <=> s.quantite
                      AND t.prix_unitaire <=> s.prix_unitaire
                      AND t.remise_pct    <=> s.remise_pct
                      AND t.horodatage_vente <=> s.horodatage_vente)
  THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- =====================================================================
-- 4. QUARANTAINE ET RAPPORT QUALITÉ
-- =====================================================================
DELETE FROM silver.rejets;

INSERT INTO silver.rejets
SELECT 'CLIENT', CAST(client_id AS STRING), motif_rejet, 'source_erp.clients', current_timestamp()
FROM silver.v_client_prepare
WHERE motif_rejet IS NOT NULL;

INSERT INTO silver.rejets
SELECT canal, cle_rejet, motif_rejet, source_fichier, current_timestamp()
FROM (
  SELECT * FROM silver.v_vente_erp
  UNION ALL
  SELECT * FROM silver.v_vente_magasin
  UNION ALL
  SELECT * FROM silver.v_vente_web
)
WHERE motif_rejet IS NOT NULL;

-- Rejets par source et motif
SELECT source, motif, count(*) AS nb_rejets
FROM silver.rejets
GROUP BY ALL
ORDER BY source, motif;

-- Lignes de vente par canal et statut
SELECT canal, statut, count(*) AS lignes, sum(montant_net) AS ca_net
FROM silver.vente_ligne
GROUP BY ALL
ORDER BY canal, statut;

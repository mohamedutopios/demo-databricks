-- =====================================================================
-- 06_controles.sql — Contrôle de bout en bout avec valeurs attendues
-- À exécuter après 05 (lot 1), puis à nouveau après le lot 2 (07 + fichiers + 02 → 05).
-- Colonne "resultat" : OK (lot 1), OK (lot 2) ou ÉCART.
-- Généré par generateur/generer_donnees.py — ne pas modifier à la main
-- =====================================================================

USE CATALOG projet_medaillon;

WITH controles AS (
  SELECT  1 AS num, 'bronze.erp_clients : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.erp_clients) AS DECIMAL(18,2)) AS obtenu,
         CAST(300 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(303 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  2 AS num, 'bronze.erp_produits : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.erp_produits) AS DECIMAL(18,2)) AS obtenu,
         CAST(60 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(60 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  3 AS num, 'bronze.erp_magasins : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.erp_magasins) AS DECIMAL(18,2)) AS obtenu,
         CAST(8 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(8 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  4 AS num, 'bronze.erp_commandes : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.erp_commandes) AS DECIMAL(18,2)) AS obtenu,
         CAST(210 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(229 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  5 AS num, 'bronze.erp_lignes_commande : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.erp_lignes_commande) AS DECIMAL(18,2)) AS obtenu,
         CAST(527 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(574 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  6 AS num, 'bronze.magasins_ventes_brut : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.magasins_ventes_brut) AS DECIMAL(18,2)) AS obtenu,
         CAST(13540 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(14493 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  7 AS num, 'bronze.web_commandes_brut : lignes' AS controle,
         CAST((SELECT count(*) FROM bronze.web_commandes_brut) AS DECIMAL(18,2)) AS obtenu,
         CAST(962 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1037 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  8 AS num, 'bronze : fichiers CSV ingérés' AS controle,
         CAST((SELECT count(DISTINCT _fichier) FROM bronze.magasins_ventes_brut) AS DECIMAL(18,2)) AS obtenu,
         CAST(29 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(31 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT  9 AS num, 'bronze : fichiers JSON ingérés' AS controle,
         CAST((SELECT count(DISTINCT _fichier) FROM bronze.web_commandes_brut) AS DECIMAL(18,2)) AS obtenu,
         CAST(28 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(30 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 10 AS num, 'silver.vente_ligne ERP : lignes' AS controle,
         CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'ERP') AS DECIMAL(18,2)) AS obtenu,
         CAST(527 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(574 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 11 AS num, 'silver.vente_ligne MAGASIN : lignes' AS controle,
         CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu,
         CAST(13533 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(14486 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 12 AS num, 'silver.vente_ligne WEB : lignes' AS controle,
         CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'WEB') AS DECIMAL(18,2)) AS obtenu,
         CAST(1873 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(2027 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 13 AS num, 'silver.rejets MAGASIN / date invalide' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'date invalide') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 14 AS num, 'silver.rejets MAGASIN / magasin inconnu' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'magasin inconnu') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 15 AS num, 'silver.rejets MAGASIN / produit inconnu' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'produit inconnu') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 16 AS num, 'silver.rejets MAGASIN / quantité invalide' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'quantité invalide') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 17 AS num, 'silver.rejets WEB / JSON invalide' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'JSON invalide') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 18 AS num, 'silver.rejets WEB / commande sans article' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'commande sans article') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 19 AS num, 'silver.rejets WEB / quantité invalide' AS controle,
         CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'quantité invalide') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 20 AS num, 'silver.rejets : total' AS controle,
         CAST((SELECT count(*) FROM silver.rejets) AS DECIMAL(18,2)) AS obtenu,
         CAST(7 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(7 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 21 AS num, 'gold.fact_ventes ERP : lignes' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP') AS DECIMAL(18,2)) AS obtenu,
         CAST(508 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(550 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 22 AS num, 'gold.fact_ventes MAGASIN : lignes' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu,
         CAST(13533 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(14486 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 23 AS num, 'gold.fact_ventes WEB : lignes' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB') AS DECIMAL(18,2)) AS obtenu,
         CAST(1762 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1911 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 24 AS num, 'gold.fact_ventes ERP : CA net' AS controle,
         CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'ERP') AS DECIMAL(18,2)) AS obtenu,
         CAST(328816.91 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(355586.43 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 25 AS num, 'gold.fact_ventes MAGASIN : CA net' AS controle,
         CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu,
         CAST(1746832.98 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1874110.21 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 26 AS num, 'gold.fact_ventes WEB : CA net' AS controle,
         CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'WEB') AS DECIMAL(18,2)) AS obtenu,
         CAST(176215.51 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(190999.99 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 27 AS num, 'gold.fact_ventes : CA net total' AS controle,
         CAST((SELECT sum(montant_net) FROM gold.fact_ventes) AS DECIMAL(18,2)) AS obtenu,
         CAST(2251865.40 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(2420696.63 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 28 AS num, 'gold.fact_ventes ERP : lignes client inconnu (-1)' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu,
         CAST(0 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(0 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 29 AS num, 'gold.fact_ventes MAGASIN : lignes client inconnu (-1)' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu,
         CAST(7961 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(8520 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 30 AS num, 'gold.fact_ventes WEB : lignes client inconnu (-1)' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu,
         CAST(204 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(212 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 31 AS num, 'gold.dim_client : lignes (versions + membre inconnu)' AS controle,
         CAST((SELECT count(*) FROM gold.dim_client) AS DECIMAL(18,2)) AS obtenu,
         CAST(301 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(304 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 32 AS num, 'gold.dim_client : versions courantes hors inconnu' AS controle,
         CAST((SELECT count(*) FROM gold.dim_client WHERE est_courant AND client_sk <> -1) AS DECIMAL(18,2)) AS obtenu,
         CAST(300 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(301 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 33 AS num, 'gold.dim_client : versions du client 12' AS controle,
         CAST((SELECT count(*) FROM gold.dim_client WHERE client_id = 12) AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(2 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 34 AS num, 'gold.fact_ventes : lignes de la commande ERP 100131 (annulée au lot 2)' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP' AND vente_id = '100131') AS DECIMAL(18,2)) AS obtenu,
         CAST(1 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(0 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 35 AS num, 'gold.fact_ventes : lignes de la commande WEB-20260910-0004 (annulée au lot 2)' AS controle,
         CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB' AND vente_id = 'WEB-20260910-0004') AS DECIMAL(18,2)) AS obtenu,
         CAST(3 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(0 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 36 AS num, 'gold.agg_ca_journalier : CA net total' AS controle,
         CAST((SELECT sum(ca_net) FROM gold.agg_ca_journalier) AS DECIMAL(18,2)) AS obtenu,
         CAST(2251865.40 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(2420696.63 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 37 AS num, 'gold.agg_produit_mensuel : CA net total' AS controle,
         CAST((SELECT sum(ca_net) FROM gold.agg_produit_mensuel) AS DECIMAL(18,2)) AS obtenu,
         CAST(2251865.40 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(2420696.63 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 38 AS num, 'gold.agg_magasin_mensuel : CA net total' AS controle,
         CAST((SELECT sum(ca_net) FROM gold.agg_magasin_mensuel) AS DECIMAL(18,2)) AS obtenu,
         CAST(1746832.98 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(1874110.21 AS DECIMAL(18,2)) AS attendu_lot2
  UNION ALL
  SELECT 39 AS num, 'gold.client_360 : lignes' AS controle,
         CAST((SELECT count(*) FROM gold.client_360) AS DECIMAL(18,2)) AS obtenu,
         CAST(300 AS DECIMAL(18,2)) AS attendu_lot1,
         CAST(301 AS DECIMAL(18,2)) AS attendu_lot2
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
  SELECT CAST((SELECT count(*) FROM bronze.erp_clients) AS DECIMAL(18,2)) AS obtenu, CAST(300 AS DECIMAL(18,2)) AS a1, CAST(303 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.erp_produits) AS DECIMAL(18,2)) AS obtenu, CAST(60 AS DECIMAL(18,2)) AS a1, CAST(60 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.erp_magasins) AS DECIMAL(18,2)) AS obtenu, CAST(8 AS DECIMAL(18,2)) AS a1, CAST(8 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.erp_commandes) AS DECIMAL(18,2)) AS obtenu, CAST(210 AS DECIMAL(18,2)) AS a1, CAST(229 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.erp_lignes_commande) AS DECIMAL(18,2)) AS obtenu, CAST(527 AS DECIMAL(18,2)) AS a1, CAST(574 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.magasins_ventes_brut) AS DECIMAL(18,2)) AS obtenu, CAST(13540 AS DECIMAL(18,2)) AS a1, CAST(14493 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM bronze.web_commandes_brut) AS DECIMAL(18,2)) AS obtenu, CAST(962 AS DECIMAL(18,2)) AS a1, CAST(1037 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(DISTINCT _fichier) FROM bronze.magasins_ventes_brut) AS DECIMAL(18,2)) AS obtenu, CAST(29 AS DECIMAL(18,2)) AS a1, CAST(31 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(DISTINCT _fichier) FROM bronze.web_commandes_brut) AS DECIMAL(18,2)) AS obtenu, CAST(28 AS DECIMAL(18,2)) AS a1, CAST(30 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'ERP') AS DECIMAL(18,2)) AS obtenu, CAST(527 AS DECIMAL(18,2)) AS a1, CAST(574 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu, CAST(13533 AS DECIMAL(18,2)) AS a1, CAST(14486 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.vente_ligne WHERE canal = 'WEB') AS DECIMAL(18,2)) AS obtenu, CAST(1873 AS DECIMAL(18,2)) AS a1, CAST(2027 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'date invalide') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'magasin inconnu') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'produit inconnu') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'MAGASIN' AND motif = 'quantité invalide') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'JSON invalide') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'commande sans article') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets WHERE source = 'WEB' AND motif = 'quantité invalide') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(1 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM silver.rejets) AS DECIMAL(18,2)) AS obtenu, CAST(7 AS DECIMAL(18,2)) AS a1, CAST(7 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP') AS DECIMAL(18,2)) AS obtenu, CAST(508 AS DECIMAL(18,2)) AS a1, CAST(550 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu, CAST(13533 AS DECIMAL(18,2)) AS a1, CAST(14486 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB') AS DECIMAL(18,2)) AS obtenu, CAST(1762 AS DECIMAL(18,2)) AS a1, CAST(1911 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'ERP') AS DECIMAL(18,2)) AS obtenu, CAST(328816.91 AS DECIMAL(18,2)) AS a1, CAST(355586.43 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN') AS DECIMAL(18,2)) AS obtenu, CAST(1746832.98 AS DECIMAL(18,2)) AS a1, CAST(1874110.21 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(montant_net) FROM gold.fact_ventes WHERE canal_code = 'WEB') AS DECIMAL(18,2)) AS obtenu, CAST(176215.51 AS DECIMAL(18,2)) AS a1, CAST(190999.99 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(montant_net) FROM gold.fact_ventes) AS DECIMAL(18,2)) AS obtenu, CAST(2251865.40 AS DECIMAL(18,2)) AS a1, CAST(2420696.63 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu, CAST(0 AS DECIMAL(18,2)) AS a1, CAST(0 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'MAGASIN' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu, CAST(7961 AS DECIMAL(18,2)) AS a1, CAST(8520 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB' AND client_sk = -1) AS DECIMAL(18,2)) AS obtenu, CAST(204 AS DECIMAL(18,2)) AS a1, CAST(212 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.dim_client) AS DECIMAL(18,2)) AS obtenu, CAST(301 AS DECIMAL(18,2)) AS a1, CAST(304 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.dim_client WHERE est_courant AND client_sk <> -1) AS DECIMAL(18,2)) AS obtenu, CAST(300 AS DECIMAL(18,2)) AS a1, CAST(301 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.dim_client WHERE client_id = 12) AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(2 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'ERP' AND vente_id = '100131') AS DECIMAL(18,2)) AS obtenu, CAST(1 AS DECIMAL(18,2)) AS a1, CAST(0 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.fact_ventes WHERE canal_code = 'WEB' AND vente_id = 'WEB-20260910-0004') AS DECIMAL(18,2)) AS obtenu, CAST(3 AS DECIMAL(18,2)) AS a1, CAST(0 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(ca_net) FROM gold.agg_ca_journalier) AS DECIMAL(18,2)) AS obtenu, CAST(2251865.40 AS DECIMAL(18,2)) AS a1, CAST(2420696.63 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(ca_net) FROM gold.agg_produit_mensuel) AS DECIMAL(18,2)) AS obtenu, CAST(2251865.40 AS DECIMAL(18,2)) AS a1, CAST(2420696.63 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT sum(ca_net) FROM gold.agg_magasin_mensuel) AS DECIMAL(18,2)) AS obtenu, CAST(1746832.98 AS DECIMAL(18,2)) AS a1, CAST(1874110.21 AS DECIMAL(18,2)) AS a2
  UNION ALL
  SELECT CAST((SELECT count(*) FROM gold.client_360) AS DECIMAL(18,2)) AS obtenu, CAST(300 AS DECIMAL(18,2)) AS a1, CAST(301 AS DECIMAL(18,2)) AS a2
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

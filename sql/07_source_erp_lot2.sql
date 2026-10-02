-- =====================================================================
-- 07_source_erp_lot2.sql — Évolutions de la base ERP au 30/09/2026
--   * client 12 : déménage à Bordeaux et passe Premium      (→ SCD2)
--   * client 45 : passe Professionnel                       (→ SCD2)
--   * client 301 : créé dans l'ERP (déjà vu sur le web)     (→ client tardif)
--   * commande 100131 : annulée                     (→ suppression du fait)
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
WHERE commande_id = 100131;

INSERT INTO source_erp.clients (client_id, prenom, nom, email, telephone, ville, code_postal, segment, date_creation, date_maj) VALUES
  (301, 'Inès', 'Garcia', 'ines.garcia301@example.com', '0611223344', 'Nantes', '44000', 'Particulier', DATE'2026-09-16', TIMESTAMP'2026-09-29 10:00:00');

INSERT INTO source_erp.commandes (commande_id, client_id, date_commande, statut, canal_commercial, date_maj) VALUES
  (100211, 68, TIMESTAMP'2026-09-29 14:56:33', 'LIVREE', 'Commercial terrain', TIMESTAMP'2026-09-29 14:56:33'),
  (100212, 265, TIMESTAMP'2026-09-29 12:16:58', 'LIVREE', 'Téléphone', TIMESTAMP'2026-09-29 12:16:58'),
  (100213, 22, TIMESTAMP'2026-09-29 14:33:52', 'LIVREE', 'Salon pro', TIMESTAMP'2026-09-29 14:33:52'),
  (100214, 178, TIMESTAMP'2026-09-29 11:33:04', 'LIVREE', 'Salon pro', TIMESTAMP'2026-09-29 11:33:04'),
  (100215, 27, TIMESTAMP'2026-09-29 12:59:10', 'LIVREE', 'Commercial terrain', TIMESTAMP'2026-09-29 12:59:10'),
  (100216, 142, TIMESTAMP'2026-09-29 11:34:09', 'LIVREE', 'Commercial terrain', TIMESTAMP'2026-09-29 11:34:09'),
  (100217, 16, TIMESTAMP'2026-09-29 12:58:39', 'LIVREE', 'Salon pro', TIMESTAMP'2026-09-29 12:58:39'),
  (100218, 118, TIMESTAMP'2026-09-29 16:46:22', 'VALIDEE', 'Téléphone', TIMESTAMP'2026-09-29 16:46:22'),
  (100219, 64, TIMESTAMP'2026-09-29 18:32:10', 'LIVREE', 'Salon pro', TIMESTAMP'2026-09-29 18:32:10'),
  (100220, 136, TIMESTAMP'2026-09-29 10:33:02', 'VALIDEE', 'Commercial terrain', TIMESTAMP'2026-09-29 10:33:02'),
  (100221, 118, TIMESTAMP'2026-09-30 14:58:07', 'VALIDEE', 'Téléphone', TIMESTAMP'2026-09-30 14:58:07'),
  (100222, 73, TIMESTAMP'2026-09-30 09:36:25', 'LIVREE', 'Téléphone', TIMESTAMP'2026-09-30 09:36:25'),
  (100223, 19, TIMESTAMP'2026-09-30 15:20:14', 'LIVREE', 'Salon pro', TIMESTAMP'2026-09-30 15:20:14'),
  (100224, 65, TIMESTAMP'2026-09-30 09:40:41', 'VALIDEE', 'Téléphone', TIMESTAMP'2026-09-30 09:40:41'),
  (100225, 21, TIMESTAMP'2026-09-30 10:46:04', 'LIVREE', 'Commercial terrain', TIMESTAMP'2026-09-30 10:46:04'),
  (100226, 15, TIMESTAMP'2026-09-30 16:24:20', 'ANNULEE', 'Commercial terrain', TIMESTAMP'2026-09-30 16:24:20'),
  (100227, 12, TIMESTAMP'2026-09-30 14:56:17', 'VALIDEE', 'Commercial terrain', TIMESTAMP'2026-09-30 14:56:17'),
  (100228, 301, TIMESTAMP'2026-09-30 13:03:18', 'VALIDEE', 'Commercial terrain', TIMESTAMP'2026-09-30 13:03:18');

INSERT INTO source_erp.lignes_commande (commande_id, ligne_num, sku, quantite, prix_unitaire, remise_pct, date_maj) VALUES
  (100211, 1, 'SKU-0013', 20, 29.90, 5, TIMESTAMP'2026-09-29 14:56:33'),
  (100211, 2, 'SKU-0002', 4, 89.90, 10, TIMESTAMP'2026-09-29 14:56:33'),
  (100212, 1, 'SKU-0017', 9, 149.90, 0, TIMESTAMP'2026-09-29 12:16:58'),
  (100213, 1, 'SKU-0045', 8, 9.99, 10, TIMESTAMP'2026-09-29 14:33:52'),
  (100213, 2, 'SKU-0047', 6, 24.99, 15, TIMESTAMP'2026-09-29 14:33:52'),
  (100213, 3, 'SKU-0011', 8, 79.99, 15, TIMESTAMP'2026-09-29 14:33:52'),
  (100214, 1, 'SKU-0011', 10, 79.99, 15, TIMESTAMP'2026-09-29 11:33:04'),
  (100214, 2, 'SKU-0002', 8, 89.90, 10, TIMESTAMP'2026-09-29 11:33:04'),
  (100214, 3, 'SKU-0037', 18, 29.90, 10, TIMESTAMP'2026-09-29 11:33:04'),
  (100214, 4, 'SKU-0036', 2, 49.90, 10, TIMESTAMP'2026-09-29 11:33:04'),
  (100215, 1, 'SKU-0016', 10, 49.90, 0, TIMESTAMP'2026-09-29 12:59:10'),
  (100215, 2, 'SKU-0017', 6, 149.90, 5, TIMESTAMP'2026-09-29 12:59:10'),
  (100215, 3, 'SKU-0031', 1, 69.90, 5, TIMESTAMP'2026-09-29 12:59:10'),
  (100215, 4, 'SKU-0043', 13, 12.90, 0, TIMESTAMP'2026-09-29 12:59:10'),
  (100216, 1, 'SKU-0027', 16, 39.90, 0, TIMESTAMP'2026-09-29 11:34:09'),
  (100216, 2, 'SKU-0036', 10, 49.90, 10, TIMESTAMP'2026-09-29 11:34:09'),
  (100216, 3, 'SKU-0021', 19, 149.90, 10, TIMESTAMP'2026-09-29 11:34:09'),
  (100216, 4, 'SKU-0023', 13, 34.99, 15, TIMESTAMP'2026-09-29 11:34:09'),
  (100217, 1, 'SKU-0009', 14, 12.90, 10, TIMESTAMP'2026-09-29 12:58:39'),
  (100217, 2, 'SKU-0010', 12, 59.99, 10, TIMESTAMP'2026-09-29 12:58:39'),
  (100218, 1, 'SKU-0009', 9, 12.90, 0, TIMESTAMP'2026-09-29 16:46:22'),
  (100219, 1, 'SKU-0002', 20, 89.90, 5, TIMESTAMP'2026-09-29 18:32:10'),
  (100220, 1, 'SKU-0009', 9, 12.90, 10, TIMESTAMP'2026-09-29 10:33:02'),
  (100220, 2, 'SKU-0032', 19, 59.99, 5, TIMESTAMP'2026-09-29 10:33:02'),
  (100220, 3, 'SKU-0037', 7, 29.90, 15, TIMESTAMP'2026-09-29 10:33:02'),
  (100221, 1, 'SKU-0003', 4, 7.90, 0, TIMESTAMP'2026-09-30 14:58:07'),
  (100222, 1, 'SKU-0016', 5, 49.90, 15, TIMESTAMP'2026-09-30 09:36:25'),
  (100222, 2, 'SKU-0050', 6, 119.00, 5, TIMESTAMP'2026-09-30 09:36:25'),
  (100222, 3, 'SKU-0048', 4, 79.99, 15, TIMESTAMP'2026-09-30 09:36:25'),
  (100223, 1, 'SKU-0038', 17, 89.90, 15, TIMESTAMP'2026-09-30 15:20:14'),
  (100223, 2, 'SKU-0013', 16, 29.90, 0, TIMESTAMP'2026-09-30 15:20:14'),
  (100223, 3, 'SKU-0031', 4, 69.90, 5, TIMESTAMP'2026-09-30 15:20:14'),
  (100224, 1, 'SKU-0033', 5, 39.90, 0, TIMESTAMP'2026-09-30 09:40:41'),
  (100224, 2, 'SKU-0041', 8, 49.90, 15, TIMESTAMP'2026-09-30 09:40:41'),
  (100225, 1, 'SKU-0059', 20, 149.90, 0, TIMESTAMP'2026-09-30 10:46:04'),
  (100225, 2, 'SKU-0029', 5, 119.00, 0, TIMESTAMP'2026-09-30 10:46:04'),
  (100225, 3, 'SKU-0010', 8, 59.99, 5, TIMESTAMP'2026-09-30 10:46:04'),
  (100226, 1, 'SKU-0059', 11, 149.90, 0, TIMESTAMP'2026-09-30 16:24:20'),
  (100226, 2, 'SKU-0017', 13, 149.90, 5, TIMESTAMP'2026-09-30 16:24:20'),
  (100226, 3, 'SKU-0025', 13, 49.90, 5, TIMESTAMP'2026-09-30 16:24:20'),
  (100226, 4, 'SKU-0010', 19, 59.99, 5, TIMESTAMP'2026-09-30 16:24:20'),
  (100227, 1, 'SKU-0037', 13, 29.90, 10, TIMESTAMP'2026-09-30 14:56:17'),
  (100227, 2, 'SKU-0035', 20, 69.90, 0, TIMESTAMP'2026-09-30 14:56:17'),
  (100227, 3, 'SKU-0028', 5, 89.90, 10, TIMESTAMP'2026-09-30 14:56:17'),
  (100228, 1, 'SKU-0004', 18, 149.90, 15, TIMESTAMP'2026-09-30 13:03:18'),
  (100228, 2, 'SKU-0027', 3, 39.90, 15, TIMESTAMP'2026-09-30 13:03:18'),
  (100228, 3, 'SKU-0034', 3, 69.90, 0, TIMESTAMP'2026-09-30 13:03:18');

-- Contrôle
SELECT client_id, ville, segment, date_maj FROM source_erp.clients WHERE client_id IN (12, 45, 301) ORDER BY client_id;
SELECT count(*) AS commandes_depuis_le_29 FROM source_erp.commandes WHERE date_maj >= TIMESTAMP'2026-09-29 00:00:00';

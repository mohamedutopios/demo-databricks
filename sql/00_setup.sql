-- =====================================================================
-- 00_setup.sql — Projet médaillon v1.2 : catalogue, schémas, volume
-- Prérequis : SQL Editor ouvert, SQL Warehouse démarré et sélectionné
-- Ré-exécutable : oui
-- =====================================================================

CREATE CATALOG IF NOT EXISTS projet_medaillon
  COMMENT 'Projet médaillon : ERP (SQL) + magasins (CSV) + web (JSON) → bronze → silver → gold → API';

USE CATALOG projet_medaillon;

CREATE SCHEMA IF NOT EXISTS source_erp COMMENT 'Simulation de la base opérationnelle ERP (source SQL)';
CREATE SCHEMA IF NOT EXISTS bronze     COMMENT 'Données brutes, append-only, traçabilité d''ingestion';
CREATE SCHEMA IF NOT EXISTS silver     COMMENT 'Données nettoyées, typées, dédoublonnées et conformées';
CREATE SCHEMA IF NOT EXISTS gold       COMMENT 'Modèle en étoile et tables de service pour l''API';

-- Zone de dépôt des fichiers CSV et JSON
CREATE VOLUME IF NOT EXISTS bronze.landing
  COMMENT 'Dépôt des fichiers sources : magasins/ (CSV) et web/ (JSON)';

-- Vérifications
SELECT current_catalog() AS catalogue, current_user() AS utilisateur;
SHOW SCHEMAS IN projet_medaillon;
SHOW VOLUMES IN projet_medaillon.bronze;

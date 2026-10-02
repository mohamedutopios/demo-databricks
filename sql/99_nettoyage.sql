-- =====================================================================
-- 99_nettoyage.sql — Suppression complète du projet
-- =====================================================================

USE CATALOG projet_medaillon;

DROP SCHEMA IF EXISTS gold       CASCADE;
DROP SCHEMA IF EXISTS silver     CASCADE;
DROP SCHEMA IF EXISTS bronze     CASCADE;   -- supprime aussi le volume landing et ses fichiers
DROP SCHEMA IF EXISTS source_erp CASCADE;

-- Uniquement si le catalogue projet_medaillon a été créé pour ce projet
-- (ne jamais exécuter sur le catalogue "workspace")
-- DROP CATALOG IF EXISTS projet_medaillon CASCADE;

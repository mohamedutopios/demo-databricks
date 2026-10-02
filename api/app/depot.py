"""Accès en lecture aux tables de service de la couche gold (Databricks SQL Warehouse)."""
from __future__ import annotations

import datetime as dt
import threading
from typing import Any, Protocol

from cachetools import TTLCache
from databricks import sql
from databricks.sdk.core import Config, oauth_service_principal

from app.config import Parametres, parametres

TRIS_CLIENTS = {
    "ca_total": "ca_total DESC",
    "nb_ventes": "nb_ventes DESC",
    "recence_jours": "recence_jours ASC NULLS LAST",
}


class DepotGold(Protocol):
    def verifier(self) -> None: ...
    def ca_journalier(self, date_debut: dt.date, date_fin: dt.date, canal: str | None) -> list[dict]: ...
    def repartition_canaux(self, date_debut: dt.date, date_fin: dt.date) -> list[dict]: ...
    def top_produits(self, mois: dt.date, categorie: str | None, limite: int) -> list[dict]: ...
    def magasins(self, mois: dt.date) -> list[dict]: ...
    def client(self, client_id: int) -> dict | None: ...
    def clients(self, segment: str | None, tri: str, limite: int) -> list[dict]: ...


class DepotDatabricks:
    """Une connexion par requête (les connexions DB-API ne se partagent pas entre threads)
    et un cache mémoire à durée de vie limitée pour éviter de solliciter le warehouse à chaque appel."""

    def __init__(self, p: Parametres | None = None):
        self._p_initial = p
        self._p_charge: Parametres | None = None
        self._cache: TTLCache | None = None
        self._verrou = threading.Lock()

    @property
    def _p(self) -> Parametres:
        """Configuration chargée au premier accès à l'entrepôt (pas à la création de l'API)."""
        if self._p_charge is None:
            self._p_charge = self._p_initial or parametres()
            if self._p_charge.cache_ttl_secondes > 0:
                self._cache = TTLCache(maxsize=512, ttl=self._p_charge.cache_ttl_secondes)
        return self._p_charge

    def _connexion(self):
        p = self._p
        options = dict(server_hostname=p.databricks_server_hostname, http_path=p.databricks_http_path,
                       catalog=p.databricks_catalog, schema=p.databricks_schema)
        if p.mode_authentification == "token":
            options["access_token"] = p.databricks_token
        else:
            options["credentials_provider"] = self._fournisseur_oauth
        return sql.connect(**options)

    def _fournisseur_oauth(self):
        """OAuth machine-à-machine d'un service principal (secret généré dans l'interface Databricks)."""
        p = self._p
        return oauth_service_principal(Config(host=f"https://{p.databricks_server_hostname}",
                                              client_id=p.databricks_client_id,
                                              client_secret=p.databricks_client_secret))

    def _executer(self, requete: str, params: dict[str, Any] | None = None, cache: bool = True) -> list[dict]:
        params = params or {}
        _ = self._p
        cle = (requete, tuple(sorted(params.items())))
        if cache and self._cache is not None:
            with self._verrou:
                if cle in self._cache:
                    return self._cache[cle]
        with self._connexion() as connexion, connexion.cursor() as curseur:
            curseur.execute(requete, params)
            colonnes = [c[0] for c in curseur.description]
            lignes = [dict(zip(colonnes, ligne)) for ligne in curseur.fetchall()]
        if cache and self._cache is not None:
            with self._verrou:
                self._cache[cle] = lignes
        return lignes

    def verifier(self) -> None:
        self._executer("SELECT count(*) AS n FROM agg_ca_journalier", cache=False)

    def ca_journalier(self, date_debut, date_fin, canal):
        requete = (
            "SELECT date_vente, canal_code, canal_libelle, nb_ventes, nb_lignes, quantite, ca_net, marge "
            "FROM agg_ca_journalier "
            "WHERE date_vente BETWEEN :date_debut AND :date_fin"
        )
        params: dict[str, Any] = {"date_debut": date_debut, "date_fin": date_fin}
        if canal:
            requete += " AND canal_code = :canal"
            params["canal"] = canal
        requete += " ORDER BY date_vente, canal_code"
        return self._executer(requete, params)

    def repartition_canaux(self, date_debut, date_fin):
        requete = (
            "SELECT canal_code, canal_libelle, sum(nb_ventes) AS nb_ventes, sum(ca_net) AS ca_net, sum(marge) AS marge, "
            "round(100 * sum(ca_net) / sum(sum(ca_net)) OVER (), 2) AS part_ca_pct "
            "FROM agg_ca_journalier "
            "WHERE date_vente BETWEEN :date_debut AND :date_fin "
            "GROUP BY canal_code, canal_libelle "
            "ORDER BY ca_net DESC"
        )
        return self._executer(requete, {"date_debut": date_debut, "date_fin": date_fin})

    def top_produits(self, mois, categorie, limite):
        requete = (
            "SELECT mois, sku, libelle, categorie, marque, quantite, ca_net, marge, taux_marge_pct, rang_dans_categorie "
            "FROM agg_produit_mensuel WHERE mois = :mois"
        )
        params: dict[str, Any] = {"mois": mois}
        if categorie:
            requete += " AND categorie = :categorie"
            params["categorie"] = categorie
        requete += f" ORDER BY ca_net DESC, sku LIMIT {int(limite)}"
        return self._executer(requete, params)

    def magasins(self, mois):
        requete = (
            "SELECT mois, code_magasin, nom, ville, region, nb_tickets, nb_articles, ca_net, marge, panier_moyen, rang_ca "
            "FROM agg_magasin_mensuel WHERE mois = :mois ORDER BY rang_ca, code_magasin"
        )
        return self._executer(requete, {"mois": mois})

    def client(self, client_id):
        lignes = self._executer(
            "SELECT client_id, nom_complet, email, ville, segment, nb_ventes, ca_total, panier_moyen, "
            "premiere_vente, derniere_vente, recence_jours, canal_prefere, categorie_preferee "
            "FROM client_360 WHERE client_id = :client_id",
            {"client_id": client_id},
        )
        return lignes[0] if lignes else None

    def clients(self, segment, tri, limite):
        if tri not in TRIS_CLIENTS:
            raise ValueError(f"Tri non autorisé : {tri}")
        requete = (
            "SELECT client_id, nom_complet, email, ville, segment, nb_ventes, ca_total, panier_moyen, "
            "premiere_vente, derniere_vente, recence_jours, canal_prefere, categorie_preferee "
            "FROM client_360 WHERE nb_ventes > 0"
        )
        params: dict[str, Any] = {}
        if segment:
            requete += " AND segment = :segment"
            params["segment"] = segment
        requete += f" ORDER BY {TRIS_CLIENTS[tri]}, client_id LIMIT {int(limite)}"
        return self._executer(requete, params)

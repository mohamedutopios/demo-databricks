"""Tests de l'API sans Databricks : dépôt simulé pour les routes, curseur simulé pour le SQL généré."""
import datetime as dt
from decimal import Decimal

import pytest
from databricks.sql.exc import Error as ErreurDatabricks
from fastapi.testclient import TestClient

from app import depot as module_depot
from app.config import Parametres
from app.depot import DepotDatabricks
from app.main import app, get_depot

CLIENT_12 = {
    "client_id": 12, "nom_complet": "Lucas DURAND", "email": "lucas.durand12@example.com", "ville": "Bordeaux",
    "segment": "Premium", "nb_ventes": 9, "ca_total": Decimal("4210.55"), "panier_moyen": Decimal("467.84"),
    "premiere_vente": dt.date(2026, 9, 2), "derniere_vente": dt.date(2026, 9, 30), "recence_jours": 1,
    "canal_prefere": "ERP", "categorie_preferee": "Vélo",
}


class DepotFactice:
    def __init__(self, panne=False):
        self.panne = panne
        self.appels = []

    def verifier(self):
        if self.panne:
            raise ErreurDatabricks("warehouse arrêté")

    def ca_journalier(self, date_debut, date_fin, canal):
        self.appels.append(("ca_journalier", date_debut, date_fin, canal))
        return [{"date_vente": dt.date(2026, 9, 1), "canal_code": "WEB", "canal_libelle": "Site e-commerce",
                 "nb_ventes": 30, "nb_lignes": 61, "quantite": 90, "ca_net": Decimal("6123.40"), "marge": Decimal("2510.12")}]

    def repartition_canaux(self, date_debut, date_fin):
        return [{"canal_code": "MAGASIN", "canal_libelle": "Magasins physiques", "nb_ventes": 5000,
                 "ca_net": Decimal("1874110.21"), "marge": Decimal("800000.00"), "part_ca_pct": Decimal("77.42")}]

    def top_produits(self, mois, categorie, limite):
        self.appels.append(("top_produits", mois, categorie, limite))
        return [{"mois": mois, "sku": "SKU-0001", "libelle": "Chaussures trail Essentiel", "categorie": "Running",
                 "marque": "Altura", "quantite": 120, "ca_net": Decimal("5988.00"), "marge": Decimal("2500.00"),
                 "taux_marge_pct": Decimal("41.75"), "rang_dans_categorie": 1}]

    def magasins(self, mois):
        return [{"mois": mois, "code_magasin": "MAG01", "nom": "Sport Hub Lille", "ville": "Lille",
                 "region": "Hauts-de-France", "nb_tickets": 700, "nb_articles": 2600, "ca_net": Decimal("230000.00"),
                 "marge": Decimal("95000.00"), "panier_moyen": Decimal("328.57"), "rang_ca": 1}]

    def client(self, client_id):
        return CLIENT_12 if client_id == 12 else None

    def clients(self, segment, tri, limite):
        self.appels.append(("clients", segment, tri, limite))
        return [CLIENT_12]


@pytest.fixture
def depot_factice():
    d = DepotFactice()
    app.dependency_overrides[get_depot] = lambda: d
    yield d
    app.dependency_overrides.clear()


@pytest.fixture
def client_http(depot_factice):
    return TestClient(app)


def test_vivant_sans_entrepot():
    app.dependency_overrides[get_depot] = lambda: DepotFactice(panne=True)
    try:
        r = TestClient(app).get("/vivant")
        assert r.status_code == 200 and r.json() == {"statut": "ok"}
    finally:
        app.dependency_overrides.clear()


def test_sante(client_http):
    r = client_http.get("/sante")
    assert r.status_code == 200 and r.json() == {"statut": "ok", "entrepot": "joignable"}


def test_sante_entrepot_indisponible():
    app.dependency_overrides[get_depot] = lambda: DepotFactice(panne=True)
    try:
        r = TestClient(app).get("/sante")
        assert r.status_code == 503 and "indisponible" in r.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_ca_journalier(client_http, depot_factice):
    r = client_http.get("/api/v1/ca/journalier", params={"date_debut": "2026-09-01", "date_fin": "2026-09-30", "canal": "WEB"})
    assert r.status_code == 200
    assert r.json()[0]["ca_net"] == 6123.4
    assert depot_factice.appels[-1] == ("ca_journalier", dt.date(2026, 9, 1), dt.date(2026, 9, 30), "WEB")


@pytest.mark.parametrize("params", [
    {"date_debut": "2026-09-30", "date_fin": "2026-09-01"},
    {"date_debut": "2025-01-01", "date_fin": "2026-09-01"},
    {"date_debut": "2026-09-01", "date_fin": "2026-09-30", "canal": "FAX"},
    {"date_debut": "01/09/2026", "date_fin": "2026-09-30"},
])
def test_ca_journalier_parametres_invalides(client_http, params):
    assert client_http.get("/api/v1/ca/journalier", params=params).status_code == 422


def test_repartition_canaux(client_http):
    r = client_http.get("/api/v1/ca/canaux", params={"date_debut": "2026-09-01", "date_fin": "2026-09-30"})
    assert r.status_code == 200 and r.json()[0]["part_ca_pct"] == 77.42


def test_top_produits(client_http, depot_factice):
    r = client_http.get("/api/v1/produits/top", params={"mois": "2026-09", "categorie": "Running", "limite": 5})
    assert r.status_code == 200 and r.json()[0]["mois"] == "2026-09-01"
    assert depot_factice.appels[-1] == ("top_produits", dt.date(2026, 9, 1), "Running", 5)


@pytest.mark.parametrize("params", [{"mois": "2026-13"}, {"mois": "202609"}, {"mois": "2026-09", "limite": 0},
                                    {"mois": "2026-09", "limite": 101}])
def test_top_produits_parametres_invalides(client_http, params):
    assert client_http.get("/api/v1/produits/top", params=params).status_code == 422


def test_magasins(client_http):
    r = client_http.get("/api/v1/magasins/performance", params={"mois": "2026-09"})
    assert r.status_code == 200 and r.json()[0]["code_magasin"] == "MAG01"


def test_fiche_client(client_http):
    r = client_http.get("/api/v1/clients/12")
    assert r.status_code == 200 and r.json()["ville"] == "Bordeaux" and r.json()["ca_total"] == 4210.55


def test_fiche_client_absente(client_http):
    assert client_http.get("/api/v1/clients/99999").status_code == 404


def test_liste_clients(client_http, depot_factice):
    r = client_http.get("/api/v1/clients", params={"segment": "Premium", "tri": "recence_jours", "limite": 3})
    assert r.status_code == 200
    assert depot_factice.appels[-1] == ("clients", "Premium", "recence_jours", 3)
    assert client_http.get("/api/v1/clients", params={"tri": "nom"}).status_code == 422


def test_openapi(client_http):
    chemins = client_http.get("/openapi.json").json()["paths"]
    assert {"/vivant", "/sante", "/api/v1/ca/journalier", "/api/v1/ca/canaux", "/api/v1/produits/top",
            "/api/v1/magasins/performance", "/api/v1/clients", "/api/v1/clients/{client_id}"} <= set(chemins)


# ---------------------------------------------------------------------------
# SQL généré par DepotDatabricks (connecteur simulé)
# ---------------------------------------------------------------------------
class CurseurFactice:
    def __init__(self, journal):
        self.journal = journal
        self.description = [("client_id",), ("ca_total",)]

    def execute(self, requete, params):
        self.journal.append((requete, dict(params)))

    def fetchall(self):
        return [(12, Decimal("10.00"))]

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class ConnexionFactice:
    def __init__(self, journal, kwargs):
        self.journal = journal
        journal.append(("connect", kwargs))

    def cursor(self):
        return CurseurFactice(self.journal)

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


@pytest.fixture
def journal(monkeypatch):
    j = []
    monkeypatch.setattr(module_depot.sql, "connect", lambda **kw: ConnexionFactice(j, kw))
    return j


def _parametres(ttl=300):
    return Parametres(databricks_server_hostname="h", databricks_http_path="/p", databricks_token="t",
                      cache_ttl_secondes=ttl, _env_file=None)


def test_depot_connexion_et_parametres(journal):
    d = DepotDatabricks(_parametres())
    d.ca_journalier(dt.date(2026, 9, 1), dt.date(2026, 9, 30), "ERP")
    connect = journal[0][1]
    assert connect["catalog"] == "projet_medaillon" and connect["schema"] == "gold"
    requete, params = journal[1]
    assert "canal_code = :canal" in requete and params == {"date_debut": dt.date(2026, 9, 1),
                                                          "date_fin": dt.date(2026, 9, 30), "canal": "ERP"}


def test_depot_sans_filtre_optionnel(journal):
    d = DepotDatabricks(_parametres())
    d.top_produits(dt.date(2026, 9, 1), None, 7)
    requete, params = journal[1]
    assert ":categorie" not in requete and requete.endswith("LIMIT 7") and params == {"mois": dt.date(2026, 9, 1)}


def test_depot_cache(journal):
    d = DepotDatabricks(_parametres(ttl=300))
    assert d.client(12) == {"client_id": 12, "ca_total": Decimal("10.00")}
    d.client(12)
    assert sum(1 for e in journal if e[0] == "connect") == 1


def test_depot_sans_cache(journal):
    d = DepotDatabricks(_parametres(ttl=0))
    d.client(12)
    d.client(12)
    assert sum(1 for e in journal if e[0] == "connect") == 2


def test_depot_tri_clients(journal):
    d = DepotDatabricks(_parametres())
    d.clients("Premium", "recence_jours", 5)
    requete, params = journal[1]
    assert "ORDER BY recence_jours ASC NULLS LAST, client_id LIMIT 5" in requete and params == {"segment": "Premium"}
    with pytest.raises(ValueError):
        d.clients(None, "nom; DROP TABLE x", 5)


def test_configuration_absente(monkeypatch, tmp_path):
    from app import main as module_main
    for v in ("DATABRICKS_SERVER_HOSTNAME", "DATABRICKS_HTTP_PATH", "DATABRICKS_TOKEN"):
        monkeypatch.delenv(v, raising=False)
    monkeypatch.chdir(tmp_path)
    module_main.parametres.cache_clear()
    module_main._depot.cache_clear()
    r = TestClient(app).get("/sante")
    assert r.status_code == 500 and "DATABRICKS_SERVER_HOSTNAME" in r.json()["detail"]
    module_main.parametres.cache_clear()
    module_main._depot.cache_clear()


def test_configuration_sans_authentification():
    from pydantic import ValidationError
    with pytest.raises(ValidationError, match="DATABRICKS_CLIENT_SECRET"):
        Parametres(databricks_server_hostname="h", databricks_http_path="/p", databricks_token="",
                   databricks_client_id="id", _env_file=None)


def test_depot_service_principal(journal, monkeypatch):
    p = Parametres(databricks_server_hostname="dbc-x.cloud.databricks.com", databricks_http_path="/p",
                   databricks_client_id="id-sp", databricks_client_secret="secret-sp", _env_file=None)
    assert p.mode_authentification == "service_principal"
    vus = {}

    class ConfigFactice:
        def __init__(self, **kw):
            self.__dict__.update(kw)

    monkeypatch.setattr(module_depot, "Config", ConfigFactice)
    monkeypatch.setattr(module_depot, "oauth_service_principal", lambda cfg: vus.setdefault("cfg", cfg) and "fournisseur")
    d = DepotDatabricks(p)
    d.client(12)
    connect = journal[0][1]
    assert "access_token" not in connect and callable(connect["credentials_provider"])
    connect["credentials_provider"]()
    assert vus["cfg"].client_id == "id-sp" and vus["cfg"].host == "https://dbc-x.cloud.databricks.com"

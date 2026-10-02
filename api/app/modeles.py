"""Schémas des réponses de l'API."""
import datetime as dt
from enum import Enum

from pydantic import BaseModel


class Canal(str, Enum):
    ERP = "ERP"
    MAGASIN = "MAGASIN"
    WEB = "WEB"


class Segment(str, Enum):
    Particulier = "Particulier"
    Premium = "Premium"
    Professionnel = "Professionnel"


class TriClients(str, Enum):
    ca_total = "ca_total"
    nb_ventes = "nb_ventes"
    recence_jours = "recence_jours"


class Sante(BaseModel):
    statut: str
    entrepot: str


class CaJournalier(BaseModel):
    date_vente: dt.date
    canal_code: str
    canal_libelle: str | None
    nb_ventes: int
    nb_lignes: int
    quantite: int
    ca_net: float
    marge: float


class RepartitionCanal(BaseModel):
    canal_code: str
    canal_libelle: str | None
    nb_ventes: int
    ca_net: float
    marge: float
    part_ca_pct: float


class ProduitMensuel(BaseModel):
    mois: dt.date
    sku: str
    libelle: str | None
    categorie: str | None
    marque: str | None
    quantite: int
    ca_net: float
    marge: float
    taux_marge_pct: float | None
    rang_dans_categorie: int


class MagasinMensuel(BaseModel):
    mois: dt.date
    code_magasin: str
    nom: str | None
    ville: str | None
    region: str | None
    nb_tickets: int
    nb_articles: int
    ca_net: float
    marge: float
    panier_moyen: float | None
    rang_ca: int


class Client360(BaseModel):
    client_id: int
    nom_complet: str | None
    email: str | None
    ville: str | None
    segment: str | None
    nb_ventes: int
    ca_total: float
    panier_moyen: float | None
    premiere_vente: dt.date | None
    derniere_vente: dt.date | None
    recence_jours: int | None
    canal_prefere: str | None
    categorie_preferee: str | None

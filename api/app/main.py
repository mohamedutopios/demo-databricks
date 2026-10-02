"""API locale exposant les données retraitées de la couche gold."""
import datetime as dt
from functools import lru_cache

from databricks.sql.exc import Error as ErreurDatabricks
from fastapi import Depends, FastAPI, HTTPException, Path, Query, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from app.config import parametres  # noqa: F401  (réinitialisé dans les tests)
from app.depot import DepotDatabricks, DepotGold
from app.modeles import (CaJournalier, Canal, Client360, MagasinMensuel, ProduitMensuel,
                         RepartitionCanal, Sante, Segment, TriClients)

MOIS_REGEX = r"^\d{4}-(0[1-9]|1[0-2])$"
PLAGE_MAX_JOURS = 366

app = FastAPI(
    title="API Ventes — couche gold",
    version="1.2.0",
    description="Données consolidées ERP (SQL), magasins (CSV) et web (JSON), servies depuis Databricks SQL.",
)


@lru_cache
def _depot() -> DepotDatabricks:
    return DepotDatabricks()


def get_depot() -> DepotGold:
    return _depot()


@app.exception_handler(ErreurDatabricks)
async def erreur_entrepot(_: Request, exc: ErreurDatabricks):
    return JSONResponse(status_code=503, content={"detail": f"Entrepôt Databricks indisponible : {exc}"})


@app.exception_handler(ValidationError)
async def configuration_incomplete(_: Request, exc: ValidationError):
    causes = ", ".join(str(e["loc"][0]).upper() if e.get("loc") else e["msg"].removeprefix("Value error, ")
                       for e in exc.errors())
    return JSONResponse(status_code=500, content={"detail": f"Configuration incomplète ou invalide dans .env : {causes}"})


def _mois(valeur: str) -> dt.date:
    annee, mois = valeur.split("-")
    return dt.date(int(annee), int(mois), 1)


def _verifier_plage(date_debut: dt.date, date_fin: dt.date) -> None:
    if date_debut > date_fin:
        raise HTTPException(status_code=422, detail="date_debut doit être antérieure ou égale à date_fin")
    if (date_fin - date_debut).days >= PLAGE_MAX_JOURS:
        raise HTTPException(status_code=422, detail=f"Plage limitée à {PLAGE_MAX_JOURS} jours")


@app.get("/vivant", tags=["Supervision"])
def vivant():
    """Sonde de vivacité du conteneur : ne sollicite pas Databricks."""
    return {"statut": "ok"}


@app.get("/sante", response_model=Sante, tags=["Supervision"])
def sante(depot: DepotGold = Depends(get_depot)):
    depot.verifier()
    return Sante(statut="ok", entrepot="joignable")


@app.get("/api/v1/ca/journalier", response_model=list[CaJournalier], tags=["Chiffre d'affaires"])
def ca_journalier(
    date_debut: dt.date = Query(..., description="AAAA-MM-JJ"),
    date_fin: dt.date = Query(..., description="AAAA-MM-JJ"),
    canal: Canal | None = Query(None),
    depot: DepotGold = Depends(get_depot),
):
    _verifier_plage(date_debut, date_fin)
    return depot.ca_journalier(date_debut, date_fin, canal.value if canal else None)


@app.get("/api/v1/ca/canaux", response_model=list[RepartitionCanal], tags=["Chiffre d'affaires"])
def repartition_canaux(
    date_debut: dt.date = Query(..., description="AAAA-MM-JJ"),
    date_fin: dt.date = Query(..., description="AAAA-MM-JJ"),
    depot: DepotGold = Depends(get_depot),
):
    _verifier_plage(date_debut, date_fin)
    return depot.repartition_canaux(date_debut, date_fin)


@app.get("/api/v1/produits/top", response_model=list[ProduitMensuel], tags=["Produits"])
def top_produits(
    mois: str = Query(..., pattern=MOIS_REGEX, description="AAAA-MM"),
    categorie: str | None = Query(None, max_length=50),
    limite: int = Query(10, ge=1, le=100),
    depot: DepotGold = Depends(get_depot),
):
    return depot.top_produits(_mois(mois), categorie, limite)


@app.get("/api/v1/magasins/performance", response_model=list[MagasinMensuel], tags=["Magasins"])
def performance_magasins(
    mois: str = Query(..., pattern=MOIS_REGEX, description="AAAA-MM"),
    depot: DepotGold = Depends(get_depot),
):
    return depot.magasins(_mois(mois))


@app.get("/api/v1/clients", response_model=list[Client360], tags=["Clients"])
def liste_clients(
    segment: Segment | None = Query(None),
    tri: TriClients = Query(TriClients.ca_total),
    limite: int = Query(20, ge=1, le=100),
    depot: DepotGold = Depends(get_depot),
):
    return depot.clients(segment.value if segment else None, tri.value, limite)


@app.get("/api/v1/clients/{client_id}", response_model=Client360, tags=["Clients"])
def fiche_client(client_id: int = Path(..., ge=1), depot: DepotGold = Depends(get_depot)):
    client = depot.client(client_id)
    if client is None:
        raise HTTPException(status_code=404, detail=f"Client {client_id} introuvable")
    return client

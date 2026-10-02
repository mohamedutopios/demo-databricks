"""Configuration lue dans les variables d'environnement (injectées par compose.yaml depuis .env)."""
from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Parametres(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    databricks_server_hostname: str = Field(min_length=1)
    databricks_http_path: str = Field(min_length=1)
    # Authentification : token personnel OU service principal (OAuth machine-à-machine)
    databricks_token: str | None = None
    databricks_client_id: str | None = None
    databricks_client_secret: str | None = None
    databricks_catalog: str = Field(default="projet_medaillon", pattern=r"^[A-Za-z_][A-Za-z0-9_]*$")
    databricks_schema: str = Field(default="gold", pattern=r"^[A-Za-z_][A-Za-z0-9_]*$")
    cache_ttl_secondes: int = Field(default=300, ge=0, le=86400)

    @model_validator(mode="after")
    def _authentification(self):
        jeton = bool(self.databricks_token)
        principal = bool(self.databricks_client_id and self.databricks_client_secret)
        if not jeton and not principal:
            raise ValueError("renseigner DATABRICKS_TOKEN, ou DATABRICKS_CLIENT_ID et DATABRICKS_CLIENT_SECRET")
        return self

    @property
    def mode_authentification(self) -> str:
        return "token" if self.databricks_token else "service_principal"


@lru_cache
def parametres() -> Parametres:
    return Parametres()

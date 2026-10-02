# syntax=docker/dockerfile:1
# =====================================================================
# API Ventes — couche gold (v1.2)
# Cibles : tests (exécute pytest pendant le build) | production (image finale)
# Compatible Docker et Podman, amd64 et arm64 (Apple Silicon)
# =====================================================================

FROM python:3.12-slim-bookworm AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

# ---------------------------------------------------------------------
# Dépendances de production, installées dans un préfixe isolé
# ---------------------------------------------------------------------
FROM base AS dependances
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ---------------------------------------------------------------------
# Tests : le build échoue si un test échoue
# ---------------------------------------------------------------------
FROM base AS tests
COPY requirements.txt requirements-dev.txt ./
RUN pip install -r requirements-dev.txt
COPY pytest.ini .
COPY app ./app
COPY tests ./tests
RUN python -m pytest -q

# ---------------------------------------------------------------------
# Production : sans outils de test, utilisateur non root
# ---------------------------------------------------------------------
FROM base AS production
LABEL org.opencontainers.image.title="api-ventes-gold" \
      org.opencontainers.image.version="1.2.0" \
      org.opencontainers.image.description="API de lecture de la couche gold Databricks (projet médaillon)"
COPY --from=dependances /install /usr/local
COPY app ./app
RUN useradd --uid 10001 --user-group --no-create-home --shell /usr/sbin/nologin api
ENV HOME=/tmp
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/vivant', timeout=4)"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

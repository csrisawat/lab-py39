# syntax=docker/dockerfile:1
# -----------------------------------------------------------------------------
# lab-py39 — DR image for AWS ECS Fargate.
# Reproduces what Azure App Service (Linux, PYTHON|3.9, zip deploy with Oryx build) does today:
#   Oryx build   : virtualenv "antenv" + pip install -r requirements.txt  -> same, in /opt/antenv
#   Startup      : App Service Startup Command "python app.py"            -> same CMD
#                  (app uses stdlib http.server, not WSGI - so no gunicorn)
#   App root     : /home/site/wwwroot                                     -> same path
#   Port         : PORT env, App Service Python default 8000
#   Config       : App Settings -> env vars -> ECS injects env vars from SSM (task definition "secrets")
# Base image: the DR pipeline ALWAYS passes --build-arg BASE_IMAGE=<private ECR golden copy pinned by digest>
#   (SSM /drlab-ecs/base/python39, filled by the "Base image mirror" pipeline), so DR builds never depend on a
#   public registry or on an EOL tag still existing. The default below is only for a local `docker build`.
# -----------------------------------------------------------------------------
ARG BASE_IMAGE=public.ecr.aws/docker/library/python:3.9-slim-bookworm
 
# ---- deps: build the virtualenv (compilers / -dev headers for native wheels go here only)
FROM ${BASE_IMAGE} AS deps
# RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN python -m venv /opt/antenv
COPY requirements.txt /tmp/requirements.txt
RUN /opt/antenv/bin/pip install -r /tmp/requirements.txt
 
# ---- runtime
FROM ${BASE_IMAGE}
# Runtime OS libs the app used on App Service go here (e.g. libpq5, tzdata, fonts):
# RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*
ENV VIRTUAL_ENV=/opt/antenv \
    PATH=/opt/antenv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000
# uid 1000 matches the optional EFS access point
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin appuser
COPY --from=deps /opt/antenv /opt/antenv
WORKDIR /home/site/wwwroot
COPY --chown=appuser:appuser . .
USER appuser
EXPOSE 8000
CMD ["python", "app.py"]

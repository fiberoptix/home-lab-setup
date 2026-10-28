# ── COPY for the rancher-k3s study track. Source of truth: GitLab production/rancher-k3s → hello-lab/Dockerfile @ 0682a5d (as built Oct 27, 2026). ──
FROM python:3.13-alpine
ARG GIT_SHA=unknown
ENV GIT_SHA=${GIT_SHA} PYTHONUNBUFFERED=1
WORKDIR /app
COPY app.py .
USER 65534:65534
EXPOSE 8080
CMD ["python", "/app/app.py"]

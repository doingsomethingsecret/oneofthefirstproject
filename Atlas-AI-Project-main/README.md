# Atlas AI — UK Immigration Assistant

A lightweight Flask-based AI assistant for UK immigration guidance, deployed with Docker Compose.

## Architecture

- **App:** Flask + Groq AI + Rule Engine + SQLite
- **CI:** Jenkins (Docker-in-Docker)
- **Quality:** SonarQube + PostgreSQL
- **Monitoring:** Prometheus + Grafana + node-exporter + blackbox-exporter

## Prerequisites

- Docker Engine 24+
- Docker Compose v2+
- 4GB+ RAM (t3.medium recommended)
- Ports available: 5000, 8080, 9000, 3000, 9090

## Quick Start

1. Clone the repo and copy environment file:
```bash
cp .env.example .env
```

2. Edit `.env` and set your secrets:
```bash
nano .env
```

3. Start all services:
```bash
docker compose up -d --build
```

4. Verify:
```bash
docker compose ps
curl http://localhost:5000/api/health
```

## Service URLs

| Service | URL |
|---------|-----|
| Atlas AI App | http://localhost:5000 |
| Grafana | http://localhost:3000/grafana |
| Prometheus | http://localhost:9090/prometheus |
| Jenkins | http://localhost:8080/jenkins |
| SonarQube | http://localhost:9000 |

## Compose Variants

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full stack (app + jenkins + sonarqube + monitoring) |
| `docker-compose.app.yml` | App only |
| `docker-compose.monitoring.yml` | Prometheus + Grafana + exporters |
| `docker-compose.sonarqube.yml` | SonarQube + PostgreSQL |
| `docker-compose.jenkins.yml` | Jenkins with Docker CLI |

## Environment Variables

See `.env.example` for all required variables.

| Variable | Required | Default |
|----------|----------|---------|
| `FLASK_SECRET_KEY` | Yes | — |
| `GF_SECURITY_ADMIN_PASSWORD` | Yes | — |
| `SONAR_JDBC_PASSWORD` | Yes | — |
| `OPENAI_API_KEY` | No | — |
| `ALB_DNS` | No | Hardcoded AWS ALB |

## Monitoring

Prometheus scrapes:
- `atlas-ai:5000/metrics` — app metrics
- `grafana:3000/metrics` — Grafana metrics
- `node-exporter:9100` — host metrics
- Blackbox probes — external service availability

Grafana dashboard **"Atlas AI Overview"** is auto-provisioned.

## Production Notes

- Remove `.env` from version control
- Use AWS Secrets Manager / Parameter Store for secrets
- Pin image tags (avoid `latest`)
- Restrict CORS origins in `app-lite.py`
- Do not expose `sonarqube-db` port 5432 publicly
- Use `depends_on` with `condition: service_healthy` for ordered startup

## License

MIT

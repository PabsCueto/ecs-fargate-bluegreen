# ecs-fargate-bluegreen

API de notas (FastAPI) containerizada con Docker y desplegada en AWS ECS/Fargate
detrás de un Application Load Balancer, con despliegues blue/green vía CodeDeploy.

## Correr en local (sin Docker)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

- Docs interactivas: http://127.0.0.1:8000/docs
- Health: `GET /health`
- Versión: `GET /version`
- Notas: `POST /notes`, `GET /notes`, `GET /notes/{id}`, `DELETE /notes/{id}`

## Estado

- [x] API local
- [ ] Docker
- [ ] ECR
- [ ] ECS/Fargate + ALB
- [ ] CodeDeploy blue/green
- [ ] CI/CD

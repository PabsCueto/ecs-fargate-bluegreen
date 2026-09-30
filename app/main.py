import os
import socket
from datetime import datetime, timezone
from itertools import count

from fastapi import FastAPI, HTTPException, Response, status
from pydantic import BaseModel, Field

# En ECS estos valores vendrán de la task definition (variables de entorno).
# Cambiarlos entre versiones nos permitirá ver el blue/green en acción.
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
DEPLOY_COLOR = os.getenv("DEPLOY_COLOR", "blue")

app = FastAPI(title="Notes API", version=APP_VERSION)


class NoteIn(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    content: str = Field(default="", max_length=1000)


class Note(NoteIn):
    id: int
    created_at: datetime


# Almacenamiento en memoria: a propósito, para que el foco del proyecto
# sea ECS/Fargate y no la base de datos.
_notes: dict[int, Note] = {}
_ids = count(1)


@app.get("/health")
def health() -> dict:
    """Lo usará el target group del ALB para saber si la tarea está sana."""
    return {"status": "ok"}


@app.get("/version")
def version() -> dict:
    """Muestra qué versión responde y desde qué contenedor."""
    return {
        "version": APP_VERSION,
        "color": DEPLOY_COLOR,
        "hostname": socket.gethostname(),
    }


@app.post("/notes", response_model=Note, status_code=status.HTTP_201_CREATED)
def create_note(payload: NoteIn) -> Note:
    note = Note(
        id=next(_ids),
        created_at=datetime.now(timezone.utc),
        **payload.model_dump(),
    )
    _notes[note.id] = note
    return note


@app.get("/notes", response_model=list[Note])
def list_notes() -> list[Note]:
    return list(_notes.values())


@app.get("/notes/{note_id}", response_model=Note)
def get_note(note_id: int) -> Note:
    note = _notes.get(note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.delete("/notes/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(note_id: int) -> Response:
    if _notes.pop(note_id, None) is None:
        raise HTTPException(status_code=404, detail="Note not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)

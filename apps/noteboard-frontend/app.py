import asyncio
from tempfile import NamedTemporaryFile
from typing import Any, List, Optional

from fastapi import FastAPI
from fastapi.templating import Jinja2Templates
from fastapi import Depends
from fastapi.requests import Request
from fastapi.responses import HTMLResponse
try:
    from google.cloud import secretmanager_v1
except ImportError:
    pass
import httpx
from pydantic import AnyHttpUrl, BaseModel, BaseSettings, validator
from Secweb import SecWeb
from Secweb.ContentSecurityPolicy import Nonce_Processor
from starlette_exporter import PrometheusMiddleware, handle_metrics
import typer
import uvicorn
import uvloop


asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())


###############################################################################
# Declarations
###############################################################################
class Settings(BaseSettings):
    SECRET_KEY: str
    SERVER_NAME: str
    SERVER_HOST: AnyHttpUrl
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    PROJECT_NAME: Optional[str]
    API_URL: AnyHttpUrl 

    class Config:
        case_sensitive = True
        env_file = ".env"


    @validator('SECRET_KEY')
    def read_secret_key(cls, v: str) -> str:
        return read_secret_from_gcp(v)


def read_secret_from_gcp(v: str) -> Optional[str]:
    if v and v.startswith('projects/'):
        client = secretmanager_v1.SecretManagerServiceClient()
        secret = client.access_secret_version(request={'name': v})
        return secret.payload.data.decode('utf-8')
    return v


def read_secret_from_gcp_as_file(v: str, autodelete: bool = True) \
        -> Optional[Any]:
    if v and v.startswith('projects/'):
        client = secretmanager_v1.SecretManagerServiceClient()
        secret = client.access_secret_version(request={'name': v})
        f = NamedTemporaryFile(delete=autodelete)
        f.write(secret.payload.data)
        f.seek(0)
        v = f
    return v


class NoteIn(BaseModel):
    text: str
    completed: bool


class Note(BaseModel):
    id: int
    text: str
    completed: bool


###############################################################################
# Global variables
###############################################################################
app = FastAPI()
cli = typer.Typer()
settings = Settings()
templates = Jinja2Templates(directory="templates")
cache = None
SecWeb(
    app=app, Option={
        'hsts': {'max-age': 2592000},
        'csp': {
            'default-src': ["'self'"],
            'base-uri': ["'self'"],
            'block-all-mixed-content': [],
            'font-src': ["'self'", 'https:', 'data:'],
            'frame-ancestors': ["'self'"],
            'img-src': ["'self'", 'data:'],
            "object-src": ["'none'"],
            "script-src": ["'self'"],
            "script-src-attr": ["'none'"],
            "style-src": ["'self'", "https:", "'unsafe-inline'"],
            "upgrade-insecure-requests": [],
            "require-trusted-types-for": ["'script'"]
        }}, script_nonce=True, style_nonce=True)


###############################################################################
# Application
###############################################################################
app.add_middleware(PrometheusMiddleware, app_name="noteboard-frontend")
app.add_route("/noteboard/metrics", handle_metrics)

@app.get("/noteboard", response_class=HTMLResponse)
async def index(request: Request):
    nonce = Nonce_Processor(DEFAULT_ENTROPY=20)

    async with httpx.AsyncClient() as client:
        r = await client.get(f"{settings.API_URL}/notes")
        result = r.json()

    return templates.TemplateResponse(
        "index.jinja2", {"request": request, "notes": result, "nonce": nonce})


@app.get("/noteboard/notes", response_model=List[Note])
async def get_notes():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{settings.API_URL}/notes")
        result = r.json()
        return result


@app.post("/noteboard/notes", response_model=Note)
async def create_note(note: NoteIn):
    async with httpx.AsyncClient() as client:
        r = await client.post(f"{settings.API_URL}/notes", json=note.dict())
        result = r.json()
        return result


###############################################################################
# CLI
###############################################################################
@cli.command()
def run(dev: bool = typer.Option(False)):
    uvicorn.run(
        app,
        host=settings.HOST,
        port=settings.PORT,
        proxy_headers=True,
        access_log=True,
        forwarded_allow_ips="*",
        factory=False)


if __name__ == "__main__":
    cli()

import asyncio
import random
import ssl
from tempfile import NamedTemporaryFile, _TemporaryFileWrapper
from typing import Any, Dict, Iterator, List, Optional

import databases
from fastapi import FastAPI
from fastapi import Depends
try:
    from google.cloud import secretmanager_v1
except ImportError:
    pass
from pydantic import AnyHttpUrl, BaseModel, BaseSettings, validator
from sqlalchemy import Boolean, Column, Integer, String, Table, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.schema import MetaData
from starlette_exporter import PrometheusMiddleware, handle_metrics
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
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

    # Databse related
    SQLALCHEMY_DATABASE_URI: str
    DATABASE_WITH_SSL: bool = False
    DATABASE_SSL_SERVER_CA_FILE: Optional[str]
    DATABASE_SSL_CLIENT_CERT_FILE: Optional[str]
    DATABASE_SSL_CLIENT_KEY_FILE: Optional[str]

    class Config:
        case_sensitive = True
        env_file = ".env"

    @validator('SECRET_KEY')
    def read_secret_key(cls, v: str) -> str:
        return read_secret_from_gcp(v)

    @validator('SQLALCHEMY_DATABASE_URI')
    def read_sa_connection_uri(cls, v: str) -> str:
        return read_secret_from_gcp(v)

    @validator('DATABASE_SSL_SERVER_CA_FILE')
    def read_ssl_server_ca_file(cls, v: str) -> str:
        return read_secret_from_gcp_as_file(v)

    @validator('DATABASE_SSL_CLIENT_CERT_FILE')
    def read_ssl_client_cert_file(cls, v: str) -> str:
        return read_secret_from_gcp_as_file(v)

    @validator('DATABASE_SSL_CLIENT_KEY_FILE')
    def read_ssl_client_key_file(cls, v: str) -> str:
        return read_secret_from_gcp_as_file(v)


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


meta = MetaData(naming_convention={
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s"
})


def get_db() -> Iterator[databases.Database]:
    yield database


def configure_db(app: FastAPI) -> databases.Database:
    global database

    db_uri = settings.SQLALCHEMY_DATABASE_URI
    options = {}
    connect_args = {}
    if settings.DATABASE_WITH_SSL:
        connect_args = create_connect_args()
        options["ssl"] = create_ssl_context()

    database = databases.Database(db_uri, **options)

    async def startup():
        # create our tables, only done if table doesn't exist yet
        # we do not support migrations in this demo.
        # these two lines are non async but shouldn't block for long on startup
        engine = create_engine(db_uri, connect_args=connect_args)
        meta.create_all(engine)
        engine.dispose()

        await database.connect()

    async def shutdown():
        await database.disconnect()

    app.add_event_handler("startup", startup)
    app.add_event_handler("shutdown", shutdown)

    return database


def create_ssl_context() -> ssl.SSLContext:
    chain_file = settings.DATABASE_SSL_SERVER_CA_FILE
    if isinstance(chain_file, _TemporaryFileWrapper):
        chain_file = chain_file.name
    ctx = ssl.create_default_context(
        ssl.Purpose.SERVER_AUTH, cafile=chain_file)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    crt_file = settings.DATABASE_SSL_CLIENT_CERT_FILE
    key_file = settings.DATABASE_SSL_CLIENT_KEY_FILE
    if crt_file and key_file:
        ctx.verify_mode = ssl.CERT_REQUIRED
        if isinstance(crt_file, _TemporaryFileWrapper):
            crt_file = crt_file.name
        if isinstance(key_file, _TemporaryFileWrapper):
            key_file = key_file.name
        ctx.load_cert_chain(certfile=crt_file, keyfile=key_file)
        ctx.check_hostname = False

    return ctx


def create_connect_args() -> Dict[str, str]:
    connect_args = {}
    connect_args["sslmode"] = "allow"

    crt_file = settings.DATABASE_SSL_CLIENT_CERT_FILE
    key_file = settings.DATABASE_SSL_CLIENT_KEY_FILE
    if crt_file and key_file:
        connect_args["sslmode"] = "require"

        connect_args["sslcert"] = settings.DATABASE_SSL_CLIENT_CERT_FILE
        if isinstance(crt_file, _TemporaryFileWrapper):
            connect_args["sslcert"] = crt_file.name

        connect_args["sslkey"] = settings.DATABASE_SSL_CLIENT_KEY_FILE
        if isinstance(key_file, _TemporaryFileWrapper):
            connect_args["sslkey"] = key_file.name

    chain_file = settings.DATABASE_SSL_SERVER_CA_FILE
    if chain_file:
        connect_args["sslmode"] = "verify-ca"
        connect_args["sslrootcert"] = chain_file
        if isinstance(chain_file, _TemporaryFileWrapper):
            connect_args["sslrootcert"] = chain_file.name

    return connect_args


notes = Table(
    "notes",
    meta,
    Column("id", Integer, primary_key=True),
    Column("text", String),
    Column("completed", Boolean),
)


class NoteIn(BaseModel):
    text: str
    completed: bool


class Note(BaseModel):
    id: int
    text: str
    completed: bool


class SlowDownMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path.startswith("/noteboard/api/v1/notes"):
            if with_latency > 0:
                a = with_latency / 1000.
                b = (with_latency + random.randint(0, with_jitter)) / 1000.
                await asyncio.sleep(random.uniform(a, b))
        return await call_next(request)


class RespondWithErrorMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path.startswith("/noteboard/api/v1/notes"):
            if with_errors:
                return Response(status_code=random.choice(with_errors))
        return await call_next(request)


###############################################################################
# Global variables
###############################################################################
app = FastAPI()
cli = typer.Typer()
settings = Settings()
Base = declarative_base()
database: databases.Database = None
with_latency = 0.
with_jitter = 100.
with_errors = None


###############################################################################
# Application API
###############################################################################
app.add_middleware(SlowDownMiddleware)
app.add_middleware(RespondWithErrorMiddleware)
app.add_middleware(PrometheusMiddleware, app_name="noteboard-frontend")
app.add_route("/noteboard/api/v1/metrics", handle_metrics)


@app.get("/noteboard/api/v1/notes", response_model=List[Note])
async def read_notes(db: databases.Database = Depends(get_db)):
    query = notes.select()
    return await db.fetch_all(query)


@app.post("/noteboard/api/v1/notes", response_model=Note)
async def create_note(note: NoteIn, db: databases.Database = Depends(get_db)):
    query = notes.insert().values(text=note.text, completed=note.completed)
    last_record_id = await db.execute(query)
    return {**note.dict(), "id": last_record_id}


@app.delete("/noteboard/api/v1/notes")
async def clear_all_notes(db: databases.Database = Depends(get_db)):
    query = notes.delete()
    await db.execute(query)


@app.get("/noteboard/api/v1/fault")
async def see_faults():
    return {
        "slowdown": {
            "latency": with_latency,
            "jitter": with_jitter
        },
        "errors": with_errors
    }


@app.get("/noteboard/api/v1/fault/slowdown")
async def make_slow(latency: float = 100., jitter: float = 100.):
    global with_jitter, with_latency
    with_latency = latency
    with_jitter = jitter


@app.delete("/noteboard/api/v1/fault/slowdown")
async def make_fast():
    global with_jitter, with_latency
    with_latency = 0.
    with_jitter = 100.


@app.get("/noteboard/api/v1/fault/error")
async def respond_with_error():
    global with_errors
    with_errors = (400, 500)


@app.delete("/noteboard/api/v1/fault/error")
async def respond_normally():
    global with_errors
    with_errors = None


###############################################################################
# CLI
###############################################################################
@cli.command()
def run(dev: bool = typer.Option(False)):
    configure_db(app)

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

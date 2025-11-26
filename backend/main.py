from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from db import init_db, close_db
from routers import events, dogs, chat
import logging

# Logging Setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up...")
    init_db()
    yield
    logger.info("Shutting down...")
    close_db()

app = FastAPI(title="MyDogCare Backend (DuckDB)", lifespan=lifespan)

# Routers
app.include_router(events.router)
app.include_router(dogs.router)
app.include_router(chat.router)

# Exception handler for validation errors
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"❌ Validation error on {request.url.path}")
    logger.error(f"📋 Error details: {exc.errors()}")
    try:
        body = await request.body()
        logger.error(f"📦 Request body: {body.decode('utf-8')[:1000]}")
    except:
        pass
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": str(exc.body)[:500]}
    )

@app.get("/")
def read_root():
    return {"status": "running", "db": "duckdb"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)

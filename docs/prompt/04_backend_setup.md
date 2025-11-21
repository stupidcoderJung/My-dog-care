# Prompt: Backend Infrastructure Setup

**Goal**: Initialize the Python FastAPI backend project.

**Context**:
We are building a backend to sync data between devices and run AI agents.

**Task**:
1.  Create a `backend` directory.
2.  Set up the basic FastAPI project structure.

**Requirements**:
- **Tech Stack**: Python 3.11+, FastAPI, SQLAlchemy (Async), Pydantic, Uvicorn.
- **File Structure**:
    - `main.py`: App entry point, CORS middleware setup.
    - `database.py`: Async engine setup (PostgreSQL), Base class.
    - `models.py`: Empty file for now.
    - `schemas.py`: Empty file for now.
    - `config.py`: Environment variables (DATABASE_URL, etc.) using `pydantic-settings`.

**Instructions for AI**:
- Provide the exact code for `main.py` and `database.py`.
- Include a `requirements.txt` or `pyproject.toml` (Poetry) with necessary dependencies.
- Ensure CORS is configured to allow requests from `*` (for development).

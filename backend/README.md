# Backend - MyDogCare Server

FastAPI-based backend for storing time-series data, managing clips, and running the LLM agent.

## Architecture

### Data Layer
- **TimescaleDB**: Time-series storage
  - `dog_states` (Hypertable): Per-dog states every second
  - `pair_relations` (Hypertable): Pair-wise relationships
  - `risk_events`: Detected risk incidents
  - `clips`: Video evidence metadata
  
- **Milvus (Vector DB)**: Semantic search for clips
- **MinIO/S3**: Video clip storage
- **Redis**: Caching and session management

### API Layer
- **FastAPI**: High-performance async API
  - `POST /dogs`: Dog profile sync
  - `POST /events/batch`: Bulk state ingestion
  - `POST /clips`: Video upload
  - `GET /analytics/*`: Time-series queries
  - `POST /chat`: LLM agent interface

### Intelligence Layer
- **LLM Agent**: Multi-expert analyst
  - **Planner**: Parse user query into execution plan
  - **Analyzer (Data)**: SQL aggregations and anomaly detection
  - **Analyzer (Expert)**: Veterinary/behavioral interpretation
  - **Presenter**: Generate summaries, charts (Chart.js spec), evidence cards

- **VLM Worker** (Gemini 2.5 Pro):
  - Hard example mining
  - Structured annotation generation
  - Training data accumulation

## Setup

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- Poetry

### Installation
```bash
# Install dependencies
poetry install

# Start databases
docker-compose up -d

# Run migrations
poetry run alembic upgrade head

# Start server
poetry run uvicorn main:app --reload
```

### Environment Variables
Create `.env` file:
```
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/mydogcare
MILVUS_HOST=localhost
MILVUS_PORT=19530
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
GEMINI_API_KEY=your_api_key
```

## Database Schema

### dog_states (Hypertable)
- `t` (timestamptz): Timestamp
- `dog_id` (uuid): Dog UUID
- `bbox_cx`, `bbox_cy`, `bbox_w`, `bbox_h` (real): Normalized bbox
- `speed_px` (real): Speed in px/s
- `behavior_probs` (jsonb): Action probabilities
- `stress_proxy` (real): Stress estimate
- `environment_lux`, `environment_db` (real): Sensors

### pair_relations (Hypertable)
- `t` (timestamptz): Timestamp
- `dog_i_id`, `dog_j_id` (uuid): Dog pair (i < j)
- `distance_norm` (real): Normalized distance
- `affinity`, `tension` (real): Relationship scores
- `interaction_tags` (text[]): Interaction types

## API Endpoints

### Dog Management
- `POST /dogs`: Upload dog profile with photo
- `GET /dogs`: Retrieve user's dogs

### Event Ingestion
- `POST /events/batch`: Bulk insert `DeviceStatePacket`s

### Analytics
- `GET /analytics/dog_timeseries?dog_id=...&metric=...`: Time-series data
- `GET /analytics/pair_timeseries?dog_i_id=...&dog_j_id=...`: Pair metrics
- `GET /analytics/risk_peaks?target=...`: Risk incidents

### Clips
- `POST /clips`: Upload video clip
- `GET /clips/search?query=...`: Semantic search

### Chat
- `POST /chat`: Ask LLM agent with evidence retrieval

## Tech Stack
- FastAPI
- SQLAlchemy (async)
- asyncpg
- TimescaleDB
- Milvus
- MinIO
- Redis
- Pydantic
- Alembic

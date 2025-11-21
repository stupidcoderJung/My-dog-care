# Prompt: Event Ingestion Pipeline

**Goal**: Implement the pipeline to send "On Air" Vision data to the server.

**Context**:
The iOS app generates Vision JSON logs every second. We need to batch these and send them to the server for storage.

**Task**:
1.  **Backend**:
    - Update `backend/models.py`: Add `EventLog` table.
    - Create `backend/routers/events.py`: Implement `POST /events` (Batch insert).
2.  **iOS**:
    - Update `Views/OnAirView.swift` (or a dedicated service).
    - Implement a buffer and timer to send logs every 10 seconds.

**Requirements**:
- **DB Model**:
    - `EventLog`: id, dog_id, timestamp, data (JSONB).
- **API**:
    - `POST /events`: Accepts a list of event objects.
- **iOS Logic**:
    - Store `VisionResponse` objects in a thread-safe array.
    - Every 10 seconds, check if array is not empty.
    - If not empty, serialize to JSON and POST to server.
    - Clear array on success.

**Instructions for AI**:
- Ensure the backend uses `JSONB` for the data column (if using Postgres) or `Text` (if SQLite).
- On iOS, handle background tasks gracefully if possible (basic implementation first).

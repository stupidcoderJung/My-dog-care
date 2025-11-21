# Prompt: Identity & Dog Sync Implementation

**Goal**: Implement User/Dog models and synchronization APIs.

**Context**:
We need to sync dog profiles between devices using Clerk authentication.

**Task**:
1.  **Backend**:
    - Update `backend/models.py`: Add `User` and `Dog` tables.
    - Create `backend/routers/dogs.py`: Implement `POST /dogs` and `GET /dogs`.
    - Add Auth dependency to verify Clerk tokens.
2.  **iOS**:
    - Create `Services/DogSyncService.swift`.
    - Implement logic to sync local SwiftData dogs with the server.

**Requirements**:
- **DB Models**:
    - `User`: id (String, PK), email.
    - `Dog`: id (Integer, PK), owner_id (String, FK), name, breed, birthdate, image_url.
- **API**:
    - `GET /dogs`: Return list of dogs for the authenticated user.
    - `POST /dogs`: Accept dog details + image (multipart/form-data or base64), save to DB/Storage, return created Dog.

**Instructions for AI**:
- Use `SQLAlchemy` models.
- For image storage, just save to a local `uploads/` folder for now (keep it simple).
- On iOS, use `Alamofire` or `URLSession` for networking.

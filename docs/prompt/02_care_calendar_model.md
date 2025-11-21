# Prompt: Care Calendar Data Model

**Goal**: Create the SwiftData model for the Care Calendar.

**Context**:
We need a local database to store manual care events like vet visits, vaccinations, and weight logs. We are using SwiftData.

**Task**:
1.  Create a new file `Models/CareEvent.swift`.
2.  Define a SwiftData model class `CareEvent`.

**Requirements**:
- **Class Name**: `CareEvent`
- **Macro**: `@Model`
- **Properties**:
    - `id`: UUID (Unique Identifier)
    - `dogId`: UUID (For multi-dog support, future sync)
    - `date`: Date (When the event happened)
    - `category`: Enum (vet, vaccine, weight, grooming, medication, symptom, other)
    - `title`: String (Short description)
    - `value`: Double? (Optional value for weight, temperature, etc.)
    - `notes`: String? (Detailed notes)
    - `isSynced`: Bool (Default false, for backend sync)
    - `createdAt`: Date (Metadata)

**Instructions for AI**:
- Define the `CareCategory` enum with `Codable` conformance.
- Ensure the model is compatible with SwiftData (iOS 17+).
- Add a convenience initializer.

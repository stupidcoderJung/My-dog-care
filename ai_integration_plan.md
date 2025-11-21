# AI Integration & Data Pipeline Vision

## 🎯 Project Vision
The goal is to build a **comprehensive AI Dog Care Assistant**.
1.  **Data Source ("On Air")**: The app captures real-time data (video streams, behavior analysis, activity logs) from the "On Air" feature.
2.  **Data Ingestion**: This data is streamed to a server and stored as a historical record of the dog's life.
3.  **AI Interface ("Chat")**: The user interacts with this data through the AI Chat. The AI acts as a **Data Analyst & Veterinarian**, capable of answering questions like *"How much did Bella sleep today?"* or *"Show me a graph of her activity this week."*

## 🏗️ Architecture Plan

To achieve this, we need a backend infrastructure that connects the raw data to the LLM.

### 1. Data Pipeline (The "Eyes")
*   **Client (iOS)**: The `OnAirView` analyzes video frames (using Vision framework or local VLM) and extracts structured events.
    *   *Example Data*: `{ "timestamp": "2023-10-27T10:00:00Z", "event": "sleeping", "confidence": 0.95 }`
*   **Ingestion API**: A lightweight server endpoint (e.g., `POST /api/events`) to receive these logs in real-time.
*   **Database**:
    *   **Time-Series DB** (e.g., InfluxDB, TimescaleDB) or **NoSQL** (Firestore, MongoDB) is best for storing timestamped activity logs.

### 2. AI Service (The "Brain")
This is the core service you need to build. It sits between the Chat UI and the Database.

#### Recommended Stack: **Python Backend (FastAPI)**
Python is the standard for AI/Data engineering.
*   **Framework**: FastAPI (high performance, easy to build APIs).
*   **LLM Orchestration**: LangChain or LlamaIndex.
*   **Model**: GPT-4o or Gemini 1.5 Pro (models with strong reasoning and large context windows).

### 3. The "Executable Code" Workflow
To show graphs, the AI shouldn't just hallucinate numbers. It needs to **query the real data**.

1.  **User Query**: "Show me a graph of activity for the last 7 days."
2.  **Function Calling (The Magic)**:
    *   The LLM recognizes it needs data. It calls a defined tool: `get_activity_stats(days=7)`.
    *   The Backend executes this SQL/Database query.
    *   **Result**: Returns JSON data `[{day: "Mon", active_hours: 4}, ...]`.
3.  **Code Generation / Visualization**:
    *   The LLM receives the JSON.
    *   It generates the **HTML/Chart.js code** (which we implemented in `ChatView`) populated with this real data.
4.  **Response**: The iOS app receives the HTML string and renders it in the `GraphWebView`.

## 🧠 Expert VLM Strategy & Data Schema

To truly understand the dog, we must go beyond simple "eating/sleeping" labels. We will leverage a **Multi-Expert Approach** in our VLM Prompt Engineering.

### A. Vision Model Expert (The "Observer")
We need to extract granular visual details that indicate health and mood.
*   **Prompt Additions**:
    *   **Posture**: `standing`, `sitting`, `lying_side`, `lying_belly`, `curled`, `sploot`.
    *   **Emotional Indicators**: `tail_wagging`, `tail_tucked`, `ears_erect`, `ears_flat`, `panting`, `yawning`, `whale_eye`.
    *   **Health Signals**: `limping`, `scratching_excessive`, `shaking`, `vomiting`, `head_tilt`.
    *   **Context**: `near_food_bowl`, `near_door`, `on_bed`, `on_floor`.

### B. Time-Series Database Expert (The "Historian")
Data is useless without temporal context.
*   **Storage Strategy**:
    *   **InfluxDB / TimescaleDB**: Store high-frequency events (1 event/sec).
    *   **Aggregation**: Downsample data to "5-minute buckets" for long-term trend analysis (e.g., "Average Activity Level per Hour").
    *   **Anomaly Detection**: Use statistical methods (Z-score) to detect deviations. *Example: "Bella usually sleeps 14 hours, but today she slept 18 hours."*

### C. Vector Database Expert (The "Memory")
For qualitative data ("notes" and "descriptions").
*   **Technology**: **FAISS** or **Pinecone**.
*   **Usage**: Embed the `notes` field (e.g., "Bella looks sad and is looking at the door").
*   **Query**: User asks "Has Bella seemed lonely lately?". The system searches vector space for semantically similar past events.

### D. Business Model Expert (The "Strategist")
Turn data into value.
*   **Health Alerts**: "Excessive scratching detected 5 times today" -> **Push Notification**: "Check for fleas/allergies."
*   **Consumables**: "Water bowl empty" detected repeatedly -> **Recommendation**: "Buy automatic water fountain."
*   **Vet Reports**: "Export 30-day activity & symptom log" -> **Premium Feature** for Vet visits.

## 📝 Enhanced JSON Schema (Target)
The VLM should output this richer structure:

```json
{
  "timestamp": "ISO8601",
  "subject": {
    "name": "Bella",
    "confidence": 0.98
  },
  "behavior": {
    "primary_action": "rest",
    "posture": "lying_side",
    "intensity": "low"
  },
  "health": {
    "symptom": "none", // or "limping", "scratching"
    "severity": 0
  },
  "emotion": {
    "mood": "relaxed", // inferred from tail/ears
    "indicators": ["eyes_closed", "breathing_slow"]
  },
  "context": {
    "location": "living_room_bed",
    "objects_nearby": ["toy_bone"]
  },
  "notes": "Bella is sleeping deeply on her side, occasional twitching (dreaming)."
}
```

## 🚀 Implementation Roadmap

### Phase 1: Server Setup (MVP)
- [ ] Set up a simple Python FastAPI server.
- [ ] Create a database (e.g., Supabase/PostgreSQL) to store "On Air" events.
- [ ] Create an API endpoint `POST /events` for the iOS app to upload data.

### Phase 2: AI Agent Setup
- [ ] Integrate OpenAI or Gemini API in the Python server.
- [ ] Define **Tools** for the LLM (e.g., `query_database`).
- [ ] Implement the `/chat` endpoint that accepts user text and returns the AI response (text or graph HTML).

### Phase 3: Connection
- [ ] Connect `ChatService.swift` in the iOS app to your real Python backend instead of the Mock service.

## 💡 Build vs. Buy?
*   **Build (Recommended)**: Using **FastAPI + LangChain + OpenAI/Gemini** gives you full control over the data and the "graph generation" logic. It's the most flexible for your "Executable Code" requirement.
*   **Buy (Managed)**: Platforms like **Firebase Genkit** or **Supabase Edge Functions** can simplify the infrastructure, but you might find it harder to implement complex "Code Interpreter" style features compared to a dedicated Python backend.

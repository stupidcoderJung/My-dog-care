# AI Integration & Data Pipeline Vision (Hybrid Edge-Cloud + Blackbox + VLM)

## 🎯 Project Vision
**MyDogCare** is a **Multi-modal Dog Memory Service (Blackbox + Time-Series Analysis)**.
It tracks multiple dogs in real-time using on-device AI (YOLO + ReID), records significant events as "Evidence Clips," stores every second as structured time-series data, and allows users to query this memory using natural language with **charts, expert analysis, and video evidence**.

**Core Architecture**:
*   **Dual-Device Setup**:
    *   **Camera Device (Sender)**: Dedicated iPhone at home running "On Air" mode (YOLO + ReID + State Packet + Clip Trigger).
    *   **Viewer Device (Receiver)**: User's personal iPhone for Chat, Charts, Calendar, and Reports.
*   **Blackbox Memory**: Not just stats, but **Time-Series Facts + Video Evidence**.
*   **AI Analyst**: Multi-expert agent (Data Analyst + Vet + Behaviorist) that answers questions with **Charts**, **Expert Advice**, and **Video Clips**.
*   **VLM (Gemini 2.5 Pro)**: Auto-labeling and training data generation (not used for real-time queries).

---

## 🏗️ Architecture Overview

### 1. On-Device (Camera Mode)
*   **Role**: The "Eyes" & "Reflexes".
*   **Tech Stack**: CoreML (YOLOv11/v12), Swift, ReID, Lightweight Behavior/Stress Heads.
*   **Pipeline**:
    1.  **Detection & Tracking**: YOLO + ReID (One-shot).
    2.  **Behavior & Stress Analysis**: Lightweight on-device models:
        *   **Behavior Classifier**: Analyzes recent frame history (bbox trajectory, speed, direction) to predict action probabilities.
        *   **Stress Proxy Head**: Estimates stress level (0~1) from behavior patterns and motion statistics.
    3.  **State Logging**: Generates `DeviceStatePacket` every second with:
        *   `dogs: [DogState]` — Normalized bbox, speed, direction, behavior probabilities, stress proxy.
        *   `relations: [PairState]` — Distance, affinity, tension between dog pairs.
        *   `environment: EnvironmentState` — Lux, decibel, crowding.
    4.  **Clip Triggering (The Blackbox)**:
        *   **Behavior Peak**: High probability of play/chase (> 0.8).
        *   **Relation Change**: Sudden spike in tension or affinity.
        *   **Risk Event**: `risk_score` exceeds threshold.
    4.  **Upload**: Sends State Packets (Batch every 10s) and Evidence Clips (MP4) to Server.

### 2. Backend Server (The "Memory")
*   **Role**: Centralized Storage & Indexing.
*   **Tech Stack**: Python (FastAPI), TimescaleDB, S3/MinIO, Vector DB (Milvus), Redis.
*   **Data Stores**:
    *   **Facts (TimescaleDB Hypertables)**:
        *   `dog_states`: Per-dog time-series (bbox, speed, behavior, stress).
        *   `pair_relations`: Per-pair time-series (distance, affinity, tension).
        *   `risk_events`: Detected risk incidents.
    *   **Evidence (S3/MinIO)**: Video clips (`.mp4`) and thumbnails.
    *   **Meaning (Vector DB)**: Embeddings of clips for semantic search.

### 3. LLM Layer (The "Brain")
*   **Role**: Planner, Analyzer (Data + Vet + Behavior), Presenter.
*   **Workflow**:
    1.  **Planner**: User Query -> Search Plan (Time Range, Filters, Metrics, Semantic Query).
    2.  **Analyzer (Data)**: Executes SQL on TimescaleDB to aggregate stats and detect anomalies (e.g., "Sleep duration dropped by 20%").
    3.  **Analyzer (Expert)**: Interprets the stats with veterinary/behavioral knowledge (e.g., "This drop suggests anxiety or pain").
    4.  **Analyzer (Evidence)**: Fetches relevant video clips from Vector DB to support the diagnosis.
    5.  **Presenter**: Generates Summary + **Charts (Chart.js Spec)** + **Evidence Card** (Top-3 Clips).

### 4. VLM Layer (Gemini 2.5 Pro - "The Teacher")
*   **Role**: Auto-labeling and training data generation.
*   **Workflow**:
    1.  **Hard Example Mining**: Select low-confidence detections or interesting clips.
    2.  **VLM Annotation**: Send to Gemini 2.5 Pro with structured prompt asking for:
        *   Caption, scene tags, per-dog behavior/emotion, interaction type, risk estimate.
    3.  **Store Labels**: Save as training data for Behavior/Relation/Risk models and QA LLM fine-tuning.
    4.  **Continuous Improvement**: Retrain models quarterly with accumulated labels.

---

## 🧠 Detailed Data Strategy

### A. On-Device Data Structures

#### `DetectedObject`
```swift
struct DetectedObject {
    let bbox: CGRect        // Original frame coords
    let confidence: Float
    let classId: Int        // Dog class index
    let trackId: Int?       // Temporary tracker ID
    let embedding: [Float]? // ReID 128d vector
}
```

#### `DogState`
```swift
struct DogState {
    let tempTrackId: Int
    let dogId: UUID?              // Set only if matched with reference
    let bboxNorm: BBoxNorm        // cx, cy, w, h (0~1)
    let speedPx: Float?           // px/s
    let directionRad: Float?      // Radians
    let behaviorProbs: [String: Float] // {"play": 0.8, "rest": 0.1}
    let stressProxy: Float?       // 0~1 estimated stress level
}
```

#### `PairState`
```swift
struct PairState {
    let dogIId: UUID
    let dogJId: UUID        // Always dogIId < dogJId
    let distanceNorm: Float // 0~1
    let relativeAngle: Float?
    let affinityScore: Float?   // 0~1
    let tensionScore: Float?    // 0~1
    let interactionTags: [String] // ["play", "chase", "face_off"]
}
```

#### `DeviceStatePacket`
```swift
struct DeviceStatePacket {
    let timestamp: Date     // UTC
    let deviceId: String
    let sessionId: String   // OnAir session UUID
    let fps: Float?
    let dogs: [DogState]
    let relations: [PairState]?
    let environment: EnvironmentState?
}
```

### B. Server Data Schema (TimescaleDB)

#### `dog_states` (Hypertable)
| Column | Type | Description |
| :--- | :--- | :--- |
| `t` | timestamptz | Timestamp (1s resolution) |
| `dog_id` | uuid | UUID of the dog |
| `temp_track_id` | integer | Temporary tracker ID |
| `bbox_cx`, `bbox_cy`, `bbox_w`, `bbox_h` | real | Normalized bbox |
| `speed_px` | real | Speed in px/s |
| `behavior_probs` | jsonb | `{ "play": 0.8, "rest": 0.1 }` |
| `dominant_action` | text | Most likely action |
| `stress_proxy` | real | 0~1 stress estimate |
| `environment_lux`, `environment_db` | real | Environmental sensors |

#### `pair_relations` (Hypertable)
| Column | Type | Description |
| :--- | :--- | :--- |
| `t` | timestamptz | Timestamp |
| `dog_i_id`, `dog_j_id` | uuid | Dog pair (i < j) |
| `distance_norm` | real | Normalized distance |
| `affinity`, `tension` | real | Relationship scores |
| `interaction_tags` | text[] | ["play", "chase"] |

#### `risk_events` (Events)
| Column | Type | Description |
| :--- | :--- | :--- |
| `risk_id` | uuid PK | Unique ID |
| `t_start`, `t_end` | timestamptz | Time range |
| `target_ids` | uuid[] | Involved dogs |
| `risk_score` | real | Peak risk score |
| `risk_stage` | text | "warning", "escalating", "high" |
| `trigger_behaviors` | text[] | Actions that triggered alert |

#### `clips` (Evidence)
| Column | Type | Description |
| :--- | :--- | :--- |
| `clip_id` | uuid PK | Unique ID |
| `t_start`, `t_end` | timestamptz | Time range |
| `dog_ids` | uuid[] | Involved dogs |
| `storage_url` | text | S3 URL |
| `vector_id` | text | Milvus ID for semantic search |
| `tags` | text[] | ["high_risk", "play_peak"] |

---

## 🚀 Implementation Roadmap (Summary)

### Phase 0: Bootstrap (VLM Data Collection) - **Initial 1 Month**
**Purpose**: Collect training data for Behavior/Stress models using VLM in real-time.
*   **Enhanced Pipeline**: Camera → **YOLO Detection** → **ReID Identification** → Tagged Image Streaming → 5 Frames → VLM Analysis
    *   **Rationale**: Provide VLM with pre-identified dog information (name, bbox) as context for more accurate behavior analysis.
    *   **Implementation**: OnAirView processes frames through YOLO+ReID first, overlays detected dog names on images, then sends tagged frames to VisionClient.
*   **VLM Usage**: Existing `VisionClient.swift` analyzes tagged frames and outputs `VisionResponse` (posture, action, emotion).
*   **Data Logging**: Store VLM analysis results as `vlm_analysis_{date}.jsonl` and upload to backend.
*   **Backend Storage**: `vlm_training_samples` table in TimescaleDB + S3/MinIO for images.
*   **Curation**: Filter low-confidence samples, remove duplicates, prepare ~10k training samples.
*   **Transition**: After 1 month → Train Behavior/Stress models → Deploy to device → Disable VLM.

### Priority 0: On-Device Intelligence (Camera Mode)
*   **Core Models**: 
    *   **YOLO**: YOLOv11/v12-nano for object detection (CoreML)
    *   **ReID**: ResNet50 feature extractor for identification (CoreML)
    *   **Behavior Classifier**: Lightweight MLP/1D-CNN for action classification
        *   Input: Recent N-frame bbox trajectories (motion vectors)
        *   Output: `behaviorProbs` - {"play": 0.8, "rest": 0.1, "chase": 0.05, ...}
        *   Implementation: `Services/Vision/BehaviorHead.swift`
    *   **Stress Proxy Head**: Small regression model for stress estimation
        *   Input: Behavior probs + motion statistics
        *   Output: `stressProxy` (0~1)
        *   Implementation: Simple MLP or rule-based + calibration network
*   **Data Structures**: `DetectedObject`, `DogState`, `PairState`, `DeviceStatePacket`.
*   **State Pipeline**: YOLO -> ReID -> Behavior/Stress Head -> StateBuilder -> EventUploader.

### Phase 1: Local Foundation & Dual Mode
*   **Dual Mode UI**: Camera Mode vs Viewer Mode switcher.
*   **Dog Profile Sync**: Up/Down sync with backend.
*   **On Air UI**: Bounding box overlay with labels and actions.

### Phase 2: Backend Infrastructure (The "Memory")
*   **Server Setup**: FastAPI + Docker Compose (TimescaleDB, Milvus, MinIO, Redis).
*   **Database Schema**: Hypertables for `dog_states` and `pair_relations`.
*   **Ingestion API**: `POST /events/batch` with async bulk insert.

### Phase 3: Intelligence (The "Brain")
*   **Clip Recording**: Circular buffer with trigger-based recording.
*   **Analytics API**: Time-series queries for charts.
*   **LLM Agent**: Planner + Analyzer (Data + Expert) + Presenter.

### Phase 3.5: VLM Auto-Labeling (Gemini 2.5 Pro)
*   **Annotation Schema**: Structured JSON labels for clips.
*   **Hard Example Mining**: Select uncertain detections.
*   **Training Data Loop**: Store labels -> Retrain models.


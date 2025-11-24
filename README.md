# MyDogCare - Hybrid Edge-Cloud Dog Monitoring System

**AI-Powered Multi-Dog Blackbox Memory & Behavioral Analysis**

MyDogCare is an advanced dog monitoring and care system that combines:
- **On-Device Real-Time AI** (YOLO + ReID) for multi-dog tracking
- **Time-Series Blackbox Memory** for every second of your dog's life  
- **Evidence-Based Analysis** with video clips, charts, and expert insights
- **VLM-Powered Auto-Labeling** for continuous model improvement

## 🏗️ System Architecture

### Dual-Device Setup
*   **Camera Device (Sender)**: Dedicated iPhone at home running 24/7 monitoring
    -   YOLO object detection + ReID identification
    -   Real-time behavior & stress analysis
    -   Automatic clip recording on significant events
    -   Sends structured state packets every second

*   **Viewer Device (Receiver)**: Your personal iPhone
    -   AI Chat Interface with charts and evidence
    -   Care Calendar for manual event logging
    -   Real-time monitoring dashboard
    -   Historical analysis and reports

### Backend Services
*   **TimescaleDB**: Time-series storage for `dog_states`, `pair_relations`, `risk_events`
*   **Vector DB (Milvus)**: Semantic search for video clips
*   **S3/MinIO**: Evidence clip storage
*   **LLM Agent**: Multi-expert analyst (Data + Veterinary + Behavioral)
*   **Gemini 2.5 Pro**: Vision-language model for auto-labeling training data

## 📊 Key Features

### Real-Time Intelligence
- Multi-dog detection and tracking
- Individual identification via ReID
- Behavior classification (play, rest, chase, etc.)
- Stress level estimation
- Pair-wise relationship tracking (affinity, tension)
- Environmental logging (lux, decibel, crowding)

### Blackbox Memory
- **1-second resolution** state packets
- Normalized bbox, speed, direction for each dog
- Pair-wise distance and interaction tags
- Automatic evidence clip generation on:
  - Behavior peaks (play > 0.8)
  - Relationship changes (tension spikes)
  - Risk events (aggression, collision)

### AI Analysis
Ask questions like:
- *"Why was Bella stressed yesterday?"*
- *"When did the dogs fight last week?"*
- *"Show me clips of them playing together"*

Get responses with:
- **Text Summary** (expert interpretation)
- **Charts** (time-series visualizations)
- **Evidence Clips** (relevant video moments)

## 🚀 Quick Start

### iOS App (`ios-app/`)
```bash
cd ios-app
open MyDogCare.xcodeproj
```
See [`ios-app/README.md`](ios-app/README.md) for details.

### Backend (`backend/`)
```bash
cd backend
docker-compose up -d
poetry install
poetry run uvicorn main:app --reload
```
See [`backend/README.md`](backend/README.md) for details.

### AI Models (`ai-models/`)
```bash
cd ai-models
source venv/bin/activate
python export_yolo.py
python export_reid.py
```
See [`ai-models/README.md`](ai-models/README.md) for details.

## 📁 Project Structure
```
My-dog-care/
├── ios-app/          # iOS application (SwiftUI + CoreML)
├── backend/          # FastAPI server + databases
├── ai-models/        # Model training & export scripts
├── docs/             # Architecture & planning documents
└── README.md         # This file
```

## 📖 Documentation
- [Project Roadmap](docs/project_roadmap_new.md) - Detailed implementation checklist
- [MVP Plans](mvp/00_index.md) - MVP stage implementation plans
- [AI Integration Plan](ai_integration_plan.md) - Architecture overview
- [AI Integration Plan (한국어)](ai_integration_plan_kr.md) - 한국어 아키텍처 개요

## 🛠️ Tech Stack
- **iOS**: Swift, SwiftUI, CoreML, Vision, CoreData
- **Backend**: Python, FastAPI, TimescaleDB, Milvus, MinIO, Redis
- **AI**: YOLOv11/v12, ResNet50 (ReID), Gemini 2.5 Pro (VLM)
- **ML Framework**: PyTorch, Ultralytics, CoreMLTools

## 📝 License
MIT

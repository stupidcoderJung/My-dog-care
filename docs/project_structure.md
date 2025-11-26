# 프로젝트 구조 분석

## 저장소 타입
다중 부분 프로젝트 (Multi-part)

## 프로젝트 부분 메타데이터

### Part 1: ai-models
- **타입**: data
- **루트 경로**: /ai-models
- **기술 스택**: Python 3.11+, PyTorch, YOLO, CoreML, ONNX
- **주요 기능**: 개체 탐지, ReID(개인 식별), AI 모델 관리
- **핵심 파일**: main.py, export_yolo.py, export_reid.py

### Part 2: backend  
- **타입**: backend
- **루트 경로**: /backend
- **기술 스택**: Python 3.13+, FastAPI, DuckDB, OpenAI, Google Generative AI
- **주요 기능**: REST API, 데이터베이스, AI 통합
- **핵심 파일**: main.py, schemas.py, routers/

### Part 3: ios-app
- **타입**: mobile
- **루트 경로**: /ios-app
- **기술 스택**: Swift, SwiftUI, iOS
- **주요 기능**: 모바일 앱, 컴퓨터 비전, 채팅, 케어 캘린더
- **핵심 파일**: MyDogCareApp.swift, Views/, Services/

### Part 4: mvp
- **타입**: documentation
- **루트 경로**: /mvp
- **기술 스택**: 문서 (Markdown)
- **주요 기능**: MVP 계획, 프로젝트 로드맵
- **핵심 파일**: 각 MVP 계획 문서들

## 통합 지점
- ai-models → ios-app (CoreML 모델 통합)
- backend → ios-app (REST API 통신)
- mvp → 전체 (프로젝트 방향성)
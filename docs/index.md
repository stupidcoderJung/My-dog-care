# MyDogCare 프로젝트 문서 인덱스

## 프로젝트 개요

### 프로젝트 정보
- **타입**: 다중 부분 프로젝트 (4개 부분)
- **주요 언어**: Python, Swift
- **아키텍처**: 하이브리드 엣지-클라우드 AI 시스템

### 빠른 참조

#### AI Models (ai-models)
- **기술 스택**: Python 3.11+, PyTorch, YOLO, CoreML
- **진입점**: `ai-models/export_yolo.py`
- **아키텍처 패턴**: AI/ML 파이프라인

#### Backend (backend)
- **기술 스택**: Python 3.13+, FastAPI, DuckDB, OpenAI, Google AI
- **진입점**: `backend/main.py`
- **아키텍처 패턴**: 마이크로서비스

#### iOS App (ios-app)
- **기술 스택**: Swift 5.9+, SwiftUI, CoreML, Vision
- **진입점**: `ios-app/MyDogCare/MyDogCareApp.swift`
- **아키텍처 패턴**: MVVM + Combine

#### MVP Planning (mvp)
- **기술 스택**: Markdown
- **진입점**: `mvp/00_index.md`
- **아키텍처 패턴**: 문서 중심

## 생성된 문서

### 프로젝트 문서
- [프로젝트 개요](./project-overview.md)
- [프로젝트 구조 분석](./project_structure.md)
- [소스 트리 분석](./source-tree-analysis.md)
- [기존 문서 인벤토리](./existing_documentation_inventory.md)

### 아키텍처 문서
- [AI Models 아키텍처](./architecture-ai-models.md)
- [Backend 아키텍처](./architecture-backend.md)
- [iOS App 아키텍처](./architecture-ios-app.md)
- [통합 아키텍처](./integration-architecture.md)

### 기술 문서
- [기술 스택 분석](./technology_stack.md)
- [개발 가이드](./development-guide.md)

### API 및 데이터 문서
- [API 계약 - Backend](./api-contracts-backend.md)
- [데이터 모델 - Backend](./data-models-backend.md)
- [UI 컴포넌트 인벤토리 - iOS App](./ui-component-inventory-ios-app.md)

## 기존 문서

### 프로젝트 루트 문서
- [README.md](../README.md) - 전체 시스템 개요 (117줄)
- [ai-models/README.md](../ai-models/README.md) - AI 모델 상세 설명 (155줄)
- [backend/README.md](../backend/README.md) - 백엔드 아키텍처 (89줄)
- [ios-app/README.md](../ios-app/README.md) - iOS 앱 기능 (82줄)

### 기획 문서
- [project_roadmap_new.md](../project_roadmap_new.md) - 프로젝트 로드맵
- [ai_integration_plan.md](../ai_integration_plan.md) - 아키텍처 개요
- [ai_integration_plan_kr.md](../ai_integration_plan_kr.md) - 한국어 아키텍처

## 시작하기

### 개발 환경 설정

#### 1. AI 모델 개발
```bash
cd ai-models
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python export_yolo.py
python export_reid.py
```

#### 2. 백엔드 개발
```bash
cd backend
uv sync
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

#### 3. iOS 앱 개발
```bash
cd ios-app
open MyDogCare.xcodeproj
# Xcode에서 빌드 및 실행
```

### API 엔드포인트
- **백엔드**: `http://localhost:8001`
- **API 문서**: `http://localhost:8001/docs`
- **이벤트 수신**: `POST /events/batch`
- **AI 채팅**: `POST /chat`

### 데이터 흐름
```
iOS 카메라 → VisionService → YOLO/ReID → 상태 분석 → EventUploader → Backend API → DuckDB
사용자 질의 → Chat API → LLM → SQL → DuckDB → 분석 결과
```

## 프로젝트 부분별 상세 정보

### AI Models (ai-models)
- **역할**: AI 모델 학습 및 CoreML 변환
- **주요 파일**: `export_yolo.py`, `export_reid.py`, `main.py`
- **출력물**: `yolo11n.mlpackage`, `ResNet50_ReID.mlmodel`
- **의존성**: PyTorch, Ultralytics, CoreML Tools

### Backend (backend)
- **역할**: REST API 서버 및 데이터 저장
- **주요 파일**: `main.py`, `routers/events.py`, `routers/chat.py`
- **데이터베이스**: DuckDB (`dog_care.duckdb`)
- **의존성**: FastAPI, DuckDB, OpenAI, Google AI

### iOS App (ios-app)
- **역할**: SwiftUI 모바일 앱 및 온디바이스 AI
- **주요 파일**: `MyDogCareApp.swift`, `Views/MainView.swift`, `Services/Vision/VisionService.swift`
- **Core ML 모델**: `Resources/Models/` 폴더
- **의존성**: SwiftUI, Core ML, Vision, Core Data

### MVP Planning (mvp)
- **역할**: 개발 계획 및 문서화
- **주요 파일**: `00_index.md`, 각 단계별 계획 문서
- **형식**: Markdown 문서
- **목적**: 개발 방향성 및 우선순위 제공

## 통합 지점

### 모델 배포
- **흐름**: `ai-models → CoreML → iOS App`
- **방식**: 수동 파일 복사
- **개선 필요**: 자동화된 배포 파이프라인

### API 통신
- **흐름**: `iOS App → HTTP → Backend API`
- **엔드포인트**: `/events/batch`, `/chat`
- **데이터 형식**: JSON (DeviceStatePacket)

### AI 통합
- **흐름**: `Backend → LLM APIs → SQL → 분석`
- **LLM**: Qwen3-Next-80B (NVIDIA), OpenAI, Google AI
- **기능**: 자연어 → SQL 변환 및 실행

## 기술적 특징

### AI/ML 기능
- **객체 탐지**: YOLOv11-nano (실시간)
- **개인 식별**: ResNet50 ReID (Int8 최적화)
- **행동 분석**: 다중 클래스 행동 분류
- **스트레스 추정**: 행동 기반 스트레스 지수

### 데이터 처리
- **실시간 처리**: 1초 간격 상태 패킷
- **시계열 저장**: DuckDB OLAP 데이터베이스
- **배치 처리**: 대량 데이터 효율적 삽입
- **오프라인 지원**: 네트워크 장애 시 데이터 버퍼

### 사용자 인터페이스
- **실시간 모니터링**: OnAirView
- **AI 채팅**: 자연어 질의응답
- **케어 캘린더**: 수동 이벤트 관리
- **강아지 관리**: 프로필 및 사진 관리

## 개발 상태

### 현재 상태
- **MVP 단계**: 핵심 기능 구현 완료
- **통합 상태**: 기본 부분 간 통합 완료
- **테스트**: 개별 부분 단위 테스트 완료
- **배포**: 로컬 개발 환경 구성 완료

### 알려진 이슈
- **코드 품질**: 일부 타입 오류 및 임포트 문제
- **자동화**: 모델 배포 및 테스트 자동화 부족
- **인증**: API 인증 미구현
- **문서**: 일부 문서 최신화 필요

### 향후 개선 방향
- **코드 품질**: 타입 오류 수정 및 코드 정리
- **자동화**: CI/CD 파이프라인 구축
- **보안**: API 인증 및 HTTPS 적용
- **확장성**: 마이크로서비스 아키텍처 전환

---

*이 문서는 MyDogCare 프로젝트의 전체적인 개요를 제공합니다. 각 부분의 상세 기술 정보는 해당 아키텍처 문서를 참조하세요.*
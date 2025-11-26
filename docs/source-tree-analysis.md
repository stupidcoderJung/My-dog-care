# 소스 트리 분석

## 프로젝트 구조 개요
MyDogCare는 4개의 주요 부분으로 구성된 다중 부분 프로젝트입니다.

```
My-dog-care-codex-delete-repository-contents-and-create-swift-project/
├── ai-models/                    # AI 모델 학습 및 내보내기
│   ├── export_yolo.py             # YOLO CoreML 내보내기
│   ├── export_reid.py             # ReID CoreML 내보내기
│   ├── main.py                    # 모델 실행
│   ├── requirements.txt            # Python 의존성
│   └── pyproject.toml             # 프로젝트 설정
│
├── backend/                       # FastAPI 백엔드 서비스
│   ├── main.py                    # 앱 진입점
│   ├── db.py                      # DuckDB 연결
│   ├── config.py                  # 설정 관리
│   ├── schemas.py                 # Pydantic 모델
│   ├── routers/                   # API 라우터
│   │   ├── events.py              # 이벤트 수신 API
│   │   ├── dogs.py                # 강아지 관리 API
│   │   └── chat.py                # AI 채팅 API
│   └── data/                      # 데이터베이스 파일
│       └── dog_care.duckdb        # DuckDB 데이터베이스
│
├── ios-app/                       # SwiftUI iOS 앱
│   ├── MyDogCare/                # 메인 앱 타겟
│   │   ├── MyDogCareApp.swift     # 앱 진입점
│   │   ├── Views/                 # SwiftUI 뷰
│   │   │   ├── MainView.swift      # 메인 탭 뷰
│   │   │   ├── OnAirView.swift    # 실시간 모니터링
│   │   │   ├── ChatView.swift     # AI 채팅
│   │   │   ├── CareCalendarView.swift # 케어 캘린더
│   │   │   └── [기타 뷰들...]
│   │   ├── Services/              # 비즈니스 로직
│   │   │   ├── Vision/           # 컴퓨터 비전
│   │   │   │   ├── VisionService.swift
│   │   │   │   ├── YOLOClient.swift
│   │   │   │   ├── ReIDTracker.swift
│   │   │   │   └── [추적 관련...]
│   │   │   ├── Network/          # 네트워크
│   │   │   │   └── EventUploader.swift
│   │   │   └── [기타 서비스...]
│   │   ├── Models/                # 데이터 모델
│   │   │   ├── Dog.swift
│   │   │   ├── DogState.swift
│   │   │   └── [기타 모델...]
│   │   └── Resources/Models/     # Core ML 모델
│   │       ├── yolo11n.mlpackage
│   │       └── ResNet50_ReID.mlmodel
│   └── MyDogCare.xcodeproj/      # Xcode 프로젝트
│
├── mvp/                          # MVP 계획 문서
│   ├── 01_yolo_reid_integration/ # YOLO+ReID 통합
│   ├── 02_vlm_tagged_input/       # VLM 태깅 입력
│   ├── [기타 MVP 계획들...]
│   └── 00_index.md               # MVP 인덱스
│
├── docs/                         # 프로젝트 문서
│   ├── project_structure.md       # 프로젝트 구조
│   ├── technology_stack.md        # 기술 스택
│   ├── api-contracts-backend.md   # API 계약
│   ├── data-models-backend.md     # 데이터 모델
│   ├── ui-component-inventory-ios-app.md # UI 컴포넌트
│   └── [기타 문서들...]
│
└── README.md                     # 프로젝트 개요
```

## 핵심 디렉토리 설명

### ai-models/ - AI 모델 개발
**목적**: YOLO 객체 탐지 및 ReID 모델 학습/내보내기
- **export_yolo.py**: YOLO 모델을 CoreML 형식으로 변환
- **export_reid.py**: ReID 모델을 CoreML 형식으로 변환  
- **main.py**: 모델 추론 및 테스트
- **requirements.txt**: PyTorch, Ultralytics, CoreML Tools 등

### backend/ - API 서버
**목적**: FastAPI 기반 REST API 및 데이터 저장
- **main.py**: FastAPI 앱 설정 및 라우터 등록
- **db.py**: DuckDB 연결 및 초기화
- **routers/events.py**: iOS 앱으로부터 상태 패킷 수신
- **routers/chat.py**: AI 채팅 및 SQL 쿼리 기능
- **data/dog_care.duckdb**: 시계열 데이터 저장소

### ios-app/ - iOS 애플리케이션
**목적**: SwiftUI 기반 모바일 앱 및 온디바이스 AI
- **MyDogCareApp.swift**: SwiftUI 앱 진입점
- **Views/**: 사용자 인터페이스 컴포넌트
- **Services/Vision/**: 컴퓨터 비전 파이프라인
- **Models/**: 데이터 모델 및 Core Data 관리
- **Resources/Models/**: Core ML 모델 파일

### mvp/ - 개발 계획
**목적**: 단계별 MVP 개발 계획 및 문서
- 각 하위 폴더: 특정 기능에 대한 상세 계획
- **00_index.md**: 전체 MVP 로드맵

## 데이터 흐름

### 1. AI 모델 파이프라인
```
ai-models/ → CoreML 모델 → ios-app/Resources/Models/
```

### 2. 데이터 수집 파이프라인
```
ios-app/VisionService → HTTP POST → backend/routers/events.py → DuckDB
```

### 3. AI 분석 파이프라인
```
사용자 질의 → backend/routers/chat.py → LLM → SQL 쿼리 → DuckDB → 분석 결과
```

## 기술 스택별 중요 파일

### Python/FastAPI
- `backend/main.py` - 앱 진입점
- `backend/routers/chat.py` - AI 통합
- `ai-models/export_yolo.py` - 모델 변환

### Swift/SwiftUI  
- `ios-app/MyDogCare/MyDogCareApp.swift` - 앱 진입점
- `ios-app/MyDogCare/Views/MainView.swift` - 메인 UI
- `ios-app/MyDogCare/Services/Vision/VisionService.swift` - 컴퓨터 비전

### AI/ML
- `ios-app/Resources/Models/yolo11n.mlpackage` - 객체 탐지 모델
- `ios-app/Resources/Models/ResNet50_ReID.mlmodel` - 개체 식별 모델

## 통합 지점

### 1. 모델 배포
- ai-models에서 생성된 CoreML 모델을 iOS 앱에 통합
- 자동화된 모델 업데이트 파이프라인 필요

### 2. API 통신
- iOS 앱의 EventUploader가 백엔드 API와 통신
- REST API를 통한 실시간 데이터 동기화

### 3. 데이터 분석
- 백엔드에서 수집된 데이터를 AI로 분석
- LLM을 통한 자연어 질의응답

## 개발 환경 설정

### AI 모델 개발
```bash
cd ai-models
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python export_yolo.py
python export_reid.py
```

### 백엔드 개발
```bash
cd backend
uv sync
uv run uvicorn main:app --reload
```

### iOS 앱 개발
```bash
cd ios-app
open MyDogCare.xcodeproj
# Xcode에서 빌드 및 실행
```

## 배포 아키텍처

### 현재 상태
- **개발 환경**: 로컬에서 각 부분 독립 실행
- **데이터 저장**: 로컬 DuckDB 파일
- **모델 배포**: 수동으로 iOS 프로젝트에 복사

### 향후 개선
- **CI/CD 파이프라인**: 자동화된 빌드 및 배포
- **클라우드 데이터베이스**: 프로덕션 환경 데이터 저장
- **모델 버전 관리**: 자동화된 모델 업데이트
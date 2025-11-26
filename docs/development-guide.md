# 개발 가이드

## 개발 환경 설정

### 1. AI 모델 개발 (ai-models/)

#### 필수 조건
- Python 3.11+
- CUDA 지원 GPU (권장)

#### 설정 단계
```bash
# 1. 가상 환경 생성
cd ai-models
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 2. 의존성 설치
pip install -r requirements.txt

# 3. 모델 다운로드 (자동)
# YOLOv11-nano 모델이 자동으로 다운로드됩니다

# 4. CoreML 모델 내보내기
python export_yolo.py      # YOLO → CoreML
python export_reid.py      # ReID → CoreML
```

#### 주요 스크립트
- `export_yolo.py`: YOLO 모델을 CoreML 형식으로 변환
- `export_reid.py`: ReID 모델을 CoreML 형식으로 변환
- `main.py`: 모델 추론 테스트

### 2. 백엔드 개발 (backend/)

#### 필수 조건
- Python 3.13+
- NVIDIA API Key (무료 사용 가능)

#### 설정 단계
```bash
# 1. 의존성 설치 (uv 사용 권장)
cd backend
uv sync  # pip install -r requirements.txt

# 2. 환경 변수 설정
# config.py에 API 키가 이미 설정되어 있음
# 또는 환경 변수: export NVIDIA_API_KEY=your_key

# 3. 데이터베이스 초기화
# 자동으로 생성됨 (data/dog_care.duckdb)

# 4. 서버 실행
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

#### API 엔드포인트
- `http://localhost:8001/docs` - Swagger UI
- `http://localhost:8001` - 상태 확인
- `POST /events/batch` - 데이터 수신
- `POST /chat` - AI 채팅

### 3. iOS 앱 개발 (ios-app/)

#### 필수 조건
- Xcode 15+
- iOS 17+ 기기
- Apple Developer 계계 (실기기 테스트)

#### 설정 단계
```bash
# 1. Xcode 프로젝트 열기
cd ios-app
open MyDogCare.xcodeproj

# 2. 모델 파일 확인
# Resources/Models/에 다음 파일이 있어야 함:
# - yolo11n.mlpackage
# - ResNet50_ReID.mlmodel

# 3. 빌드 및 실행
# Xcode에서 ⌘+R 또는 실행 버튼 클릭
```

#### 주요 설정
- **Deployment Target**: iOS 17.0+
- **Bundle Identifier**: com.mydogcare.app
- **Capabilities**: Camera, Photo Library

## 테스트

### 1. 백엔드 테스트
```bash
cd backend

# API 상태 확인
curl http://localhost:8001

# 이벤트 전송 테스트
curl -X POST http://localhost:8001/events/batch \
  -H "Content-Type: application/json" \
  -d '{"packets": []}'

# 채팅 테스트
curl -X POST http://localhost:8001/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "테스트"}'
```

### 2. AI 모델 테스트
```bash
cd ai-models
source venv/bin/activate

# YOLO 추론 테스트
python main.py

# 모델 내보내기 테스트
python export_yolo.py
python export_reid.py
```

### 3. iOS 앱 테스트
- Xcode 시뮬레이터에서 실행
- 실기기에서 테스트 (카메라 권한 필요)
- Core ML 모델 로딩 확인

## 빌드 프로세스

### 1. AI 모델 빌드
```bash
# PyTorch → ONNX → CoreML 파이프라인
python export_yolo.py  # NMS 포함, FP16
python export_reid.py  # Int8 양자화
```

### 2. 백엔드 빌드
```bash
# 개발용
uv run uvicorn main:app --reload

# 프로덕션용
uv run uvicorn main:app --host 0.0.0.0 --port 8001
```

### 3. iOS 앱 빌드
```bash
# Xcode에서:
# - ⌘+B: 빌드
# - ⌘+R: 실행
# - ⌘+⇧+B: 아카이브 빌드
```

## 공통 개발 작업

### 1. 코드 스타일
- **Python**: Black + isort 사용 권장
- **Swift**: SwiftLint 기준 준수

### 2. Git 워크플로우
```bash
# 기본 브랜치: main
# 피처 브랜치: feature/기능명
# 커밋 메시지: feat: 기능 설명
```

### 3. 디버깅
- **백엔드**: 로그 레벨 INFO로 설정
- **iOS**: Xcode 콘솔 및 디버거 사용
- **AI 모델**: 추론 결과 시각화

## 문제 해결

### 일반적인 문제

#### 1. 모델 로딩 실패
- iOS: Resources/Models/ 경로 확인
- 권한: 앱 번들에 모델 포함되었는지 확인

#### 2. API 연결 실패
- 백엔드: 서버 실행 상태 확인
- iOS: 백엔드 URL 설정 확인 (EventUploader)

#### 3. 카메라 권한
- iOS: Info.plist에 카메라 권한 추가
- 실기기: 설정 → 개인정보 보호 → 카메라

### 성능 최적화

#### 1. AI 모델
- YOLO: nano 모델 사용 (속도 우선)
- ReID: Int8 양자화로 크기 감소

#### 2. 백엔드
- DuckDB: 시계열 데이터 최적화
- 배치 처리: 대량 데이터 삽입 사용

#### 3. iOS 앱
- 프레임 스트라이드: 2프레임 간격 처리
- 메모리 관리: Core Data 자동 관리 사용

## 배포 준비

### 1. 백엔드 배포
```bash
# Docker화 (향후)
# docker build -t mydogcare-backend .
# docker run -p 8001:8001 mydogcare-backend
```

### 2. iOS 앱 배포
- App Store Connect에 앱 업로드
- TestFlight 베타 테스트
- App Store 심사 제출

### 3. 모델 버전 관리
- 모델 버전 태깅
- Core ML 모델 버전 관리
- 호환성 테스트
# 기술 스택 분석

## Part 1: ai-models (Data/AI 프로젝트)

### 핵심 기술
| 카테고리 | 기술 | 버전 | 용도 |
|---------|------|------|------|
| 언어 | Python | 3.11+ | 기본 개발 언어 |
| ML 프레임워크 | PyTorch | 2.2.2 | 딥러닝 모델 학습 |
| 객체 탐지 | YOLO/Ultralytics | 8.3.230+ | 실시간 개체 탐지 |
| 모델 변환 | CoreML Tools | 9.0 | iOS용 모델 변환 |
| 모델 포맷 | ONNX | 1.16.0+ | 모델 교환 포맷 |
| 수치 계산 | NumPy | <2.0 | 배열 연산 |
| 컴퓨터 비전 | OpenCV | 4.11.0.86 | 이미지 처리 |
| 시각화 | Matplotlib | 3.10.7 | 결과 시각화 |

### 아키텍처 패턴
- **AI/ML 파이프라인**: 데이터 수집 → 전처리 → 모델 학습 → 내보내기
- **모델 최적화**: PyTorch → ONNX → CoreML 변환 파이프라인
- **VLM 통합**: Gemini 2.5 Pro를 통한 자동 레이블링

---

## Part 2: backend (Backend 프로젝트)

### 핵심 기술
| 카테고리 | 기술 | 버전 | 용도 |
|---------|------|------|------|
| 언어 | Python | 3.13+ | 기본 개발 언어 |
| 웹 프레임워크 | FastAPI | 0.122.0+ | REST API 서버 |
| 데이터베이스 | DuckDB | 1.4.2+ | 임베디드 OLAP DB |
| AI 통합 | OpenAI | 2.8.1+ | GPT 모델 연동 |
| AI 통합 | Google Generative AI | 0.8.5+ | Gemini 모델 연동 |
| AI 에이전트 | Qwen Agent | 0.0.31 | LLM 에이전트 |
| 데이터 처리 | Pandas | 2.3.3 | 데이터 분석 |
| 데이터 검증 | Pydantic | 2.12.4+ | 데이터 모델링 |
| ASGI 서버 | Uvicorn | 0.38.0+ | 비동기 웹 서버 |

### 아키텍처 패턴
- **마이크로서비스**: FastAPI 기반의 경량화된 API 서비스
- **임베디드 데이터베이스**: DuckDB를 통한 고성능 시계열 데이터 저장
- **AI 통합**: 다중 LLM 제공업체 연동 (OpenAI, Google, Qwen)

---

## Part 3: ios-app (Mobile 프로젝트)

### 핵심 기술
| 카테고리 | 기술 | 버전 | 용도 |
|---------|------|------|------|
| 언어 | Swift | 5.9+ | iOS 개발 언어 |
| UI 프레임워크 | SwiftUI | - | 선언형 UI |
| 머신러닝 | CoreML | - | 온디바이스 AI 추론 |
| 컴퓨터 비전 | Vision | - | 이미지 분석 |
| 데이터 저장 | Core Data | - | 로컬 데이터 저장 |
| 비동기 처리 | Combine | - | 반응형 프로그래밍 |
| 모델 | YOLOv11-nano | - | 실시간 객체 탐지 |
| 모델 | ResNet50 ReID | - | 개체 재식별 |

### 아키텍처 패턴
- **온디바이스 AI**: CoreML을 통한 실시간 추론
- **MVVM**: SwiftUI + Combine 기반의 아키텍처
- **듀얼 디바이스**: 카메라/뷰어 모드 분리 운영

---

## Part 4: mvp (Documentation 프로젝트)

### 핵심 기술
| 카테고리 | 기술 | 버전 | 용도 |
|---------|------|------|------|
| 문서 형식 | Markdown | - | 기술 문서화 |
| 계획 관리 | Text | - | MVP 로드맵 |

### 아키텍처 패턴
- **문서 중심**: Markdown 기반의 경량화된 계획 관리

---

## 통합 아키텍처

### 부분 간 통합
1. **ai-models → ios-app**: CoreML 모델 배포
2. **backend → ios-app**: REST API 통신  
3. **mvp → 전체**: 프로젝트 방향성 및 계획

### 기술 스택 요약
- **프론트엔드**: Swift/SwiftUI (iOS)
- **백엔드**: Python/FastAPI
- **AI/ML**: PyTorch, CoreML, YOLO
- **데이터**: DuckDB, Core Data
- **통합**: REST API, 모델 파일 교환
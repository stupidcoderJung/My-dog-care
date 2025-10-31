# PupHealth-RT: 반려견 건강 실시간 추적

## NVDINOv2로 프레임 특징/자세를 추출하고, qwen3-vl·LLM으로 요약/설명, SKLearn으로 이상탐지를 수행합니다.
 - 요구사항: Python 3.10+, PyTorch, OpenCV, FastAPI, scikit-learn, qwen3-vl(로컬/서빙), PostgreSQL/TimescaleDB, Redis.
 - 설치: `pip install -r requirements.txt` (선택) `pre-commit install`.
 - 데이터: `data/` 이미지 또는 `CAMERA_URL` 스트림; 주석 도구는 `tools/label/`.
 - 학습: `python train_nvdinov2.py` (특징추출기 미세조정) → `python train_sklearn.py` (이상탐지/분류).
 - 실행: `uvicorn app.main:app --reload`; 대시보드 `/dashboard`; 웹훅 알림은 `ALERT_WEBHOOK` 환경변수.
 - 설정: `config.yaml`에서 모델 경로(qwen3-vl, NVDINOv2), 임계치, 샘플링 주기, 저장소(로컬/DB) 지정.
 - 사용: REST `/ingest`(업로드) `/analyze`(프레임 분석) `/trends`(지표/추세); 한국어 프롬프트 질의 지원.
 - 고지: 본 프로젝트는 의료기기가 아니며, 개인정보는 로컬 우선 처리(옵션: 익명화된 동기화).

# MyDogCare Backend (MVP)

FastAPI + DuckDB 기반의 경량화된 고성능 백엔드입니다.
iOS 앱에서 전송되는 강아지 행동 데이터를 저장하고, LLM을 통해 자연어로 질의할 수 있습니다.

## 🏗️ Architecture

- **Web Framework**: FastAPI (Async, Auto Docs)
- **Database**: DuckDB (Embedded OLAP, High Performance, SQL Standard)
- **AI Integration**: Qwen Agent + NVIDIA API (Tool Calling for SQL Execution)
  - Model: `qwen/qwen3-next-80b-a3b-thinking`
  - 무료 NVIDIA API 사용 (비용 걱정 없음!)


## 🚀 Features

1.  **Event Ingestion**: `POST /events/batch`
    - iOS `DeviceStatePacket` 대량 수신 및 고속 저장
2.  **Dog Management**: `POST /dogs`, `GET /dogs`
    - 강아지 프로필 관리 및 동기화
3.  **AI Chat**: `POST /chat`
    - "오늘 버디가 얼마나 놀았어?" -> SQL 변환 -> 결과 분석 -> 답변

## 🛠️ Setup (using uv)

```bash
# 1. 의존성 설치 (uv가 자동으로 venv 생성 및 패키지 설치)
cd backend
uv sync

# 2. 서버 실행
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload

# 접속: http://localhost:8001
# API 문서: http://localhost:8001/docs
```

**참고:** NVIDIA API Key는 `config.py`에 하드코딩되어 있습니다. (무료 사용 가능)


## 📁 Directory Structure

```
backend/
├── main.py             # App Entrypoint
├── db.py               # DuckDB Connection & Init
├── config.py           # Settings
├── schemas.py          # Pydantic Models
├── routers/
│   ├── events.py       # Event Ingestion API
│   ├── dogs.py         # Dog Profile API
│   └── chat.py         # LLM Chat API
└── data/
    └── dog_care.duckdb # Database File
```

## 💬 Usage Examples

### 1. iOS 앱에서 데이터 전송
iOS 앱의 `EventUploader`를 `http://<your-ip>:8001`로 설정하면 자동으로 데이터가 쌓입니다.

### 2. LLM 채팅 테스트

```bash
# 테이블 확인
curl -L -X POST http://localhost:8001/chat/ \
  -H "Content-Type: application/json" \
  -d '{"query": "데이터베이스에 어떤 테이블이 있어?"}' | jq

# 강아지 수 확인
curl -L -X POST http://localhost:8001/chat/ \
  -H "Content-Type: application/json" \
  -d '{"query": "등록된 강아지가 몇 마리야?"}' | jq

# 시계열 데이터 쿼리
curl -L -X POST http://localhost:8001/chat/ \
  -H "Content-Type: application/json" \
  -d '{"query": "최근 1시간 동안 기록된 행동 데이터는 몇 개야?"}' | jq
```

**백엔드 로그에서 LLM이 생성한 SQL과 실행 결과를 실시간으로 확인할 수 있습니다!**

```
INFO:routers.chat:🔧 Tool Call: execute_sql_query
INFO:routers.chat:📝 SQL Query: SELECT COUNT(*) FROM dog_states WHERE t > now() - INTERVAL '1 hour';
INFO:routers.chat:✅ Rows returned: 1
```


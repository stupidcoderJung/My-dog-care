from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid

# --- Dog Profile ---
class DogCreate(BaseModel):
    id: uuid.UUID
    name: str
    breed: str
    photoId: Optional[str] = None

class DogResponse(DogCreate):
    createdAt: Optional[datetime] = None

# --- State Packet (수정: iOS 형식에 맞춤) ---
class BboxNorm(BaseModel):
    cx: float
    cy: float
    w: float
    h: float

class DogState(BaseModel):
    dogId: Optional[uuid.UUID] = None
    bboxNorm: BboxNorm  # 객체 형식
    speedPx: Optional[float] = None
    directionRad: Optional[float] = None
    behaviorProbs: Optional[Dict[str, float]] = None
    stressProxy: Optional[float] = None
    # iOS 추가 필드 (저장은 안 하지만 받아들임)
    vlmAction: Optional[str] = None
    vlmEmotion: Optional[str] = None
    vlmPosture: Optional[str] = None
    vlmHealth: Optional[str] = None
    vlmNotes: Optional[str] = None
    tempTrackId: Optional[int] = None
    timestamp: Optional[str] = None  # iOS가 보내는 개별 타임스탬프

class PairState(BaseModel):
    dogIId: uuid.UUID
    dogJId: uuid.UUID
    distanceNorm: float
    affinityScore: Optional[float] = None
    tensionScore: Optional[float] = None
    interactionTags: List[str] = []

class EnvironmentState(BaseModel):
    lux: Optional[float] = None
    decibel: Optional[float] = None
    crowding: Optional[int] = None

class DeviceStatePacket(BaseModel):
    timestamp: str  # ISO 8601 문자열로 변경
    deviceId: str
    sessionId: str
    fps: Optional[float] = None
    dogs: List[DogState]
    relations: Optional[List[PairState]] = None
    environment: Optional[EnvironmentState] = None

# iOS는 배열을 직접 보내므로 BatchEvents 타입 제거
# events.py에서 직접 List[DeviceStatePacket]를 사용

# --- Chat ---
class ChatRequest(BaseModel):
    query: str

class ChatResponse(BaseModel):
    answer: str
    sql: Optional[str] = None
    data: Optional[List[Dict[str, Any]]] = None

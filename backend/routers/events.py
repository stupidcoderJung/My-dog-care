from fastapi import APIRouter, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from schemas import DeviceStatePacket
from db import get_db_connection
from typing import List
import json
import logging
from datetime import datetime

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/events", tags=["events"])

@router.post("/batch")
async def ingest_batch(request: Request, packets: List[DeviceStatePacket]):
    # Log raw body for debugging
    try:
        body = await request.body()
        body_str = body.decode('utf-8')
        logger.info(f"📦 Full Request Body: {body_str}")
    except Exception as e:
        logger.error(f"Failed to log body: {e}")
    
    logger.info(f"📦 Received {len(packets)} packets")
    
    con = get_db_connection()
    
    # Prepare data for bulk insert
    dog_states_data = []
    pair_relations_data = []
    
    for packet in packets:
        # Parse ISO timestamp to datetime
        try:
            ts = datetime.fromisoformat(packet.timestamp.replace('Z', '+00:00'))
        except:
            ts = datetime.now()
        
        # 1. Dog States
        for dog in packet.dogs:
            dog_states_data.append((
                ts,
                packet.deviceId,
                packet.sessionId,
                dog.dogId,
                dog.bboxNorm.cx, dog.bboxNorm.cy, dog.bboxNorm.w, dog.bboxNorm.h,
                dog.speedPx,
                dog.directionRad,
                json.dumps(dog.behaviorProbs) if dog.behaviorProbs else None,
                dog.stressProxy,
                packet.environment.lux if packet.environment else None,
                packet.environment.decibel if packet.environment else None,
                dog.vlmAction,
                dog.vlmEmotion,
                dog.vlmPosture,
                dog.vlmHealth,
                dog.vlmNotes
            ))
            
        # 2. Pair Relations
        if packet.relations:
            for pair in packet.relations:
                pair_relations_data.append((
                    ts,
                    packet.deviceId,
                    packet.sessionId,
                    pair.dogIId,
                    pair.dogJId,
                    pair.distanceNorm,
                    pair.affinityScore,
                    pair.tensionScore,
                    pair.interactionTags
                ))
    
    # Bulk Insert
    try:
        if dog_states_data:
            con.executemany("""
                INSERT INTO dog_states VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, dog_states_data)
            logger.info(f"✅ Inserted {len(dog_states_data)} dog states")
            
        if pair_relations_data:
            con.executemany("""
                INSERT INTO pair_relations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, pair_relations_data)
            logger.info(f"✅ Inserted {len(pair_relations_data)} pair relations")
            
        return {"status": "ok", "inserted_packets": len(packets)}
        
    except Exception as e:
        logger.error(f"❌ Error inserting batch: {e}")
        raise HTTPException(status_code=500, detail=str(e))

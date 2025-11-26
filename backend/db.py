import duckdb
import logging
from config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

# Global connection (DuckDB is thread-safe for read/write with a single connection in many cases, 
# but for web apps, creating a cursor per request is safer or using a connection pool pattern.
# DuckDB Python client manages concurrency well on a single connection object.)
_con = None

def get_db_connection():
    global _con
    if _con is None:
        _con = duckdb.connect(settings.DATABASE_URL)
    return _con

def init_db():
    con = get_db_connection()
    
    # Create tables
    con.execute("""
        CREATE TABLE IF NOT EXISTS dogs (
            id UUID PRIMARY KEY,
            name VARCHAR,
            breed VARCHAR,
            photo_id VARCHAR,
            created_at TIMESTAMP
        );
    """)
    
    con.execute("""
        CREATE TABLE IF NOT EXISTS dog_states (
            t TIMESTAMP,
            device_id VARCHAR,
            session_id VARCHAR,
            dog_id UUID,
            bbox_cx FLOAT,
            bbox_cy FLOAT,
            bbox_w FLOAT,
            bbox_h FLOAT,
            speed_px FLOAT,
            direction_rad FLOAT,
            behavior_probs JSON,
            stress_proxy FLOAT,
            environment_lux FLOAT,
            environment_db FLOAT,
            vlm_action VARCHAR,
            vlm_emotion VARCHAR,
            vlm_posture VARCHAR,
            vlm_health VARCHAR,
            vlm_notes VARCHAR
        );
    """)

    # Migration: Add columns individually
    columns_to_add = [
        "vlm_action VARCHAR",
        "vlm_emotion VARCHAR",
        "vlm_posture VARCHAR",
        "vlm_health VARCHAR",
        "vlm_notes VARCHAR"
    ]
    
    for col_def in columns_to_add:
        try:
            con.execute(f"ALTER TABLE dog_states ADD COLUMN {col_def}")
            logger.info(f"✅ Added column: {col_def}")
        except:
            pass # Column likely exists
    
    con.execute("""
        CREATE TABLE IF NOT EXISTS pair_relations (
            t TIMESTAMP,
            device_id VARCHAR,
            session_id VARCHAR,
            dog_i_id UUID,
            dog_j_id UUID,
            distance_norm FLOAT,
            affinity_score FLOAT,
            tension_score FLOAT,
            interaction_tags VARCHAR[]
        );
    """)
    
    logger.info("Database initialized successfully.")

def close_db():
    global _con
    if _con:
        _con.close()
        _con = None

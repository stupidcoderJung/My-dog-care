from fastapi import APIRouter, HTTPException
from schemas import ChatRequest, ChatResponse
from db import get_db_connection
from config import get_settings
from qwen_agent.agents import Assistant
from qwen_agent.tools.base import BaseTool, register_tool
import logging
import json

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])
settings = get_settings()

# Define custom SQL execution tool for Qwen Agent
@register_tool('execute_sql_query')
class SQLExecutorTool(BaseTool):
    description = 'Execute a SQL query on the DuckDB database and return results'
    parameters = [{
        'name': 'query',
        'type': 'string',
        'description': 'The SQL query to execute (DuckDB syntax)',
        'required': True
    }]

    def call(self, params: str, **kwargs) -> str:
        """Execute SQL query and return results as JSON string"""
        try:
            # Parse params
            params_dict = json.loads(params) if isinstance(params, str) else params
            query = params_dict.get('query')
            
            logger.info(f"🔧 Tool Call: execute_sql_query")
            logger.info(f"📝 SQL Query: {query}")
            
            # Execute query
            con = get_db_connection()
            result = con.execute(query).fetchdf()
            data = result.to_dict(orient='records')
            
            logger.info(f"✅ Rows returned: {len(data)}")
            
            return json.dumps({
                "success": True,
                "data": data,
                "row_count": len(data)
            }, default=str)
            
        except Exception as e:
            logger.error(f"❌ SQL Error: {e}")
            return json.dumps({
                "success": False,
                "error": str(e)
            })

# Configure LLM for Qwen Agent
llm_cfg = {
    'model': 'qwen/qwen3-next-80b-a3b-thinking',
    'model_server': settings.NVIDIA_BASE_URL,
    'api_key': settings.NVIDIA_API_KEY,
}

# System prompt with DB schema info
SYSTEM_MESSAGE = """
You are a Dog Care Analytics Assistant with access to a DuckDB database.

Available tables:
1. dogs (id UUID, name VARCHAR, breed VARCHAR, photo_id VARCHAR, created_at TIMESTAMP)
2. dog_states (t TIMESTAMP, device_id VARCHAR, session_id VARCHAR, dog_id UUID, 
   bbox_cx FLOAT, bbox_cy FLOAT, bbox_w FLOAT, bbox_h FLOAT,
   speed_px FLOAT, direction_rad FLOAT,
   behavior_probs JSON, stress_proxy FLOAT,
   environment_lux FLOAT, environment_db FLOAT,
   vlm_action VARCHAR, vlm_emotion VARCHAR,
   vlm_posture VARCHAR, vlm_health VARCHAR, vlm_notes VARCHAR)
   - vlm_action: Action (e.g., "sleeping", "running")
   - vlm_emotion: Emotion (e.g., "happy", "relaxed")
   - vlm_posture: Posture (e.g., "lying_side", "sitting")
   - vlm_health: Health signals (e.g., "limping", "none")
   - vlm_notes: Detailed observations (e.g., "Sleeping peacefully")
3. pair_relations (t TIMESTAMP, device_id VARCHAR, session_id VARCHAR,
   dog_i_id UUID, dog_j_id UUID, distance_norm FLOAT,
   affinity_score FLOAT, tension_score FLOAT, interaction_tags VARCHAR[])

You have access to execute_sql_query tool to run SQL queries.
Use it to answer user questions about their dogs' behavior and activities.

IMPORTANT:
- The 'dogs' table contains registered profiles.
- The 'dog_states' table contains actual activity logs.
- If 'dogs' table is empty, check 'dog_states' to see which dogs are active (use DISTINCT dog_id).
- When asked "what dogs are there?", check BOTH tables.

Tips for DuckDB SQL:
- Use 'ILIKE' for case-insensitive string matching.
- Use json_extract(behavior_probs, '$.play') to access JSON fields
- Use now() or CURRENT_TIMESTAMP for current time
- Use INTERVAL for time ranges, e.g., t > now() - INTERVAL '1 hour'
"""

@router.post("/", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if not settings.NVIDIA_API_KEY:
        return ChatResponse(answer="NVIDIA API Key not configured.")
    
    try:
        logger.info(f"💬 User Query: {req.query}")
        
        # Create agent with SQL executor tool
        bot = Assistant(
            llm=llm_cfg,
            system_message=SYSTEM_MESSAGE,
            function_list=['execute_sql_query']  # Use our registered tool
        )
        
        # Run agent
        messages = [{'role': 'user', 'content': req.query}]
        responses = None
        for responses in bot.run(messages=messages):
            pass  # Get final response
        
        # Extract answer and metadata
        if responses and len(responses) > 0:
            final_response = responses[-1]
            answer = final_response.get('content', 'No response generated.')
            
            # Try to extract SQL from function calls if available
            executed_sql = None
            query_data = None
            
            # Check if there were function calls in the response
            if 'function_call' in final_response:
                func_call = final_response['function_call']
                if func_call.get('name') == 'execute_sql_query':
                    args = json.loads(func_call.get('arguments', '{}'))
                    executed_sql = args.get('query')
            
            return ChatResponse(
                answer=answer,
                sql=executed_sql,
                data=query_data
            )
        else:
            return ChatResponse(answer="No response received from agent.")
            
    except Exception as e:
        logger.error(f"💥 Error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

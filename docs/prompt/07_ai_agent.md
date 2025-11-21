# Prompt: AI Agent & Chat Implementation

**Goal**: Build the LangChain agent and connect the Chat UI.

**Context**:
We have the data (Events, Care Logs). Now we need the "Brain" to answer user questions.

**Task**:
1.  **Backend**:
    - Create `backend/agent/tools.py`: Define tools to query the DB.
    - Create `backend/agent/core.py`: Setup LangChain agent.
    - Create `backend/routers/chat.py`: Chat endpoint.
2.  **iOS**:
    - Update `Services/ChatService.swift` to call the real API.

**Requirements**:
- **Tools**:
    - `get_care_history(dog_id, category)`: SQL query to `care_logs`.
    - `get_activity_stats(dog_id, days)`: SQL query to `event_logs` (aggregation).
- **Agent**:
    - Use `OpenAIFunctionsAgent` or similar.
    - System Prompt: "You are a helpful dog care assistant. You have access to the dog's real data. Always check the data before answering."
- **API**:
    - `POST /chat`: Input `{ message, dog_id }`, Output `{ response_text, html_graph? }`.

**Instructions for AI**:
- Provide the Python code for the tools using `SQLAlchemy`.
- Show how to inject the `db` session into the tools.
- On iOS, ensure the `GraphWebView` can handle the HTML returned by the agent.

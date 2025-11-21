# Prompt: Vision Intelligence Implementation

**Goal**: Update `VisionClient.swift` to use a sophisticated system prompt and implement robust JSON parsing for the response.

**Context**:
We are building an AI Dog Care app. The "On Air" feature analyzes video frames to detect dog behavior. Currently, the prompt is too simple. We need a structured JSON output containing posture, action, emotion, and health signals.

**Task**:
1.  Modify `VisionClient.swift`.
2.  Update the `systemPrompt` in `analyzeStream` to enforce a strict JSON schema.
3.  Define a `VisionResponse` Codable struct that matches the schema.
4.  Implement parsing logic to convert the string response into `VisionResponse`.

**Input Files**:
- `Services/ModelRegistry.swift` (VisionClient)

**Desired JSON Schema**:
```json
{
  "timestamp": "ISO8601 String",
  "dogs": [
    {
      "name": "String",
      "confidence": "Float (0.0-1.0)",
      "posture": "String (standing, sitting, lying_side, lying_belly, curled, sploot)",
      "action": "String (sleeping, eating, drinking, playing, walking, grooming, idle)",
      "emotion": "String (relaxed, tail_wagging, ears_flat, panting, whale_eye, anxious)",
      "health_signals": ["String (limping, scratching, vomiting, shaking, none)"]
    }
  ],
  "environment": {
    "location": "String",
    "objects": ["String"]
  }
}
```

**Instructions for AI**:
- Use the provided JSON schema in the system prompt.
- Ensure the system prompt explicitly forbids markdown blocks (```json ... ```) and demands raw JSON.
- Add error handling for JSON parsing.
- If parsing fails, log the raw response for debugging.

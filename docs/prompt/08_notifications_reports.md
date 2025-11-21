# Prompt: Notifications & Reports

**Goal**: Implement proactive notifications and PDF reports.

**Context**:
We want to alert users about health anomalies and provide monthly summaries.

**Task**:
1.  **Backend**:
    - Create `backend/scheduler.py`: Setup `APScheduler`.
    - Implement logic to analyze daily logs and trigger alerts.
    - Create `backend/reports.py`: Generate PDF using `ReportLab`.

**Requirements**:
- **Scheduler**:
    - Run every night at 00:00.
    - Check for: `scratching` count > threshold, `vomiting` count > 0.
    - If condition met, create a notification record (or mock push).
- **Report**:
    - Generate a PDF containing:
        - Dog Name & Photo.
        - Activity Graph (Matplotlib image).
        - Health Incident List.
    - Endpoint `GET /reports/{dog_id}/{month}` to download.

**Instructions for AI**:
- Provide the scheduler setup code.
- Provide a simple PDF generation function example.

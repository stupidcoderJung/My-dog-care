# Prompt: On Air Continuous Loop Implementation

**Goal**: Implement a continuous analysis loop for the "On Air" feature.

**Context**:
Currently, the "On Air" feature only triggers a single analysis when a button is pressed. We need it to run continuously when activated, simulating a real-time monitoring feed.

**Task**:
1.  Modify `Views/OnAirView.swift`.
2.  Implement a toggle mechanism to Start/Stop analysis.
3.  Create a loop that continuously calls the Vision API while active.

**Requirements**:
- **UI**:
    - Replace the single "Analyze" button with a Toggle or Start/Stop button.
    - Show a visual indicator (e.g., "LIVE" badge or spinning activity indicator) when analyzing.
- **Logic**:
    - Use a `@State` variable `isAnalyzing` (Bool).
    - When `isAnalyzing` becomes true, trigger the first analysis.
    - In the completion handler of the analysis:
        - Check if `isAnalyzing` is still true.
        - If yes, wait for a short delay (e.g., 1 second) to avoid API rate limits.
        - Call the analysis function again.
    - Ensure the loop stops immediately when `isAnalyzing` is set to false.
- **Safety**:
    - Handle errors gracefully (don't crash the loop on one failed request, just retry after delay).
    - Ensure memory management (avoid retain cycles in the loop).

**Instructions for AI**:
- Use Swift's `Task` and `await/async` for the loop if possible, or a recursive function with `DispatchQueue.main.asyncAfter`.
- Ensure the UI remains responsive during the loop.

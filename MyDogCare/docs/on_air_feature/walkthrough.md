# On Air Feature Walkthrough

I have implemented the "On Air" feature (Menu 3) which allows users to stream video, capture frames, and analyze them using an LLM with specific domain knowledge about their dogs.

## Changes

### 1. Camera Manager
- Created `CameraManager.swift` to handle AVFoundation sessions.
- Implemented `captureBurst(count:interval:)` to capture 5 frames at 0.2s intervals.

### 2. Vision Client
- Updated `VisionClient` in `ModelRegistry.swift`.
- Added `analyzeStream(images:dogs:)` method.
- Implemented the specific prompt structure with:
    - System Role
    - Domain Knowledge (dynamically populated from registered dogs)
    - Allowed Action Labels
    - JSON Output Schema

### 3. On Air View
- Created `OnAirView.swift`.
- **Top Half**: Live camera feed with an "Analyze Stream" button.
- **Middle**: Horizontal scroll view showing the 5 captured frames.
- **Bottom**: Scrollable text area displaying the JSON analysis result.

### 4. Main View
- Replaced "Menu 3" with "On Air" tab.
- Updated icon to `video.fill`.

### 6. Multi-turn Prompt Refactoring & Structured Debug
- Refactored `VisionClient` to construct a conversation history.
- Iterates through registered dogs, sending their image (first) as a User message and simulating an AI acknowledgment using `aiDescription`.
- The final User message contains the camera stream images and the main instruction.
- Updated `VisionClient` to return `[DebugTurn]` instead of a single string.
- Updated `PromptDebugView` to visually render each turn with its role, images, and text content.
- Refined the final prompt to dynamically list registered dogs (e.g., "Ato | Telli") and removed "unknown" from options.
- Updated `OnAirView` to use a `TabView` for the bottom section.
- Users can swipe left on the analysis result to see the debug info.

### 7. Camera Resource Optimization
- Modified `CameraManager` to prevent the capture session from starting automatically upon initialization.
- The camera now only starts when `start()` is explicitly called (in `OnAirView.onAppear`) and stops when `stop()` is called (`OnAirView.onDisappear`).
- Added debug logs to verify session state changes.

### 8. Camera Orientation Fix
- Updated `CameraManager` to explicitly set `videoOrientation` to `.portrait`.
- This ensures the camera feed is upright and not rotated.

## Verification Results

### Automated Tests
- No automated tests were added as this feature relies heavily on hardware (Camera) and external APIs (LLM).

### Manual Verification Steps
1.  **Launch the App**: Ensure the app builds and runs on a device (Simulator does not support Camera).
2.  **Permissions**: Navigate to the "On Air" tab. Accept camera permissions.
3.  **Live Feed**: Verify the camera feed is visible in the top half.
4.  **Analyze**: Point the camera at a dog (or object) and tap "Analyze Stream".
5.  **Capture**: Watch the middle strip populate with 5 images.
6.  **Result**: Wait for the analysis to complete and verify the JSON output appears at the bottom.
    - Check that `which` field corresponds to a registered dog or "unknown".
    - Check that `action` is one of the allowed labels.

## Screenshots
> [!NOTE]
> Since I cannot run the app on a physical device with a camera, I cannot provide screenshots of the live feed. The UI layout has been implemented as requested.

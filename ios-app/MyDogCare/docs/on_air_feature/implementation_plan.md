# Fix Camera Orientation

## Goal Description
Correct the camera feed orientation in the "On Air" view.
Currently, the camera feed appears rotated because the `AVCaptureConnection` video orientation is not explicitly set, and raw camera buffers are typically landscape.

## Proposed Changes

### Services
#### [MODIFY] [CameraManager.swift](file:///Users/jipibe.j/Downloads/My-dog-care-codex-delete-repository-contents-and-create-swift-project/MyDogCare/Services/CameraManager.swift)
- In `setupSession`, after adding `videoOutput`, retrieve the `AVCaptureConnection`.
- Set `connection.videoOrientation = .portrait`.
- Also ensure `isVideoMirrored` is false (since we are using the back camera).

## Verification Plan

### Manual Verification
1.  **Open On Air**: Launch the app and go to the "On Air" tab.
2.  **Check Feed**: Verify that the camera feed is now upright (portrait) and not rotated 90 degrees.

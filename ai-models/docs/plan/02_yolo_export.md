# 👁️ Task 2: YOLO Export

## 🎯 Objective
Export the YOLOv11 Nano model to CoreML format (`.mlmodel`) with NMS (Non-Maximum Suppression) baked in for efficient on-device inference.

## 📋 Detailed Steps
1.  **Load Model**: Download/Load `yolo11n.pt` using Ultralytics.
2.  **Configure Export**:
    *   **Format**: `coreml`
    *   **NMS**: `True` (Critical for iOS Vision)
    *   **Precision**: `Half` (FP16) for Neural Engine optimization.
    *   **Image Size**: 640x640.
3.  **Run Export**: Execute the export script.
4.  **Verify**: Check if `yolo11n.mlmodel` is generated and valid.

## 🤖 AI Execution Prompt
(Copy this to the AI Agent)

```text
@ai-models/

I need you to execute **Task 2: YOLO Export**.

**Instructions**:
1.  Ensure you are in `ai-models/` and the `venv` is active (or use the python executable in venv).
2.  Create a Python script named `export_yolo.py` with the following logic:
    ```python
    from ultralytics import YOLO

    # Load the Nano model
    model = YOLO("yolo11n.pt")

    # Export to CoreML with NMS and FP16
    model.export(
        format="coreml",
        nms=True,
        conf=0.5,
        iou=0.45,
        half=True,
        int8=False
    )
    ```
3.  Run this script.
4.  Verify that `yolo11n.mlmodel` (or `yolo11n.mlpackage`) is created in the current directory.
5.  (Optional) If a folder is created, zip it or keep it as is, but note its path.

**Deliverable**:
*   `export_yolo.py` script.
*   `yolo11n.mlmodel` file.
```

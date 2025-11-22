# 🛠️ Task 1: Environment Setup

## 🎯 Objective
Initialize a clean Python virtual environment and install all necessary dependencies for model training and exporting.

## 📋 Detailed Steps
1.  **Check Python Version**: Ensure Python 3.10 or 3.11 is available.
2.  **Create Venv**: Create a virtual environment named `venv` in `ai-models/`.
3.  **Install Dependencies**:
    *   `ultralytics`: For YOLO.
    *   `coremltools`: For CoreML conversion.
    *   `torch`, `torchvision`: PyTorch backend.
    *   `onnx`: Intermediate format support.

## 🤖 AI Execution Prompt
(Copy this to the AI Agent)

```text
@ai-models/

I need you to execute **Task 1: Environment Setup** for the MyDogCare model pipeline.

**Instructions**:
1.  Navigate to the `ai-models/` directory.
2.  Check if a virtual environment named `venv` exists.
    *   If NOT, create one: `python3 -m venv venv`.
3.  Activate the environment and install the following packages:
    *   `ultralytics`
    *   `coremltools`
    *   `torch`
    *   `torchvision`
    *   `onnx`
4.  Create a `requirements.txt` file capturing these dependencies (freeze).

**Deliverable**:
*   A ready-to-use `venv`.
*   A `requirements.txt` file.
*   Confirmation that `import ultralytics` and `import coremltools` work without errors.
```

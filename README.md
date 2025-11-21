# MyDogCare 🐶

**MyDogCare** is an intelligent iOS application designed to be your comprehensive dog care assistant. It combines real-time video analysis ("On Air") with an interactive AI Chat to help you monitor and understand your dog's health and behavior.

## 🌟 Key Features

### 1. 💬 AI Chat (Menu 1)
*   **Interactive Assistant**: Chat with an AI that understands your dog's context.
*   **Executable Code**: The AI can generate and render interactive graphs (e.g., activity trends) directly in the chat bubble.
*   **Context Aware**: Designed to integrate with data collected from the "On Air" feature.

### 2. 📅 Care Calendar (Menu 2 - Proposed)
*   *Planned Feature*: A structured log for your dog's medical and care history.
*   **Events**: Track Vet Visits, Vaccinations, Weight Logs, Grooming, and Medications.
*   **AI Integration**: This data will serve as the "long-term memory" for the AI, allowing it to answer questions like *"When is the next vaccination due?"*.

### 3. 📹 On Air (Menu 3)
*   **Real-time Analysis**: Uses the camera to monitor your dog in real-time.
*   **Vision Intelligence**: Capable of detecting behaviors and events (powered by local VLM or Vision framework).
*   **Advanced Data Strategy**:
    *   **Vision Expert**: Detects posture, emotion (tail/ears), and health signals (limping, scratching).
    *   **Time-Series**: Tracks duration and frequency of behaviors to detect anomalies.
    *   **Business Logic**: Provides actionable health alerts and product recommendations based on observed data.

### 4. ⚙️ Settings
*   **User Profile**: Manage your account (via Clerk).
*   **App Preferences**: Configure notifications and other settings.

## 🧠 AI Architecture
This project aims to connect real-time data with LLM reasoning.
For a detailed architectural vision, please refer to **[ai_integration_plan.md](ai_integration_plan.md)**.

## 🛠️ Setup & Requirements

### Prerequisites
*   **iOS 17.0+**
*   **Xcode 15+**

### Authentication (Clerk)
1.  Create an application in the [Clerk Dashboard](https://dashboard.clerk.com).
2.  Add your **Publishable Key** to `MyDogCare/Info.plist` under `ClerkPublishableKey`.
3.  Configure Signing & Capabilities in Xcode.

### Local LLM (Optional/Advanced)
The app supports local GGUF models for vision tasks.
*   Place your `.gguf` models in the `models` directory.
*   Ensure `llama.xcframework` is present in the project root if building with local LLM support.

## 🚀 Getting Started
1.  Clone the repository.
2.  Open `MyDogCare.xcodeproj` in Xcode.
3.  Wait for Swift Package Manager to resolve dependencies (Clerk SDK, etc.).
4.  Run on a Simulator or physical device.

---
*Note: This project is under active development. "Menu 2" is currently a placeholder for the upcoming Care Calendar feature.*

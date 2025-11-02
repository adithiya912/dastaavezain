# DastaavezAi 🗣️📄🤖

**A multi-modal AI assistant designed to help India's non-literate population scan, interpret, and interact with complex documents using generative AI.**

> DastaavezAi aims to bridge the digital and literacy divide by providing a simple, voice-first interface. Users can take a picture of any document (like a government form, a bank slip, or a utility bill) and ask questions about it in their native language. The app uses AI to understand the document and generate simple, culturally-validated pictogram-based explanations.

---

## 🚀 Core Features

* **🎙️ Vernacular Voice Control:** Full app control using conversational, spoken Hindi (or other vernacular languages).
* **📸 Scan & Understand:** Instantly scan any document using the device camera.
* **🧠 AI-Powered Q&A:** Ask specific questions about the scanned document (e.g., "What is this form for?", "Where is my father's name?").
* **🖼️ Pictogram Explanations:** For complex or confusing terms (like "Nominee" or "Signature"), the app generates simple visual pictograms to explain what is needed.
* **✍️ Guided Form Filling:** A voice-driven assistant that guides the user step-by-step through filling out complex forms.

---

## 🖼️ Screenshots

*(Add your app screenshots here to show off your UI!)*

| Scan Page | AI Result | Pictogram Example |
| :---: | :---: | :---: |
|  |  |  |

---

## 🔩 Architecture Overview

This project uses a secure, scalable client-server architecture to protect the Gemini API key and offload heavy processing from the user's device.

1.  **Flutter App (Client):** The user picks an image from their camera or gallery.
2.  **Firebase Storage:** The app uploads the image to a secure Firebase Storage bucket and gets a download URL.
3.  **Firebase Cloud Functions:** The app calls the `analyzeDocument` Cloud Function, passing the image's download URL.
4.  **Backend (Google Cloud):**
    * The Cloud Function (running on Google's servers) securely accesses the secret **Gemini API Key**.
    * It fetches the image from the URL, converts it to Base64, and sends it to the Gemini API with a prompt.
5.  **Flutter App (Client):** The function returns the extracted text from Gemini, which is then displayed to the user in the app.

```
[Flutter App] ---- 1. Upload Image ----> [Firebase Storage]
     |
     |
     +---- 2. Call Function (with URL) ----> [Cloud Function: analyzeDocument]
                                                   |
                                                   |
     <---- 4. Return Result (JSON/Text) <---- [3. Calls Gemini API (Securely)]
```

---

## 🛠️ Technology Stack

### Frontend
* **[Flutter](https://flutter.dev/):** For the cross-platform (Android/iOS) user interface.
* **Packages:**
    * `firebase_core`: To connect to the Firebase backend.
    * `firebase_storage`: For uploading the document images.
    * `cloud_functions`: For calling the backend function securely.
    * `image_picker`: For selecting images from the camera or gallery.

### Backend
* **[Firebase Cloud Functions](https://firebase.google.com/docs/functions):** Serverless backend (Node.js) to host the secure logic.
* **[Gemini API (Google Generative AI)](https://ai.google.dev/):** The core multi-modal AI model used for document interpretation.
* **Firebase Security:**
    * **Firebase Secrets:** To securely store the Gemini API key (not in the app).
    * **Firebase Storage Rules:** To protect user-uploaded documents.
    * **Firebase App Check (Recommended):** To ensure requests come from the real app.
    * **SHA-1 Fingerprints:** To secure API calls from the Android app.

---

## 🏁 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

* **Flutter SDK:** [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
* **Firebase CLI:** `npm install -g firebase-tools`
* **Firebase Project:** Create a new project at [console.firebase.google.com](https://console.firebase.google.com/)
* **Gemini API Key:** Get one from [Google AI Studio](https://ai.google.dev/).

### 1. Setup the Firebase Project

1.  **Create Project:** Create a new project in the Firebase Console.
2.  **Enable Services:** In the console, enable **Storage** and **Functions**.
3.  **Register Android App:**
    * Go to **Project Settings** -> **Add app** -> **Android**.
    * Use the package name `com.example.dastaavezain`.
    * Run `cd android && ./gradlew signingReport` in your local terminal and add the **SHA-1** key to your Firebase app.
    * Download the **`google-services.json`** file and place it in the `android/app/` directory.

### 2. Setup the Frontend (Flutter)

```bash
# Clone the repository
git clone [https://github.com/YOUR_USERNAME/dastaavezain.git](https://github.com/YOUR_USERNAME/dastaavezain.git)

# Navigate to the project directory
cd dastaavezain

# Get Flutter dependencies
flutter pub get
```

### 3. Setup the Backend (Cloud Functions)

```bash
# Navigate to the functions directory
cd functions

# Install npm dependencies
npm install

# --- CRITICAL: SET YOUR API KEY ---
# This securely stores your Gemini key on Google's servers, not in your code.
# Run this command and paste your key when prompted.
firebase functions:secrets:set GEMINI_API_KEY

# Deploy your Cloud Function
# (You may need to run `firebase login` first)
firebase deploy --only functions
```

### 4. Run the App

```bash
# Go back to the root project folder
cd ..

# Run the app on your connected device or emulator
flutter run
```

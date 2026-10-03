# KooKed 🍳 — *Cook What You Have.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-4.21-000000?logo=express&logoColor=white)](https://expressjs.com)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-1.5%20Flash-8E75B2?logo=google&logoColor=white)](https://ai.google.dev)
[![Python](https://img.shields.io/badge/ML%20Pipeline-Scikit--Learn-F7931E?logo=scikit-learn&logoColor=white)](https://scikit-learn.org)

**KooKed** is an AI-powered smart kitchen assistant and sustainable inventory management platform designed to eliminate household food waste. By bridging computer vision, receipt OCR, a First-In First-Out (FIFO) recipe matching engine, and automated pantry reconciliation, KooKed empowers households to effortlessly cook delicious meals using what is already in their fridge and pantry.

---

## 📑 Table of Contents

- [About The Project](#-about-the-project)
  - [The Problem](#the-problem)
  - [The KooKed Solution](#the-kooked-solution)
  - [Core Principles](#core-principles)
- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Repository Structure](#-repository-structure)
- [Tech Stack](#-tech-stack)
- [Quick Start Guide](#-quick-start-guide)
  - [Prerequisites](#prerequisites)
  - [1. Backend Server Setup](#1-backend-server-setup-nodejs--express)
  - [2. Mobile App Setup](#2-mobile-app-setup-flutter)
  - [3. Machine Learning Setup](#3-machine-learning-setup-optional-python)
- [Environment Variables](#-environment-variables)
- [End-to-End User Workflows](#-end-to-end-user-workflows)
- [Troubleshooting & FAQs](#-troubleshooting--faqs)
- [Contributing](#-contributing)
- [License](#-license)

---

## 💡 About The Project

### The Problem
Household food waste is one of the leading contributors to municipal landfill accumulation, avoidable greenhouse gas emissions, and personal budget leakages. Traditional pantry tracking apps fail because manual data entry is tedious, predictive expiration models guess inaccurately and lead to premature disposal, and pantry lists never stay synchronized with what actually gets cooked.

### The KooKed Solution
KooKed creates a **frictionless, closed-loop kitchen ecosystem**:
1. **Effortless Ingestion**: Scan produce and grocery items via AI vision or supermarket receipt OCR.
2. **FIFO-Driven Utilization**: Surface recipes prioritizing items that entered the pantry earliest.
3. **"I Cooked This" Closed Loop**: Completing a recipe automatically reconciles and deducts ingredients from your live pantry.
4. **Impact Measurement**: Track real money and CO₂ emissions saved in a personal Sustainability Dashboard.

### Core Principles
- **Human-in-the-Loop AI**: AI acts as an assistant, never as an unmonitored decision-maker. All AI detections and consumption estimates have confirmation gates before writing to the database.
- **Strict FIFO Prioritization**: No guesswork on expiration dates. Items are tracked by `dateAdded`, prioritizing older ingredients first.
- **Shared Household Inventory**: Pantries are scoped to households, keeping housemates and families automatically in sync.
- **Offline-First Resilience**: Cached locally with Hive CE, ensuring the app remains fully functional inside grocery stores or low-reception kitchens.

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| 🥗 **Smart Digital Pantry** | Real-time tracking of ingredients categorized by type (`Raw`, `Packaged`, `Prepared`, `Leftover`, `Frozen`) with FIFO ordering and low-stock alerts. |
| 📸 **AI Food Vision Scanner** | Snap photos of groceries or countertop produce; Google Gemini Vision identifies items, estimated quantities, and categories automatically. |
| 🧾 **Receipt & Bill OCR** | Capture supermarket bills to batch-extract purchased food items and insert them into your pantry after review. |
| 🍲 **Intelligent Recipe Engine** | Automatically segregates recipes into: <br>• **Cook Now:** 100% ingredients ready in pantry (ordered by oldest item first). <br>• **Almost There:** Missing 1–3 items, with instant 1-click addition to your shopping list. |
| 🍳 **"I Cooked This" Reconciliation** | One-tap completion triggers automated pantry deduction of used ingredients, closing the loop between planning and reality. |
| 🤖 **AI Sous-Chef & Chef Mode** | Conversational kitchen companion for ingredient substitutions, recipe customizations, wine pairings, and step-by-step cooking support. |
| 🛒 **Smart Shopping List** | Auto-populated by missing recipe ingredients and manual requests; check off items to auto-transfer them into your pantry. |
| 📊 **Sustainability Dashboard** | Track food saved (kg), money saved, meals cooked, and estimated carbon offset (CO₂e). |

---

## 🏛 System Architecture

```text
               +--------------------------------------------+
               |          KooKed Flutter Client             |
               |      (iOS, Android, Web, Desktop)          |
               +----------------------+---------------------+
                                      |
                 +--------------------+--------------------+
                 |                                         |
                 v                                         v
   +-----------------------------+           +-----------------------------+
   |  KooKed API Proxy (Express) |           |      Firebase Services      |
   |   - Vision / OCR routes     |           |   - Firebase Authentication |
   |   - AI Chat & Sous-Chef     |           |   - Cloud Firestore (DB)    |
   |   - Recipe Generation       |           |   - Firebase Cloud Storage  |
   |   - Rate Limiting & Auth    |           |   - Firebase Cloud Messaging|
   +--------------+--------------+           +-----------------------------+
                  |
                  v
   +-----------------------------+
   |   Google Gemini 1.5 Flash   |
   |  Multimodal Vision & NLP    |
   +-----------------------------+
```

---

## 📂 Repository Structure

```text
kooked/
├── lib/                             # Flutter frontend source code
│   ├── config/                      # App theme, routes (GoRouter), page transitions
│   ├── models/                      # Domain models (PantryItem, Recipe, ShoppingItem, etc.)
│   ├── screens/                     # UI screens
│   │   ├── auth/                    # Login & registration flows
│   │   ├── camera/                  # Camera vision scanner & receipt bill OCR
│   │   ├── chat/                    # AI Sous-Chef chat assistant
│   │   ├── dashboard/               # Sustainability & statistics dashboard
│   │   ├── pantry/                  # Pantry inventory list & item edit screens
│   │   ├── recipes/                 # Recipe catalog, detail, & cook mode
│   │   ├── settings/                # Notifications & household settings
│   │   └── shopping/                # Smart shopping list
│   ├── services/                    # Business logic (Firestore, RecipeEngine, ApiService, Hive Cache)
│   ├── utils/                       # Constants, formatters, and helpers
│   ├── widgets/                     # Reusable UI components & custom cards
│   ├── firebase_options.dart        # Platform-specific Firebase credentials
│   └── main.dart                    # Application entry point
├── server/                          # Node.js + Express backend service
│   ├── middleware/                  # Firebase Auth token validation & Rate limiting
│   ├── routes/                      # Gemini proxy endpoints (/vision, /ocr, /chat, etc.)
│   ├── utils/                       # Prompt engineering & response normalizers
│   ├── index.js                     # Express server entry point
│   ├── package.json                 # Server dependencies & scripts
│   └── .env.example                 # Template for server environment variables
├── ml/                              # Python Machine Learning module (Phase 2)
│   ├── data/                        # Train, validation, test datasets & metadata
│   ├── models/                      # Dual-head classification models & vectorizers
│   ├── scripts/                     # Data validation, training, and benchmarking scripts
│   └── requirements.txt             # Python dependencies
└── pubspec.yaml                     # Flutter project dependencies & asset configs
```

---

## 🛠 Tech Stack

### Frontend (Mobile App)
- **Framework:** [Flutter 3.x](https://flutter.dev) (Dart SDK `^3.12.2`)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Local Storage / Caching:** [Hive CE](https://pub.dev/packages/hive_ce) & [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Hardware Integration:** [Camera](https://pub.dev/packages/camera) & [Image Picker](https://pub.dev/packages/image_picker)
- **Styling:** Custom Material 3 Design System (`#2D6A4F` Forest Green palette) & Google Fonts (Inter / Outfit)

### Backend (API Proxy)
- **Runtime:** [Node.js](https://nodejs.org) (v18+) with ES Modules
- **Framework:** [Express 4](https://expressjs.com)
- **AI Integration:** Google Generative AI SDK (`@google/generative-ai`)
- **Security:** Firebase Admin SDK authentication token verification & `express-rate-limit`

### Cloud & Database
- **Authentication:** Firebase Auth (Email/Password & Google Sign-In)
- **Database:** Cloud Firestore (Real-time NoSQL)
- **Storage:** Firebase Cloud Storage (Receipt and item images)
- **Push Notifications:** Firebase Cloud Messaging (FCM)

### Machine Learning
- **Environment:** Python 3.10+
- **Libraries:** Scikit-Learn, Pandas, NumPy
- **Architecture:** Dual-head TF-IDF vectorizers with Logistic Regression for fast, lightweight local food categorization and inventory state prediction

---

## 🚀 Quick Start Guide

### Prerequisites
Make sure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.12.2`)
- [Node.js](https://nodejs.org/) (`>= 18.x`) & npm
- [Git](https://git-scm.com/)
- [Python](https://www.python.org/) (`>= 3.10`) *(optional, for ML pipeline)*
- A [Google Cloud / Gemini API Key](https://ai.google.dev/)
- A [Firebase Project](https://console.firebase.google.com/)

---

### 1. Backend Server Setup (Node.js / Express)

The backend handles rate-limited, authenticated requests to Google Gemini.

```bash
# Navigate to the server folder
cd server

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
```

Open `server/.env` and supply your keys:
```env
PORT=3000
NODE_ENV=development
GEMINI_API_KEY=your_actual_gemini_api_key_here
GEMINI_MODEL=gemini-1.5-flash

# Firebase Admin Credentials
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=your-service-account-email@project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nyour_key\n-----END PRIVATE KEY-----\n"
```

Start the API proxy server:
```bash
npm run dev
# The server will run at http://localhost:3000 (Healthcheck: http://localhost:3000/api/health)
```

---

### 2. Mobile App Setup (Flutter)

In a new terminal window, navigate back to the Flutter project root:

```bash
# Ensure you are in the kooked root directory
cd kooked

# Install Flutter dependencies
flutter pub get

# Check available devices/emulators
flutter devices
```

#### Running the App:
```bash
# For Chrome / Web:
flutter run -d chrome

# For Windows Desktop:
flutter run -d windows

# For Android (running with custom API backend URL):
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3000/api

# For iOS Simulator:
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:3000/api
```

> **Note on Android Emulator:** Android emulators use `http://10.0.2.2:3000` to communicate with the host machine's `localhost:3000`. KooKed's `ApiService` detects this automatically, or you can pass it explicitly with `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api`.

---

### 3. Machine Learning Setup (Optional: Python)

If you are developing or retraining the local food categorization models:

```bash
cd ml

# Create and activate a virtual environment
python -m venv venv
# On Windows:
venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

# Install ML dependencies
pip install -r requirements.txt

# Run dataset validation or training scripts
python scripts/validate_data.py
python scripts/train_models.py
```

---

## 🔐 Environment Variables

### Backend Server (`server/.env`)
| Variable | Description | Default |
| :--- | :--- | :--- |
| `PORT` | Port the Express server listens on | `3000` |
| `NODE_ENV` | Runtime environment (`development` / `production`) | `development` |
| `GEMINI_API_KEY` | Google Gemini API Key for vision, OCR, and chat | *Required* |
| `GEMINI_MODEL` | Gemini model variant | `gemini-1.5-flash` |
| `FIREBASE_PROJECT_ID`| Firebase project identifier | *Required* |
| `FIREBASE_CLIENT_EMAIL`| Firebase Service Account client email | *Required* |
| `FIREBASE_PRIVATE_KEY`| Firebase Service Account RSA private key | *Required* |

### Mobile Client (`--dart-define`)
| Flag | Description | Default |
| :--- | :--- | :--- |
| `API_BASE_URL` | Base URL of the KooKed Express proxy | `http://localhost:3000/api` (Web/Desktop/iOS) or `http://10.0.2.2:3000/api` (Android) |

---

## 🔄 End-to-End User Workflows

```
  +------------------+       +-------------------+       +--------------------+
  | 1. Ingestion     | ----> | 2. Recipe Match   | ----> | 3. Cook & Deduct   |
  | Scan / Receipt / |       | FIFO 'Cook Now' & |       | "I Cooked This"    |
  | Manual Entry     |       | 'Almost There'    |       | Reconciles Pantry  |
  +------------------+       +-------------------+       +--------------------+
                                       |                           |
                                       v                           v
                             +-------------------+       +--------------------+
                             | 4. Smart Shopping |       | 5. Sustainability  |
                             | Missing Items to  |       | Track Saved Food,  |
                             | Grocery List      |       | CO2e, and Money    |
                             +-------------------+       +--------------------+
```

1. **Multi-Modal Ingestion:** Capture items via Camera Food Vision, Supermarket Bill OCR, or fast manual input. Review and confirm items into your digital pantry.
2. **FIFO-Driven Discovery:** Open the Recipes tab. The engine evaluates what you have against recipe requirements. It ranks dishes prioritizing items added first to prevent spoilage.
3. **Cooking & Auto-Deduction:** Follow guided steps or interact with the AI Sous-Chef. Tap **"I Cooked This"** to automatically adjust pantry quantities.
4. **Shopping Synchronization:** Need an ingredient for an "Almost There" recipe? Add it to the Shopping List with one tap. Checking it off auto-moves it into your pantry.
5. **Impact Tracking:** Watch your Sustainability Dashboard quantify the kilograms of food kept from landfills and the money saved by eating what you own.

---

## ❓ Troubleshooting & FAQs

#### Q: `npm run dev` fails with `ENOENT: no such file or directory`
> **A:** `package.json` is located inside the `server/` directory, not the project root. Run:
> ```bash
> cd server
> npm run dev
> ```

#### Q: Running `flutter start` returns `Could not find a command named "start"`
> **A:** The Flutter CLI command to run applications is `flutter run`, not `flutter start`:
> ```bash
> flutter run
> ```

#### Q: The app cannot reach the backend on an Android Emulator
> **A:** The Android emulator treats `localhost` as its own loopback. Use `10.0.2.2:3000` or launch the app with:
> ```bash
> flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
> ```

#### Q: Camera or Image Picker crashes on mobile
> **A:** Ensure camera permissions are granted. For Android, verify `AndroidManifest.xml` includes `CAMERA` and `READ_EXTERNAL_STORAGE` permissions. For iOS, verify `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are present in `Info.plist`.

---

## 🤝 Contributing

Contributions to KooKed are welcome!
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <b>Cook What You Have. Save What You Spend. Protect The Planet. 🌱</b><br>
  Made with ❤️ by the KooKed Team
</p>

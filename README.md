# Splitwise Clone App 💸

A premium, feature-rich Splitwise clone application built using Flutter. This app allows users to log expenses, split bills, track simplified net balances across groups and friends, link phone numbers, send custom in-app notifications/reminders, write group notes, and handle settlements.

---

## 🚀 Key Features

* **Premium Dark Mode & Visuals:** Designed with a curated dark-mode glassmorphic theme, smooth micro-animations, Outfit/Inter typography, and custom illustration cartoon avatars.
* **Smart Net Balances & Settlements:** Calculates unified net balances (direct 1-on-1 + mutual group simplified debts) per person. Supports **Cross-Group Settle Up** that automatically distributes settlements across simplified mutual group balances first before logging direct ones.
* **Flexible Phone & Email Linking:** Built-in background self-healing that queries placeholders matching either email or phone (using last 10 digits variations like suffix, `91`, `+91`, `0` prefixes) to claim and merge pending group history instantly upon registration or phone linkage.
* **Silent Google Authentication:** Google Sign-in v7+ support that silently resolves and handles cancellation without displaying errors in the UI.
* **Multi-Currency Schema:** Supports Indian Rupee (₹/INR), US Dollar ($/USD), and Euro (€/EUR) built on a USD base currency database schema, with exchange rates configuration in the Account tab.
* **Group Notes 📝:** Option in every group type to write, share, and manage important sticky notes (displaying content, author, and relative posting time).
* **Group Types Redesign:** Custom views, tabs, and actions based on group types: **Trip**, **Family**, **Self** (tracks personal budget and total spent without member splits), and **No Expense** (tracks direct 1-on-1 balances).
* **Offline-First Auth Caching:** SharedPreferences-based authentication and dashboard caching for instant page render times, updating Firestore data asynchronously.
* **Device Contacts & Quick Suggestions:** Integrates Android and iOS native contacts using `flutter_contacts` alongside quick category suggestion chips ('Food', 'Transportation', etc.) in the Add Expense flow.

---

## 🛠️ Technology Stack & Libraries

- **Frontend:** Flutter & Dart
- **State Management:** Provider
- **Backend & Database:** Firebase Auth (Email/Password & Google Sign-in) & Cloud Firestore
- **Local Cache:** SharedPreferences
- **Native Contacts:** `flutter_contacts`
- **Link Launcher:** `url_launcher` (Whatsapp redirecting, Mail triggers)
- **Icons & Splash:** `flutter_launcher_icons`
- **AI Partner:** Developed in pair programming with **Google Antigravity**

---

## 📋 Setup & Installation Instructions

Follow these steps to run the application locally on your machine:

### 1. Prerequisites
Make sure you have installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (ver 3.38.5 or higher recommended)
- [Dart SDK](https://dart.dev/get-started) (ver 3.10.4 or higher recommended)
- Android Studio / Xcode (for mobile emulators)
- VS Code or your preferred editor with Flutter plugins installed

### 2. Clone and Open
Clone the repository and open it in your editor:
```bash
git clone <repository_url>
cd Splitwise
```

### 3. Install Dependencies
Download the project dependencies:
```bash
flutter pub get
```

### 4. Configure Firebase (Optional)
The app runs in **Mock Mode** automatically if Firebase is unconfigured. To link your own Firebase project:
1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password** and **Google** providers in Firebase Auth.
3. Enable **Cloud Firestore** and set rules to allow authenticated reads/writes.
4. Run `flutterfire configure` to generate `lib/firebase_options.dart` or download/configure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
5. Add your Android SHA-1 fingerprint inside the Firebase console to enable Google Sign-In.

### 5. Running the App
Run the app in debug mode on your connected emulator/device:
```bash
flutter run
```

### 6. Running Tests
Run the complete unit and widget test suite to confirm everything is working:
```bash
flutter test
```

---

## 🤖 AI Development
This project has been developed in pair programming with **Google Antigravity**, an agentic AI coding assistant designed by the Google DeepMind team. Antigravity assisted in:
- DB architecture, Firestore schema design, and self-healing claim pipelines.
- Glassmorphic UI redesign, keyboard focus collisions handling, and currency exchange modules.
- Phone variations matching, case-insensitive auth linking, and in-app notifications.

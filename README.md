# Manikutti Mobile Client

A premium, offline-first mobile companion for the **Manikutti Finance Tracker** built using **Flutter**. It allows family members to track their personal and family expenses, synchronize data with Google Sheets via a Next.js serverless backend, and work completely offline when network connection is unavailable.

---

## ✨ Features

- **Offline-First Storage**: Saves all transactions locally in a secure SQLite database to prevent lag and ensure it works without internet access.
- **Background Synchronization**: Detects network connectivity changes, automatically pushing local offline edits to Google Sheets and pulling remote updates.
- **UTC Timezone Normalization**: Automatically converts all timestamps to UTC before performing duplicate checks, neutralizing timezone offsets between local devices (e.g., IST) and Vercel servers (UTC).
- **Interactive Ledger UI**: Modern UI featuring net savings metrics, category badges, dynamic charts, filter chips, and automated sync indicators.
- **Secure Authentication**: Verification via email OTP (one-time passwords) that issues stateless JWT credentials.

---

## 🛠️ Getting Started

### Prerequisites
- **Flutter SDK**: Ensure you have Flutter version `3.18.0` or higher installed.
- **Dart SDK**: Clean environment setup with package dependencies resolved.
- **Android Studio / Xcode**: Formats and builds debug/release payloads.

### Installation & Run
1. Navigate to the mobile project directory:
   ```bash
   cd manikutti_mobile
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Connect a physical Android/iOS phone (with USB Debugging active) or start an emulator.
4. Run the application:
   ```bash
   flutter run
   ```

---

## 🚀 CI/CD Pipeline & Deployments

This repository uses a decentralized **Polyrepo** architecture, meaning it manages its own builds and deployments independently from the Web Dashboard.

* **Quality Gates (PRs):** Any Pull Request opened against the `main` branch automatically triggers `pr-checks.yml`, which runs `dart format`, `flutter analyze`, and unit tests.
* **Auto-Merge:** Once checks pass, the PR is automatically squash-merged into `main` using a Personal Access Token (PAT).
* **Automated Deployments:** A push/merge to `main` triggers `distribute.yml`. This workflow:
  1. Builds a Release APK.
  2. Sets the build number to the unique GitHub Run Number.
  3. Uploads the APK directly to **Firebase App Distribution** (to the `family` tester group).
* **Parent Sync:** Finally, the `sync-parent.yml` workflow updates the `manikutti-hub` parent repository so it always points to this exact production release.

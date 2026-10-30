# Identification Feature (Flutter)

This feature handles banana variety identification (Ambul, Ambun, Anamalu, Kolikuttu, Red, Seeni), export suitability evaluation, and live dataset training management.

---

## 1. Directory Structure

```
lib/features/identification/
├── data/
│   ├── models/
│   │   ├── dataset_stats.dart        # Dataset counts & unsynced tracking
│   │   ├── sync_status.dart          # Live sync progress and summary models
│   │   ├── training_status.dart      # Version metrics and run state
│   │   └── variety_identification_result.dart
│   └── identification_service.dart   # Dio HTTP API client & mock service
├── domain/
│   └── entities/
├── presentation/
│   ├── identification_routes.dart
│   └── screens/
│       ├── identification_screen.dart       # Camera / Gallery inference
│       ├── dataset_training_screen.dart     # Dataset sync, training, and rollback
│       ├── export_recommendation_screen.dart
│       ├── market_trends_screen.dart
│       └── alerts_screen.dart
└── README.md
```

---

## 2. Admin API Key Configuration

Administrative features (dataset syncing, retraining, version rollback) require the `ADMIN_API_KEY`:

1. **Option A (In-App Dialog):**
   - Tap the Key icon (`Icons.key`) in the AppBar of the Dataset & Training screen.
   - Enter your key (e.g., `testkey`).
   - The key is automatically persisted across app launches using `shared_preferences`.

2. **Option B (Compile-Time Flag):**
   - Run or debug passing the define:
     ```bash
     flutter run --dart-define=ADMIN_API_KEY=testkey
     ```
   - Pre-configured in `.vscode/launch.json`.

---

## 3. Dataset & Training Screen Capabilities

- **Scan Raw Folders:** Triggers background sync of hand-copied raw photos with live progress polling (percentage, items processed, speed, and ETA).
- **Dataset Statistics Table:** Real-time table displaying per-variety **Raw**, **Processed**, and **Unsynced** image counts.
- **Mutual Exclusion Handling:** Retrain button is safely disabled while raw synchronization is in progress.
- **Model Retraining:** Triggers candidate model retraining with real-time status updates and promotion verification.
- **Version History & Rollback:** View historical training runs (accuracy, macro F1, promotion status) with single-tap rollback.

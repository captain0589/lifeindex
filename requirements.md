# LifeIndex — Requirements

## App Overview
**LifeIndex** is a native iOS app (Swift/SwiftUI) that connects to Apple HealthKit and serves as a holistic health dashboard. It aggregates data from Apple Watch and other health devices (Oura, Withings, etc.) into a unified experience with insights, trends, recovery tracking, wellness scoring, and exportable health reports.

## Tech Stack
- **Language:** Swift
- **UI Framework:** SwiftUI (MVVM architecture)
- **Health Data:** Apple HealthKit
- **Charts:** Swift Charts (iOS 16+)
- **Local Storage:** Core Data
- **Backend:** Custom (Vapor or Node.js) — PostgreSQL
- **Auth:** Sign in with Apple (primary), email/password (secondary)
- **Hosting:** AWS or Railway (MVP)

## Target
- **Platform:** iOS only
- **Minimum iOS:** 16.0+
- **Devices:** iPhone (Apple Watch companion data via HealthKit)
- **Goal:** Launch on App Store as a product

---

## Core Features

### 1. Holistic Dashboard
- Unified daily view: sleep, activity, heart rate, HRV, steps, calories, blood oxygen
- Weekly/monthly/yearly trend charts
- Cross-metric correlations (e.g., "Your sleep quality improves when you walk 8k+ steps")
- Customizable widgets — users pick which metrics matter most
- Daily "LifeIndex Score" — a single 0-100 score synthesizing all health data

### 2. Fitness + Recovery
- Workout history pulled from HealthKit (all workout types)
- Training load tracker (rolling 7-day / 28-day volume)
- Recovery score based on HRV, resting heart rate, sleep quality
- Strain vs. recovery balance visualization
- Suggested rest days based on trends

### 3. Wellness Tracking
- Mood logging (quick daily check-in: 1-5 scale + optional journal)
- Stress indicators derived from HRV + heart rate patterns
- Mindfulness minutes tracking (from Apple Health)
- Correlation between mental wellness inputs and physical metrics
- Breathing/mindfulness reminders via notifications

### 4. Health Reports
- Generate PDF/shareable health summaries (weekly, monthly, custom range)
- Doctor-friendly format with key vitals, trends, and anomalies
- Export raw data as CSV
- Shareable via AirDrop, email, or save to Files
- Highlight anomalies/notable changes automatically

---

## Architecture

### iOS App
- **UI:** SwiftUI with MVVM architecture
- **Local storage:** Core Data for caching health data + user preferences
- **HealthKit:** Background delivery for real-time data updates
- **Charts:** Swift Charts (iOS 16+) for all visualizations
- **Notifications:** Local notifications for reminders, anomaly alerts

### Custom Backend
- **Purpose:** User accounts, cloud sync, advanced analytics, push notifications
- **Tech:** Vapor (Swift on server) OR Node.js/Express — TBD
- **Database:** PostgreSQL for structured health data
- **Auth:** Sign in with Apple (primary), email/password (secondary)
- **API:** RESTful, versioned (v1/v2)
- **Hosting:** AWS or Railway for MVP

### Data Flow
```
Health Devices → Apple Health (HealthKit) → LifeIndex iOS App → Custom Backend
                                                ↓
                                          Core Data (local cache)
                                                ↓
                                          SwiftUI Views
```

---

## Project Structure
```
LifeIndex/
├── LifeIndex.xcodeproj
├── LifeIndex/
│   ├── App/
│   │   ├── LifeIndexApp.swift
│   │   ├── MainTabView.swift
│   │   └── AppDelegate.swift
│   ├── Core/
│   │   ├── HealthKit/
│   │   │   ├── HealthKitManager.swift
│   │   │   └── HealthDataTypes.swift
│   │   ├── Scoring/
│   │   │   ├── LifeIndexScoreEngine.swift
│   │   │   └── RecoveryScoreEngine.swift
│   │   ├── Networking/
│   │   │   ├── APIClient.swift
│   │   │   ├── Endpoints.swift
│   │   │   └── AuthManager.swift
│   │   └── Persistence/
│   │       ├── CoreDataStack.swift
│   │       └── Models/
│   │           └── MoodLog.swift
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── DashboardViewModel.swift
│   │   │   ├── LifeIndexScoreCard.swift
│   │   │   └── MetricWidgets/
│   │   │       └── MetricWidget.swift
│   │   ├── Fitness/
│   │   │   └── FitnessView.swift
│   │   ├── Wellness/
│   │   │   └── WellnessView.swift
│   │   ├── Reports/
│   │   │   └── ReportsView.swift
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Shared/
│   │   ├── Components/
│   │   ├── Extensions/
│   │   │   └── DateExtensions.swift
│   │   └── Theme/
│   │       └── Theme.swift
│   └── Resources/
│       └── Assets.xcassets
├── LifeIndexTests/
├── LifeIndexUITests/
└── Backend/
    └── (Vapor or Node project)
```

---

## Implementation Phases

### Phase 1 — Foundation (MVP) ✅
1. Create Xcode project with SwiftUI
2. Set up HealthKit integration (permissions, data reading)
3. Build the Dashboard with daily metrics display
4. Implement LifeIndex Score algorithm (v1 — weighted average of key metrics)
5. Set up Core Data for local caching
6. Build onboarding flow (HealthKit permissions, device setup)

### Phase 2 — Fitness & Recovery
7. Workout history view with HealthKit workout data
8. Training load calculation (7-day / 28-day)
9. Recovery score engine (HRV + resting HR + sleep)
10. Strain vs. recovery visualization

### Phase 3 — Wellness
11. Mood logging UI + local persistence
12. Stress indicator derived from HRV patterns
13. Mindfulness tracking integration
14. Correlation engine (mood vs. physical metrics)

### Phase 4 — Reports & Export
15. PDF report generation (weekly/monthly summaries)
16. CSV data export
17. Share sheet integration (AirDrop, email, Files)
18. Anomaly detection and highlighting

### Phase 5 — Backend & Sync
19. Set up custom backend (API, database, auth)
20. Sign in with Apple integration
21. Cloud sync for user data
22. Push notifications for anomaly alerts and reminders

### Phase 6 — Polish & Launch
23. App Store assets (screenshots, description, privacy policy)
24. Performance optimization
25. TestFlight beta testing
26. App Store submission

---

## Scoring Algorithms

### LifeIndex Score (0–100)
Weighted average across health metrics:
| Metric             | Weight |
|--------------------|--------|
| Sleep Duration     | 20%    |
| Steps              | 15%    |
| HRV                | 15%    |
| Heart Rate         | 10%    |
| Resting Heart Rate | 10%    |
| Blood Oxygen       | 10%    |
| Active Calories    | 10%    |
| Mindful Minutes    | 5%     |
| Workout Minutes    | 5%     |

Each metric is scored 0.0–1.0 based on proximity to an ideal range, then weighted.

### Recovery Score (0–100)
| Component          | Weight |
|--------------------|--------|
| HRV vs baseline    | 40%    |
| Resting HR vs baseline | 30% |
| Sleep duration     | 30%    |

---

## Xcode Setup Requirements
1. Create iOS App project (SwiftUI lifecycle) named "LifeIndex"
2. Add **HealthKit** capability (Target → Signing & Capabilities)
3. Add `Info.plist` key: `NSHealthShareUsageDescription` — "LifeIndex reads your health data to calculate your daily score and show insights."
4. Create `LifeIndex.xcdatamodeld` with entity:
   - **MoodLog**: id (UUID), mood (Integer 16), note (String, optional), date (Date)

---

## Key Decisions (TBD)
- Backend: Vapor (Swift) vs. Node.js/Express
- Minimum iOS version: iOS 17+ (better Swift Charts) vs. iOS 16+
- Monetization: Free tier + premium subscription vs. one-time purchase
- Score algorithm weights: needs tuning with real user data

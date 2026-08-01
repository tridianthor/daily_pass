# Daily Pass

Cross-platform daily activity tracking app for building and maintaining positive habits.

## Features

- **Calendar-based tracking** - Visual progress indicators showing completion status per day
- **Flexible scheduling** - One-time or recurring activities (daily, weekly, monthly)
- **Offline-first** - All data stored locally, works without internet
- **Cross-platform** - iOS, Android, Windows, and Linux support
- **Dark mode** - Comfortable viewing in any lighting
- **Data portability** - Export and import your data as JSON

## Tech Stack

- **Framework:** Flutter 3.7+
- **State Management:** flutter_riverpod
- **Navigation:** go_router
- **Database:** SQLite (sqflite)
- **Calendar:** table_calendar

## Getting Started

### Prerequisites

- Flutter SDK 3.7+
- Android Studio / Xcode (for mobile)
- VS Code with Flutter extensions (recommended)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd daily_pass

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Building

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

## Project Structure

```
lib/
├── main.dart           # App entry point
├── app.dart            # App configuration
├── app_router.dart     # Navigation routes
├── core/               # Core utilities
├── features/           # Feature modules
│   ├── calendar/       # Calendar component
│   ├── activities/     # Activity management
│   └── settings/       # App settings
├── models/             # Data models
└── providers/          # Riverpod providers
```

## License

MIT License

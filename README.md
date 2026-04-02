# Location Automation App

A cross-platform mobile application (iOS + Android) that automatically switches phone profiles based on geographical zones with on-device ML learning.

## Features

- **Zone Management**: Create, edit, and delete geographical zones with GPS/WiFi/Bluetooth detection
- **Profile System**: Configure ringtone, vibration, unmute, DND, alarms, and timers settings
- **Automatic Detection**: Automatically switches profiles when entering/exiting zones
- **Detection Priority**: Manual > GPS > WiFi > Bluetooth
- **On-Device ML Learning**: Tracks patterns and suggests profile modifications
- **Battery Efficient**: Targets <5% battery usage per day
- **Material3 UI**: Modern, minimal design with consistent elevation and 8dp grid spacing
- **Dark Theme**: Full dark mode with adaptive map tiles (CartoDB Dark Matter), toggleable in Settings
- **Zone Search**: Auto-complete search bar on the map with RTL/Arabic support for quick zone navigation
- **Sound Effects**: Contextual audio feedback for automation toggle, zone creation, editing, and deletion
- **Debug Mode**: Simulate zone entry/exit triggers with on-screen buttons for testing

## Platform Support

- **iOS**: 15+
- **Android**: 10+ (API 29)

## Tech Stack

### Core (Swift)
- Cross-platform Swift using Swift SDK for Android
- SQLite.swift for local storage
- On-device ML for pattern detection

### iOS
- Swift/UIKit
- Apple Maps
- Core Location for geofencing

### Android
- Kotlin
- OSMDroid (OpenStreetMap)
- Google Play Services Location

## Project Structure

```
location-automation-app/
├── Sources/
│   ├── Core/           # Shared Swift code
│   │   ├── Learning/   # ML engine
│   │   ├── Location/   # Location services
│   │   ├── Models/     # Data models
│   │   ├── Storage/   # Database
│   │   └── Logging/   # Logger
│   ├── iOS/           # iOS-specific code
│   │   ├── Location/  # iOS location
│   │   ├── Profile/   # iOS profile service
│   │   └── UI/        # View controllers
│   └── Android/       # Android-specific code
│       ├── Location/  # Android location
│       ├── Profile/  # Android profile service
│       └── UI/        # Activities
├── android/           # Android Gradle project
│   └── app/
├── Tests/             # Swift tests
└── Package.swift      # Swift package manifest
```

## Building

### iOS (requires macOS/Xcode)
```bash
xcodebuild -scheme LocationAutomation -configuration Debug build
```

### Android
```bash
cd android
./gradlew assembleDebug
```

### Swift (Linux for testing)
```bash
swift test
```

## Architecture

### Detection Priority
1. **Manual**: User manually triggers zone
2. **GPS**: Primary location detection via geofencing
3. **WiFi**: Fallback when WiFi network matches zone
4. **Bluetooth**: Last resort for detection

### Learning System
- **PatternTracker**: Records entry/exit times and durations
- **DeviationDetector**: Analyzes patterns for anomalies
- **SuggestionGenerator**: Proposes profile modifications
- **SuggestionApprovalManager**: User approval workflow

### Profile Types
| Setting | Description |
|---------|-------------|
| Ringtone | Enable/disable ringtone |
| Vibration | Enable/disable vibration |
| Unmute | Override DND |
| DND | Do Not Disturb mode |
| Alarms | Allow alarm sounds |
| Timers | Allow timer sounds |

## Permissions

### iOS
- Location (Always)
- Bluetooth

### Android
- ACCESS_FINE_LOCATION
- ACCESS_COORDINATES
- ACCESS_BACKGROUND_LOCATION
- BLUETOOTH
- FOREGROUND_SERVICE
- POST_NOTIFICATIONS

## Testing

### Unit Tests
```bash
swift test
```

### Android Instrumented Tests
```bash
cd android
./gradlew connectedAndroidTest
```

## License

MIT